import AppKit
import Sparkle

final class UpdateHTTP: URLProtocol {
    static var response: (URLRequest) -> (Int, Data) = { _ in (404, Data()) }
    override class func canInit(with request: URLRequest) -> Bool { true }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let (status, data) = Self.response(request)
        client?.urlProtocol(self, didReceive: HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: "HTTP/1.1", headerFields: nil)!, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: data); client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}
@MainActor final class UpdateTestInstaller: UpdateInstalling {
    var isBusy = false, begins = 0, stopped = false
    var onFailure: ((Error) -> Void)?, onChange: (() -> Void)?
    func begin(_ release: UpdateRelease) throws { begins += 1; isBusy = true; onChange?() }
    func stop() { stopped = true }
}

@MainActor func updateTests(outputDirectory: URL? = nil) async throws {
    let repo = "sample/hejo", archive = "https://github.com/sample/hejo/releases/download/v0.2.1/hejo-0.2.1-arm64.zip"
    func fixture(_ change: (inout [String: Any]) -> Void = { _ in }) throws -> Data {
        var value: [String: Any] = ["tag_name":"v0.2.1", "draft":false, "prerelease":false, "assets":[
            ["id":11,"name":"appcast.xml","state":"uploaded","size":500,"browser_download_url":"https://github.com/sample/hejo/releases/download/v0.2.1/appcast.xml"],
            ["id":12,"name":"hejo-0.2.1-arm64.zip","state":"uploaded","size":4096,"browser_download_url":archive]]]
        change(&value); return try JSONSerialization.data(withJSONObject:value)
    }
    let valid = try fixture(), release = try UpdateRelease.decode(valid, repository:repo)
    try check(release.version == "0.2.1" && release.archiveSize == 4096 && release.feedURL.absoluteString == "https://github.com/sample/hejo/releases/latest/download/appcast.xml", "AT84 public release discovery")
    for change: (inout [String:Any])->Void in [
        { $0["draft"] = true }, { $0["prerelease"] = true }, { $0["tag_name"] = "v0.2.1-beta" }, { $0["tag_name"] = "0.2.1" },
        { var a = $0["assets"] as! [[String:Any]]; a.append(a[0]); $0["assets"] = a },
        { var a = $0["assets"] as! [[String:Any]]; a[1]["browser_download_url"] = "https://invalid.test/release.zip"; $0["assets"] = a },
        { var a = $0["assets"] as! [[String:Any]]; a[1]["size"] = 0; $0["assets"] = a },
        { var a = $0["assets"] as! [[String:Any]]; a[0]["state"] = "new"; $0["assets"] = a }
    ] {
        do { _ = try UpdateRelease.decode(fixture(change), repository:repo); throw TestFailure.assertion("AT84 invalid metadata accepted") }
        catch is TestFailure { throw TestFailure.assertion("AT84 invalid metadata accepted") } catch {}
    }
    try check(UpdateRelease.latestURL(repository:"sample/hejo?secret=x") == nil, "AT84 repository configuration cannot inject a query")
    func allows(file:String = archive, version:String = "0.2.1", size:UInt64 = 4096, installation:String = "application", notes:URL? = nil, information:URL? = nil, deltas:Bool = false) -> Bool {
        release.allows(file:URL(string:file), version:version, size:size, installation:installation, notes:notes, information:information, hasDeltas:deltas)
    }
    try check(allows(), "AT84 signed feed enclosure allowed")
    try check(!allows(file:"https://invalid.test/release.zip") && !allows(file:archive+"?x=1") && !allows(version:"0.2.2") && !allows(size:4095), "AT84 address version size boundary")
    try check(!allows(installation:"package") && !allows(notes:URL(string:archive)) && !allows(information:URL(string:archive)) && !allows(deltas:true), "AT84 only full app no notes information deltas")
    // Exercise the actual SDK appcast decoder and the delegate's validation path.
    let item = SUAppcastItem(dictionary:["enclosure":["url":archive,"length":"4096","sparkle:version":"3","sparkle:shortVersionString":"0.2.1","sparkle:installationType":"application"]])!
    let version = try SparkleInstaller.validate(item, release:release)
    try check(version.0 == "0.2.1" && version.1 == "3", "AT84 SDK item delegate validation")
    let badItem = SUAppcastItem(dictionary:["enclosure":["url":"https://invalid.test/archive.zip","length":"4096","sparkle:version":"3","sparkle:shortVersionString":"0.2.1"]])!
    do { _ = try SparkleInstaller.validate(badItem, release:release); throw TestFailure.assertion("AT84 SDK delegate accepted foreign archive") }
    catch UpdateFailure.invalidRelease {}
    try check(SUStandardVersionComparator().compareVersion("0.2.1", toVersion:"0.2.0") == .orderedDescending, "AT84 Sparkle version comparator")
    let suite = "hejo-update-test-"+UUID().uuidString, defaults = UserDefaults(suiteName:suite)!
    defer { defaults.removePersistentDomain(forName:suite) }
    var calendar = Calendar(identifier:.gregorian); calendar.timeZone = TimeZone(secondsFromGMT:0)!
    let date = Date(timeIntervalSince1970:1_800_000_000), reminder = UpdateReminder(defaults:defaults, calendar:calendar)
    reminder.hideToday(now:date)
    let midnight = calendar.date(byAdding:.day,value:1,to:calendar.startOfDay(for:date))!
    try check(!reminder.allowsCheck(manual:false,now:midnight.addingTimeInterval(-1)) && reminder.allowsCheck(manual:false,now:midnight) && reminder.allowsCheck(manual:true,now:date), "AT84 calendar midnight and manual bypass")
    let settings = UpdateNoticeSettings(defaults:defaults)
    try check(settings.enabled, "AT84 update notices default on"); settings.setEnabled(false)
    try check(UpdateNoticePolicy.allows(manual:true,enabled:false,reminderAllows:false) && !UpdateNoticePolicy.allows(manual:false,enabled:false,reminderAllows:true), "AT84 manual when disabled")
    let marker = UpdateInstallation(defaults:defaults); marker.preparing(version:"0.2.1",build:"3")
    try check(!marker.installed(version:"0.2.1",build:"2") && marker.installed(version:"0.2.1",build:"3") && !marker.installed(version:"0.2.1",build:"3"), "AT84 expected version and build once")
    let config = URLSessionConfiguration.ephemeral; config.protocolClasses = [UpdateHTTP.self]
    var requests = 0
    UpdateHTTP.response = { request in
        requests += 1
        if request.value(forHTTPHeaderField:"Authorization") != nil { return (400, Data()) }
        return (200, valid)
    }
    func client() -> UpdateReleaseClient { UpdateReleaseClient(configuration:config,repository:repo) }
    let installer = UpdateTestInstaller(); var alerts:[NSAlert] = [], answer = NSApplication.ModalResponse.alertThirdButtonReturn
    let app = AppUpdate(defaults:defaults,client:client(),installer:installer,installed:{true},current:{("0.2.0","2")},present:{ alert in alerts.append(alert); return answer })
    app.check(manual:false); await pause(0.1); try check(requests == 0, "AT84 notices off stops automatic only")
    app.checkNow(); app.checkNow(); try await waitFor { alerts.count == 1 }
    try check(requests == 1 && installer.begins == 0 && app.menuTitle == "업데이트 0.2.1 설치…", "AT84 discovery one request no consent no install cached menu")
    try check(alerts[0].messageText == "hejo 새 버전 0.2.1" && alerts[0].informativeText == "새 업데이트가 있어요. 지금 업데이트할까요?\n업데이트하면 새 버전을 받아 지금 앱과 바꾸고 다시 실행해요. 설정과 대화 기록은 그대로예요.", "AT84 consent wording")
    try check(alerts[0].buttons.map(\.title) == ["업데이트","오늘 다시 보지 않음","나중에"] && alerts[0].buttons[2].keyEquivalent == "\u{1b}", "AT84 three consent buttons")
    let window = PetSettingsWindow(); window.onAppUpdate = { app.checkNow() }; window.updateAppUpdates(app)
    try check(window.updateAvailable.stringValue == "새 버전 0.2.1이 있어요" && window.updateButton.title == "업데이트", "AT84 settings cached action")
    window.updateButton.performClick(nil); app.checkNow()
    try await waitFor {installer.begins == 1}
    try check(requests == 2 && alerts.count == 1 && !app.canCheck, "AT84 cached explicit consent revalidates release and starts once")
    app.stop(); try check(installer.stopped, "AT84 stop cancels update discovery")
    alerts = []; let absent = AppUpdate(defaults:defaults,client:client(),installer:UpdateTestInstaller(),installed:{false},present:{ alerts.append($0); return .alertFirstButtonReturn })
    absent.start(); absent.checkNow()
    try check(absent.timer == nil && alerts.last?.informativeText == "응용 프로그램 폴더에 설치한 뒤 업데이트할 수 있어요.", "AT84 application install boundary"); absent.stop()
    alerts = []; answer = .alertSecondButtonReturn; settings.setEnabled(true); defaults.removeObject(forKey:UpdateReminder.key)
    let hidden = AppUpdate(defaults:defaults,client:client(),installer:UpdateTestInstaller(),installed:{true},current:{("0.2.0","2")},present:{ alerts.append($0); return answer })
    let before = Date(); hidden.start()
    try check(hidden.timer!.timeInterval == 21600 && abs(hidden.timer!.fireDate.timeIntervalSince(before)-30) < 2, "AT84 thirty seconds then six hours")
    hidden.check(manual:false); try await waitFor { alerts.count == 1 }
    let count = requests; hidden.check(manual:false); await pause(0.1)
    try check(requests == count, "AT84 hide today suppresses automatic checks"); hidden.stop()
    alerts = []; UpdateHTTP.response = { _ in (200,valid) }
    let latest = AppUpdate(defaults:defaults,client:client(),installer:UpdateTestInstaller(),installed:{true},current:{("0.2.1","3")},present:{ alerts.append($0); return .alertFirstButtonReturn })
    latest.checkNow(); try await waitFor { alerts.count == 1 }
    try check(alerts[0].informativeText == "최신 버전이에요 (0.2.1)", "AT84 latest version message"); latest.stop()
    alerts = []; UpdateHTTP.response = { _ in (404,Data()) }
    let missing = AppUpdate(defaults:defaults,client:client(),installer:UpdateTestInstaller(),installed:{true},present:{ alerts.append($0); return .alertFirstButtonReturn })
    missing.checkNow(); try await waitFor { alerts.count == 1 }
    try check(alerts[0].informativeText == "아직 업데이트 릴리스가 없어요.", "AT84 release missing fixed error"); missing.stop()
    let bubbleHome = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:bubbleHome) }
    let bubble = BubbleReveal(store:try LocalStore(directory:bubbleHome)), instant = Date()
    bubble.showInstalled("hejo 0.2.1으로 업데이트됨",now:instant)
    _ = bubble.update(BubbleReveal.Input(),now:instant)
    try check(bubble.notice.kind == .update && bubble.notice.headline == "hejo 0.2.1으로 업데이트됨", "AT84 installed pet notice")
    var paused = BubbleReveal.Input(); paused.paused = true; _ = bubble.update(paused,now:instant)
    try check(bubble.notice.kind == .idle, "AT84 paused priority above update notice")
    _ = bubble.update(BubbleReveal.Input(),now:instant.addingTimeInterval(10))
    try check(bubble.notice.kind == .idle, "AT84 installed pet notice expires ten seconds")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        func capture(_ window:NSWindow,_ name:String) throws {
            let command=Process();command.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture")
            command.arguments=["-x","-l",String(window.windowNumber),outputDirectory.appendingPathComponent(name).path]
            try command.run();command.waitUntilExit();try check(command.terminationStatus==0,"AT84 window capture")
        }
        let alert=AppUpdate.automaticAlert(version:"0.2.1");var captureError:Error?
        let timer=Timer(timeInterval:0.5,repeats:false){ _ in MainActor.assumeIsolated {
            do {try capture(alert.window,"task33-hejo-consent.png")}catch{captureError=error}
            NSApp.abortModal()
        }}
        RunLoop.main.add(timer,forMode:.modalPanel);NSApp.activate(ignoringOtherApps:true);_ = alert.runModal();alert.window.orderOut(nil)
        if let captureError {throw captureError}
        window.tabs.selectTabViewItem(at:0);window.window.center();window.window.makeKeyAndOrderFront(nil);await pause(0.4)
        try capture(window.window,"task33-hejo-settings.png");window.window.orderOut(nil)
    }
    print("AT-HF-84 APP PASS")
}

@MainActor func updateLegacyNetwork(_ args:[String]) async throws {
    let store = try LocalStore(directory:URL(fileURLWithPath:args[2])), client = GateClient(store:store,credentials:MemoryCredentials())
    let controller = try testConversation(client:client), model = controller.model
    try client.pair(address:args[3],code:args[4],device:"fake update compatibility")
    try await waitFor { controller.canSend && model.employees.contains { $0.id == "alpha" } }
    let key = ConversationKey(employee:"alpha",thread:"11111111-1111-4111-8111-111111111111")
    model.select(key); controller.setText("compatibility request"); await controller.sendCurrent()
    try await waitFor { model.timeline(key).contains { $0.role == "employee" && $0.text == "old gate reply" } }
    try check(model.groups["room-fixture"]?.title == "가짜 단체방", "AT84 old gate rooms welcome received")
    let sequence = store.settings.applied
    try check(sequence >= 2, "AT84 old gate new app contiguous cache")
    client.stop(); print("AT84_OLD_GATE_NEW_APP_PASS")
}
