import AppKit

/// AT93: settings actions use the real native controls without registering login items or changing a live home.
@MainActor func settingsTests() async throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:root) }
    let store=try LocalStore(directory:root), settings=PetSettingsWindow()
    try check(settings.tabs.tabViewItems.map(\.label)==["일반","화면과 펫","연결과 동기화","고급","계정"],"AT93 tabs exclude clipboard and drop")
    settings.fit(to:CGRect(x:10,y:20,width:1000,height:500))
    try check(settings.window.contentView!.bounds.width==620 && settings.window.frame.height==468 && settings.window.frame.midX==510 && settings.window.frame.midY==270,"AT93 fit small pointer screen with sixteen point margins")
    for item in settings.tabs.tabViewItems {
        settings.tabs.selectTabViewItem(item)
        let scroll=item.view as! NSScrollView
        try check(scroll.hasVerticalScroller && scroll.documentView!.isFlipped,"AT93 every page scrolls")
        scroll.documentView!.scroll(CGPoint(x:0,y:100))
        settings.tabs.selectTabViewItem(at:settings.tabs.indexOfTabViewItem(item)==0 ? 1:0)
        settings.tabs.selectTabViewItem(item)
        try check(scroll.contentView.bounds.origin.y==0,"AT93 tab returns to top")
    }
    for state in [LoginLaunchState.enabled,.requiresApproval,.notRegistered,.notFound] {
        let value=LoginLaunchPresentation.resolve(state,installed:true)
        settings.refreshLogin(value)
        try check(settings.loginCheck.state == (state == .enabled ? .on:.off) && settings.loginSettings.isHidden == !value.showsSettings && settings.loginStatus.stringValue==value.message,"AT93 actual login controls follow all states")
    }
    settings.refreshLogin(LoginLaunchPresentation.resolve(.notRegistered,installed:true,failed:true))
    try check(settings.loginStatus.stringValue=="등록을 마치지 못했어요. 로그인 항목 설정을 확인해 주세요." && !settings.loginSettings.isHidden,"AT93 registration failure stays inline")
    var names:[String]=[],sizes:[Double]=[]
    settings.onName={names.append($0)};settings.onScale={sizes.append($0)}
    for (name,message) in [(" ","펫 이름을 입력해 주세요."),(String(repeating:"가",count:21),"이름은 20자까지 입력할 수 있어요."),("가\u{1}나","표시할 수 있는 문자로 이름을 입력해 주세요.")] {
        settings.nameField.stringValue=name;_ = settings.nameField.sendAction(settings.nameField.action,to:settings.nameField.target)
        try check(names.isEmpty && settings.nameHint.stringValue==message && settings.nameHint.textColor == .systemRed,"AT93 name rejects without truncation")
    }
    settings.nameField.stringValue="  가   나  ";_ = settings.nameField.sendAction(settings.nameField.action,to:settings.nameField.target)
    try check(names==["가 나"] && settings.nameField.stringValue=="가 나" && settings.nameHint.stringValue=="이름을 저장했어요. 모든 화면에 적용했습니다.","AT93 name folds whitespace and NFC only on save")
    for value in [25.0,76,200] {settings.scaleSlider.doubleValue=value;_ = settings.scaleSlider.sendAction(settings.scaleSlider.action,to:settings.scaleSlider.target)}
    try check(settings.scaleSlider.isContinuous && sizes==[25,76,200] && settings.scaleSlider.toolTip=="캐릭터만 25%부터 200%까지 조절 · 말풍선 크기는 고정","AT93 continuous scale and original tooltip")
    for (saved,connected,title) in [(false,false,"아직 맞출 수 없어요"),(true,false,"이 Mac에 저장했어요"),(true,true,"맞췄어요")] {
        try check(PetSettingsWindow.layoutResult(saved:saved,connected:connected).messageText==title,"AT93 result dialog three outcomes")
    }
    let tap=try ThreeTapController(store:store,live:false,reader:FakeThreeTapReader(),machineName:{"fixture Mac"})
    settings.updateThreeTap(tap);try check(settings.tapCopyButton.isHidden,"AT93 request copy hidden without failure")
    tap.receive(.failed("fixture failure"));settings.updateThreeTap(tap)
    try check(!settings.tapCopyButton.isHidden && !settings.threeTapCheck.isEnabled,"AT93 request copy visible on failure")
    let pasteboard=NSPasteboard.withUniqueName();settings.requestPasteboard=pasteboard
    defer { pasteboard.releaseGlobally() }
    settings.tapCopyButton.performClick(nil)
    try check(pasteboard.string(forType:.string)==tap.failure?.request,"AT93 copy uses full ThreeTap request")
    let room=Room(id:"room-a",title:"가짜 방",members:["alpha"],lead:"alpha")
    settings.refreshHome(rooms:[room],selected:room.id)
    var home="";settings.onHome={home=$0};_ = settings.homePicker.sendAction(settings.homePicker.action,to:settings.homePicker.target)
    try check(home==room.id && settings.homePicker.itemTitles==["기본(홈 방 기본)","#가짜 방"],"AT93 existing home choice through real popup")
    settings.refreshHome(rooms:[],selected:room.id)
    try check(settings.homePicker.indexOfSelectedItem==0,"AT93 unavailable home shows fallback without overwriting saved choice")
    let candidate=Bundle.main.executableURL!.deletingLastPathComponent().appendingPathComponent("hejo.app/Contents/Resources/Pet")
    let resource=FileManager.default.fileExists(atPath:candidate.path) ? candidate:URL(fileURLWithPath:"app/.build/hejo.app/Contents/Resources/Pet")
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resource))
    settings.onPreview={pet.preview()};settings.onPointer={pet.previewPointer()}
    settings.previewButton.performClick(nil)
    try check(pet.pet.previewRow==0 && (1.95...2).contains(pet.previewTimer!.fireDate.timeIntervalSinceNow),"AT93 first motion preview two seconds")
    for row in 1..<12 {pet.previewTimer?.fire();try check(pet.pet.previewRow==row,"AT93 original preview order")}
    try check((PetAnimationTimeline.dozeCycle-0.05...PetAnimationTimeline.dozeCycle).contains(pet.previewTimer!.fireDate.timeIntervalSinceNow),"AT93 doze cycle duration")
    pet.previewTimer?.fire();try check(pet.pet.previewRow==nil,"AT93 preview releases after final motion")
    settings.pointerButton.performClick(nil)
    try check(pet.pet.previewLook && (14.95...15).contains(pet.previewTimer!.fireDate.timeIntervalSinceNow) && pet.pet.foldedBubble.detail=="hejo · 포인터를 움직여 보세요","AT93 pointer preview fifteen seconds and original wording")
    pet.previewTimer?.fire();try check(!pet.pet.previewLook,"AT93 pointer preview ends")
    let client=GateClient(store:store,credentials:MemoryCredentials()),controller=try testConversation(client:client)
    let frame:[String:Any]=["v":1,"type":"message","seq":1,"msg_id":"fixture-post","employee":"alpha","thread":"fixture-thread","role":"employee","text":"hello","ts":"2026-01-01T00:00:00Z"]
    controller.setPaused(true);controller.receive(frame)
    try check(controller.model.messages.isEmpty,"AT93 pause holds presentation delivery")
    controller.setPaused(false);try check(controller.model.messages["fixture-post"]?.text=="hello","AT93 restart receives held records")
    let connections=ConnectionsWindow(controller:controller)
    try check(connections.window.contentView!.bounds.size==CGSize(width:760,height:560) && connections.window.minSize==CGSize(width:760,height:500),"AT93 connection window native size")
    try await waitHTTPTests()
    try await stateWaitTests(root:root)
    settings.window.orderOut(nil);pet.panel.orderOut(nil)
    print("AT-HF-93 APP PASS")
}

