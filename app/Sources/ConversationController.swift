import AppKit

struct ConversationDraft {
    var text = ""
    var attachments: [URL] = []
    var picks = Set<String>()
    var isEmpty: Bool { text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty && attachments.isEmpty && picks.isEmpty }
}
struct ConversationFailedSend: Identifiable {
    var id = UUID()
    var key: ConversationKey
    var draft: ConversationDraft
    var newPost: Bool
    var reason: String
    var workspace = ""
    var shown = ""
    var place:ConversationKey? = nil
}
@MainActor final class ConversationController {
    let todoDrawer = TodoDrawerModel()
    var drawerFilter = TodoDrawerModel.Filter.all
    private(set) var drawerOpen = false
    private var drawerChatExpanded = false
    var drawerVisible: Bool { drawerOpen && drawerChatExpanded }
    private var deadlineRequestedAt: Date?
    /// List requests carry an increasing number; responses older than the last applied one are dropped.
    private var deadlineRefs=[String:Int](), listSeq=0, lastAppliedSeq=0
    var deadlineSender: (([String:Any]) async throws -> Void)?
    // Owner close of a deadline card. Memory only: a close waits five seconds (undo), is sent,
    // then the card stays hidden until a list requested after the success confirms the ledger.
    struct PendingClose { let cardID: String, ref: TodoDrawerModel.DeadlineRef, title: String, outcome: String, sendAt: Date }
    private struct InFlightClose { let id: String, employee: String, timeoutAt: Date }
    static let closeUndoSeconds: TimeInterval=5, closeResponseSeconds: TimeInterval=75
    private(set) var pendingClose: PendingClose?
    private var closesInFlight=[String:InFlightClose]()          // card id -> request
    private var closesConfirming=[String:(seq:Int,employee:String)]()
    private(set) var closeFailed=false
    var hiddenDeadlineCards: Set<String> { Set(closesInFlight.keys).union(closesConfirming.keys).union(pendingClose.map{[$0.cardID]} ?? []) }
    var drawerSnapshot: TodoDrawerModel.Snapshot {
        var value=todoDrawer.snapshot(model,filter:drawerFilter,now:model.renderTime,hidden:hiddenDeadlineCards)
        value.undoTitle=pendingClose?.title;value.closeFailed=closeFailed
        return value
    }
    func setDrawerState(open: Bool, chatExpanded: Bool) {
        guard drawerOpen != open || drawerChatExpanded != chatExpanded else{return}
        let wasVisible=drawerVisible
        drawerOpen=open;drawerChatExpanded=chatExpanded
        if drawerVisible && !wasVisible { closeFailed=false;requestDeadlines() }
        notifyChange()
    }
    func pollDeadlines() {
        pollDeadlineCloses()
        guard drawerVisible else{return}
        if deadlineRequestedAt.map({clock().timeIntervalSince($0)>=300}) ?? true {requestDeadlines()}
    }
    /// `force` is the confirmation read after a close: it is asked even while the drawer is folded.
    func requestDeadlines(force:Bool=false) {
        guard drawerVisible || force else{return}
        deadlineRequestedAt=clock()
        let ref=UUID().uuidString.lowercased();listSeq+=1;deadlineRefs[ref]=listSeq
        let frame:[String:Any]=["v":1,"type":"deadlines","id":ref]
        Task { [weak self] in
            guard let self else{return}
            guard self.drawerVisible || force else {self.deadlineRefs[ref]=nil;return}
            do {if let sender=self.deadlineSender {try await sender(frame)}else{try await self.client.send(frame)}}
            catch {self.deadlineRefs[ref]=nil;self.todoDrawer.receive(["available":true,"reason":"command_failed"]);self.notifyChange()}
        }
    }
    func closeDeadline(_ card:TodoDrawerModel.Card,outcome:String) {
        guard card.kind == .deadline,let ref=card.deadlineRef,!hiddenDeadlineCards.contains(card.id) else{return}
        if let earlier=pendingClose {pendingClose=nil;sendClose(earlier)}
        pendingClose=PendingClose(cardID:card.id,ref:ref,title:card.title,outcome:outcome,sendAt:clock().addingTimeInterval(Self.closeUndoSeconds))
        notifyChange()
    }
    func undoClose() {
        guard pendingClose != nil else{return}
        pendingClose=nil;notifyChange()
    }
    /// Runs on the controller's half-second tick whether or not the drawer is visible.
    func pollDeadlineCloses() {
        let now=clock()
        if let waiting=pendingClose,now>=waiting.sendAt {pendingClose=nil;sendClose(waiting);notifyChange()}
        let lost=closesInFlight.filter{now>=$0.value.timeoutAt}.map(\.key)
        for card in lost {failClose(card)}
    }
    private func sendClose(_ close:PendingClose) {
        let ref=UUID().uuidString.lowercased()
        closesInFlight[close.cardID]=InFlightClose(id:ref,employee:close.ref.employee,timeoutAt:clock().addingTimeInterval(Self.closeResponseSeconds))
        let frame:[String:Any]=["v":1,"type":"deadline_close","id":ref,"employee":close.ref.employee,"deadline":close.ref.id,"outcome":close.outcome]
        Task { [weak self] in
            guard let self else{return}
            do {if let sender=self.deadlineSender {try await sender(frame)}else{try await self.client.send(frame)}}
            catch {if self.closesInFlight[close.cardID]?.id==ref {self.failClose(close.cardID)}}
        }
    }
    private func failClose(_ card:String) {
        guard closesInFlight.removeValue(forKey:card) != nil else{return}
        closeFailed=true;notifyChange()
    }
    private func card(forCloseRef ref:String)->String? {closesInFlight.first{$0.value.id==ref}?.key}
    private func receiveClose(_ frame:[String:Any]) {
        guard let ref=frame["ref"] as? String,let card=card(forCloseRef:ref),let sent=closesInFlight[card] else{return}
        guard frame["type"] as? String=="deadline_close_status",frame["ok"] as? Bool==true else{failClose(card);return}
        closesInFlight[card]=nil;closeFailed=false
        // The confirming list is the next one asked: nothing asked earlier may release this card.
        closesConfirming[card]=(listSeq+1,sent.employee)
        requestDeadlines(force:true)
        notifyChange()
    }
    private func receiveDeadlineList(_ frame:[String:Any],number:Int) {
        guard number>lastAppliedSeq else{return}   // an older answer arriving late never overrides a newer one
        lastAppliedSeq=number
        todoDrawer.receive(frame)
        guard frame["type"] as? String != "error",frame["available"] as? Bool==true,frame["reason"]==nil else{return}
        let failed=Set(frame["failed"] as? [String] ?? [])
        for (card,wait) in closesConfirming where wait.seq<=number && !failed.contains(wait.employee) {closesConfirming[card]=nil}
    }
    /// App shutdown: a close still waiting for its five seconds is dropped, never sent.
    func stop() {
        pendingClose=nil;closesInFlight=[:];closesConfirming=[:];closeFailed=false
        timer?.invalidate();timer=nil
    }
    private func resetCloses() {pendingClose=nil;closesInFlight=[:];closesConfirming=[:];closeFailed=false}
    let client: GateClient
    let model: ConversationModel
    let files: GateHTTP
    var calendarEvents: [CalendarEntry] = [] { didSet { notifyChange() } }
    func calendarActions(for message: ConversationMessage) -> [BubbleReveal.Action] {
        guard message.role != "owner", !message.pending else { return [] }
        return BubbleReveal.Action.content(message.text, events: calendarEvents, at: ThreadTools.date(message.timestamp)).filter(\.isCalendar)
    }
    lazy var pictures: PictureCache = { let cache=PictureCache(http:files);cache.onChange={ [weak self] in self?.notifyChange() };return cache }()
    func avatar(_ employee:String) -> ProfileAvatar {
        let person=model.person(matching:employee)
        return ProfileAvatar(color:PictureCodec.color(name:person?.name ?? employee,hex:person?.color),image:pictures.image(person?.avatar))
    }
    func palette(_ employee:String,dark:Bool)->CharacterPalette {
        let colors=model.employees.sorted{$0.name==$1.name ? $0.id<$1.id:$0.name<$1.name}.compactMap { person -> (id:String,color:NSColor)? in
            guard let hex=person.color,let color=MessageFormat.color(hex) else{return nil};return (person.id,color)
        }
        return CharacterPalette.make(hue:CharacterPalette.hues(colors:colors)[employee],dark:dark)
    }
    var pictureSender: ((String,String,Data?) async throws -> String?)?
    func changePicture(kind:String,id:String,url:URL?,png:Data?=nil) async -> String? {
        let address=client.store.settings.address,epoch=client.connectionEpoch,token=client.bearer
        do {
            let data:Data?
            if let png {data=png}
            else if let url { data=try await Task.detached { try PictureCodec.png(Data(contentsOf:url)) }.value } else { data=nil }
            guard address==client.store.settings.address,epoch==client.connectionEpoch,token==client.bearer else { return nil }
            let picture:String?
            if let pictureSender {picture=try await pictureSender(kind,id,data)}
            else {picture=try await files.setPicture(kind:kind,id:id,data:data)}
            guard address==client.store.settings.address,epoch==client.connectionEpoch,token==client.bearer else { return nil }
            return picture
        } catch {
            switch error {
            case FileTransferFailure.invalidFile: notice="이미지 파일만 쓸 수 있어요"
            case FileTransferFailure.tooLarge: notice="사진은 512 KiB까지 쓸 수 있어요"
            case FileTransferFailure.unauthorized: notice="출입증을 확인하지 못했어요. 다시 연결해 주세요."
            default: notice="사진을 바꾸지 못했어요. 연결을 확인해 주세요."
            };return nil
        }
    }
    private var makingRoom=false
    private var reopeningRoom:String?
    func sendFields(_ key:ConversationKey,recipient:String?=nil)->[String:Any] {
        if let room=model.groups[key.employee] {var fields:[String:Any]=["employee":recipient ?? room.lead ?? room.members[0],"room":room.id];if recipient != nil {fields["targeted"]=true};return fields}
        return ["employee":key.employee]
    }
    func roomCommand(_ kind:String,room:Room?=nil,title:String?=nil,description:String?=nil,members:[String]?=nil,lead:String?=nil,archived:Bool?=nil) async {
        guard canSend else {notice="서버에 연결된 뒤 다시 해 주세요.";return}
        var frame:[String:Any]=["v":1,"type":kind]
        if let room {frame["id"]=room.id}
        if kind=="room_save" {frame["title"]=title ?? room?.title ?? "";frame["description"]=description ?? room?.description ?? "";frame["members"]=members ?? room?.members ?? [];frame["lead"]=lead ?? room?.lead ?? ""}
        if let archived {frame["archived"]=archived}
        makingRoom = kind=="room_save" && room==nil
        if kind=="room_archive",archived==false {reopeningRoom=room?.id}
        do {try await client.send(frame)} catch {makingRoom=false;transferFailed(error)}
    }
    private(set) var drafts: [ConversationKey: ConversationDraft] = [:]
    /// The current composer's auto/new/thread place; bubbles use their real thread directly.
    var composeKey:ConversationKey?
    private var newPostPlaces=Set<ConversationKey>()
    func registerNewPlace(_ key:ConversationKey){newPostPlaces.insert(key)}
    private var draftAddress:String
    func prepareDraftAddress(){
        let address=client.store.settings.address;guard address != draftAddress else{return}
        draftBanks[draftAddress]=drafts;drafts=draftBanks[address] ?? [:];draftAddress=address;composeKey=nil
    }
    func savedDraft(_ key:ConversationKey,address:String)->ConversationDraft {
        address==draftAddress ? drafts[key] ?? ConversationDraft():draftBanks[address]?[key] ?? ConversationDraft()
    }
    private var draftBanks:[String:[ConversationKey:ConversationDraft]]=[:]
    func moveDraft(from:ConversationKey?,to:ConversationKey,carry:Bool) {
        if carry,let from,from != to,draft(for:to).isEmpty,let words=drafts.removeValue(forKey:from) {drafts[to]=words}
        composeKey=to
    }
    func folded() {if let key=composeKey ?? model.selected {drafts[key]?.picks=[]};notifyChange()}
    private var reconnectPending = Set<String>()
    private struct PendingSend {var key:ConversationKey;var draft:ConversationDraft;var bubble=false;var workspace:String;var shown:String;var newPost:Bool;var at:Date;var revision:Int;var place:ConversationKey}
    func timeline(_ key:ConversationKey)->[ConversationMessage] {
        let echoes=pending.sorted{$0.value.at<$1.value.at}.filter{$0.value.key==key && $0.value.workspace==replicaAddress}.map{id,item in
            var message=ConversationMessage(id:"pending:"+id,key:key,role:"owner",text:item.draft.text,files:item.draft.attachments.map{MessageFile(fileID:$0.absoluteString,name:$0.lastPathComponent,mime:"application/octet-stream",size:0)},buttons:[],replyState:nil,seq:Int.max,latestSeq:Int.max,timestamp:ISO8601DateFormatter().string(from:item.at),clientMessageID:id)
            message.pending=true;return message
        }
        return model.timeline(key)+echoes
    }
    func includingPending(_ threads:[ConversationThread],scope:[String])->[ConversationThread] {
        var result=threads;var seen=Set(threads.map(\.key))
        for entry in pending.values.sorted(by:{$0.at<$1.at}) where entry.workspace==replicaAddress && scope.contains(entry.key.employee) && seen.insert(entry.key).inserted {
            result.append(ConversationThread(key:entry.key,title:String(entry.draft.text.prefix(48)),preview:entry.draft.text,latestSeq:Int.max))
        }
        return result
    }
    private var pending:[String:PendingSend]=[:]
    private(set) var bubbleProblems:[ConversationKey:String]=[:]
    func draft(for key:ConversationKey)->ConversationDraft {prepareDraftAddress();return drafts[key] ?? ConversationDraft()}
    func bubblePending(_ key:ConversationKey)->Bool {pending.values.contains{$0.key==key}}
    private func failPending(_ entry:PendingSend,reason:String){
        if entry.bubble,entry.workspace != draftAddress {
            let current=draftBanks[entry.workspace]?[entry.key]?.text ?? ""
            draftBanks[entry.workspace,default:[:]][entry.key,default:ConversationDraft()].text=[entry.draft.text,current].filter{!$0.isEmpty}.joined(separator:"\n")
        } else if entry.bubble {
            let current=drafts[entry.key]?.text ?? ""
            drafts[entry.key,default:ConversationDraft()].text=[entry.draft.text,current].filter{!$0.isEmpty}.joined(separator:"\n")
            bubbleProblems[entry.key]=reason
        } else {saveFailure(entry.key,draft:entry.draft,reason:reason,workspace:entry.workspace,shown:entry.shown,newPost:entry.newPost,place:entry.place)}
    }
    /// Text-only use of the same send/pending/confirmation path. Main-composer attachments stay in their draft.
    @discardableResult func sendBubbleReply(_ key:ConversationKey) async ->Bool {
        let words=draft(for:key).text
        guard !words.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty,!bubblePending(key) else{return false}
        guard !model.timeline(key).isEmpty,canSend else {bubbleProblems[key]="연결과 스레드를 확인해 주세요.";notifyChange();return false}
        guard words.utf8.count<=65_536 else {bubbleProblems[key]="너무 큼 · 글은 64 KiB까지 보낼 수 있어요.";notifyChange();return false}
        bubbleProblems[key]=nil;drafts[key,default:ConversationDraft()].text=""
        return await transmit(key,draft:ConversationDraft(text:words),bubble:true)
    }
    private(set) var failures:[ConversationFailedSend]=[]
    private var newPostIDs=Set<String>()
    private var composeRevision=0
    private var followup:ConversationKey?
    var notice = "" { didSet { notifyChange() } }
    var onChange: (() -> Void)?
    private var updateDepth = 0
    private var changePending = false
    var isUpdating: Bool { updateDepth > 0 }
    /// Only explicit synchronous UI transactions coalesce notifications. Other callers
    /// retain immediate delivery, including model/member-state side effects.
    func performUpdates(_ updates: () -> Void) {
        updateDepth += 1
        updates()
        updateDepth -= 1
        if updateDepth == 0 && changePending {
            changePending = false
            onChange?()
        }
    }
    func notifyChange() {
        if isUpdating { changePending = true } else { onChange?() }
    }
    var onConnectionsFrame: (([String:Any])->Void)?
    var onRevealThread: ((ConversationKey)->Void)?
    private var stoppedTargets:[ConversationKey:String]=[:]
    var stopped:Set<ConversationKey> {Set(stoppedTargets.keys)}
    private func controlRecipient(_ key:ConversationKey,working:Bool=false)->String {
        if working,let writer=model.typingPeople[key]?.keys.sorted().first {return writer}
        return stoppedTargets[key] ?? model.timeline(key).last(where:{$0.role != "owner"})?.speaker ?? key.employee
    }
    private(set) var interruptions: [ConversationKey:Date] = [:]
    private(set) var branching: [ConversationKey:Date] = [:]
    private(set) var deleting = Set<ConversationKey>()
    private(set) var confirmingDelete: [ConversationKey:Date] = [:]
    private var checklistSelections:[String:(ReplyChecklist,Set<String>)]=[:]
    func checklistSelection(_ message:ConversationMessage)->ReplyChecklist? {
        guard model.messages[message.id] != nil,var data=message.checklist else{return nil}
        if let stored=checklistSelections[message.id],stored.0==data {data.selected=data.items.filter{stored.1.contains($0)}}
        return data
    }
    func selectChecklist(_ message:ConversationMessage,selected:Set<String>) {
        if model.messages[message.id] != nil,let data=message.checklist {checklistSelections[message.id]=(data,selected)}
    }
    var clock:()->Date = Date.init
    func working(_ key:ConversationKey)->Bool {
        model.typing[key] != nil || model.timeline(key).contains{$0.role != "owner" && ($0.streaming || (!$0.finalized && ThreadTools.thinking($0.text)))}
    }
    func canInterrupt(_ key:ConversationKey)->Bool {
        guard let writer=model.typingPeople[key]?.keys.sorted().first else{return false}
        return model.employees.first{$0.id==writer}?.queued != true
    }
    @discardableResult func openAttachmentLink(_ url: URL) -> Bool {
        guard let endpoint = try? GateClient.endpoint(client.store.settings.address), url.host == endpoint.host, url.port == endpoint.port,
              url.path.hasPrefix("/v1/files/") else { return false }
        let parts = url.pathComponents
        guard parts.count == 5, let message = model.messages.values.first(where: { $0.speaker == parts[3] && $0.files.contains(where: { $0.fileID == parts[4] }) }),
              let file = message.files.first(where: { $0.fileID == parts[4] }) else { transferFailed(FileTransferFailure.unavailable); return true }
        Task { await open(file, employee: message.speaker, date: ThreadTools.date(message.timestamp)) }
        return true
    }
    func openLink(_ url:URL) {
        guard let key=ThreadTools.destination(url),!model.timeline(key).isEmpty else { notice="그 스레드를 불러오지 못했어요";return }
        model.select(key);onRevealThread?(key)
    }
    func branch(_ key:ConversationKey) async {
        if let at=branching[key],clock().timeIntervalSince(at)<6 {return}
        guard canSend else {transferFailed(GateFailure.notConnected);return}
        branching[key]=clock();notifyChange()
        do { try await client.send(["v":1,"type":"thread_branch","id":UUID().uuidString.lowercased(),"room":key.employee,"thread":key.thread,"client_msg_id":UUID().uuidString.lowercased()]) }
        catch { branching[key]=nil;transferFailed(error) }
    }
    func deleteThread(_ key:ConversationKey) async {
        guard !deleting.contains(key) else{return}
        guard let at=confirmingDelete[key],clock().timeIntervalSince(at)<4 else {confirmingDelete=[key:clock()];notifyChange();return}
        guard canSend else {transferFailed(GateFailure.notConnected);return}
        confirmingDelete[key]=nil;deleting.insert(key);notifyChange()
        do { try await client.send(["v":1,"type":"thread_delete","id":UUID().uuidString.lowercased(),"room":key.employee,"thread":key.thread]) }
        catch {deleting.remove(key);transferFailed(error)}
    }
    @discardableResult func sendText(_ text:String,key:ConversationKey,recipient:String?=nil) async -> Bool {
        guard canSend else {transferFailed(GateFailure.notConnected);return false}
        let target=recipient ?? controlRecipient(key,working:text=="/stop")
        if let room=model.groups[key.employee],!room.members.contains(target) {transferFailed(GateFailure.notConnected);return false}
        if text != "/stop" {return await transmit(key,draft:ConversationDraft(text:text),recipient:target)}
        let id=UUID().uuidString.lowercased()
        do {try await client.send(["v":1,"type":"send","id":id,"thread":key.thread,"client_msg_id":id,"text":text].merging(sendFields(key,recipient:target)){$1})}
        catch {transferFailed(error);return false}
        notifyChange();return true
    }

