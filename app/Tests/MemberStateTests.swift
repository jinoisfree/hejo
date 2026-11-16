import AppKit

@MainActor private final class StateHubFixture {
    var doc = StateDocument()
    var offline = false
    var beforePush: (() throws -> Void)?
    func fetch(_ since: Int?) throws -> StateDocument {
        if offline { throw HubClient.Failure.unreachable }
        return StateDocument(rev: doc.rev, items: since == doc.rev ? [:] : doc.items)
    }
    func push(_ changes: [String: StateEntry]) throws -> StateDocument {
        if offline { throw HubClient.Failure.unreachable }
        try beforePush?(); beforePush = nil
        doc = StateDocument(rev: doc.rev+1, items: MemberState.merge(doc.items, changes)); return doc
    }
    func attach(_ state: MemberState) {
        state.fetch = { try self.fetch($0) }; state.push = { try self.push($0) }
    }
}

@MainActor func memberStateTests() async throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let aStore = try LocalStore(directory: home.appendingPathComponent("a"))
    try aStore.update { $0.readSeq = ["alpha:thread-a": 20]; $0.stateDevice = "mac-a" }
    let a = MemberState(store: aStore), hub = StateHubFixture()
    hub.doc = StateDocument(rev: 1, items: ["pin:alpha": StateEntry(v: "4", at: 50, dev: "mac-b"), "thread:alpha/thread-a": StateEntry(v: "10", at: 50, dev: "mac-b")])
    var unpinned: [Int] = []; a.onUnpinned = { unpinned.append($0) }
    try a.join(member: "member-a", hub: "hub.test", legacy: ["pinned": "alpha,beta,gamma,delta,epsilon,zeta,eta", "muted": "beta", "hidden": "gamma"])
    try check(a.pending["pin:epsilon"]?.v == "5" && a.pending["pin:zeta"] == nil && a.pending.values.allSatisfy { $0.at == 1 } && unpinned == [2], "AT74 migrate five pins at time one and announce two releases once")
    let raw = try JSONSerialization.jsonObject(with: Data(contentsOf: aStore.settingsURL)) as! [String: Any]
    try check(raw["readSeq"] == nil && (raw["stateJoined"] as? [String: Bool])?["hub.test/member-a"] == true && raw["pendingState"] != nil, "AT74 join marker, queue, and read deletion share one durable document")
    // Kill/restart boundary immediately after that local write, before any network request.
    let restarted = MemberState(store: try LocalStore(directory: aStore.directory))
    restarted.onUnpinned = { unpinned.append($0) }
    try restarted.join(member: "member-a", hub: "hub.test", legacy: ["pinned": "zeta"])
    try check(restarted.pending == a.pending && unpinned == [2], "AT74 restart sends the original queue and does not migrate again")
    hub.attach(restarted); await restarted.sync()
    try check(restarted.pending.isEmpty && restarted.value("pin:alpha") == "4" && restarted.read("thread:alpha/thread-a") == 20, "AT74 nonempty hub retains newer B layout but accepts larger migrated A read")
    let b = MemberState(store: try LocalStore(directory: home.appendingPathComponent("b")))
    try b.join(member: "member-a", hub: "hub.test", legacy: [:]); hub.attach(b)
    let edits = ["zone:alpha": "section-b", "pin:beta": "2", "bell:alpha/thread-a": "42", "confirm:post-a": "1", "check:post-a:0": "1"]
    try restarted.set(edits, at: 100); await restarted.sync(); await b.sync()
    try check(edits.allSatisfy { b.value($0.key) == $0.value } && MemberState.interval == 30, "AT74 two clients agree on zone/pin/bell/confirm/check with thirty-second scheduling")
    hub.offline = true; var failed = false; restarted.onFailure = { failed = $0 }
    try restarted.set(["mute:alpha": "1"], at: 101); await restarted.sync()
    try check(failed && restarted.pending["mute:alpha"]?.v == "1" && restarted.value("mute:alpha") == "1", "AT74 failed network preserves usable local view and durable queue")
    hub.offline = false; await restarted.sync(); await b.sync()
    try check(!failed && restarted.pending.isEmpty && b.value("mute:alpha") == "1", "AT74 reconnect resends queued edit")
    try restarted.set(["title:alpha": "first"], at: 102)
    hub.beforePush = { try restarted.set(["title:alpha": "second"], at: 103) }
    await restarted.sync()
    try check(hub.doc.items["title:alpha"]?.v == "second" && restarted.pending.isEmpty, "AT74 an edit during an in-flight PATCH survives its older acknowledgement")
    // A remote-only key was not in this Mac's snapshot before the standardization fetch.
    hub.doc.rev += 1; hub.doc.items["zone:remote"] = StateEntry(v: "remote-section", at: 99, dev: "mac-b")
    let reads = hub.doc.items.filter { MemberState.isRead($0.key) }
    try await restarted.makeLayoutStandard(); await restarted.sync(); await b.sync()
    try check(hub.doc.items["zone:remote"]?.v == nil && hub.doc.items["zone:remote"] != nil && b.value("zone:alpha") == "section-b", "AT74 standardization tombstones absent layout keys and sends local layout")
    try check(hub.doc.items.filter { MemberState.isRead($0.key) } == reads, "AT74 standardization does not touch reads")
    let encoded = try JSONSerialization.jsonObject(with: JSONEncoder().encode(StateEntry(v: nil, at: 5, dev: "mac-a"))) as! [String: Any]
    try check(encoded["v"] is NSNull, "AT73 wire tombstone is explicit null")
    let markerCount = restarted.store.settings.stateJoined?.count
    try restarted.join(member: "member-b", hub: "hub.test", legacy: [:])
    try check(restarted.items.isEmpty && restarted.pending.isEmpty && restarted.store.settings.stateJoined?.count == (markerCount ?? 0)+1, "AT74 different member uses a separate replica and outbox")
    // A failed rename must leave both the in-memory old settings and migration inputs intact.
    let failureStore = try LocalStore(directory: home.appendingPathComponent("failure"))
    try failureStore.update { $0.readSeq = ["alpha:t": 9] }
    let backup = failureStore.directory.appendingPathComponent("previous.json")
    try FileManager.default.moveItem(at: failureStore.settingsURL, to: backup)
    try FileManager.default.createDirectory(at: failureStore.settingsURL, withIntermediateDirectories: false)
    let failure = MemberState(store: failureStore)
    do { try failure.join(member: "member-a", hub: "hub.test", legacy: ["pinned": "alpha"]); throw TestFailure.assertion("migration accepted failed rename") } catch GateFailure.storage { }
    try check(failureStore.settings.readSeq?["alpha:t"] == 9 && failureStore.settings.stateJoined == nil && failureStore.settings.pendingState == nil, "AT74 failed local write does not lose reads or advance join marker")
    try FileManager.default.removeItem(at: failureStore.settingsURL); try FileManager.default.moveItem(at: backup, to: failureStore.settingsURL)
    try failure.join(member: "member-a", hub: "hub.test", legacy: [:])
    try check(failure.read("thread:alpha/t") == 9, "AT74 local failure is recoverable on retry")
    let alert = PetSettingsWindow.layoutConfirmation(connected: true)
    try check(alert.messageText == "이 Mac 화면을 다른 Mac에도 맞출까요?" && alert.informativeText == "같은 hejo 계정으로 로그인한 다른 Mac의 섹션·방 순서·접힘·숨김·알림 끄기·사진이 이 Mac과 같아져요. 읽음 표시는 어느 Mac에서 읽었든 그대로 합쳐져요." && alert.buttons.map(\.title) == ["맞추기", "취소"], "AT74 nineteenth-plan confirmation exact text")
    let offline = PetSettingsWindow.layoutConfirmation(connected: false)
    try check(offline.messageText == "아직 맞출 수 없어요" && offline.informativeText == "hejo에 연결된 뒤 다시 해 주세요.", "AT74 offline explanation")
    let settings = PetSettingsWindow(); var clicked = false; settings.onSyncLayout = { clicked = true }; settings.syncLayout.performClick(nil)
    try check(clicked && settings.tabs.tabViewItems.last?.label == "연결과 동기화", "AT74 real native settings control dispatch")
    b.connect(fetch: { try hub.fetch($0) }, push: { try hub.push($0) })
    await pause(0.03)
    hub.doc.rev += 1; hub.doc.items["check:timer:0"] = StateEntry(v: "1", at: 200, dev: "mac-a")
    try check(b.timer?.timeInterval == 30, "AT74 real synchronization timer repeats every thirty seconds")
    b.timer?.fire(); try await waitFor { b.value("check:timer:0") == "1" }
    hub.doc.rev += 1; hub.doc.items["confirm:activation"] = StateEntry(v: "1", at: 201, dev: "mac-a")
    b.activate(); try await waitFor { b.value("confirm:activation") == "1" }
    b.disconnect(); try check(b.timer == nil && b.fetch == nil, "AT74 sign-out cancels polling and forgets credentials")
    URLProtocol.registerClass(StubHub.self); defer { URLProtocol.unregisterClass(StubHub.self) }
    let wire = HubClient(address: "hub.test:47800")
    let remote = try await wire.state(since: 6, token: "tok")
    let tombstone = StateEntry(v: nil, at: 20, dev: "mac-a")
    let patched = try await wire.patch(state: ["zone:alpha": tombstone], token: "tok")
    try check(remote.rev == 7 && remote.items["read:alpha"]?.v == "42" && patched.rev == 8 && patched.items["zone:alpha"] == tombstone, "AT73 native HubClient decodes authenticated GET and PATCH documents")
    let sent = StubHub.requests.last!
    try check(sent.0 == "PATCH" && sent.1 == "/v1/me/state" && ((sent.2["items"] as? [String: Any])?["zone:alpha"] as? [String: Any])?["v"] is NSNull, "AT73 actual HTTP request carries item tombstones")
    let model = try ConversationModel(store: LocalStore(directory: home.appendingPathComponent("room-read")))
    for seq in 1...2 {
        try model.apply(["type":"message", "seq":seq, "msg_id":UUID().uuidString.lowercased(), "employee":"alpha", "thread":UUID().uuidString.lowercased(), "role":"employee", "text":"fixture", "ts":"2026-01-01T00:00:00Z"])
    }
    model.markAllRead("alpha")
    let roomEntry = model.memberState.items["read:alpha"]
    try check(roomEntry?.v == "2", "AT74 all-read has a room position independent of retained thread entries")
    model.memberState.fetch = { _ in StateDocument() }
    model.memberState.push = { _ in StateDocument(rev: 1, items: ["read:alpha": roomEntry!]) }
    await model.memberState.sync()
    try check(!model.memberState.items.keys.contains { $0.hasPrefix("thread:") } && model.unread(employee: "alpha") == 0, "AT74 pruned thread positions do not make an already-read room unread again")
    print("AT-HF-74 PASS (fake hub, migration, interruption, offline, layout, native UI)")
}

