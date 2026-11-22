import AppKit

/// Transport substitute only: gesture and frame validation use the product code.
final class FakeThreeTapReader: ThreeTapReading {
    var onHealth: ((ThreeTapHealth) -> Void)?
    var onTap: (() -> Void)?
    var starts = 0, stops = 0, reconnects = 0
    private var frames = ThreeTapFrames()
    func start() { starts += 1 }
    func stop() { stops += 1 }
    func reconnect() { reconnects += 1 }
    func frame(_ contacts: [ThreeTapContact]?, count: Int, time: Double) {
        switch frames.receive(contacts, count: count, at: time) {
        case .ignored: break
        case .failed(let reason): onHealth?(.failed(reason))
        case .valid(let tapped): onHealth?(.ready); if tapped { onTap?() }
        }
    }
}

@MainActor func threeTapTests(resourceDirectory: URL, outputDirectory: URL? = nil) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try LocalStore(directory: directory)
    try check(ThreeTapDiagnostics.output == nil && ThreeTapDiagnostics.timestamp() == nil, "tap tracing defaults off")
    try check(ThreeTapDiagnostics.traceURL(nil) == nil && ThreeTapDiagnostics.traceURL("") == nil, "tap tracing requires explicit destination")
    try check(ThreeTapDiagnostics.traceURL(directory.appendingPathComponent("trace.jsonl").path) == nil, "tap tracing refuses output outside build directory")
    let buildDirectory = directory.appendingPathComponent(".build")
    try FileManager.default.createDirectory(at: buildDirectory, withIntermediateDirectories: true)
    try check(ThreeTapDiagnostics.traceURL(buildDirectory.appendingPathComponent("trace.jsonl").path) != nil, "tap tracing accepts build directory")
    try FileManager.default.createSymbolicLink(at: buildDirectory.appendingPathComponent("escape"), withDestinationURL: directory)
    try check(ThreeTapDiagnostics.traceURL(buildDirectory.appendingPathComponent("escape/trace.jsonl").path) == nil, "tap tracing rejects symlink escape")
    try FileManager.default.createSymbolicLink(at: buildDirectory.appendingPathComponent("linked.jsonl"), withDestinationURL: directory.appendingPathComponent("outside.jsonl"))
    try check(ThreeTapDiagnostics.traceURL(buildDirectory.appendingPathComponent("linked.jsonl").path) == nil, "tap tracing refuses dangling output symlink")
    try check(ThreeTapDiagnostics.traceURL(buildDirectory.appendingPathComponent("missing/trace.jsonl").path) == nil, "tap tracing requires existing output directory")
    func contacts(_ count: Int, drift: Double = 0) -> [TapContact] {
        (0..<count).map { TapContact(id: $0, x: 0.2 + Double($0) * 0.1 + drift, y: 0.5) }
    }
    func gesture(_ samples: [(Double, Int, Double)]) -> [Bool] {
        var state = ThreeTapGesture()
        return samples.map { state.receive(contacts($0.1, drift: $0.2), at: $0.0) }
    }
    try check(gesture([(0,3,0),(0.2,0,0)]).last == true, "AT86 three finger tap")
    try check(gesture([(0,3,0),(0.4,0,0)]).last == false, "AT86 long hold rejected")
    try check(gesture([(0,3,0),(0.1,4,0),(0.2,0,0)]).last == false, "AT86 fourth finger rejected")
    try check(gesture([(0,2,0),(0.2,0,0)]).last == false, "AT86 two fingers rejected")
    try check(gesture([(0,3,0),(0.1,3,0.05),(0.2,0,0)]).last == false, "AT86 moving finger rejected")
    try check(gesture([(0,3,0),(0.1,0,0),(0.2,3,0),(0.3,0,0),(0.6,3,0),(0.7,0,0)]).filter { $0 }.count == 2, "AT86 gesture cooldown")
    var staggered = ThreeTapGesture()
    _ = staggered.receive(contacts(1), at: 0)
    _ = staggered.receive(contacts(2), at: 0.02)
    _ = staggered.receive(contacts(3), at: 0.04)
    _ = staggered.receive(contacts(2), at: 0.08)
    try check(staggered.receive([], at: 0.12), "AT86 staggered contact landing")

    var frames = ThreeTapFrames()
    for n in 0..<29 { try check(frames.receive(nil, count: -1, at: Double(n)) == .ignored, "AT86 invalid streak below threshold") }
    try check(frames.receive(nil, count: -1, at: 29) == .failed("접촉 프레임 검사: 개수"), "AT86 thirty invalid frames fail")
    frames = ThreeTapFrames()
    for n in 0..<29 { _ = frames.receive(nil, count: -1, at: Double(n)) }
    _ = frames.receive([], count: 0, at: 29)
    try check(frames.receive(nil, count: -1, at: 30) == .ignored, "AT86 valid frame resets bad streak")
    let raw = (0..<3).map { ThreeTapContact(id: $0, state: 4, x: 0.2 + Double($0) * 0.1, y: 0.5) }
    for (bad, reason) in [([ThreeTapContact(id: 0, state: 8, x: 0, y: 0)], "상태"),
                          ([ThreeTapContact(id: 0, state: 4, x: 1.06, y: 0)], "좌표"),
                          ([raw[0], raw[0]], "ID 중복")] {
        frames = ThreeTapFrames()
        for _ in 0..<29 { _ = frames.receive(bad, count: bad.count, at: 0) }
        try check(frames.receive(bad, count: bad.count, at: 0) == .failed("접촉 프레임 검사: " + reason), "AT86 identifies invalid frame")
    }
    frames = ThreeTapFrames()
    _ = frames.receive(raw, count: 3, at: 1)
    try check(frames.receive(raw, count: 3, at: 0.1) == .ignored, "AT86 backwards clock cancels")
    try check(frames.receive([], count: 0, at: 0.2) == .valid(tapped: false), "AT86 clock reset waits for release")
    try check(!ThreeTapReader.isTrackpad(rows: 9, columns: 20) && ThreeTapReader.isTrackpad(rows: 10, columns: 20), "AT86 Touch Bar ignored")
    try check(!ThreeTapReader.isTrackpad(rows: 20, columns: 0), "AT86 empty sensor ignored")
    let identity = [ThreeTapDeviceIdentity(pointer: 1, id: 10)]
    try check(ThreeTapDeviceIdentity.keep(identity, [.init(pointer: 2, id: 10)], allRunning: true, cfEqual: false), "AT86 stable device keeps registration")
    try check(!ThreeTapDeviceIdentity.keep(identity, [.init(pointer: 2, id: 20)], allRunning: true, cfEqual: false), "AT86 replacement reconnects")

    var health: [ThreeTapHealth] = []
    let noLibrary = ThreeTapReader(loadLibrary: { nil })
    noLibrary.onHealth = { health.append($0) }; noLibrary.start()
    try check(health == [.failed("dlopen")], "AT86 missing framework fails closed")
    health = []
    let noSymbols = ThreeTapReader(loadLibrary: { UnsafeMutableRawPointer(bitPattern: 1) }, resolveSymbol: { _, _ in nil })
    noSymbols.onHealth = { health.append($0) }; noSymbols.start()
    try check(health == [.failed("기호 없음: MTDeviceCreateList")], "AT86 missing symbols report once")

    var now = 10.0
    let reader = FakeThreeTapReader()
    let controller = try ThreeTapController(store: store, live: true, reader: reader, now: { now },
                                            lookupUsesThreeFingers: { true }, machineName: { "검사용 Mac" })
    controller.os = "test-os"; controller.build = "TEST"; controller.app = "test-app"; controller.appBuild = "TEST"
    defer { controller.stop() }
    let pet = PetController(store: store, atlas: try SpriteAtlas(resourceDirectory: resourceDirectory))
    pet.reducedMotion = { true }; pet.show()
    defer { pet.panel.close() }
    controller.onTap = { pet.threeFingerTapped() }
    var notices: [(String, ThreeTapFailure?)] = []
    controller.onNotice = { notices.append(($0, $1)) }
    let settings = PetSettingsWindow()
    defer { settings.window.close() }
    settings.onThreeTap = { controller.toggle() }
    controller.onChange = { settings.updateThreeTap(controller) }
    settings.updateThreeTap(controller)
    try check(settings.threeTapCheck.state == .on && settings.threeTapCheck.isEnabled && settings.threeTapCheck.toolTip == "트랙패드가 연결되면 사용할 수 있어요.", "AT86 absent device preference and hint follow source")
    controller.start()
    reader.frame(raw, count: 3, time: 0)
    reader.frame([], count: 0, time: 0.2)
    try check(pet.chatExpanded, "AT86 tap opens through pet click")
    try check(notices.filter { $0.0 == ThreeTapController.lookupText }.count == 1, "AT86 lookup conflict explained once")
    controller.tapped()
    try check(pet.chatExpanded, "AT86 controller cooldown across callbacks")
    now = 10.5; controller.tapped()
    try check(!pet.chatExpanded, "AT86 next tap closes through pet click")
    pet.pet.isPaused = true; now = 11; controller.tapped()
    try check(!pet.chatExpanded, "AT86 resting ignores tap")
    pet.pet.isPaused = false; pet.panel.orderOut(nil); now = 11.5; controller.tapped()
    try check(!pet.chatExpanded, "AT86 hidden pet ignores tap")
    pet.show()
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.didWakeNotification, object: nil)
    await pause(0.02)
    try check(reader.reconnects == 1, "AT86 wake reconnects")
    settings.threeTapCheck.performClick(nil)
    now = 12; controller.tapped()
    try check(!controller.enabled && !pet.chatExpanded && store.settings.threeTapEnabled == false, "AT86 off preference suppresses tap")
    let restored = try ThreeTapController(store: LocalStore(directory: directory), live: false, machineName: { "검사용 Mac" })
    try check(!restored.enabled, "AT86 Mac setting durable")
    settings.threeTapCheck.performClick(nil)
    try check(controller.enabled && reader.starts == 2, "AT86 preference on restarts reader")
    reader.onHealth?(.ready)
    try check(notices.filter { $0.0 == ThreeTapController.lookupText }.count == 1, "AT86 lookup notice remains deduplicated")

    if let outputDirectory {
        try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
        settings.tabs.selectTabViewItem(at: 1)
        settings.tabs.wantsLayer = true
        settings.tabs.layer?.backgroundColor = NSColor.white.cgColor
        settings.window.makeKeyAndOrderFront(nil)
        settings.tabs.layoutSubtreeIfNeeded(); await pause(0.05)
        let bitmap = settings.tabs.bitmapImageRepForCachingDisplay(in: settings.tabs.bounds)!
        settings.tabs.cacheDisplay(in: settings.tabs.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: outputDirectory.appendingPathComponent("task35-hejo-settings.png"))
    }
    for n in 0..<30 { reader.frame(nil, count: -1, time: Double(n + 1)) }
    let failure = controller.failure!
    try check(controller.health == .failed("접촉 프레임 검사: 개수") && reader.stops >= 2, "AT86 invalid frames stop reader")
    try check(settings.threeTapCheck.state == .off && !settings.threeTapCheck.isEnabled, "AT86 failure disables setting")
    try check(notices.filter { $0.1 != nil }.count == 1, "AT86 failure notice once")
    controller.showNotice(notices.last!.0, failure: failure)
    let alert = controller.noticeAlert!
    defer { alert.window.close() }
    controller.showNotice(notices.last!.0, failure: failure)
    try check(controller.noticeAlert === alert, "AT86 duplicate failure window suppressed")
    try check(alert.buttons.map(\.title) == ["수정 요청문 복사", "닫기"], "AT86 local copy only no external report")
    try check(failure.request.contains("hejo") && !failure.request.contains("ddots") && failure.request.contains("접촉 프레임 검사: 개수"), "AT86 hejo repair request")
    let pasteboard = NSPasteboard(name: .init("hejo-three-tap-test-" + UUID().uuidString))
    defer { pasteboard.releaseGlobally() }
    ThreeTapController.copy(failure, to: pasteboard)
    try check(pasteboard.string(forType: .string) == failure.request, "AT86 request copied")
    controller.receive(.failed("later")); now = 20; controller.tapped()
    try check(!pet.chatExpanded && notices.filter { $0.1 != nil }.count == 1, "AT86 failure latches")
    let again = try ThreeTapController(store: LocalStore(directory: directory), live: false, machineName: { "검사용 Mac" })
    again.os = controller.os; again.build = controller.build; again.app = controller.app; again.appBuild = controller.appBuild
    var repeated = 0; again.onNotice = { _, _ in repeated += 1 }
    again.receive(.failed("접촉 프레임 검사: 개수"))
    try check(repeated == 0, "AT86 failure deduplicated after restart")
    var checkState = ThreeTapCheck(lastOS: "old-os")
    checkState.begin(os: "new-os")
    try check(checkState.receive(.absent, os: "new-os", failureKey: "") == nil && checkState.pendingUpdate, "AT86 absent preserves OS update check")
    try check(checkState.receive(.ready, os: "new-os", failureKey: "") == .healthy, "AT86 update health notice")
    try check(checkState.receive(.ready, os: "new-os", failureKey: "") == nil, "AT86 health notice once")
    if let outputDirectory {
        alert.layout()
        let content = alert.window.contentView!
        content.wantsLayer = true; content.layer?.backgroundColor = NSColor.white.cgColor
        let bitmap = content.bitmapImageRepForCachingDisplay(in: content.bounds)!
        content.cacheDisplay(in: content.bounds, to: bitmap)
        try bitmap.representation(using: .png, properties: [:])!.write(to: outputDirectory.appendingPathComponent("task35-hejo-failure.png"))
    }
    print("AT-HF-86 APP PASS")
}