    func stop(_ key:ConversationKey) async {
        guard !stopped.contains(key),canSend else{return}
        stoppedTargets[key]=controlRecipient(key,working:true);if !(await sendText("/stop",key:key,recipient:stoppedTargets[key])) {stoppedTargets.removeValue(forKey:key)}
    }
    private(set) var transferFailure: IslandFailure? { didSet { notifyChange() } }
    private(set) var stateFailure: IslandFailure? { didSet { notifyChange() } }
    private var activeUploads:[ConversationKey:String]=[:]
    private(set) var uploads: [ConversationKey: IslandUpload] = [:] { didSet { notifyChange() } }
    var islandInput: IslandModel.Input {
        IslandModel.Input(messages:Array(model.messages.values).map { var message=$0;if model.confirmed(message.id) {message.replyState=nil};return message },typing:model.typing,
            names:Dictionary(uniqueKeysWithValues:model.employees.map { ($0.id,$0.name) }),
            unread:model.visibleUnreadTotal,selected:model.selected,
            status:client.status,failure:transferFailure ?? stateFailure,uploads:uploads,muted:model.petMuted)
    }
    var onOpenFile: (URL) -> Void = { NSWorkspace.shared.open($0) }
    private(set) var paused = false
    // Presentation delivery pauses, while the gate keeps its authenticated socket and durable replay cache.
    private var pausedFrames: [[String: Any]] = []
    func setPaused(_ value: Bool) {
        guard paused != value else { return }; paused = value
        if !value { let frames = pausedFrames; pausedFrames = []; for frame in frames { receive(frame) } }
        notifyChange()
    }
    private var replicaAddress: String
    private var timer: Timer?
    init(client: GateClient, downloads:URL?=nil) throws {
        self.client = client; replicaAddress = client.store.settings.address;draftAddress=replicaAddress; model = try ConversationModel(store: client.store); files = GateHTTP(client: client,downloads:downloads)
        model.noticeClock={ [weak self] in self?.clock() ?? Date() }
        model.onChange = { [weak self] in
            guard let self else{return}
            let span = ThreeTapDiagnostics.startSpan()
            defer { ThreeTapDiagnostics.endSpan("model_change", span) }
            if self.client.replayComplete {self.model.clearArchivedPins();self.model.clearHomeChannelFlags()}
            self.notifyChange()
        }
        model.memberState.onFailure = { [weak self] failed in
            self?.stateFailure = failed ? IslandFailure(message: "화면 상태를 맞추지 못했어요", firstWords: "") : nil
        }
        model.memberState.onUnpinned = { [weak self] count in self?.notice = "고정 자리 5개를 넘어 \(count)개의 고정을 풀었어요." }
        client.telegram.onChange = { [weak self] in self?.notifyChange() }
        client.onFrame = { [weak self] frame in self?.receive(frame) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self, !self.paused else{return}
                self.pollDeadlines()
                let old=(self.confirmingDelete.count,self.interruptions.count,self.branching.count)
                self.model.expireTyping()
                let now=self.clock();self.confirmingDelete=self.confirmingDelete.filter{now.timeIntervalSince($0.value)<4}
                self.interruptions=self.interruptions.filter{key,at in self.working(key) && !self.model.timeline(key).contains{$0.role=="employee" && ThreadTools.date($0.timestamp)>at}}
                self.branching=self.branching.filter{now.timeIntervalSince($0.value)<6}
                if old != (self.confirmingDelete.count,self.interruptions.count,self.branching.count) {self.notifyChange()}
            }
        }
    }
    deinit { timer?.invalidate() }
    func receive(_ frame: [String: Any]) {
        performUpdates { receiveFrame(frame) }
    }
    private func receiveFrame(_ frame: [String: Any]) {
        let kind=frame["type"] as? String
        if kind=="deadline_close_status" || (kind=="error" && (frame["ref"] as? String).map{card(forCloseRef:$0) != nil} == true) {
            receiveClose(frame);return
        }
        if kind=="deadlines_status" || (kind=="error" && (frame["ref"] as? String).map{deadlineRefs[$0] != nil} == true) {
            guard let ref=frame["ref"] as? String,let number=deadlineRefs.removeValue(forKey:ref) else{return}
            receiveDeadlineList(frame,number:number);notifyChange();return
        }

        if ["connections_status","connection_result"].contains(frame["type"] as? String ?? "") {onConnectionsFrame?(frame);return}
        if paused { pausedFrames.append(frame); return }
        if ["welcome","roster"].contains(frame["type"] as? String ?? "") { pictures.invalidate() }
        if frame["type"] as? String == "welcome" { reconnectPending = Set(pending.keys) }
        if frame["type"] as? String == "sync_done", frame["more"] as? Bool == false {
            let unconfirmed = reconnectPending.intersection(pending.keys)
            reconnectPending = []
            if let id=unconfirmed.sorted().first(where:{pending[$0]?.workspace==replicaAddress}), let entry=pending[id] {
                transferFailure=IslandFailure(message:"전송 확인이 없어요. 내용을 확인하고 다시 보내 주세요.",firstWords:IslandModel.firstLine(entry.draft.text),retryKey:entry.key,isSend:true)
            }
            for id in unconfirmed {
                if let entry=pending.removeValue(forKey:id) {failPending(entry,reason:"전송 확인이 없어요. 내용을 확인하고 다시 보내 주세요.")}
                newPostIDs.remove(id)
            }
        }
        if frame["type"] as? String == "welcome", replicaAddress != client.store.settings.address {
            todoDrawer.receive(["available":false]);resetCloses();prepareDraftAddress();model.resetReplica();newPostIDs=[];followup=nil;transferFailure=nil;bubbleProblems=[:];uploads=[:];activeUploads=[:];stoppedTargets=[:];interruptions=[:];branching=[:];deleting=[];confirmingDelete=[:];checklistSelections=[:];replicaAddress = client.store.settings.address
        }
        if kind=="welcome" {
            deadlineRefs=[:]
            // Requests that were waiting on the old connection are lost; their answers will never come.
            for card in Array(closesInFlight.keys) {failClose(card)}
            requestDeadlines()
        }
        let previousRooms=Set(model.groups.keys)
        do { try model.apply(frame) } catch { notice = "대화 기록을 읽지 못했어요. 다시 연결해 주세요." }
        if frame["type"] as? String=="welcome",frame["rooms"] != nil {model.clearArchivedPins()}
        if frame["type"] as? String=="room",let data=frame["room"] as? [String:Any],let id=data["id"] as? String,let room=model.groups[id],client.replayComplete {
            if makingRoom && !previousRooms.contains(id) {makingRoom=false;model.select(employee:id)}
            if reopeningRoom==id,room.archived != true {reopeningRoom=nil;model.restore(id);model.select(employee:id);onRevealThread?(model.selected!)}
            if room.archived==true,model.selected?.employee==id {model.selectHome()}
        }
        if frame["type"] as? String=="room_deleted",let room=frame["id"] as? String {
            drafts=drafts.filter{$0.key.employee != room};pending=pending.filter{$0.value.workspace != replicaAddress || $0.value.key.employee != room};failures.removeAll{$0.workspace==replicaAddress && $0.key.employee==room};bubbleProblems=bubbleProblems.filter{$0.key.employee != room};if followup?.employee==room {followup=nil}
        }
        if let employee=(frame["room"] ?? frame["employee"]) as? String,let thread=frame["thread"] as? String {
            let key=ConversationKey(employee:employee,thread:thread)
            if (frame["branch_from"] as? [String:Any])?["thread"] is String,client.replayComplete {
                model.select(key);onRevealThread?(key)
            }
            if frame["role"] as? String == "owner",frame["text"] as? String != "/stop" { stoppedTargets.removeValue(forKey:key) }
            if frame["role"] as? String == "employee" { interruptions[key]=nil }
            if frame["role"] as? String == "employee",followup==key,!ThreadTools.thinking(frame["text"] as? String ?? "") {
                followup=nil
                if (model.selected?.employee==key.employee || model.isHome && model.homeScope.contains(key.employee)),draft.isEmpty {let home=model.isHome;model.select(key,notify:false,inHome:home);onRevealThread?(key)}
            }
            if !working(key) { interruptions[key]=nil }
        }
        if frame["scope"] as? String == "thread",let room=frame["room"] as? String,let thread=frame["thread"] as? String {
            let key=ConversationKey(employee:room,thread:thread)
            bubbleProblems[key]=nil;pending=pending.filter{$0.value.workspace != replicaAddress || $0.value.key != key};deleting.remove(key);stoppedTargets.removeValue(forKey:key);interruptions[key]=nil
            if followup==key {followup=nil}
            checklistSelections=checklistSelections.filter{model.messages[$0.key] != nil}
        }
        if let id = frame["client_msg_id"] as? String, let entry = pending.removeValue(forKey: id) {
            if newPostIDs.remove(id) != nil,entry.revision==composeRevision {followup=entry.key}
            model.markThreadRead(entry.key)
            transferFailure=nil;notice=""
            if !entry.draft.attachments.isEmpty {Task {await files.keepSent(entry.draft.attachments,date:entry.at)}}
        }
        if frame["type"] as? String == "error" {
            deleting=[];makingRoom=false
            if let ref=frame["ref"] as? String {newPostIDs.remove(ref)}
            let entry=(frame["ref"] as? String).flatMap { pending.removeValue(forKey:$0) }
            let message:String
            switch frame["code"] as? String {
            case "room_deleted":message="이미 삭제한 방이에요."
            case "room_not_found":message="방을 찾지 못했어요."
            case "invalid_room":message="방 이름과 직원 2명 이상, 대표 직원을 확인해 주세요."
            case "unknown_employee":message="직원 명부를 확인해 주세요."
            case "journal_write_failed":message="서버에 저장하지 못했어요. 다시 시도해 주세요."
            case "unknown_file": message = "첨부를 찾지 못했어요. 파일을 다시 첨부해 주세요."
            case "too_large": message = "너무 큼 · 글이나 첨부 크기를 줄여 주세요."
            case "button_expired": message = "만료된 버튼이에요. 새 답장을 확인해 주세요."
            default: message = "요청을 처리하지 못했어요. 다시 시도해 주세요."
            }
            let repair=["unknown_file","too_large","button_expired"].contains(frame["code"] as? String ?? "")
            transferFailure=IslandFailure(message:message,firstWords:entry.map { IslandModel.firstLine($0.draft.text) } ?? "",retryKey:repair ? nil : entry?.key,isSend:entry != nil)
            if let entry {failPending(entry,reason:message)}
        }
        notifyChange()
    }
    var draft: ConversationDraft {prepareDraftAddress();return (composeKey ?? model.selected).flatMap { drafts[$0] } ?? ConversationDraft() }
    var canSend: Bool { client.isConnected && client.replayComplete }
    var sending: Bool { pending.values.contains { $0.workspace == replicaAddress } }
    func setText(_ text: String, for destination: ConversationKey? = nil) {prepareDraftAddress();if let key = destination ?? composeKey ?? model.selected { drafts[key, default: ConversationDraft()].text = text } }
    func mention(_ employee:String) {
        guard let key=composeKey ?? model.selected else{return}
        let name=model.name(employee)
        drafts[key,default:ConversationDraft()].text=WorkspaceMention.toggle(draft.text,name:name)
        if drafts[key]!.picks.contains(employee) {drafts[key]!.picks.remove(employee)} else {drafts[key]!.picks.insert(employee)}
        notifyChange()
    }
    func pickHome(_ employee:String) {
        guard model.homeRecipients.members.contains(where:{$0.id==employee}) else{return}
        cancelFollowup()
        if let key=model.selected,!model.timeline(key).isEmpty {model.selectHome()}
        guard let key=composeKey ?? model.selected else{return}
        let selected=drafts[key]?.picks.contains(employee)==true
        drafts[key,default:ConversationDraft()].picks=selected ? []:[employee]
        notifyChange()
    }
    func cancelFollowup() {composeRevision+=1;followup=nil}
    private func saveFailure(_ key:ConversationKey,draft:ConversationDraft,reason:String,workspace:String?=nil,shown:String?=nil,newPost:Bool?=nil,place draftPlace:ConversationKey?=nil) {
        let address=workspace ?? replicaAddress,place=shown ?? model.selectionIdentity,destinationPlace=draftPlace
        failures.append(.init(key:key,draft:draft,newPost:newPost ?? model.timeline(key).isEmpty,reason:reason,workspace:address,shown:place,place:destinationPlace))
        if address==replicaAddress {notice=reason+" · 보내지 못한 글은 "+(place==model.selectionIdentity ? "입력창 위":"보낸 방의 입력창 위")+" ‘되살리기’로 다시 쓸 수 있어요."}
    }
    var currentFailures:[ConversationFailedSend] {failures.filter{$0.workspace==replicaAddress}}
    var shownFailures:[ConversationFailedSend] {currentFailures.filter{$0.shown==model.selectionIdentity}}
    var elsewhereFailures:[ConversationFailedSend] {currentFailures.filter{$0.shown != model.selectionIdentity}}
    var onRestoreDraft:((ConversationKey,Bool,Bool)->Void)?
    var onShowFailure:((ConversationFailedSend)->Void)?

    func discardFailure(_ id:UUID) {
        guard failures.contains(where:{$0.id==id}) else{return}
        failures.removeAll{$0.id==id};if failures.isEmpty {transferFailure=nil};notice="";notifyChange()
    }
    func restoreFailure(_ id:UUID) {
        guard let failure=failures.first(where:{$0.id==id}) else{return}
        guard failure.workspace==replicaAddress else{return}
        if failure.shown != model.selectionIdentity {onShowFailure?(failure);return}
        if !failure.newPost && model.timeline(failure.key).isEmpty {notice="그 스레드를 아직 불러오지 못했어요. 잠시 뒤 다시 눌러 주세요.";return}
        if !model.timeline(failure.key).isEmpty || model.rooms.contains(where:{$0.id==failure.key.employee}) {
            let inHome=failure.shown==HomeRoom.id
            let key=failure.newPost ? failure.place ?? failure.key:failure.key
            moveDraft(from:composeKey,to:key,carry:model.selected==failure.key)
            let current=drafts[key] ?? ConversationDraft()
            var files=failure.draft.attachments
            for file in current.attachments where !files.contains(file) {files.append(file)}
            guard files.count<=10 else {notice="첨부가 10개를 넘어 되살리지 못했어요. 지금 첨부를 줄인 뒤 다시 눌러 주세요.";return}
            drafts[key]=ConversationDraft(text:[failure.draft.text,current.text].filter{!$0.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty}.joined(separator:"\n"),attachments:files,picks:current.picks.isEmpty ? failure.draft.picks:current.picks)
            failures.removeAll{$0.id==id};model.select(key,notify:false,inHome:inHome)
            onRestoreDraft?(key,failure.newPost,inHome)
            if onRestoreDraft==nil && !failure.newPost {onRevealThread?(key)}
            notice="";transferFailure=nil;notifyChange()
        }
    }

    func retrySaved(_ key:ConversationKey) async {
        if drafts[key]?.isEmpty != false,let item=failures.first(where:{$0.key==key}) {
            restoreFailure(item.id)
            guard !failures.contains(where:{$0.id==item.id}) else{return}
            if item.newPost {await sendCurrent();return}
        }
        await sendCurrent(for:key)
    }
    func addAttachments(_ urls: [URL]) {
        guard let key = composeKey ?? model.selected else { return }
        let existing = drafts[key]?.attachments ?? []
        let result = ClipboardAttachments.validate(urls.filter { !existing.contains($0) }, available: max(0,10-existing.count))
        drafts[key, default: ConversationDraft()].attachments += result.files
        if let message = result.notice { notice = message }; notifyChange()
    }
    func removeAttachment(_ url: URL) { if let key = composeKey ?? model.selected { drafts[key]?.attachments.removeAll { $0 == url }; notifyChange() } }
    func sendCurrent(for destination:ConversationKey?=nil,homeNew:Bool=false,draftFrom:ConversationKey?=nil) async {
        guard let key=destination ?? model.selected else{return}
        let source=draftFrom ?? (destination==nil ? composeKey:nil) ?? key
        let draft=drafts[source] ?? ConversationDraft()
        let home=key.employee==HomeRoom.id || homeNew
        let channel=home ? model.homeChannel:nil,picked=draft.picks.first
        var outgoing=draft,target=key
        if channel != nil {outgoing.text=model.home.channelPost(draft.text,picked:picked)}
        guard !outgoing.text.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty || !outgoing.attachments.isEmpty else{return}
        if home {
            let employee:String
            if let channel {employee=channel.id}
            else {switch model.home.destination(text:outgoing.text,picked:picked) {
                case .refused(let reason):notice=reason;notifyChange();return
                case .employee(let id):employee=id
            }}
            target=ConversationKey(employee:employee,thread:UUID().uuidString.lowercased())
        } else if key==source,newPostPlaces.contains(source) {target=ConversationKey(employee:key.employee,thread:UUID().uuidString.lowercased())}
        guard canSend else {
            let reason=transferMessage(GateFailure.notConnected)
            transferFailure=IslandFailure(message:reason,firstWords:IslandModel.firstLine(outgoing.text),retryKey:target,isSend:true)
            saveFailure(target,draft:outgoing,reason:reason,place:source);drafts[source]=ConversationDraft();notifyChange();return
        }
        guard outgoing.text.utf8.count<=65_536 else {
            let reason="너무 큼 · 글은 64 KiB까지 보낼 수 있어요."
            transferFailure=IslandFailure(message:reason,firstWords:IslandModel.firstLine(outgoing.text),isSend:true)
            saveFailure(target,draft:outgoing,reason:reason,place:source);drafts[source]=ConversationDraft();notifyChange();return
        }
        drafts[source]=ConversationDraft()
        _=await transmit(target,draft:outgoing,place:source)
    }
    private func transmit(_ key:ConversationKey,draft:ConversationDraft,bubble:Bool=false,place:ConversationKey?=nil,recipient:String?=nil) async ->Bool {
        let id = UUID().uuidString.lowercased(), address = client.store.settings.address, epoch = client.connectionEpoch
        let destination=sendFields(key,recipient:recipient ?? (bubble ? controlRecipient(key,working:true):nil))
        if model.timeline(key).isEmpty {composeRevision+=1;followup=nil;newPostIDs.insert(id)}
        let attempt=PendingSend(key:key,draft:draft,bubble:bubble,workspace:replicaAddress,shown:model.selectionIdentity,newPost:model.timeline(key).isEmpty,at:clock(),revision:composeRevision,place:place ?? key)
        pending[id]=attempt;notice="";notifyChange()
        if !draft.attachments.isEmpty {activeUploads[key]=id;uploads[key]=IslandUpload(completed:0,total:draft.attachments.count) }
        defer {if activeUploads[key]==id,address==replicaAddress {uploads[key]=nil;activeUploads[key]=nil}}
        do {
            var uploaded: [MessageFile] = []
            let sizes=try GateHTTP.prepareUploads(draft.attachments)
            for (index,url) in draft.attachments.enumerated() {
                uploaded.append(try await files.upload(url, employee: destination["employee"] as! String,expectedSize:sizes[index]))
                guard address==client.store.settings.address,epoch==client.connectionEpoch,canSend else{throw GateFailure.notConnected}
                if activeUploads[key]==id {uploads[key]=IslandUpload(completed:uploaded.count,total:draft.attachments.count)}
            }
            guard address == client.store.settings.address, epoch == client.connectionEpoch, canSend else { throw GateFailure.notConnected }
            try await client.send(["v":1, "type":"send", "id":id, "thread":key.thread,
                                   "text":draft.text.trimmingCharacters(in:.whitespacesAndNewlines), "client_msg_id":id, "files":uploaded.map(\.fileID)].merging(destination){$1})
            model.markThreadRead(key)
            stoppedTargets.removeValue(forKey:key);if canInterrupt(key) {interruptions[key]=clock()}
        } catch {
            pending[id] = nil;newPostIDs.remove(id)
            let reason=transferMessage(error)
            failPending(attempt,reason:reason)
            if attempt.workspace==replicaAddress {transferFailure=IslandFailure(message:reason,firstWords:IslandModel.firstLine(draft.text),retryKey:key,isSend:true)}
            notifyChange();return false
        }
        notifyChange();return true
    }
    func click(_ button: MessageButton, message: ConversationMessage) async {
        if button.kind=="reply",button.label=="의견" {model.select(message.key);onRevealThread?(message.key);return}
        guard canSend else { transferFailed(GateFailure.notConnected); return }
        do { try await client.send(ConversationModel.click(message: message, button: button)); transferFailure=nil }
        catch { transferFailed(error) }
    }
    private var openingFiles=Set<String>()
    @discardableResult func open(_ file: MessageFile, employee: String, date:Date) async ->Bool {
        guard openingFiles.insert(file.fileID).inserted else{return true}
        defer {openingFiles.remove(file.fileID)}
        notice=""
        do {
            let result=try await files.openedFile(file,employee:employee,date:date)
            onOpenFile(result.url);transferFailure=nil
            if let problem=result.problem {notice=problem;notifyChange()}
            return true
        }
        catch {transferFailed(error);return false}
    }
    private func transferMessage(_ error:Error)->String {
        if let error=error as? OutgoingFileProblem {return error.message}
        switch error {
        case GateFailure.notConnected:return "연결이 복구된 뒤 다시 보내 주세요."
        case FileTransferFailure.tooLarge,GateFailure.tooLarge:return "너무 큼 · 첨부는 50 MiB까지 보낼 수 있어요."
        case FileTransferFailure.unauthorized:return "출입증을 확인하지 못했어요. 다시 연결해 주세요."
        default:return "파일을 처리하지 못했어요. 파일과 연결을 확인해 주세요."
        }
    }
    private func transferFailed(_ error:Error) {
        let message:String
        if case FileTransferFailure.changed=error {message="파일이 바뀌었어요. 다시 첨부해 주세요."}
        else {message=transferMessage(error)}
        transferFailure=IslandFailure(message:message,firstWords:"")
    }
}