@MainActor func memberStateCapture(outputDirectory: URL) async throws {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    func capture(_ window: NSWindow, _ name: String) async throws {
        window.center(); window.orderFrontRegardless(); await pause(0.3)
        let command = Process(); command.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        command.arguments = ["-x", "-l", String(window.windowNumber), outputDirectory.appendingPathComponent(name).path]
        try command.run(); command.waitUntilExit(); try check(command.terminationStatus == 0, "AT74 capture \(name)")
        window.orderOut(nil)
    }
    let settings = PetSettingsWindow()
    settings.tabs.selectTabViewItem(at: 3)
    try await capture(settings.window, "hejo-sync-settings.png")
    for connected in [true, false] {
        let alert = PetSettingsWindow.layoutConfirmation(connected: connected)
        // macOS can suppress NSAlert's window-server image. Reuse its actual AppKit content
        // in a plain test window; the original dialog construction and controls are unchanged.
        alert.layout()
        let display = NSWindow(contentRect: alert.window.contentView!.bounds, styleMask: [.titled], backing: .buffered, defer: false)
        display.title = "hejo · 확인 창 분리 시험"; display.contentView = alert.window.contentView
        try await capture(display, connected ? "hejo-confirmation.png" : "hejo-offline.png")
    }
    print("TASK24_CAPTURE_OK")
}
