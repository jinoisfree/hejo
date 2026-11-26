#if HEJO_HISTORY_TRANSPORT_TEST
import Foundation
import AppKit

private final class HistoryTransportCredentials: GateCredentialStore {
    private var token: String?
    func read(account: String) -> String? { token }
    func save(_ token: String, account: String) -> Bool { self.token = token; return true }
    func delete(account: String) { token = nil }
}
@main struct HistoryTransportHarness {
    @MainActor static func bubbleHistoryCheck(store:LocalStore,fixture:ConversationMessage) throws {
        do {
            try HistoryHTTP.validate(["id":"bad-state","status":"missing","eligible":true],kind:"message_state")
            throw HistoryFailure.server("invalid_message_state_accepted",retryable:false)
        } catch HistoryFailure.invalidResponse {}
        let bubble=BubbleReveal(store:store),now=Date(timeIntervalSince1970:1800000000)
        var input=BubbleReveal.Input(ready:true,history:.init(baseline:10,through:10,deletedIDs:[]))
        guard !bubble.update(input,now:now) else {throw HistoryFailure.invalidResponse}
        input.messages=[fixture]
        guard !bubble.update(input,now:now),bubble.notice.kind == .idle else {throw HistoryFailure.server("old_body_nudge",retryable:false)}
        var fresh=fixture;fresh.id="fresh-bubble";fresh.seq=11;fresh.latestSeq=11
        fresh.text="답변\nhttps://example.invalid/answer"
        input.messages=[fresh];input.history = .init(baseline:10,through:11,deletedIDs:[])
        guard bubble.update(input,now:now),bubble.notice.body==fresh.text,bubble.notice.actions.first == .link(URL(string:"https://example.invalid/answer")!) else {throw HistoryFailure.invalidResponse}
        // Eviction cannot dismiss a visible reply or destroy its original actions.
        input.messages=[]
        guard !bubble.update(input,now:now),bubble.notice.id==fresh.id,bubble.remindLater(now:now) else {throw HistoryFailure.invalidResponse}
        _=bubble.update(input,now:now.addingTimeInterval(1801))
        guard bubble.reminders[fresh.id] != nil,bubble.notice.kind == .idle else {throw HistoryFailure.server("unloaded_reminder_consumed",retryable:false)}
        input.messages=[fresh]
        guard !bubble.update(input,now:now.addingTimeInterval(1802)),bubble.notice.headline.hasSuffix("다시 알림"),bubble.reminders.isEmpty else {throw HistoryFailure.invalidResponse}
        guard bubble.remindLater(now:now) else {throw HistoryFailure.invalidResponse}
        input.messages=[];input.history = .init(baseline:10,through:12,deletedIDs:[fresh.id])
        _=bubble.update(input,now:now)
        guard bubble.reminders.isEmpty else {throw HistoryFailure.server("deleted_reminder_retained",retryable:false)}
        // Reconnection raises the baseline; loading a newer historical body is not live.
        fresh.seq=19;fresh.latestSeq=19;input.messages=[fresh]
        input.history = .init(baseline:20,through:20,deletedIDs:[])
        guard !bubble.update(input,now:now) else {throw HistoryFailure.invalidResponse}
    }
    @MainActor static func thumbnailBudgetCheck(directory:URL) throws {
        let url=directory.appendingPathComponent("thumbnail-fixture.png")
        guard let bitmap=NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:640,pixelsHigh:320,bitsPerSample:8,
            samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:640*4,bitsPerPixel:32),
            let data=bitmap.representation(using:.png,properties:[:]) else {throw HistoryFailure.invalidResponse}
        try data.write(to:url);defer {try? FileManager.default.removeItem(at:url)}
        let cache=AttachmentThumbnailCache(byteLimit:524288)
        let tile=FileTile(file:.init(fileID:"fixture",name:"fixture.png",mime:"image/png",size:data.count))
        weak var first:NSImage?
        try autoreleasepool {
            let image=try cache.load(url,id:"first");first=image;tile.picture=image
            guard image.size==CGSize(width:512,height:256),cache.cachedBytes==524288,
                  FileTile.imageSize(image)==CGSize(width:220,height:110) else {throw HistoryFailure.server("thumbnail_decode_bound",retryable:false)}
        }
        try autoreleasepool {
            let image=try cache.load(url,id:"second")
            guard cache.cachedBytes==524288,cache.retainedBytes==1048576,cache.displayedExcessBytes==524288,
                  cache.image("first") === tile.picture,cache.image("second") === image else {throw HistoryFailure.server("thumbnail_cache_budget",retryable:false)}
        }
        autoreleasepool {tile.picture=nil}
        guard first==nil,cache.retainedBytes==524288,cache.displayedExcessBytes==0 else {throw HistoryFailure.server("thumbnail_display_retained",retryable:false)}
        cache.removeAll()
        guard cache.cachedBytes==0,cache.retainedBytes==0,cache.image("second")==nil else {throw HistoryFailure.invalidResponse}
    }
    @MainActor static func rendererLifetimeCheck() async throws {
        let post=NativeThreadCard.Post(id:"lifetime-post",mine:false,text:NSAttributedString(string:"fixture body"),speaker:"Fixture",time:"",avatar:ProfileAvatar(),nameColor:.labelColor,openLink:{_ in})
        let content=NativeThreadCard.Content(id:"lifetime-card",top:[.post(post)],replies:nil,rail:nil,actions:[],deleting:nil,
            style:.init(inset:12,fill:0,stroke:nil,lineWidth:1),bell:nil,onBell:{},clickCard:{},bubbleWidth:300,quiet:.secondaryLabelColor,expanded:false)
        let card=NativeThreadCard(frame:.zero)
        card.configure(NativeThreadCard.layout(content,width:320))
        guard card.subviews.compactMap({$0 as? NSTextView}).contains(where:{$0.string=="fixture body"}) else {throw HistoryFailure.invalidResponse}
        var empty=content;empty.top=[]
        card.configure(NativeThreadCard.layout(empty,width:320))
        guard card.subviews.compactMap({$0 as? NSTextView}).allSatisfy({$0.string.isEmpty}) else {throw HistoryFailure.server("hidden_text_retained",retryable:false)}
        card.configure(NativeThreadCard.layout(content,width:320));card.releaseContent()
        guard card.value==nil,card.subviews.compactMap({$0 as? NSTextView}).allSatisfy({$0.string.isEmpty}) else {throw HistoryFailure.invalidResponse}
        let list=NativeThreadList(frame:NSRect(x:0,y:0,width:360,height:180))
        list.clock={10};list.automaticallyTicks=false;list.reduceMotion={true}
        list.show([content],identity:"fixture",historyMode:true)
        list.readerInput(wheel:true)
        list.show([content],identity:"fixture",historyMode:true)
        guard list.hasDeferredUpdate else {throw HistoryFailure.invalidResponse}
        list.show([],identity:"fixture",historyMode:true)
        guard !list.hasDeferredUpdate,list.contents.isEmpty,list.layouts.isEmpty else {throw HistoryFailure.server("evicted_render_deferred",retryable:false)}
        list.show([content],identity:"budget",historyMode:true)
        guard list.renderedTextPayloadBytes==24 else {throw HistoryFailure.server("shared_text_double_counted",retryable:false)}
        list.textPayloadBudgetBytes=32
        list.readerInput(wheel:true)
        var replacement=content
        var replacementPost=post;replacementPost.text=NSAttributedString(string:"changed body")
        replacement.top=[.post(replacementPost)]
        list.show([replacement],identity:"budget",historyMode:true)
        guard !list.hasDeferredUpdate,list.renderedTextPayloadBytes==24 else {throw HistoryFailure.server("over_budget_deferred_text",retryable:false)}
        list.textPayloadBudgetBytes=8
        guard list.textPayloadExcessBytes>=16 else {throw HistoryFailure.server("required_text_excess_hidden",retryable:false)}
        list.show([],identity:"budget",historyMode:true)
        guard list.renderedTextPayloadBytes==0,list.textKitPayloadBytes==0 else {throw HistoryFailure.server("removed_text_budget_retained",retryable:false)}
        list.textPayloadBudgetBytes=10*1024*1024
        let window=NSWindow(contentRect:NSRect(x:0,y:0,width:360,height:180),styleMask:[.titled],backing:.buffered,defer:false)
        window.contentView=list;window.orderFrontRegardless()
        defer {window.orderOut(nil)}
        weak var captured:NSObject?
        autoreleasepool {
            let token=NSObject();captured=token
            var cards:[NativeThreadCard.Content]=[]
            for index in 0..<8 {
                var item=content;item.id="recycle-\(index)"
                var body=post;body.id=item.id;body.text=NSAttributedString(string:Array(repeating:"fixture line",count:16).joined(separator:"\n"))
                item.top=[.post(body)];item.clickCard={_ = token.description}
                cards.append(item)
            }
            list.show(cards,identity:"recycle",historyMode:true)
        }
        list.contentView.scroll(to:.zero);list.layoutSubtreeIfNeeded()
        guard let first=list.table.view(atColumn:0,row:0,makeIfNecessary:true) as? NativeThreadCard else {throw HistoryFailure.server("fixture_no_real_cell",retryable:false)}
        guard first.value?.content.id=="recycle-0",captured != nil else {throw HistoryFailure.invalidResponse}
        list.contentView.scroll(to:NSPoint(x:0,y:list.table.bounds.height-100));list.reflectScrolledClipView(list.contentView)
        for _ in 0..<100 {
            list.layoutSubtreeIfNeeded()
            if first.value?.content.id != "recycle-0" {break}
            try await Task.sleep(nanoseconds:10_000_000)
        }
        guard first.value?.content.id != "recycle-0" else {throw HistoryFailure.server("offscreen_cell_kept_content",retryable:false)}
        list.show([],identity:"recycle",historyMode:true);list.layoutSubtreeIfNeeded()
        for _ in 0..<100 {
            if captured==nil {break}
            try await Task.sleep(nanoseconds:10_000_000)
        }
        guard captured==nil,list.contents.isEmpty,list.layouts.isEmpty,first.value==nil else {throw HistoryFailure.server("recycled_callback_retained",retryable:false)}
    }
    @MainActor static func main() async throws {
#if HEJO_LEGACY_REFERENCE
        let legacyArgs = CommandLine.arguments
        if legacyArgs.count > 6, legacyArgs[5] == "autoload-legacy" {
            let directory = URL(fileURLWithPath:legacyArgs[3])
            let store = try LocalStore(directory:directory,historyMode:false)
            let client = GateClient(store:store,credentials:HistoryTransportCredentials())
            defer { client.stop() }
            try await HistoryAutoloadHarness.runLegacy(client:client,args:legacyArgs)
            return
        }
#endif

        let fixtureKey=ConversationKey(employee:"alpha",thread:"11111111-1111-4111-8111-111111111111")
        let fixture=ConversationMessage(id:"fixture",key:fixtureKey,role:"employee",text:"첫 글",files:[.init(fileID:"fixture-file",name:"sample.txt",mime:"text/plain",size:1)],buttons:[],replyState:"answered",seq:1,latestSeq:1,timestamp:"2026-01-01T00:00:00Z",clientMessageID:nil)
        let formatted=ThreadTools.copy([fixture],key:fixtureKey,name:{_ in "직원 A"},zone:TimeZone(secondsFromGMT:0)!)
        guard formatted=="@직원 A 스레드 · 글 1개\nhejo://thread?room=alpha&thread=11111111-1111-4111-8111-111111111111\n\n[2026-01-01 00:00] 직원 A\n첫 글\n[처리 완료]\n📎 sample.txt" else {throw HistoryFailure.invalidResponse}
        do {
            _ = try HistoryHTTP.message(["type":"message","msg_id":"fixture","missing":true,"room":"alpha"])
            throw HistoryFailure.server("fixture_missing_accepted",retryable:false)
        } catch HistoryFailure.invalidResponse {}
        let sidebarItem=SidebarLayout.Item(id:"alpha",name:"Fixture",kind:.direct,freshness:.unknown)
        var sidebarRow=SidebarLayout.Row(kind:.room,id:"alpha",name:"Fixture",items:[sidebarItem])
        let cell=EmployeeSidebarCell(frame:NSRect(x:0,y:0,width:180,height:56));cell.name="Fixture";cell.row=sidebarRow;cell.refreshChrome()
        guard sidebarRow.freshness == .unknown,cell.toolTip?.contains("집계 확인 중") == true,cell.freshnessMark.string as? String == "?" else {throw HistoryFailure.invalidResponse}
        sidebarRow.items[0].freshness = .updating;cell.row=sidebarRow;cell.refreshChrome()
        guard cell.toolTip?.contains("집계 갱신 중") == true,cell.freshnessMark.string as? String == "↻" else {throw HistoryFailure.invalidResponse}
        sidebarRow.items[0].freshness = .ready;cell.row=sidebarRow;cell.refreshChrome()
        guard cell.freshnessMark.isHidden else {throw HistoryFailure.invalidResponse}
        weak var measuredBody:NSAttributedString?
        autoreleasepool {
            let body=NSAttributedString(string:"ephemeral layout fixture",attributes:[.font:NSFont.systemFont(ofSize:13)])
            measuredBody=body
            let first=NativeThreadCard.textSize(body,width:160)
            guard NativeThreadCard.textSize(body,width:160)==first else {fatalError("layout cache changed size")}
        }
        guard measuredBody == nil else {throw HistoryFailure.server("measurement_retains_body",retryable:false)}
        try await rendererLifetimeCheck()
        let args = CommandLine.arguments
        let home = URL(fileURLWithPath:args[3]), legacy = home.appendingPathComponent("cache/frames.jsonl")
        try FileManager.default.createDirectory(at:legacy.deletingLastPathComponent(),withIntermediateDirectories:true)
        let untouched = Data("deliberately invalid legacy fixture\n".utf8); try untouched.write(to:legacy)
        try thumbnailBudgetCheck(directory:home)
        // Match the product default, and reject accidentally opting back into replay.
        let store = try LocalStore(directory:home)
        guard store.historyMode,try Data(contentsOf:legacy)==untouched else {throw HistoryFailure.invalidResponse}
        do {
            _ = try LocalStore(directory:home,historyMode:false)
            throw HistoryFailure.server("legacy_mode_accepted",retryable:false)
        } catch GateFailure.protocolError {}
        guard try Data(contentsOf:legacy)==untouched else {throw HistoryFailure.invalidResponse}
        try bubbleHistoryCheck(store:store,fixture:fixture)
        let client = GateClient(store:store, credentials:HistoryTransportCredentials())
        defer { client.stop() }
        if args.count > 6, args[5] == "alert-seen" {
            try await HistoryAlertSeenHarness.run(client:client,args:args)
            return
        }
        if args.count > 5, args[5] == "autoload" {
            try await HistoryAutoloadHarness.run(client:client,args:args)
            return
        }
        if args.count > 5, ["controller-image","controller-file-budget","controller-restore","controller-group","controller-intent","controller","controller-plan","controller-pages","controller-copyfail","controller-search","controller-noticefail","controller-questions","controller-file","controller-file-delete","controller-file-reconnect","controller-cache","controller-receipt","controller-upload-delete","controller-upload-reconnect","controller-receipt-notfound","controller-receipt-deleted"].contains(args[5]) {
            try await controllerCheck(client:client,args:args)
            return
        }
        let model = try ConversationModel(store:store)
        var historical = 0, live = 0
        client.onFrame = { frame in if frame["type"] as? String == "message" { historical += 1 }; try! model.apply(frame) }
        client.onHistoryFrame = { frame in
            guard frame["type"] as? String == "message", frame["text"] as? String == "fixture live" else { throw HistoryFailure.invalidResponse }
            try model.apply(frame)
            live += 1
        }
        try client.pair(address:args[1],code:args[2],device:"Fixture history client")
        for _ in 0..<250 {
            if client.isConnected || client.status == .updateRequired { break }
            try await Task.sleep(nanoseconds:20_000_000)
        }
        if args.count > 5, args[5] == "unsupported" {
            let preserved = try Data(contentsOf:legacy)
            guard client.status == .updateRequired, !client.isConnected, historical == 0, preserved == untouched else { throw HistoryFailure.invalidResponse }
            print("PASS unsupported server blocked before WebSocket")
            return
        }
        guard client.isConnected, client.historyThrough == 2, historical == 0 else { throw HistoryFailure.invalidResponse }
        let context = try await client.history.context(model.historyContext(generation:1))
        model.history.beginContext(context,generation:1)
        let summaryPage = try await client.history.query(context:context,kind:"threads",scope:"alpha")
        try model.applyHistoryThreads(summaryPage,scope:"alpha",context:context,generation:1)
        let key = ConversationKey(employee:"alpha",thread:args[4])
        guard model.messages.isEmpty, model.history.summaries[key]?.messageCount == 2,
              model.unread(key) == 2, model.originalSeq(key) == 2 else { throw HistoryFailure.invalidResponse }
        let overview = try await client.history.query(context:context,kind:"overview",scope:"alpha")
        try model.applyHistoryOverview(overview["items"] as! [[String:Any]],context:context,generation:1)
        guard model.unread(employee:"alpha") == 2 else { throw HistoryFailure.invalidResponse }
        let target:[String:String] = ["room":"alpha","thread":args[4]]
        let page = try await client.history.query(context:context,kind:"messages",scope:"alpha",fields:["target":target,"limit":1])
        guard let rows = page["items"] as? [[String:Any]], rows.count == 1, rows[0]["text"] as? String == "second",
              let cursor = page["next"] as? String else { throw HistoryFailure.invalidResponse }
        try model.applyHistoryMessages(page,key:key,context:context,generation:1)
        guard model.messages.count == 1, model.unread(key) == 2, model.applied == 2 else { throw HistoryFailure.invalidResponse }
        // HP-02 in the product path: whole-history presentation must survive a partial body page.
        var localDerivations = [String]()
        model.onDerive = { kind, _ in localDerivations.append(kind) }
        model.withRenderValues {
            _ = model.homeThreads
            _ = model.sidebar
            _ = model.notices("alpha")
            _ = model.assessment(key)
        }
        model.onDerive = nil
        guard localDerivations.isEmpty, model.unread(key) == 2, model.messages.count == 1 else {
            throw HistoryFailure.server("local_history_aggregate",retryable:false)
        }
        let older = try await client.history.query(context:context,kind:"messages",scope:"alpha",fields:["target":target,"limit":1,"cursor":cursor])
        guard older["complete"] as? Bool == true else { throw HistoryFailure.invalidResponse }
        let full = try await client.history.query(context:context,kind:"messages",scope:"alpha",fields:["target":target])
        guard let first = (full["items"] as? [[String:Any]])?.first, let ref = first["contentRef"] as? String,
              let id = first["msg_id"] as? String, let revision = first["revision"] as? Int else { throw HistoryFailure.invalidResponse }
        let body = try await client.history.content(reference:ref,id:id,revision:revision)
        guard (body["text"] as? String)?.count == 20000 else { throw HistoryFailure.invalidResponse }
        guard client.liveSequence == 2 else { throw HistoryFailure.invalidResponse }
        FileHandle.standardOutput.write(Data("READY\n".utf8))
        for _ in 0..<250 {
            if live == 1 { break }
            try await Task.sleep(nanoseconds:20_000_000)
        }
        let preserved = try Data(contentsOf:legacy)
        guard live == 1, client.liveSequence == 3, historical == 0, preserved == untouched else { throw HistoryFailure.invalidResponse }
        let cache = try store.historyCache(); try cache.put(body)
        let cached = try cache.message(id); guard cached?["revision"] as? Int == revision else { throw HistoryFailure.invalidResponse }
        var rejectedGap = false
        do { _ = try await client.receive(["v":1,"type":"message","seq":5]) } catch { rejectedGap = true }
        guard rejectedGap, client.liveSequence == 3 else { throw HistoryFailure.invalidResponse }
        var rejectedRow = false
        do { try HistoryHTTP.validate(["msg_id":"fixture","revision":true],kind:"messages") } catch { rejectedRow = true }
        guard rejectedRow, HistoryHTTP.integer(true) == nil else { throw HistoryFailure.invalidResponse }
        let latestID = rows[0]["msg_id"] as! String
        var malformed = rows[0]; malformed["room"] = true
        var rejectedRoom = false
        do { try model.applyHistoryBody(malformed) } catch HistoryFailure.invalidResponse { rejectedRoom = true }
        guard rejectedRoom else { throw HistoryFailure.invalidResponse }
        try model.applyHistoryBody(["msg_id":latestID,"missing":true])
        guard model.messages[latestID] != nil else { throw HistoryFailure.invalidResponse }
        try model.apply(["type":"edit","seq":4,"msg_id":latestID,"text":"new current body","final":true])
        try model.applyHistoryMessages(page,key:key,context:context,generation:1)
        guard model.messages[latestID]?.text == "new current body", model.applied == 4 else { throw HistoryFailure.invalidResponse }
        try model.apply(["type":"delete","seq":5,"msg_id":latestID])
        try model.applyHistoryMessages(page,key:key,context:context,generation:1)
        guard model.messages[latestID] == nil, model.applied == 5 else { throw HistoryFailure.invalidResponse }
        let read = try await client.history.query(context:context,kind:"read_plan",scope:"alpha",fields:["action":"thread","target":target])
        let changes = read["changes"] as! [String:String]
        let intent = model.history.intentGeneration
        model.select(key,markRead:false)
        var rejectedIntent = false
        do { try model.applyHistoryReadPlan(changes,context:context,generation:1,intent:intent) } catch HistoryFailure.changed { rejectedIntent = true }
        guard rejectedIntent, model.memberState.read("thread:alpha/"+args[4]) == 0 else { throw HistoryFailure.invalidResponse }
        try model.applyHistoryReadPlan(changes,context:context,generation:1,intent:model.history.intentGeneration)
        guard model.memberState.read("thread:alpha/"+args[4]) == 3, model.history.context == nil else { throw HistoryFailure.invalidResponse }
        var rejectedContext = false
        do { try model.applyHistoryThreads(summaryPage,scope:"alpha",context:context,generation:1) } catch HistoryFailure.changed { rejectedContext = true }
        guard rejectedContext else { throw HistoryFailure.invalidResponse }
        print("PASS model partial totals, revision guards, selection cancellation and hub read plan")
        print("PASS history preflight, auth, pages, content, live cursor and legacy preservation")
    }
    @MainActor static func controllerCheck(client: GateClient, args: [String]) async throws {
        var budget=HistoryResidentBudget();if args[5]=="controller-restore" {budget.countLimit=(args.count>6 && ["view-root","view-root-owner"].contains(args[6])) ? 1:2}
        let controller = try ConversationController(client:client,downloads:URL(fileURLWithPath:args[3]).appendingPathComponent("downloads"),residentBudget:budget)
        defer { controller.stop() }
        controller.setPaused(true)
        if args[5] == "controller-questions" {
            try controller.model.memberState.set(["read:alpha":"0","thread:alpha/"+args[6]:"4"])
        }
        try client.pair(address:args[1],code:args[2],device:"Fixture controller")
        var restoreStage="connected"
        func stage(_ value:String) {
            restoreStage=value
            if args[5]=="controller-restore" {FileHandle.standardError.write(Data(("RESTORE_STAGE "+value+"\n").utf8))}
        }
        func wait(_ condition: () -> Bool) async throws {
            for _ in 0..<500 {
                if condition() { return }
                if let error = controller.historyLoading.failure { throw error }
                try await Task.sleep(nanoseconds:20_000_000)
            }
            throw HistoryFailure.server("fixture_timeout_"+restoreStage,retryable:false)
        }
        if args[5] == "controller-noticefail" {
            for _ in 0..<500 {
                if controller.historyLoading.failure != nil {break}
                try await Task.sleep(nanoseconds:20_000_000)
            }
            guard controller.historyLoading.failure != nil,controller.model.history.notices.isEmpty,
                  controller.model.history.noticeRows.isEmpty,controller.drawerSnapshot.historyUpdating else {throw HistoryFailure.server("fixture_notice_atomic",retryable:false)}
            controller.historyLoading.retry()
        }
        try await wait { client.isConnected && !controller.historyLoading.busy && !controller.model.history.refreshing }
        controller.setPaused(false)
        let model = controller.model, key = ConversationKey(employee:"alpha",thread:args[4])
        guard model.residentBudget.bytes > 0,model.residentBudget.bytes <= HistoryResidentBudget.maximumBytes,
              model.sidebar.items.first(where:{$0.id == "alpha"})?.freshness == .ready else {throw HistoryFailure.invalidResponse}
        if args[5] == "controller-image" {
            controller.setPaused(true)
            let view=ConversationView(controller:controller,clipboardArea:URL(fileURLWithPath:args[3]).appendingPathComponent("clipboard"))
            let window=NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:700),styleMask:[.titled],backing:.buffered,defer:false)
            window.contentView=view;window.orderFrontRegardless();defer {window.orderOut(nil)}
            func tiles()->[FileTile] {
                var pending:[NSView]=[view],result:[FileTile]=[]
                while let next=pending.popLast() {if let tile=next as? FileTile {result.append(tile)};pending.append(contentsOf:next.subviews)}
                return result
            }
            view.chooseEmployee("alpha");view.chooseThread(key);view.refresh();view.layoutSubtreeIfNeeded()
            try await wait {view.layoutSubtreeIfNeeded();return tiles().filter {$0.picture != nil}.count==2}
            weak var first=tiles().first?.picture
            guard first != nil,tiles().allSatisfy({$0.picture?.size==CGSize(width:512,height:256)}) else {throw HistoryFailure.server("view_thumbnail_decode",retryable:false)}
            // Remove the actual list cells, retain the View/cache, then recreate the cells.
            view.chooseEmployee("beta");view.refresh();view.layoutSubtreeIfNeeded()
            try await wait {tiles().isEmpty}
            guard first != nil else {throw HistoryFailure.server("thumbnail_cache_lost",retryable:false)}
            view.chooseEmployee("alpha");view.chooseThread(key);view.refresh();view.layoutSubtreeIfNeeded()
            try await wait {tiles().filter {$0.picture != nil}.count==2}
            guard tiles().contains(where:{$0.picture === first}) else {throw HistoryFailure.server("thumbnail_not_shared",retryable:false)}
            FileHandle.standardOutput.write(Data("IMAGE_READY\n".utf8))
            try await wait {model.history.deletedThreads[key] != nil}
            view.refresh();view.layoutSubtreeIfNeeded()
            try await wait {tiles().allSatisfy {$0.picture==nil} && first==nil}
            print("PASS authenticated View thumbnails, reuse and deletion release")
            return
        }
        if args[5] == "controller-restore" {
            controller.setPaused(true)
            guard let summary=model.history.summaries[key] else {throw HistoryFailure.invalidResponse}
            model.historyOpenAnchor=summary.rootID
            stage("initial-open")
            controller.historyLoading.open(key)
            try await wait {!controller.historyLoading.busy}
            stage("initial-open-complete")
            guard model.messages[summary.rootID] != nil,let victim=model.evictedHistoryBody(key) else {throw HistoryFailure.server("fixture_no_eviction",retryable:false)}
            let page=model.history.messagePages[key],unread=model.unread(key)
            if args.count>6,["view","view-long","view-cycle","view-root","view-root-owner"].contains(args[6]) {
                let mode = args[6]
                controller.setPaused(false)
                let view = ConversationView(controller:controller,clipboardArea:URL(fileURLWithPath:args[3]).appendingPathComponent("clipboard"))
                let list = view.history
                let window = NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:mode=="view" ? 700:420),
                                      styleMask:[.titled],backing:.buffered,defer:false)
                window.contentView = view
                window.orderFrontRegardless()
                defer { window.orderOut(nil) }

                func visibleBodies() -> Set<String> {
                    let bounds = list.contentView.bounds
                    guard let index = list.layouts.firstIndex(where:{$0.content.id==key.thread}) else { return [] }
                    let row = list.table.rect(ofRow:index)
                    let prefix = "history-body:"
                    let known = Set(model.historyReplyIDs(key)).union([summary.rootID])
                    return Set(list.layouts[index].anchors.compactMap { id, local -> String? in
                        guard local.offsetBy(dx:row.minX,dy:row.minY).intersects(bounds) else { return nil }
                        let message = id.hasPrefix(prefix) ? String(id.dropFirst(prefix.count)):id
                        return known.contains(message) ? message:nil
                    })
                }
                var lastVisible = Set<String>()
                let publish = list.onLoadViewport
                list.onLoadViewport = { cards in
                    guard !cards.isEmpty else { publish?(cards);return }
                    let visible = visibleBodies()
                    for id in visible.subtracting(lastVisible).sorted() where model.evictedHistoryBodies[id] != nil {
                        FileHandle.standardError.write(Data(("RESTORE_VISIBLE "+id+"\n").utf8))
                    }
                    lastVisible = visible
                    publish?(cards)
                }
                defer { list.onLoadViewport = publish }
                func settleVisible() async throws {
                    try await Task.sleep(nanoseconds:600_000_000)
                    try await wait {
                        view.layoutSubtreeIfNeeded()
                        return !controller.historyLoading.busy && !list.hasDeferredUpdate &&
                            visibleBodies().allSatisfy { model.messages[$0] != nil }
                    }
                }
                func wheel(_ delta: Int32) {
                    let event = CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:1,wheel1:delta,wheel2:0,wheel3:0)!
                    list.scrollWheel(with:NSEvent(cgEvent:event)!)
                }
                func scroll(_ y: CGFloat) {
                    list.readerInput(wheel:false)
                    list.contentView.scroll(to:NSPoint(x:0,y:y))
                    list.reflectScrolledClipView(list.contentView)
                    view.layoutSubtreeIfNeeded()
                }
                func assertPreserved() throws {
                    guard model.messages[summary.rootID] != nil,model.unread(key)==unread,
                          model.history.messagePages[key]?.next==page?.next,
                          model.history.messagePages[key]?.complete==page?.complete else {
                        throw HistoryFailure.server("restore_changed_page_or_semantics",retryable:false)
                    }
                }

                view.chooseEmployee("alpha");view.chooseThread(key);view.refresh();view.layoutSubtreeIfNeeded()
                try await settleVisible()
                try assertPreserved()
                if mode=="view-root-owner" {
                    guard model.messages[summary.rootID]?.role=="owner",
                          view.threadContent(summary.thread).actions.contains(where:{$0.identifier=="branch-"+summary.thread.id}) else {
                        throw HistoryFailure.server("unloaded_employee_branch_missing",retryable:false)
                    }
                }
                if mode != "view-root" && mode != "view-root-owner" {
                    stage("view-ready")
                    if mode != "view" {
                        guard list.table.bounds.height > list.contentView.bounds.height+100 else {
                            throw HistoryFailure.server("fixture_not_scrollable",retryable:false)
                        }
                    }
                    scroll(mode=="view" ? 0:40)
                    stage("first-wheel")
                    wheel(40)
                    try await settleVisible()
                    stage("first-restore-complete")
                    try assertPreserved()
                    scroll(0)
                    guard let anchor = list.frame(for:key.thread,message:summary.rootID) else {
                        throw HistoryFailure.server("fixture_no_view_anchor",retryable:false)
                    }
                    let offset = anchor.minY-list.contentView.bounds.minY
                    if mode != "view" {
                        let visible = visibleBodies()
                        guard model.timeline(key).allSatisfy({ $0.id == summary.rootID || !visible.contains($0.id) }) else {
                            throw HistoryFailure.server("fixture_reply_still_visible",retryable:false)
                        }
                    }
                    stage("second-wheel")
                    wheel(40)
                    try await settleVisible()
                    try assertPreserved()
                    guard let restored = list.frame(for:key.thread,message:summary.rootID),
                          abs(restored.minY-list.contentView.bounds.minY-offset)<1 else {
                        throw HistoryFailure.server("fixture_anchor",retryable:false)
                    }
                    stage("anchor-settled")
                }
                if mode=="view-cycle" {
                    FileHandle.standardOutput.write(Data("VIEW_CYCLE_STARTED\n".utf8))
                    for _ in 0..<2 {
                        scroll(max(0,list.table.bounds.maxY-list.contentView.bounds.height))
                        wheel(-40)
                        try await settleVisible()
                        try assertPreserved()
                        scroll(0)
                        wheel(40)
                        try await settleVisible()
                        try assertPreserved()
                    }
                }
                FileHandle.standardOutput.write(Data("RESTORE_READY\n".utf8))
                try await wait { model.history.deletedThreads[key] != nil }
                guard !model.evictedHistoryBodies.values.contains(where:{$0.key==key}),model.messages[summary.rootID]==nil,
                      !controller.historyLoading.restoreEvicted(key) else {
                    throw HistoryFailure.server("deleted_eviction_restored",retryable:false)
                }
                print("PASS evicted body restored without cursor reset")
                return
            }
            guard controller.historyLoading.restoreEvicted(key),controller.historyLoading.restoreEvicted(key) else {throw HistoryFailure.invalidResponse}
            if args.count>6,args[6]=="content-cancel" {
                try await wait {model.historyRestorePin==victim && model.history.contentReferences[victim] != nil}
                guard let seq=model.evictedHistoryBodies[victim]?.seq,
                      let second=model.evictedHistoryBody(key,before:seq) else {throw HistoryFailure.server("fixture_no_content_eviction",retryable:false)}
                try model.memberState.set(["confirm:"+victim:"1"])
                controller.historyLoading.inputsChanged()
                try await wait {!controller.historyLoading.busy}
                guard controller.historyLoading.restoreEvicted(key,before:seq) else {throw HistoryFailure.invalidResponse}
                try await wait {model.historyRestorePin==second && model.history.contentReferences[second] != nil}
                guard model.messages[victim]==nil,model.messages[second]==nil else {throw HistoryFailure.server("content_published_before_response",retryable:false)}
                print("CONTENT_PIN_REPLACED");fflush(stdout)
                try await wait {!controller.historyLoading.busy}
                guard model.messages[second] != nil,model.historyRestorePin==second else {throw HistoryFailure.server("replacement_content_pin_lost",retryable:false)}
                model.pinHistoryViewport([second]);model.pinHistoryViewport([])
                guard controller.historyLoading.restoreEvicted(key,before:seq+1) else {throw HistoryFailure.invalidResponse}
                try await wait {!controller.historyLoading.busy}
                for _ in 0..<2 {
                    for (id,before) in [(second,seq),(victim,seq+1)] {
                        guard model.evictedHistoryBodies[id] != nil,model.messages[id]==nil else {throw HistoryFailure.server("fixture_body_not_reevicted",retryable:false)}
                        guard controller.historyLoading.restoreEvicted(key,before:before) else {throw HistoryFailure.invalidResponse}
                        try await wait {!controller.historyLoading.busy}
                        guard model.messages[id] != nil,model.evictedHistoryBodies[id]==nil,model.messages.count==2,
                              model.messages[summary.rootID] != nil else {throw HistoryFailure.server("repeat_restore_budget_or_root",retryable:false)}
                    }
                }
            }
            if args.count>6,["edit","context"].contains(args[6]) {
                try await wait {model.applied>=5}
                if args[6]=="context" {try model.memberState.set(["confirm:"+victim:"1"]);controller.historyLoading.inputsChanged()}
                FileHandle.standardOutput.write(Data("RESTORE_EDIT_SEEN\n".utf8))
                for _ in 0..<500 {
                    if !controller.historyLoading.busy {break}
                    try await Task.sleep(nanoseconds:20_000_000)
                }
                if args[6]=="edit" {
                    guard (controller.historyLoading.failure as? HistoryFailure) == .server("restore_changed",retryable:true),
                          model.messages[victim]==nil,model.evictedHistoryBodies[victim] != nil else {throw HistoryFailure.server("stale_restore_accepted",retryable:false)}
                    controller.historyLoading.retry()
                    try await wait {!controller.historyLoading.busy}
                } else {
                    guard controller.historyLoading.failure==nil,model.messages[victim]?.text != "restore fixture 2" else {throw HistoryFailure.server("cancelled_restore_accepted",retryable:false)}
                    if model.evictedHistoryBodies[victim] != nil {
                        guard controller.historyLoading.restoreEvicted(key) else {throw HistoryFailure.invalidResponse}
                        try await wait {!controller.historyLoading.busy}
                    }
                }
                guard model.messages[victim]?.text=="restore edited body" else {throw HistoryFailure.server("restore_edit_lost",retryable:false)}
            } else {try await wait {!controller.historyLoading.busy}}
            stage("first-restore-complete")
            guard model.messages[victim] != nil,model.evictedHistoryBodies[victim]==nil,
                  model.messages[summary.rootID] != nil,model.unread(key)==unread,
                  model.history.messagePages[key]?.next==page?.next,
                  model.history.messagePages[key]?.complete==page?.complete else {throw HistoryFailure.server("restore_changed_page_or_semantics",retryable:false)}
            if let other=model.evictedHistoryBody(key),let position=model.evictedHistoryBodies[other]?.seq {
                guard model.evictedHistoryBody(key,before:position) != other else {throw HistoryFailure.invalidResponse}
            }
            stage("anchor-settled")
            FileHandle.standardOutput.write(Data("RESTORE_READY\n".utf8))
            try await wait {model.history.deletedThreads[key] != nil}
            guard !model.evictedHistoryBodies.values.contains(where:{$0.key==key}),model.messages[summary.rootID]==nil,
                  !controller.historyLoading.restoreEvicted(key) else {throw HistoryFailure.server("deleted_eviction_restored",retryable:false)}
            print("PASS evicted body restored without cursor reset")
            return
        }
        if args[5] == "controller-group" {
            controller.setPaused(true)
            let group=ConversationKey(employee:args[6],thread:args[4])
            guard model.timeline(group).isEmpty else {throw HistoryFailure.server("group_body_loaded",retryable:false)}
            controller.setText("group bubble",for:group)
            guard await controller.sendBubbleReply(group) else {throw HistoryFailure.invalidResponse}
            try await wait {!controller.sending}
            guard model.history.summaries[group]?.activity.lastSpeaker == "beta",!controller.working(group),
                  await controller.sendText("/stop",key:group) else {throw HistoryFailure.invalidResponse}
            print("PASS unloaded group control")
            return
        }
        if args[5] == "controller-intent" {
            controller.setPaused(true)
            let retry=ConversationKey(employee:"alpha",thread:args[6])
            guard model.timeline(key).isEmpty,model.timeline(retry).isEmpty else {throw HistoryFailure.invalidResponse}
            controller.setText("bubble fixture",for:key)
            guard await controller.sendBubbleReply(key) else {throw HistoryFailure.server("unloaded_bubble_rejected",retryable:false)}
            try await wait {!controller.sending}
            model.select(retry,notify:false,markRead:false)
            controller.setText("retry fixture",for:retry)
            await controller.sendCurrent(for:retry)
            guard let failure=controller.currentFailures.first,!failure.newPost,failure.key==retry,
                  model.timeline(retry).isEmpty else {throw HistoryFailure.server("reply_misclassified",retryable:false)}
            controller.restoreFailure(failure.id)
            guard controller.currentFailures.isEmpty,controller.draft(for:retry).text=="retry fixture" else {throw HistoryFailure.invalidResponse}
            await controller.retrySaved(retry)
            try await wait {!controller.sending}
            guard controller.currentFailures.isEmpty else {throw HistoryFailure.invalidResponse}
            let place=ConversationKey(employee:"alpha",thread:UUID().uuidString.lowercased())
            controller.registerNewPlace(place);controller.composeKey=place
            model.select(place,notify:false,markRead:false)
            controller.setText("new fixture",for:place)
            await controller.sendCurrent(for:place)
            try await wait {!controller.sending}
            guard controller.currentFailures.isEmpty else {throw HistoryFailure.invalidResponse}
            print("PASS unloaded reply and explicit intent")
            return
        }
        if ["controller-upload-delete","controller-upload-reconnect"].contains(args[5]) {
            let epoch=client.connectionEpoch, revision=client.fileAccessRevision
            let source=client.store.directory.appendingPathComponent("sample.txt")
            try Data("fixture".utf8).write(to:source)
            let pending=Task {try await controller.files.upload(source,employee:"alpha")}
            if args[5] == "controller-upload-delete" {try await wait {client.fileAccessRevision>revision}}
            else {try await wait {client.isConnected && client.connectionEpoch>epoch}}
            print("UPLOAD_FAULT_OBSERVED");fflush(stdout)
            do {_ = try await pending.value;throw HistoryFailure.invalidResponse} catch FileTransferFailure.unavailable {}
            guard !controller.sending,try Data(contentsOf:source)==Data("fixture".utf8) else {throw HistoryFailure.invalidResponse}
            print("PASS upload result rejected after access change")
            return
        }
        if ["controller-receipt-notfound","controller-receipt-deleted"].contains(args[5]) {
            let epoch=client.connectionEpoch
            guard await controller.sendText("boundary fixture",key:key) else {throw HistoryFailure.invalidResponse}
            try await wait {client.connectionEpoch>epoch && !controller.historyLoading.busy && !model.history.refreshing}
            if args[5] == "controller-receipt-notfound" {
                guard controller.sending,controller.failures.isEmpty else {throw HistoryFailure.invalidResponse}
                print("NOTFOUND_READY");fflush(stdout)
                try await wait {!controller.sending}
            } else {
                guard !controller.sending,!model.timeline(key).contains(where:{$0.text == "boundary fixture"}) else {throw HistoryFailure.invalidResponse}
            }
            guard controller.failures.isEmpty else {throw HistoryFailure.invalidResponse}
            print("PASS receipt boundary without automatic resend or failure")
            return
        }
        if args[5] == "controller-receipt" {
            let epoch=client.connectionEpoch
            guard await controller.sendText("receipt fixture",key:key) else {throw HistoryFailure.invalidResponse}
            try await wait {client.connectionEpoch>epoch && !controller.sending && !model.history.refreshing}
            guard controller.failures.isEmpty else {throw HistoryFailure.invalidResponse}
            print("RECEIPT_READY");fflush(stdout)
            try await wait {model.timeline(key).contains{$0.text == "after duplicates"}}
            guard !controller.sending,controller.failures.isEmpty,
                  model.timeline(key).filter({$0.text == "receipt fixture"}).count == 1 else {throw HistoryFailure.invalidResponse}
            print("PASS reconnect receipt and duplicate acknowledgements")
            return
        }
        if args[5] == "controller-cache" {
            guard let first=model.timeline(key).first else {throw HistoryFailure.invalidResponse}
            let before=try client.store.historyCache().message(first.id)
            guard before?["text"] as? String == "first" else {throw HistoryFailure.invalidResponse}
            print("CACHE_READY");fflush(stdout)
            try await wait {model.messages[first.id]?.text == "edited"}
            let cached=try client.store.historyCache().message(first.id)
            // A refreshed page may already replace the invalidated copy; old text must never survive.
            guard cached == nil || cached?["text"] as? String == "edited" else {throw HistoryFailure.invalidResponse}
            print("PASS live edit invalidates persisted body")
            return
        }
        if ["controller-file-delete", "controller-file-reconnect"].contains(args[5]) {
            let file=MessageFile(fileID:args[6],name:"sample.txt",mime:"text/plain",size:7)
            let epoch=client.connectionEpoch, revision=client.fileAccessRevision
            let pending=Task {try await controller.files.openedFile(file,employee:"alpha",date:Date(timeIntervalSince1970:0))}
            if args[5] == "controller-file-delete" {
                try await wait {client.fileAccessRevision>revision}
            } else {
                try await wait {client.isConnected && client.connectionEpoch>epoch}
            }
            print("FILE_FAULT_OBSERVED");fflush(stdout)
            do {_ = try await pending.value;throw HistoryFailure.invalidResponse} catch FileTransferFailure.unavailable {}
            let cache=client.store.directory.appendingPathComponent("cache/history-files")
            guard !FileManager.default.fileExists(atPath:cache.path),
                  !FileManager.default.fileExists(atPath:controller.files.downloads.root.path) else {throw HistoryFailure.invalidResponse}
            if args[5] == "controller-file-reconnect" {
                let fresh=try await controller.files.download(file,employee:"alpha")
                guard try Data(contentsOf:fresh)==Data("fixture".utf8) else {throw HistoryFailure.invalidResponse}
            }
            print("PASS in-flight attachment rejected without cache or Downloads publication")
            return
        }
        if args[5] == "controller-file-budget" {
            controller.setPaused(true)
            let cache=GateHTTP(client:client,downloads:URL(fileURLWithPath:args[3]).appendingPathComponent("budget-downloads"),historyFileByteLimit:8)
            try cache.refreshFileCache()
            let countRoot=client.store.directory.appendingPathComponent("cache/history-files/fixture-count")
            for index in 0..<129 {
                let folder=countRoot.appendingPathComponent(String(index))
                try FileManager.default.createDirectory(at:folder,withIntermediateDirectories:true)
                try Data().write(to:folder.appendingPathComponent("empty"))
            }
            try cache.refreshFileCache()
            let entries=FileManager.default.enumerator(at:countRoot,includingPropertiesForKeys:[.isRegularFileKey])!
            var count=0
            while let url=entries.nextObject() as? URL {
                if try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile==true {count+=1}
            }
            guard count==128,cache.historyFileBytes==0 else {throw HistoryFailure.server("file_count_boundary",retryable:false)}
            let first=MessageFile(fileID:args[6],name:"sample.txt",mime:"text/plain",size:7)
            let second=MessageFile(fileID:args[7],name:"sample.txt",mime:"text/plain",size:7)
            let opening=Task {try await cache.openedFile(first,employee:"alpha",date:Date(timeIntervalSince1970:0))}
            defer {opening.cancel()}
            for _ in 0..<500 {
                try cache.refreshFileCache()
                if cache.historyPinnedFileBytes==7 {break}
                try await Task.sleep(nanoseconds:20_000_000)
            }
            guard cache.historyPinnedFileBytes==7 else {throw HistoryFailure.server("fixture_file_not_pinned",retryable:false)}
            let other=try await cache.download(second,employee:"alpha")
            guard cache.historyFileBytes==14,cache.historyFileExcessBytes==6 else {throw HistoryFailure.server("active_file_evicted",retryable:false)}
            try cache.refreshFileCache()
            guard cache.historyFileBytes==7,cache.historyPinnedFileBytes==7,!FileManager.default.fileExists(atPath:other.path) else {throw HistoryFailure.server("idle_file_not_evicted",retryable:false)}
            if args.count>8,args[8]=="cancel" {
                opening.cancel()
                do {_ = try await opening.value;throw HistoryFailure.server("cancelled_file_published",retryable:false)}
                catch is CancellationError {}
                catch let error as URLError where error.code == .cancelled {}
                try cache.refreshFileCache()
                guard cache.historyPinnedFileBytes==0 else {throw HistoryFailure.server("cancelled_file_pin_retained",retryable:false)}
                let destination=URL(fileURLWithPath:args[3]).appendingPathComponent("budget-downloads")
                let saved=FileManager.default.enumerator(at:destination,includingPropertiesForKeys:[.isRegularFileKey])
                while let url=saved?.nextObject() as? URL {
                    guard try url.resourceValues(forKeys:[.isRegularFileKey]).isRegularFile != true else {throw HistoryFailure.server("cancelled_download_saved",retryable:false)}
                }
                _=try await cache.download(second,employee:"alpha")
                try cache.refreshFileCache()
                guard cache.historyFileBytes==7,cache.historyFileExcessBytes==0 else {throw HistoryFailure.invalidResponse}
                print("FILE_PIN_READY");fflush(stdout)
                print("PASS attachment budget, count boundary and cancelled reader pin release")
                return
            }
            print("FILE_PIN_READY");fflush(stdout)
            let saved=try await opening.value
            try cache.refreshFileCache()
            guard cache.historyPinnedFileBytes==0,try Data(contentsOf:saved.url)==Data("fixture".utf8) else {throw HistoryFailure.server("file_pin_not_released",retryable:false)}
            _=try await cache.download(second,employee:"alpha")
            try cache.refreshFileCache()
            guard cache.historyFileBytes==7,cache.historyFileExcessBytes==0,FileManager.default.fileExists(atPath:saved.url.path) else {throw HistoryFailure.invalidResponse}
            print("PASS attachment budget, active file pin, release and Downloads preservation")
            return
        }
        if args[5] == "controller-file" {
            let file=MessageFile(fileID:args[6],name:"sample.txt",mime:"text/plain",size:7)
            guard model.messages.count==1 else {throw HistoryFailure.invalidResponse}
            let metadata=try await controller.files.attachmentMetadata(employee:"alpha",id:file.fileID)
            guard metadata.file==file else {throw HistoryFailure.invalidResponse}
            var linked:URL?
            controller.onOpenFile={linked=$0}
            let link=try client.authorizedRequest(components:["v1","files","alpha",file.fileID]).url!
            guard controller.openAttachmentLink(link) else {throw HistoryFailure.invalidResponse}
            try await wait {linked != nil}
            guard model.messages.count==1,try Data(contentsOf:linked!)==Data("fixture".utf8) else {throw HistoryFailure.invalidResponse}
            do {_ = try await controller.files.attachmentMetadata(employee:"beta",id:file.fileID);throw HistoryFailure.invalidResponse} catch FileTransferFailure.unavailable {}
            let url=try await controller.files.download(file,employee:"alpha")
            guard url.path.contains("cache/history-files/"),try Data(contentsOf:url)==Data("fixture".utf8) else {throw HistoryFailure.invalidResponse}
            let opened=try await controller.files.openedFile(file,employee:"alpha",date:Date(timeIntervalSince1970:0))
            guard opened.problem==nil,try Data(contentsOf:opened.url)==Data("fixture".utf8) else {throw HistoryFailure.invalidResponse}
            do {_ = try await controller.files.download(file,employee:"beta");throw HistoryFailure.invalidResponse} catch FileTransferFailure.unavailable {}
            controller.setPaused(true);client.stop()
            try await wait {!FileManager.default.fileExists(atPath:url.path)}
            guard FileManager.default.fileExists(atPath:opened.url.path) else {throw HistoryFailure.server("paused_cleanup_removed_download",retryable:false)}
            client.resume()
            try await wait {client.isConnected && client.historySession != nil}
            _=try await controller.files.download(file,employee:"alpha")
            print("FILE_READY");fflush(stdout)
            try await wait {client.fileAccessRevision>0}
            guard !FileManager.default.fileExists(atPath:url.path),FileManager.default.fileExists(atPath:opened.url.path) else {throw HistoryFailure.invalidResponse}
            do {_ = try await controller.files.openedFile(file,employee:"alpha",date:Date(timeIntervalSince1970:0));throw HistoryFailure.invalidResponse} catch FileTransferFailure.unavailable {}
            do {_ = try await controller.files.attachmentMetadata(employee:"alpha",id:file.fileID);throw HistoryFailure.invalidResponse} catch FileTransferFailure.unavailable {}
            print("PASS unloaded attachment auth, namespaced cache and deleted saved-copy rejection")
            return
        }
        if args[5] == "controller-noticefail" {
            guard model.history.notices.count==51,controller.drawerSnapshot.counts[.alert]==51,model.messages.count==1 else {throw HistoryFailure.server("fixture_notice_retry",retryable:false)}
            print("PASS notice page failure is atomic and retry restores complete drawer")
            return
        }
        if args[5] == "controller-questions" {
            guard model.history.questions.count==2,model.history.notices.isEmpty,model.messages.count==1 else {throw HistoryFailure.server("fixture_question_scope",retryable:false)}
            let reminderID=model.history.questions.first!.id
            try client.store.update{$0.reminders=[reminderID:1]}
            try await wait {!model.history.refreshing && !controller.historyLoading.busy}
            let bubble=BubbleReveal(store:client.store),resolver=HistoryBubbleResolver()
            resolver.refresh(client:client,model:model,bubble:bubble,chatOpen:false,now:Date())
            try await wait {resolver.currentStates(context:model.history.context)[reminderID] != nil || resolver.failed}
            guard !resolver.failed,resolver.currentStates(context:model.history.context)[reminderID]?.read == false,
                  resolver.currentBodies(context:model.history.context).map(\.id)==[reminderID],model.messages.count==1 else {throw HistoryFailure.server("fixture_bubble_resolve",retryable:false)}
            let body=resolver.currentBodies(context:model.history.context)[0]
            let received=ThreadTools.date(body.timestamp),clock=Calendar.current
            let meetingStart=clock.date(byAdding:.day,value:1,to:clock.startOfDay(for:received))!.addingTimeInterval(15*3600)
            let meeting=CalendarEntry(identifier:"fixture-meeting",calendarID:"fixture",title:"3시 회의",start:meetingStart,end:meetingStart.addingTimeInterval(3600),calendar:"시험 일정",location:"",notes:"")
            var bubbleInput=BubbleReveal.Input(messages:[body],calendarEvents:[meeting],ready:true,history:.init(baseline:client.historyThrough,through:client.liveSequence,deletedIDs:[],states:resolver.currentStates(context:model.history.context)))
            guard !bubble.update(bubbleInput,now:Date()),bubble.notice.id==reminderID,bubble.reminders.isEmpty,
                  bubble.notice.actions == [.link(URL(string:"https://example.invalid/answer")!),.calendar([meeting]),.remindLater] else {throw HistoryFailure.server("fixture_bubble_original_actions",retryable:false)}
            bubbleInput.questions=[reminderID];_=bubble.update(bubbleInput,now:Date())
            guard bubble.notice.kind == .approval,bubble.notice.detail=="first question" else {throw HistoryFailure.invalidResponse}
            bubbleInput.chatOpen=true;bubbleInput.opened=key;_=bubble.update(bubbleInput,now:Date())
            bubbleInput.chatOpen=false;bubbleInput.messages=[];_=bubble.update(bubbleInput,now:Date())
            guard bubble.historyBodyCandidates(states:resolver.currentStates(context:model.history.context),questions:[reminderID],muted:[],opened:nil,now:Date()).isEmpty else {throw HistoryFailure.invalidResponse}
            let island=IslandModel()
            var input=controller.islandInput
            island.update(input)
            guard island.snapshot().hoverQuestion=="생각 중... · 열기 ›",island.snapshot().expanded==nil else {throw HistoryFailure.invalidResponse}
            // Loading an old body must never look like a new worker reply.
            input.typing=[key:Date().addingTimeInterval(100)];island.update(input)
            controller.historyLoading.open(key)
            try await wait {!controller.historyLoading.busy}
            input=controller.islandInput;island.update(input)
            guard island.snapshot().expanded==nil else {throw HistoryFailure.server("fixture_old_body_event",retryable:false)}
            try model.memberState.set(["confirm:"+model.history.questions[0].id:"1"])
            try await wait {!model.history.refreshing && !controller.historyLoading.busy && model.history.questions.count==1}
            guard controller.islandInput.historyQuestions?.count==1 else {throw HistoryFailure.invalidResponse}
            print("PASS Island complete asked metadata independent of notices and old body loading")
            return
        }
        if args[5] == "controller-search" {
            _ = NSApplication.shared
            let before=Set(model.messages.keys)
            let view=ConversationView(controller:controller,clipboardArea:URL(fileURLWithPath:args[3]).appendingPathComponent("clipboard"))
            view.frame=CGRect(x:0,y:0,width:900,height:720)
            let searchWindow=NSWindow(contentRect:view.frame,styleMask:[.titled],backing:.buffered,defer:false)
            searchWindow.contentView=view;searchWindow.orderFrontRegardless()
            defer {searchWindow.orderOut(nil)}
            view.openSearch();view.search.stringValue="obsolete";view.scheduleSearch()
            view.search.stringValue="needle";view.scheduleSearch()
            try await Task.sleep(nanoseconds:100_000_000)
            guard view.historySearch.busy,view.historySearch.groups.isEmpty else {throw HistoryFailure.server("search_debounce",retryable:false)}
            try await wait {!view.historySearch.busy}
            guard !view.historySearch.failed,view.historySearch.groups.count==1,
                  let hit=view.historySearch.groups.first?.matches.first,
                  hit.snippet=="fixture needle body",!before.contains(hit.id),Set(model.messages.keys)==before else {throw HistoryFailure.server("fixture_search_1",retryable:false)}
            view.searchResults.showHistory(view.historySearch.groups,query:"needle",selection:0,name:model.name,room:{$0})
            guard view.searchResults.stack.arrangedSubviews.count==2 else {throw HistoryFailure.server("fixture_search_2",retryable:false)}
            view.setSidebarWidth(ConversationSidebar.expandedWidth);view.employeeSearch.stringValue="needle";view.refresh()
            try await wait {!view.historySidebarSearch.busy}
            guard view.historySidebarSearch.failed,view.historySidebarSearch.hits.isEmpty else {throw HistoryFailure.server("fixture_search_failure",retryable:false)}
            view.historySidebarSearch.retry()
            try await wait {!view.historySidebarSearch.busy}
            guard view.historySidebarSearch.hits.map(\.id)==[hit.id] else {throw HistoryFailure.server("fixture_search_3",retryable:false)}
            guard let hitRow=view.sidebarRows.firstIndex(where:{$0.kind == .hit}),
                  let hitCell=view.employeeTable.view(atColumn:0,row:hitRow,makeIfNecessary:true) as? SidebarHitCell,
                  hitCell.body.font?.pointSize==11,hitCell.body.maximumNumberOfLines==2,
                  hitCell.body.stringValue=="fixture needle body",
                  hitCell.speaker.stringValue==model.name(hit.speaker),hitCell.room.stringValue==model.header(hit.key.room).title,
                  !view.sidebarRows.contains(where:{$0.kind == .section}),
                  view.employeeTable.numberOfRows==view.sidebarRows.count else {throw HistoryFailure.server("sidebar_table_layout",retryable:false)}
            guard let box=view.searchResults.stack.arrangedSubviews.last as? NSStackView,
                  let header=box.arrangedSubviews.first as? WorkspaceResultHeader else {throw HistoryFailure.invalidResponse}
            header.onClick?()
            try await wait {model.messages[hit.id] != nil && !controller.historyLoading.busy}
            guard model.selected==hit.conversationKey,model.messages[hit.id]?.text=="fixture needle body" else {throw HistoryFailure.server("fixture_search_4",retryable:false)}
            view.refresh()
            try await wait {!view.historySidebarSearch.busy && view.historySidebarSearch.hits.contains(where:{$0.id==hit.id})}
            guard let staleRow=view.sidebarRows.firstIndex(where:{$0.kind == .hit && $0.name==hit.id}) else {throw HistoryFailure.invalidResponse}
            // A new search generation can clear hits before the table consumes its old row.
            // Even with the original body resident, that row must not become a legacy body hit.
            view.historySidebarSearch.reset()
            guard view.tableView(view.employeeTable,heightOfRow:staleRow)==44,
                  view.tableView(view.employeeTable,viewFor:nil,row:staleRow)==nil else {throw HistoryFailure.server("stale_search_used_body",retryable:false)}
            view.openSearch();view.search.stringValue="fixture";view.scheduleSearch()
            try await wait {!view.historySearch.busy}
            guard view.historySearch.groups.count==2 else {throw HistoryFailure.server("search_two_groups",retryable:false)}
            view.moveSearch(1)
            guard view.searchSelection==1 else {throw HistoryFailure.invalidResponse}
            view.moveSearch(-1)
            guard view.searchSelection==0 else {throw HistoryFailure.invalidResponse}
            let chosen=view.historySearch.groups[0].matches[0]
            view.chooseSearch()
            try await wait {!controller.historyLoading.busy && model.messages[chosen.id] != nil}
            guard !view.isSearchOpen,view.highlightedMessageID==chosen.id,model.selected==chosen.conversationKey else {throw HistoryFailure.server("search_return_anchor",retryable:false)}
            view.openSearch();view.search.stringValue="needle";view.scheduleSearch()
            try await wait {!view.historySearch.busy}
            view.layoutSubtreeIfNeeded();view.searchResults.layoutSubtreeIfNeeded()
            guard let resultBox=view.searchResults.stack.arrangedSubviews.dropFirst().first as? NSStackView,
                  let resultHeader=resultBox.arrangedSubviews.first as? WorkspaceResultHeader,
                  abs(resultHeader.frame.width-(view.searchResults.contentSize.width-48))<1,
                  resultHeader.date.frame.maxX>500,resultBox.frame.height<180 else {throw HistoryFailure.server("search_result_layout",retryable:false)}
            let malformed:[String:Any]=["id":"bad","key":["room":"alpha","thread":"fixture"],"snippet":"partial","revision":1]
            do {try HistoryHTTP.validate(malformed,kind:"search");throw HistoryFailure.changed} catch HistoryFailure.invalidResponse {}
            print("PASS server search display, cancellation, unloaded anchor and sidebar")
            return
        }
        if args[5] == "controller-copyfail" {
            _ = NSApplication.shared
            let view=ConversationView(controller:controller,clipboardArea:URL(fileURLWithPath:args[3]).appendingPathComponent("clipboard"))
            let board=NSPasteboard.withUniqueName();defer {board.releaseGlobally()}
            board.setString("fixture original clipboard",forType:.string);view.clipboardBoard=board
            view.copyHistory(key)
            try await wait {!view.historyCopyInProgress}
            guard board.string(forType:.string)=="fixture original clipboard",controller.notice.contains("전체 복사") else {throw HistoryFailure.invalidResponse}
            print("PASS copy final revision failure preserves clipboard")
            return
        }
        if args[5] == "controller-pages" {
            guard model.history.summaries[key]?.messageCount == 51, model.messages.count == 50,
                  let rootID=model.history.summaries[key]?.rootID,model.messages[rootID] == nil else {throw HistoryFailure.invalidResponse}
            var progress:[Int]=[]
            let copied=try await controller.historyLoading.copy(key) { done,_ in progress.append(done) }
            guard progress==[50,51],model.messages.count==50,model.messages[rootID]==nil else {throw HistoryFailure.invalidResponse}
            _ = NSApplication.shared
            let view=ConversationView(controller:controller,clipboardArea:URL(fileURLWithPath:args[3]).appendingPathComponent("clipboard"))
            let board=NSPasteboard.withUniqueName();defer {board.releaseGlobally()}
            board.setString("fixture unchanged",forType:.string);view.clipboardBoard=board
            view.copyHistory(key);view.copyHistory(key)
            try await Task.sleep(nanoseconds:100_000_000)
            guard board.string(forType:.string)=="fixture unchanged",!view.historyCopyInProgress else {throw HistoryFailure.invalidResponse}
            let summary=model.history.summaries[key]!
            let unloaded=view.threadContent(summary.thread)
            guard !unloaded.top.contains(where:{if case .post = $0{return true};return false}),
                  unloaded.replies?.contains(where:{if case .post = $0{return true};return false}) == true else {throw HistoryFailure.invalidResponse}
            controller.historyLoading.olderMessages(key)
            try await wait { !controller.historyLoading.busy }
            guard model.history.messagePages[key]?.complete == true, model.messages[rootID] == nil,
                  model.history.contentReferences[rootID] != nil else {throw HistoryFailure.invalidResponse}
            controller.historyLoading.open(key)
            try await wait { !controller.historyLoading.busy && model.messages[rootID] != nil }
            guard model.messages[rootID]?.text.count == 20000,model.timeline(key).count == 51,
                  model.applied == 51,client.liveSequence == 51 else {throw HistoryFailure.invalidResponse}
            guard copied==ThreadTools.copy(model.timeline(key),key:key,name:model.name,group:false) else {throw HistoryFailure.invalidResponse}
            view.copyHistory(key)
            try await wait {!view.historyCopyInProgress}
            guard board.string(forType:.string)==copied else {throw HistoryFailure.invalidResponse}
            let anchor=model.timeline(key)[1].id
            controller.historyLoading.open(key,anchor:anchor)
            try await wait {!controller.historyLoading.busy}
            guard model.history.messagePages[key]?.anchor==anchor,model.history.messagePages[key]?.next != nil else {throw HistoryFailure.invalidResponse}
            controller.historyLoading.olderMessages(key)
            try await wait {!controller.historyLoading.busy}
            guard model.history.messagePages[key]?.complete==true else {throw HistoryFailure.invalidResponse}
            controller.historyLoading.open(key,anchor:rootID)
            try await wait {!controller.historyLoading.busy}
            guard model.history.messagePages[key]?.newerCount==1 else {throw HistoryFailure.invalidResponse}
            let loaded=view.threadContent(summary.thread)
            guard loaded.top.contains(where:{if case .post(let post) = $0{return post.id==rootID};return false}) else {throw HistoryFailure.invalidResponse}
            try await anchorCheck(loaded)
            print("PASS explicit root, content reference, older page, summary card and stable reader anchor")
            return
        }
        if args[5] == "controller-plan" {
            guard model.history.notices.count==51,model.notices("alpha").flatMap(\.messages).count==51,
                  controller.drawerSnapshot.counts[.alert]==51,model.messages.count==1 else {throw HistoryFailure.server("fixture_complete_notices",retryable:false)}
            let missing=model.history.notices.first(where:{model.messages[$0.id]==nil})!
            controller.todoDrawer.receive(["available":true,"items":[["employee":"alpha","id":"fixture-deadline","title":"fixture","due":"2026-01-01","notice":["message_id":missing.id,"thread":missing.key.thread]]]])
            guard let deadline=(controller.drawerSnapshot.urgent+controller.drawerSnapshot.rest).first(where:{$0.kind == .deadline}),deadline.linked,deadline.key==missing.conversationKey,deadline.messageID==missing.id else {throw HistoryFailure.server("fixture_deadline_anchor",retryable:false)}
            let searchContext=model.history.context!
            let found=try await client.history.search(context:searchContext,query:"fixture",mode:"groups")
            guard found.count==51,Set(found.compactMap{($0["key"] as? [String:String])?["thread"]}).count==51,model.messages.count==1 else {throw HistoryFailure.server("fixture_search_pages",retryable:false)}
            guard model.memberState.read("read:alpha") == 51, model.messages.count == 1 else { throw HistoryFailure.invalidResponse }
            guard model.history.threadOrder[model.isHome ? "home":"alpha"]?.count == 50 else {throw HistoryFailure.invalidResponse}
            controller.historyLoading.olderThreads()
            try await wait { !controller.historyLoading.busy }
            guard model.history.threadOrder[model.isHome ? "home":"alpha"]?.count == 51,model.messages.count == 1 else {throw HistoryFailure.invalidResponse}
            model.markAllRead("alpha")
            for _ in 0..<500 {
                if controller.historyLoading.failure != nil { break }
                try await Task.sleep(nanoseconds:20_000_000)
            }
            guard controller.historyLoading.failure != nil,
                  !model.memberState.items.keys.contains(where:{$0.hasPrefix("thread:alpha/")}) else { throw HistoryFailure.invalidResponse }
            // An explicit second action retries the complete plan; failed pages never committed.
            model.markAllRead("alpha")
            for _ in 0..<500 {
                if model.memberState.items.keys.filter({$0.hasPrefix("thread:alpha/")}).count == 51 { break }
                try await Task.sleep(nanoseconds:20_000_000)
            }
            guard model.memberState.items.keys.filter({$0.hasPrefix("thread:alpha/")}).count == 51 else { throw HistoryFailure.invalidResponse }
            print("PASS controller multi-page read failure is atomic and explicit retry succeeds")
            return
        }
        guard model.history.summaries[key]?.messageCount == 2, model.messages.count == 2,
              model.selected == key, model.memberState.read("read:alpha") == 2,
              model.memberState.read("thread:alpha/"+args[4]) == 0 else { throw HistoryFailure.invalidResponse }
        model.markThreadRead(key)
        try await wait { model.memberState.read("thread:alpha/"+args[4]) == 2 && !controller.historyLoading.busy }
        FileHandle.standardOutput.write(Data("READY\n".utf8))
        try await wait { model.history.summaries[key]?.messageCount == 3 && !model.history.refreshing && !controller.historyLoading.busy }
        guard client.liveSequence == 3, model.applied == 3, model.timeline(key).last?.text == "fixture live",
              model.unread(key) == 1 else { throw HistoryFailure.invalidResponse }
        print("PASS controller bounded bootstrap, atomic read, coalesced live refresh")
    }

    @MainActor static func anchorCheck(_ template:NativeThreadCard.Content) async throws {
        let list=NativeThreadList(frame:CGRect(x:0,y:0,width:500,height:220))
        list.automaticallyTicks=false;list.reduceMotion={true}
        func card(_ id:String)->NativeThreadCard.Content {
            var value=template;value.id=id;value.replies=nil;value.actions=[]
            value.top=[.accessory(id:id,height:300,view:{NSView()})];return value
        }
        list.show([card("one"),card("two")],identity:"fixture")
        list.readerInput(wheel:false)
        list.contentView.scroll(to:CGPoint(x:0,y:140));list.reflectScrolledClipView(list.contentView)
        let before=list.frame(for:"one")!.minY-list.contentView.bounds.minY
        list.show([card("older"),card("one"),card("two")],identity:"fixture")
        try await Task.sleep(nanoseconds:500_000_000)
        let after=list.frame(for:"one")!.minY-list.contentView.bounds.minY
        guard abs(before-after)<1 else {throw HistoryFailure.server("fixture_anchor",retryable:false)}
    }
}
#endif
