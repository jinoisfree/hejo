import AppKit

let controlThread="11111111-1111-4111-8111-111111111111"
let controlMessage="33333333-3333-4333-8333-333333333333"
func controlFrame(_ seq:Int,thread:String=controlThread,text:String="✅ 보고서",role:String="employee")->[String:Any] {
    ["v":1,"type":"message","seq":seq,"msg_id":seq==1 ? controlMessage:UUID().uuidString.lowercased(),"employee":"alpha","thread":thread,"role":role,"text":text,"files":[],"buttons":[],"reply_state":NSNull(),"ts":"2026-01-01T00:00:00Z"]
}
@MainActor func threadToolsTests(outputDirectory:URL?=nil) async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client)
    let model=controller.model,key=ConversationKey(employee:"alpha",thread:controlThread)
    controller.receive(["v":1,"type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    func commit(_ row:[String:Any]) throws {try store.append(row);controller.receive(row)}
    var root=controlFrame(1,text:"첫 글");root["files"]=[["file_id":"55555555-5555-4555-8555-555555555555","name":"sample.txt","mime":"text/plain","size":1]];root["reply_state"]="answered"
    try commit(root)
    let text=ThreadTools.copy(model.timeline(key),key:key,name:model.name,zone:TimeZone(secondsFromGMT:0)!)
    try check(text=="@직원 A 스레드 · 글 1개\nhejo://thread?room=alpha&thread=11111111-1111-4111-8111-111111111111\n\n[2026-01-01 00:00] 직원 A\n첫 글\n[처리 완료]\n📎 sample.txt","AT75 copy exact header, link, timestamp, state and attachment spacing")
    let sharedFile:[String:Any]=["file_id":"66666666-6666-4666-8666-666666666666","name":"shared.txt","mime":"text/plain","size":1]
    var thought=controlFrame(2,text:"생각 중...");thought["files"]=[sharedFile];try commit(thought)
    try check(!ThreadTools.copy(model.timeline(key),key:key,name:model.name).contains("생각 중"),"AT75 excludes thinking")
    try check(ThreadTools.destination(ThreadTools.link(key))==key && ThreadTools.destination(URL(string:"hejo://other?room=alpha&thread=bad")!)==nil,"AT75 link parsing")
    controller.openLink(ThreadTools.link(.init(employee:"alpha",thread:UUID().uuidString.lowercased())))
    try check(controller.notice=="그 스레드를 불러오지 못했어요","AT75 missing link destination")
    model.setVisible(false);model.toggleBell(key)
    try check(model.bell(key)==false && model.unread(key)==0,"AT76 bell marks read")
    model.toggleBell(key);try check(model.bell(key)==true,"AT76 bell undismisses without regressing thread position")
    let reloaded=try ConversationModel(store:try LocalStore(directory:home));try check(reloaded.bell(key)==true,"AT76 bell null persists")
    for (mark,hex) in [("❌","#E01E5A"),("⚠️","#ECB22E"),("✅","#2EB67D"),("📌","#1D9BD1")] {try check(ThreadTools.color(mark+" 제목")==MessageFormat.color(hex),"AT76 status exact hex")}
    try check(ThreadTools.color("제목")==nil,"AT76 ordinary report has no status color")
    var faces=Array(repeating:model.messages[controlMessage]!,count:5)
    for i in faces.indices {faces[i].key.employee="fake-\(i)"}
    try check(ThreadTools.answeredFaces(faces)==["fake-0","fake-1","fake-2"],"AT76 answered faces cap three")
    var answer:String?
    let checklist=ReplyChecklistView(.init(items:["전체","하나","둘"],selected:[],canSkip:true)){answer=$0}
    let chips=checklist.arrangedSubviews.compactMap{$0 as? NSStackView}.flatMap(\.arrangedSubviews).compactMap{$0 as? FileChip}
    chips.first{$0.title=="☐ 전체"}?.invoke?()
    let selectedChips=checklist.arrangedSubviews.compactMap{$0 as? NSStackView}.flatMap(\.arrangedSubviews).compactMap{$0 as? FileChip}
    selectedChips.first{$0.title=="작성"}?.invoke?()
    try check(answer=="선택: 전체","AT76 checklist all answer")
    selectedChips.first{$0.title=="건너뛰기"}?.invoke?();try check(answer=="건너뛰기","AT76 checklist skip")
    try check(ThreadTools.toggle(["전체","하나","둘"],selected:["전체","하나","둘"],label:"하나")==["둘"],"AT76 checklist clears all when one is removed")
    var choicePost=model.messages[controlMessage]!
    choicePost.checklist = .init(items:["전체","하나","둘"],selected:[],canSkip:true)
    controller.selectChecklist(choicePost,selected:["둘"])
    try check(controller.checklistSelection(choicePost)?.selected==["둘"],"AT76 selected reply choices survive accessory recreation")
    choicePost.checklist?.selected=["하나"]
    try check(controller.checklistSelection(choicePost)?.selected==["하나"],"AT76 server checklist revision supersedes stale unsent choices")
    let frozen=model.messages[controlMessage]!.text
    model.toggleCheck(controlMessage,line:0,original:false)
    try check(model.check(controlMessage,line:0,original:false) && model.messages[controlMessage]!.text==frozen,"AT76 check changes only member state")
    try check(WritingSpinner.levels(at:0,reduceMotion:false)==[1,0,0,0.35,0.5,0.7] && WritingSpinner.levels(at:1,reduceMotion:true)==WritingSpinner.levels(at:0,reduceMotion:true),"AT76 six-position fading spinner and reduced motion")
    let ui=ConversationView(controller:controller);ui.frame=CGRect(x:0,y:0,width:720,height:650)
    for day in 2...3 {var row=controlFrame(day+1,thread:UUID().uuidString.lowercased(),text:"| A | B |\n| :-- | --: |\n| left | right |");row["ts"]="2026-01-0\(day)T00:00:00Z";if day==2 {row["files"]=[sharedFile]};try commit(row)}
    ui.refresh();ui.layoutSubtreeIfNeeded()
    try check(ui.history.contents.filter{$0.id.hasPrefix("date:")}.count==3,"AT76 three day boundaries")
    let tablePosts=ui.history.contents.flatMap(\.top).compactMap{piece -> NativeThreadCard.Post? in if case .post(let p)=piece{return p};return nil}.filter{$0.text.string.contains("left")}
    try check(tablePosts.count==2,"AT76 table posts stay in native cards")
    var sawRight=false
    tablePosts.first?.text.enumerateAttribute(.paragraphStyle,in:NSRange(location:0,length:tablePosts.first!.text.length)){value,_,_ in
        if let style=value as? NSParagraphStyle,!style.textBlocks.isEmpty,style.alignment == .right {sawRight=true}
    }
    try check(sawRight,"AT76 table cells use TextKit right alignment")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        let window=NSWindow(contentRect:ui.frame,styleMask:[.titled],backing:.buffered,defer:false);window.contentView=ui;window.orderFrontRegardless()
        await pause(0.2);ui.layoutSubtreeIfNeeded();ui.displayIfNeeded()
        if let image=ui.bitmapImageRepForCachingDisplay(in:ui.bounds) {ui.cacheDisplay(in:ui.bounds,to:image);try image.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task25-hejo-dates-table.png"))}
        window.orderOut(nil)
    }
    let exclusive=home.appendingPathComponent("cache/files/55555555-5555-4555-8555-555555555555"),shared=home.appendingPathComponent("cache/files/66666666-6666-4666-8666-666666666666")
    for directory in [exclusive,shared] {try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true);try Data("fake".utf8).write(to:directory.appendingPathComponent("file.txt"))}
    let point:[String:Any]=["v":1,"type":"delete","seq":5,"msg_id":controlMessage,"scope":"thread","room":"alpha","thread":controlThread,"at":"2026-01-04T00:00:00Z"]
    try commit(point)
    try check(model.timeline(key).isEmpty && store.records.prefix(2).allSatisfy{$0["type"] as? String=="delete" && $0["text"]==nil && $0["files"]==nil},"AT75 scope purges view and durable cache at same seq")
    try check(controller.checklistSelection(choicePost)==nil,"AT75 deletion also releases unsent checklist choices and rejects stale accessories")
    try check(!FileManager.default.fileExists(atPath:exclusive.path) && FileManager.default.fileExists(atPath:shared.path),"AT75 local exclusive attachment cache removed, shared attachment retained")
    try check(try LocalStore(directory:home).records.count==5,"AT75 compacted cache recovers contiguous cursor")
    let unknown:[String:Any]=["v":1,"type":"future_kind","seq":6]
    _=try await client.receive(["v":1,"type":"welcome","employees":[],"head_seq":5])
    _=try await client.receive(unknown)
    try check(store.settings.applied==6 && model.applied==6,"AT75 unknown durable frame advances both cursors")
    print("THREAD_TOOLS_UNIT_PASS")
}