/// A held network request is the only substitute: product grouping, outbox and revision acceptance run unchanged.
@MainActor private func stateWaitTests(root:URL) async throws {
    let state=MemberState(store:try LocalStore(directory:root.appendingPathComponent("sync")))
    var polls=0,active=0,maxActive=0,sends:[[String:StateEntry]]=[],doc=StateDocument()
    var release:CheckedContinuation<(StateDocument,Bool),Error>?
    state.connect(fetch:{_ in polls+=1;return doc},push:{changes in
        active+=1;maxActive=max(maxActive,active);sends.append(changes)
        await pause(0.1);active-=1
        doc=StateDocument(rev:doc.rev+1,items:MemberState.merge(doc.items,changes));return doc
    },wait:{_ in
        try await withCheckedThrowingContinuation { release=$0 }
    })
    await pause(0.02)
    doc=StateDocument(rev:1,items:[:])
    release?.resume(returning:(doc,true));release=nil
    await pause(0.02)
    try check(state.waitingSupported && state.timer==nil && polls==0,"AT93 declared wait replaces thirty-second polling")
    try state.set(["pin:alpha":"1"],at:10);await pause(0.7);try state.set(["mute:beta":"1"],at:11)
    await pause(0.6);try check(sends.isEmpty,"AT93 edits do not escape before 1.5 second group")
    await pause(0.4)
    try check(sends.count==1 && sends[0].count==2 && maxActive==1,"AT93 group sends both edits once without overlapping")
    try await waitFor { state.pending.isEmpty }
    // The already-started wait can finish after a newer PATCH. Never regress its revision.
    release?.resume(returning:(StateDocument(rev:0,items:[:]),true));release=nil
    await pause(0.02);try check(state.document.rev>=1 && state.value("pin:alpha")=="1","AT93 stale wait cannot roll back acknowledgement")
    state.disconnect();release?.resume(throwing:CancellationError());release=nil
    state.connect(fetch:{_ in polls+=1;return doc},push:{_ in doc},wait:{_ in (doc,false)})
    await pause(0.02);try check(!state.waitingSupported && state.timer?.timeInterval==30,"AT93 old hub without capability keeps old thirty-second receive")
    state.disconnect()
}

private final class WaitHubProtocol: URLProtocol {
    static var supported = true
    static var last: URLRequest?
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "wait.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        Self.last=request
        let response=HTTPURLResponse(url:request.url!,statusCode:200,httpVersion:nil,headerFields:Self.supported ? ["X-Hejo-State-Wait":"1"]:[:])!
        client?.urlProtocol(self,didReceive:response,cacheStoragePolicy:.notAllowed)
        client?.urlProtocol(self,didLoad:Data("{\"rev\":7,\"items\":{}}".utf8));client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

@MainActor private func waitHTTPTests() async throws {
    URLProtocol.registerClass(WaitHubProtocol.self);defer {URLProtocol.unregisterClass(WaitHubProtocol.self)}
    let hub=HubClient(address:"wait.test:47800")
    for support in [true,false] {
        WaitHubProtocol.supported=support
        let (doc,declared)=try await hub.waitState(revision:7,token:"fixture-token")
        let request=WaitHubProtocol.last!
        try check(doc.rev==7 && declared==support && request.url?.path=="/v1/me/state" && request.url?.query=="wait=7" && request.timeoutInterval==30 && request.value(forHTTPHeaderField:"Authorization")=="Bearer fixture-token","AT93 actual wait request and explicit capability negotiate old hub")
    }
}
