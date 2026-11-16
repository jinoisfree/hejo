import AppKit

struct ConversationDraft {
    var text = ""
    var attachments: [URL] = []
}
@MainActor final class ConversationController {
    let client: GateClient
    let model: ConversationModel
    let files: GateHTTP
    lazy var pictures: PictureCache = { let cache=PictureCache(http:files);cache.onChange={ [weak self] in self?.onChange?() };return cache }()
    func avatar(_ employee:String) -> ProfileAvatar {
        let person=model.employees.first{$0.id==employee}
        return ProfileAvatar(color:PictureCodec.color(name:person?.name ?? employee,hex:person?.color),image:pictures.image(person?.avatar))
    }
    func changePicture(kind:String,id:String,url:URL?) async -> String? {
        let address=client.store.settings.address,epoch=client.connectionEpoch,token=client.bearer
        do {
            let data:Data?
            if let url { data=try await Task.detached { try PictureCodec.png(Data(contentsOf:url)) }.value } else { data=nil }
            guard address==client.store.settings.address,epoch==client.connectionEpoch,token==client.bearer else { return nil }
            let picture=try await files.setPicture(kind:kind,id:id,data:data)
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
    private(set) var drafts: [ConversationKey: ConversationDraft] = [:]
    private var reconnectPending = Set<String>()
    private var pending: [String: (key: ConversationKey, draft: ConversationDraft)] = [:]
    var notice = "" { didSet { onChange?() } }
    var onChange: (() -> Void)?
    var onRevealThread: ((ConversationKey)->Void)?
    private(set) var stopped = Set<ConversationKey>()
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
        model.typing[key] != nil || model.timeline(key).contains{$0.role != "owner" && ($0.streaming || ThreadTools.thinking($0.text))}
    }
    func openLink(_ url:URL) {
        guard let key=ThreadTools.destination(url),!model.timeline(key).isEmpty else { notice="그 스레드를 불러오지 못했어요";return }
        model.select(key);onRevealThread?(key)
    }
    func branch(_ key:ConversationKey) async {
        if let at=branching[key],clock().timeIntervalSince(at)<6 {return}
        guard canSend else {transferFailed(GateFailure.notConnected);return}
        branching[key]=clock();onChange?()
        do { try await client.send(["v":1,"type":"thread_branch","id":UUID().uuidString.lowercased(),"room":key.employee,"thread":key.thread,"client_msg_id":UUID().uuidString.lowercased()]) }
        catch { branching[key]=nil;transferFailed(error) }
    }
    func deleteThread(_ key:ConversationKey) async {
        guard !deleting.contains(key) else{return}
        guard let at=confirmingDelete[key],clock().timeIntervalSince(at)<4 else {confirmingDelete=[key:clock()];onChange?();return}
        guard canSend else {transferFailed(GateFailure.notConnected);return}
        confirmingDelete[key]=nil;deleting.insert(key);onChange?()
        do { try await client.send(["v":1,"type":"thread_delete","id":UUID().uuidString.lowercased(),"room":key.employee,"thread":key.thread]) }
        catch {deleting.remove(key);transferFailed(error)}
    }
    @discardableResult func sendText(_ text:String,key:ConversationKey) async -> Bool {
        guard canSend else {transferFailed(GateFailure.notConnected);return false}
        do {
            let id=UUID().uuidString.lowercased()
            try await client.send(["v":1,"type":"send","id":id,"employee":key.employee,"thread":key.thread,"client_msg_id":id,"text":text])
            if text != "/stop" {stopped.remove(key)}
            if text != "/stop",working(key) {interruptions[key]=clock()}
        } catch {transferFailed(error);return false}
        onChange?()
        return true
    }
    func stop(_ key:ConversationKey) async {
        guard !stopped.contains(key),canSend else{return}
        stopped.insert(key);if !(await sendText("/stop",key:key)) {stopped.remove(key)}
    }
    private(set) var transferFailure: IslandFailure? { didSet { onChange?() } }
    private(set) var stateFailure: IslandFailure? { didSet { onChange?() } }
    private(set) var uploads: [ConversationKey: IslandUpload] = [:] { didSet { onChange?() } }
    var islandInput: IslandModel.Input {
        IslandModel.Input(messages:Array(model.messages.values).map { var message=$0;if model.confirmed(message.id) {message.replyState=nil};return message },typing:model.typing,
            names:Dictionary(uniqueKeysWithValues:model.employees.map { ($0.id,$0.name) }),
            unread:model.visibleUnreadTotal,selected:model.selected,
            status:client.status,failure:transferFailure ?? stateFailure,uploads:uploads,muted:model.muted)
    }
    var onOpenFile: (URL) -> Void = { NSWorkspace.shared.open($0) }
    private var replicaAddress: String
    private var timer: Timer?
    init(client: GateClient) throws {
        self.client = client; replicaAddress = client.store.settings.address; model = try ConversationModel(store: client.store); files = GateHTTP(client: client)
        model.onChange = { [weak self] in self?.onChange?() }
        model.memberState.onFailure = { [weak self] failed in
            self?.stateFailure = failed ? IslandFailure(message: "화면 상태를 맞추지 못했어요", firstWords: "") : nil
        }
        model.memberState.onUnpinned = { [weak self] count in self?.notice = "고정 자리 5개를 넘어 \(count)개의 고정을 풀었어요." }
        client.onFrame = { [weak self] frame in self?.receive(frame) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in
                guard let self else{return}
                let old=(self.confirmingDelete.count,self.interruptions.count,self.branching.count)
                self.model.expireTyping()
                let now=self.clock();self.confirmingDelete=self.confirmingDelete.filter{now.timeIntervalSince($0.value)<4}
                self.interruptions=self.interruptions.filter{key,at in self.working(key) && !self.model.timeline(key).contains{$0.role=="employee" && ThreadTools.date($0.timestamp)>at}}
                self.branching=self.branching.filter{now.timeIntervalSince($0.value)<6}
                if old != (self.confirmingDelete.count,self.interruptions.count,self.branching.count) {self.onChange?()}
            }
        }
    }
    deinit { timer?.invalidate() }
    func receive(_ frame: [String: Any]) {
        if ["welcome","roster"].contains(frame["type"] as? String ?? "") { pictures.invalidate() }
        if frame["type"] as? String == "welcome" { reconnectPending = Set(pending.keys) }
        if frame["type"] as? String == "sync_done", frame["more"] as? Bool == false {
            let unconfirmed = reconnectPending.intersection(pending.keys)
            reconnectPending = []
            if let id=unconfirmed.sorted().first, let entry=pending[id] {
                transferFailure=IslandFailure(message:"전송 확인이 없어요. 내용을 확인하고 다시 보내 주세요.",firstWords:IslandModel.firstLine(entry.draft.text),retryKey:entry.key,isSend:true)
            }
            for id in unconfirmed { pending[id] = nil }
        }
        if frame["type"] as? String == "welcome", replicaAddress != client.store.settings.address {
            model.resetReplica(); drafts = [:]; pending = [:]; transferFailure=nil; uploads=[:];stopped=[];interruptions=[:];branching=[:];deleting=[];confirmingDelete=[:];checklistSelections=[:];replicaAddress = client.store.settings.address
        }
        do { try model.apply(frame) } catch { notice = "대화 기록을 읽지 못했어요. 다시 연결해 주세요." }
        if let employee=frame["employee"] as? String,let thread=frame["thread"] as? String {
            let key=ConversationKey(employee:employee,thread:thread)
            if (frame["branch_from"] as? [String:Any])?["thread"] is String,client.replayComplete {
                model.select(key);onRevealThread?(key)
            }
            if frame["role"] as? String == "owner",frame["text"] as? String != "/stop" { stopped.remove(key) }
            if frame["role"] as? String == "employee" { interruptions[key]=nil }
            if !working(key) { interruptions[key]=nil }
        }
        if frame["scope"] as? String == "thread",let room=frame["room"] as? String,let thread=frame["thread"] as? String {
            let key=ConversationKey(employee:room,thread:thread)
            drafts[key]=nil;pending=pending.filter{$0.value.key != key};deleting.remove(key);stopped.remove(key);interruptions[key]=nil
            checklistSelections=checklistSelections.filter{model.messages[$0.key] != nil}
        }
        if let id = frame["client_msg_id"] as? String, let entry = pending.removeValue(forKey: id) {
            transferFailure=nil
            if drafts[entry.key]?.text == entry.draft.text && drafts[entry.key]?.attachments == entry.draft.attachments { drafts[entry.key] = ConversationDraft() }
        }
        if frame["type"] as? String == "error" {
            deleting=[]
            let entry=(frame["ref"] as? String).flatMap { pending.removeValue(forKey:$0) }
            let message:String
            switch frame["code"] as? String {
            case "unknown_file": message = "첨부를 찾지 못했어요. 파일을 다시 첨부해 주세요."
            case "too_large": message = "너무 큼 · 글이나 첨부 크기를 줄여 주세요."
            case "button_expired": message = "만료된 버튼이에요. 새 답장을 확인해 주세요."
            default: message = "요청을 처리하지 못했어요. 다시 시도해 주세요."
            }
            let repair=["unknown_file","too_large","button_expired"].contains(frame["code"] as? String ?? "")
            transferFailure=IslandFailure(message:message,firstWords:entry.map { IslandModel.firstLine($0.draft.text) } ?? "",retryKey:repair ? nil : entry?.key,isSend:entry != nil)
        }
        onChange?()
    }
    var draft: ConversationDraft { model.selected.flatMap { drafts[$0] } ?? ConversationDraft() }
    var canSend: Bool { client.isConnected && client.replayComplete }
    var sending: Bool { guard let key = model.selected else { return false }; return pending.values.contains { $0.key == key } }
    func setText(_ text: String, for destination: ConversationKey? = nil) { if let key = destination ?? model.selected { drafts[key, default: ConversationDraft()].text = text } }
    func addAttachments(_ urls: [URL]) {
        guard let key = model.selected else { return }
        let existing = drafts[key]?.attachments ?? []
        let result = ClipboardAttachments.validate(urls.filter { !existing.contains($0) }, available: max(0,10-existing.count))
        drafts[key, default: ConversationDraft()].attachments += result.files
        if let message = result.notice { notice = message }; onChange?()
    }
    func removeAttachment(_ url: URL) { if let key = model.selected { drafts[key]?.attachments.removeAll { $0 == url }; onChange?() } }
    func sendCurrent(for destination: ConversationKey? = nil) async {
        guard let key = destination ?? model.selected, !pending.values.contains(where: { $0.key == key }) else { return }
        let draft = drafts[key] ?? ConversationDraft()
        guard !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.attachments.isEmpty else { return }
        guard canSend else { transferFailed(GateFailure.notConnected,for:key); return }
        guard draft.text.utf8.count <= 65_536 else { transferFailure=IslandFailure(message:"너무 큼 · 글은 64 KiB까지 보낼 수 있어요.",firstWords:IslandModel.firstLine(draft.text),isSend:true); return }
        let id = UUID().uuidString.lowercased(), address = client.store.settings.address, epoch = client.connectionEpoch
        pending[id] = (key, draft); notice = ""
        if !draft.attachments.isEmpty { uploads[key]=IslandUpload(completed:0,total:draft.attachments.count) }
        defer { uploads[key]=nil }
        do {
            var uploaded: [MessageFile] = []
            for url in draft.attachments {
                uploaded.append(try await files.upload(url, employee: key.employee))
                uploads[key]=IslandUpload(completed:uploaded.count,total:draft.attachments.count)
            }
            guard address == client.store.settings.address, epoch == client.connectionEpoch, canSend else { throw GateFailure.notConnected }
            try await client.send(["v":1, "type":"send", "id":id, "employee":key.employee, "thread":key.thread,
                                   "text":draft.text.trimmingCharacters(in:.whitespacesAndNewlines), "client_msg_id":id, "files":uploaded.map(\.fileID)])
            stopped.remove(key);if working(key) {interruptions[key]=clock()}
        } catch {
            pending[id] = nil; transferFailed(error,for:key)
        }
        onChange?()
    }
    func click(_ button: MessageButton, message: ConversationMessage) async {
        if button.kind=="reply",button.label=="의견" {model.select(message.key);onRevealThread?(message.key);return}
        if button.kind=="reply",button.label=="확인" {model.confirm(message);return}
        guard canSend else { transferFailed(GateFailure.notConnected); return }
        do { try await client.send(ConversationModel.click(message: message, button: button)); transferFailure=nil }
        catch { transferFailed(error) }
    }
    func open(_ file: MessageFile, employee: String) async {
        do { let url = try await files.download(file, employee: employee); onOpenFile(url); transferFailure=nil }
        catch { transferFailed(error) }
    }
    private func transferFailed(_ error: Error, for key: ConversationKey? = nil) {
        let message:String, retryable:Bool
        switch error {
        case FileTransferFailure.tooLarge, GateFailure.tooLarge: message = "너무 큼 · 첨부는 50 MiB까지 보낼 수 있어요."; retryable=false
        case FileTransferFailure.unauthorized: message = "출입증을 확인하지 못했어요. 다시 연결해 주세요."; retryable=false
        case FileTransferFailure.changed: message = "파일이 바뀌었어요. 다시 첨부해 주세요."; retryable=false
        case GateFailure.notConnected: message = "연결이 복구된 뒤 다시 보내 주세요."; retryable=true
        default: message = "파일을 처리하지 못했어요. 파일과 연결을 확인해 주세요."; retryable=true
        }
        transferFailure=IslandFailure(message:message,firstWords:key.map { IslandModel.firstLine(drafts[$0]?.text ?? "") } ?? "",retryKey:retryable ? key : nil,isSend:key != nil)
    }
}