@MainActor func threadNetwork(_ args:[String]) async throws {
    let store=try LocalStore(directory:URL(fileURLWithPath:args[2])),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try ConversationController(client:client)
    defer {client.stop()}
    let ui=ConversationView(controller:controller);ui.frame=CGRect(x:0,y:0,width:720,height:650)
    try client.pair(address:args[3],code:"test_code-12",device:"Thread fixture")
    try await waitFor{client.replayComplete && controller.model.messages[controlMessage] != nil}
    let key=ConversationKey(employee:"alpha",thread:controlThread),post=controller.model.messages[controlMessage]!
    await controller.click(post.buttons[0],message:post)
    await controller.click(post.buttons[1],message:post)
    try check(controller.model.confirmed(post.id),"AT76 opinion/confirm are local member choices")
    await controller.click(post.buttons[2],message:post)
    try await waitFor{controller.model.messages[controlMessage]?.replyState=="answered"}
    controller.setText("interrupt",for:key);await controller.sendCurrent(for:key)
    try check(controller.interruptions[key] != nil,"AT76 owner input while working marks interruption")
    try await waitFor{controller.model.timeline(key).contains{$0.text=="새 답"}}
    try check(controller.interruptions[key]==nil,"AT76 next employee answer clears interruption")
    await controller.stop(key);await controller.stop(key)
    try await waitFor{controller.model.timeline(key).contains{$0.text=="/stop"}}
    try check(controller.stopped.contains(key),"AT76 stop offers undo after typing off")
    await controller.sendText(ThreadTools.undo,key:key)
    try await waitFor{controller.model.timeline(key).contains{$0.text==ThreadTools.undo}}
    try check(!controller.stopped.contains(key),"AT76 undo persists as exact owner text then clears")
    await controller.branch(key);await controller.branch(key)
    try await waitFor{controller.model.selected?.thread != controlThread}
    let branch=controller.model.selected!
    try check(controller.model.timeline(branch).first?.branchFrom==controlThread,"AT75 branch event opens new thread")
    controller.openLink(ThreadTools.link(key));try check(controller.model.selected==key,"AT75 in-app link opens existing thread")
    var now=Date();controller.clock={now}
    await controller.deleteThread(key)
    now=now.addingTimeInterval(4.1);await controller.deleteThread(key)
    try check(!controller.deleting.contains(key) && !controller.model.timeline(key).isEmpty,"AT75 expired four-second confirmation only rearms")
    await controller.deleteThread(key)
    try await waitFor{controller.model.timeline(key).isEmpty}
    try check(!controller.deleting.contains(key) && !controller.model.timeline(branch).isEmpty,"AT75 deletion finishes and preserves other thread")
    if args.count>4 {
        let directory=URL(fileURLWithPath:args[4]);try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        controller.openLink(ThreadTools.link(branch));ui.refresh();ui.layoutSubtreeIfNeeded()
        if let image=ui.bitmapImageRepForCachingDisplay(in:ui.bounds) {ui.cacheDisplay(in:ui.bounds,to:image);try image.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent("task25-controls.png"))}
    }
    print("THREAD_NETWORK_PASS")
}
