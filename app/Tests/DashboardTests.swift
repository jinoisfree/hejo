import AppKit

@MainActor func dashboardTests(outputDirectory:URL?=nil) async throws {
    let now = Date(),root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:root)}
    let store=try LocalStore(directory:root),bubble=BubbleReveal(store:store)
    let a=WorkItem(provider:.codex,sessionID:"work-one",turnID:"t",project:"project",state:.running,updatedAt:now,source:"로컬 기록",event:"task_started")
    var b=a;b.provider = .claude;b.sessionID="work-two";b.state = .waiting;b.source="공식 훅"
    var c=a;c.sessionID="work-end";c.state = .responded
    var input=BubbleReveal.Input(ready:true,tasks:[b,a,c])
    bubble.update(input,now:now)
    try check(bubble.notice.workState == .waiting && bubble.notice.headline == "Claude Code · 확인 필요" && bubble.notice.detail == "작업 중: Codex 1","AT98 urgent task text precedes chat writing")
    try check(!bubble.notice.held && bubble.notice.actions.isEmpty && bubble.notice.key == nil,"AT98 task not a chat approval/reply target")
    let key=ConversationKey(employee:"staff",thread:"thread")
    let message=ConversationMessage(id:"question",key:key,role:"employee",text:"확인해 주세요",files:[],buttons:[],replyState:nil,seq:1,latestSeq:1,timestamp:Dates.fractional.string(from:now))
    input.messages=[message];input.questions=[message.id];input.names=["staff":"직원"]
    bubble.update(input,now:now)
    try check(bubble.notice.workState == nil && bubble.notice.held,"AT98 employee approval precedes external task")
    input.questions=[];bubble.showInstalled("업데이트했어요",now:now);bubble.update(input,now:now)
    try check(bubble.notice.kind == .update,"AT98 installed update precedes task")
    bubble.update(input,now:now.addingTimeInterval(11));try check(bubble.notice.workState == .waiting,"AT98 task after installation notice expires")
    b.state = .failed;input.tasks=[b,a];input.typing=[key:now.addingTimeInterval(120)]
    bubble.update(input,now:now);try check(bubble.notice.kind == .failure,"AT98 recent task failure precedes writing")
    input.tasks=[a];bubble.update(input,now:now);try check(bubble.notice.kind == .writing && bubble.notice.workState == nil,"AT98 employee writing precedes ordinary work")
    input.typing=[:];input.messages=[];bubble.update(input,now:now)
    try check(bubble.notice.workState == .running,"AT98 active task fallback")
    input.paused=true;bubble.update(input,now:now);try check(bubble.notice.workState == nil && bubble.notice.headline == "쉬고 있어요","AT98 pause precedes all")
    input.paused=false;input.tasks=[c];input.selectedTask=c.id
    bubble.update(input,now:now.addingTimeInterval(20));try check(bubble.notice.workState == .idle && bubble.notice.headline == "Codex · 응답 종료","AT98 pinned completion text stays but animation rests at twenty seconds")
    let model=DashboardModel();model.tasks=[b,a,c];model.connections=[.init(provider:.codex,available:true,fileCount:2,detail:"최근 기록 2개 · 공식 훅 수신 확인"),.init(provider:.claude,available:false,fileCount:0,detail:"기록 폴더에 접근할 수 없음")];model.lastScan=now
    let view=Dashboard(model:model),window=NSWindow(contentRect:view.frame,styleMask:[.titled],backing:.buffered,defer:false)
    window.contentView=view;window.isReleasedWhenClosed=false
    window.orderFrontRegardless();defer{window.orderOut(nil)}
    view.layoutSubtreeIfNeeded();try check(view.taskButtons.count == 3,"AT98 task rows")
    try check(view.scroll.frame.minY == 243 && view.taskButtons.map{$0.frame.height} == [66,66,66] && view.taskButtons.map{$0.frame.minY} == [0,74,148],"AT98 original dashboard row geometry")
    try check(view.filter.frame == CGRect(x:424,y:209,width:260,height:24),"AT98 source filter geometry at 710pt")
    let stableRow=view.taskButtons[0];model.onChange?();try check(view.taskButtons[0] === stableRow,"AT98 periodic refresh preserves native control identity")
    var selected:String?,hooks=0,refresh=0,preview=0,paused=0
    model.onSelect={selected=$0;model.selectedID=$0;model.onChange?()};model.onHooks={hooks+=1};model.onRefresh={refresh+=1};model.onPreview={preview+=1};model.onPause={paused+=1}
    view.taskButtons[0].performClick(nil);try check(selected == b.id && view.taskButtons[0].pinned && view.taskButtons[0].pinFrame.minX<200,"AT98 pin task")
    view.taskButtons[0].performClick(nil);try check(selected == nil,"AT98 unpin task")
    view.filter.selectedSegment=2;NSApp.sendAction(view.filter.action!,to:view.filter.target,from:view.filter)
    try check(view.taskButtons.count == 1 && view.taskButtons[0].item.provider == .claude,"AT98 provider filter")
    view.hooksButton.performClick(nil);view.refreshButton.performClick(nil);view.previewButton.performClick(nil);view.pauseButton.performClick(nil)
    try check(hooks==1 && refresh==1 && preview==1 && paused==1,"AT98 real buttons route to existing owners")
    model.name="펫";try check(model.name == "펫", "AT98 identity change redraws the open dashboard")
    model.name="hejo"
    let settings=PetSettingsWindow();settings.onHooks={hooks+=1};settings.hooksButton.performClick(nil)
    try check(hooks==2 && settings.hooksButton.title == "승인 알림 연결 안내","AT98 settings help is connected")
    try check(HooksHelp.title == "승인 대기 알림 연결" && HooksHelp.explanation.contains("기본 연결은 Codex와 Claude Code"),"AT98 source help wording")
    let delegate=AppDelegate(),menu=delegate.makeStatusMenu(),item=menu.items.first{$0.title == "작업 목록"}
    try check(item?.action == #selector(AppDelegate.showDashboard) && item?.isEnabled == true,"AT98 task menu active")
    let candidate=Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("hejo.app/Contents/Resources/Pet")
    let resource=FileManager.default.fileExists(atPath:candidate.path) ? candidate:URL(fileURLWithPath:"app/.build/hejo.app/Contents/Resources/Pet")
    let atlas=try SpriteAtlas(resourceDirectory:resource)
    let pet=PetController(store:store,atlas:atlas)
    pet.pet.pointerLocation={CGPoint(x:-1000,y:-1000)}
    pet.pet.resolveScreen={_,_ in CGPoint(x:100,y:500)}
    pet.pet.taskState = .waiting;pet.pet.hasAsked=true;pet.pet.bubbleNotice=BubbleReveal.Notice(kind:.approval,headline:"Claude Code · 확인 필요",detail:"작업 중: Codex 1",key:nil,id:"task:waiting",workState:.waiting)
    pet.show();pet.pet.animate();pet.pet.foldedBubble.tick(at:0,paused:false)
    try check(pet.pet.displayedFrame.row == PetAnimation.waiting.rawValue,"AT98 waiting task uses approval animation")
    try check(pet.pet.foldedBubble.kind == .approval && pet.pet.foldedBubble.statusDotVisible,"AT98 orange task dot")
    pet.pet.hasAsked=false;pet.pet.taskState = .running
    pet.pet.screenFocus=ScreenFocus(taskID:a.id,turnID:a.turnID,provider:.codex,taskStartedAt:now,firstObservedAt:now,expiresAt:now.addingTimeInterval(60),target:ScreenTarget(appName:"Example",windowTitle:"Work"))
    // A pointer outside the pet prevents pointer attention from taking priority over the task window.
    var resolved=0;pet.pet.resolveScreen={_,_ in resolved+=1;return CGPoint(x:100,y:500)}
    pet.pet.animate()
    try check(resolved>0 && pet.pet.displayedFrame.row >= 9,"AT98 active task can resolve public window geometry")
    pet.reducedMotion={true};pet.pet.reduceMotion={true};pet.pet.taskState = .failed;pet.pet.sendFailed=true;pet.pet.homeConversation=true
    pet.showChat();pet.pet.animate()
    try check(pet.pet.displayedFrame.row == PetAnimation.failed.rawValue,"AT98 expanded home conversation cannot cover failed task animation")
    pet.collapseChat()
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        model.tasks[0].state = .waiting;model.filter="전체";view.filter.selectedSegment=0;model.lastScan=Date(timeIntervalSince1970:1_700_000_000)
        for i in model.tasks.indices {model.tasks[i].updatedAt=model.lastScan!}
        view.refresh();view.layoutSubtreeIfNeeded();try captureWork(view,to:outputDirectory.appendingPathComponent("task47-hejo-dashboard.png"))
        model.selectedID="claude:work-two";model.onChange?();view.layoutSubtreeIfNeeded();try captureWork(view,to:outputDirectory.appendingPathComponent("task47-hejo-pinned.png"))
        model.tasks=[];model.onChange?();view.layoutSubtreeIfNeeded();try captureWork(view,to:outputDirectory.appendingPathComponent("task47-hejo-empty.png"))
    }
    pet.panel.orderOut(nil)
    print("AT-HF-98 APP PASS · temporary sessions/settings only")
}
@MainActor private func captureWork(_ view:NSView,to url:URL) throws {
    guard let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else {throw TestFailure.assertion("AT98 bitmap")}
    view.cacheDisplay(in:view.bounds,to:bitmap)
    try bitmap.representation(using:.png,properties:[:])!.write(to:url)
}
