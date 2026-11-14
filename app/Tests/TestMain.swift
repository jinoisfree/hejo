import AppKit

func check(_ condition: @autoclosure () throws -> Bool, _ message: String) throws {
    if try !condition() { throw TestFailure.assertion(message) }
}
enum TestFailure: Error { case assertion(String) }
@MainActor func pause(_ seconds: Double) async { try? await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000)) }
@MainActor func waitForTransition(_ controller: PetController, progress: CGFloat) async {
    let deadline = ProcessInfo.processInfo.systemUptime + 2
    while controller.transitionProgress != progress && ProcessInfo.processInfo.systemUptime < deadline {
        await pause(0.01)
    }
}

@MainActor func waitFor(_ seconds: Double = 8, _ condition: () -> Bool) async throws {
    let deadline = Date().addingTimeInterval(seconds)
    while !condition(), Date() < deadline { await pause(0.025) }
    try check(condition(), "timed out")
}
final class MemoryCredentials: GateCredentialStore {
    var token: String?
    func read(account: String) -> String? { token }
    func save(_ token: String, account: String) -> Bool { self.token = token; return true }
    func delete(account: String) { token = nil }
}
@MainActor final class TestDelegate: NSObject, NSApplicationDelegate {
    func applicationDidFinishLaunching(_ notification: Notification) {
        Task { @MainActor in
            do {
                let args = CommandLine.arguments
                if args.contains("--lock-child") {
                    let lock = try InstanceLock(directory: URL(fileURLWithPath: args[2])); withExtendedLifetime(lock) { }
                } else if args.count > 1 && args[1] == "--conversation" {
                    try await conversationNetwork(args)
                } else if args.count > 1 && args[1].hasPrefix("--network-") {
                    try await network(args)
                } else { try await unit() }
                print("APP_TEST_OK"); fflush(stdout); exit(0)
            } catch GateFailure.alreadyRunning { print("INSTANCE_LOCK_REJECTED_EXPECTED"); fflush(stdout); exit(1) }
            catch { print("APP_TEST_FAILED \(error)"); fflush(stdout); exit(1) }
        }
    }
    func unit() async throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: dir) }
        let store = try LocalStore(directory: dir)
        let instance = try InstanceLock(directory: dir)
        let p = Process(); p.executableURL = Bundle.main.executableURL; p.arguments = ["--lock-child", dir.path]
        try p.run()
        while p.isRunning { await pause(0.02) }
        try check(p.terminationStatus == 1, "single instance rejects competing process")
        withExtendedLifetime(instance) { }
        try store.select(address: "ws://localhost:47820", device: "test-device")
        try store.append(["v": 1, "type": "delete", "seq": 1, "msg_id": UUID().uuidString.lowercased()])
        try store.update { $0.applied = 999 }
        let restored = try LocalStore(directory: dir)
        try check(restored.settings.applied == 1, "applied restored from durable contiguous replica")
        var broken = try Data(contentsOf: restored.cacheURL); broken.append(Data("{incomplete".utf8)); try broken.write(to: restored.cacheURL)
        try check(try LocalStore(directory: dir).settings.applied == 1, "corrupt cache tail discarded")
        try FileManager.default.removeItem(at: restored.cacheURL)
        let reset = try LocalStore(directory: dir)
        try check(reset.settings.applied == 0, "cache deletion resets applied")
        try check(try GateClient.endpoint("localhost:47820").absoluteString == "ws://localhost:47820/v1/ws", "endpoint")
        for invalid in ["https://localhost", "ws://owner@localhost", "ws://localhost/x", "ws://localhost?token=x"] {
            do { _ = try GateClient.endpoint(invalid); throw TestFailure.assertion("bad endpoint accepted") } catch GateFailure.badAddress { }
        }
        var delay = ReconnectDelay()
        try check((0..<8).map { _ in delay.next() } == [1,2,4,8,16,30,30,30], "backoff capped")
        delay.reset(); try check(delay.next() == 1, "backoff reset")
        _ = try GateClient.encoded(["v": 1, "type": "pong"])
        do { _ = try GateClient.encoded(["v": 1, "type": "send", "text": String(repeating: "한", count: 400_000)]); throw TestFailure.assertion("UTF8 size limit missing") } catch GateFailure.tooLarge { }
        let memory = MemoryCredentials(), auth = GateClient(store: reset, credentials: MemoryCredentials())
        _ = try await auth.receive(["v":1, "type":"pair_rejected", "reason":"wrong"])
        try check(auth.status == .wrongCode, "wrong code guidance")
        let revoked = GateClient(store: reset, credentials: memory)
        memory.token = "test-credential"
        _ = try await revoked.receive(["v":1, "type":"auth_rejected", "reason":"revoked"])
        try check(revoked.status == .revoked && memory.token == nil, "revocation stops and removes credential")
        try check(GateKeychain().read(account: "bad\"") == nil && !GateKeychain().save("bad\"", account: "test"), "keychain command input rejects quotes")
        try check(PetIdentity.normalized("  ") == "hejo" && PetIdentity.normalized(String(repeating:"a", count:30)).count == 20, "neutral pet identity")
        let atlas = try SpriteAtlas(resourceDirectory: URL(fileURLWithPath: CommandLine.arguments.last!))
        let controller = PetController(store: reset, atlas: atlas)
        let first = PetDisplay(frame: CGRect(x: 0,y: 0,width: 1200,height: 900), visible: CGRect(x: 0,y: 40,width: 1200,height: 830))
        let second = PetDisplay(frame: CGRect(x: 1200,y: 0,width: 1000,height: 800), visible: CGRect(x: 1200,y: 30,width: 1000,height: 740))
        controller.displays = { [first, second] }; controller.placePet(at: CGPoint(x: 500,y: 550)); controller.show()
        controller.reducedMotion = { false }
        let front = NSWorkspace.shared.frontmostApplication?.processIdentifier
        controller.showChat(); try check(controller.chatExpanded && controller.panel.chatExpanded, "AT47 menu opens")
        let open = controller.placementTarget!
        try check(controller.transitionOpenRect == open.globalBubble, "AT47 genie rectangle is PetPlacement")
        let foot = PetLayout.visibleSprite(in: open.spriteRect)
        try check(controller.pet.genie.target.x == min(max(foot.midX, open.bubbleRect.minX), open.bubbleRect.maxX), "AT47 foot anchored distortion")
        try check(controller.transitionProgress == 0, "AT47 opening starts folded")
        await waitForTransition(controller, progress: 1)
        try check(controller.transitionProgress == 1 && controller.transitionSteps > 0, "AT47 0.30s completes")
        try check(!controller.panel.isKeyWindow, "opening does not make key")
        try check(front == NSWorkspace.shared.frontmostApplication?.processIdentifier, "opening keeps foreground app")
        controller.pet.onClick?(); try check(!controller.chatExpanded, "AT47 pet re-click folds")
        await waitForTransition(controller, progress: 0); try check(controller.transitionProgress == 0, "AT47 closing ends folded")
        controller.reducedMotion = { true }
        controller.pet.onClick?(); try check(controller.chatExpanded && controller.transitionSteps == 0, "AT47 reduce motion immediate open")
        let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
        controller.panel.sendEvent(escape); try check(!controller.chatExpanded && controller.transitionSteps == 0, "AT47 Escape folds")
        controller.showChat(); controller.pet.collapseButton.performClick(nil)
        try check(!controller.chatExpanded, "AT47 fold button")
        // Drive the same AppKit input methods that receive real pet events.
        func drag(_ distance: CGFloat) throws {
            let cell = controller.pet.spriteRect
            let grip = stride(from: cell.minY+1, to: cell.maxY, by: 2).lazy.flatMap { y in
                stride(from: cell.minX+1, to: cell.maxX, by: 2).map { CGPoint(x: $0, y: y) }
            }.first { controller.pet.spriteContains($0) }!
            var pointer = controller.panel.convertPoint(toScreen: grip)
            controller.pet.pointerLocation = { pointer }
            func event(_ type: NSEvent.EventType) -> NSEvent { NSEvent.mouseEvent(with: type, location: grip, modifierFlags: [], timestamp: 0, windowNumber: controller.panel.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)! }
            controller.pet.mouseDown(with: event(.leftMouseDown)); pointer.x += distance
            controller.pet.mouseDragged(with: event(.leftMouseDragged)); controller.pet.mouseUp(with: event(.leftMouseUp))
        }
        try drag(3); try check(controller.chatExpanded, "AT48 3px is click")
        let before = controller.placementTarget!.globalSprite
        try drag(5); try check(controller.chatExpanded && controller.placementTarget!.globalSprite != before, "AT48 5px moves without toggling")
        controller.movePet(to: CGPoint(x: 2100,y: 700)); controller.endPetDrag()
        let target = controller.placementTarget!
        try check(second.visible.contains(target.globalBubble), "AT48 second screen edge contains conversation")
        controller.displays = { [first] }
        NotificationCenter.default.post(name: NSApplication.didChangeScreenParametersNotification, object: nil)
        try check(first.visible.contains(controller.placementTarget!.globalBubble), "AT48 removed display clamps placement")
        // Original PetCarrySmoke invariant: carrying from the top holds the bottom, then grows downward past the top.
        let topOrigin = PetLayout.sprite(foot: CGPoint(x: first.visible.midX, y: first.frame.maxY + 500), scale: controller.pet.petScale).origin
        controller.preferredChatSize.height = 600; controller.placePet(at: topOrigin)
        let carry = controller.placementTarget!
        try check(carry.bubbleBelow, "carry opens below at top")
        let anchor = carry.anchorOrigin
        controller.movePet(to: CGPoint(x: anchor.x, y: anchor.y - 40))
        let down = controller.placementTarget!.globalBubble
        try check(abs(down.minY - carry.globalBubble.minY) < 1 && abs(down.height - carry.globalBubble.height + 40) < 1, "carry down keeps bottom and shrinks")
        controller.movePet(to: CGPoint(x: anchor.x, y: anchor.y + 40))
        let up = controller.placementTarget!.globalBubble
        try check(abs(up.minY - carry.globalBubble.minY + 40) < 1 && abs(up.height - carry.globalBubble.height - 40) < 1, "carry beyond top grows downward")
        controller.endPetDrag()
        controller.panel.orderOut(nil)
        try check(LoginLaunchPresentation.resolve(.enabled, installed: false).canChange == false, "login registration requires installation")
        try await conversationUnitTests(resourceDirectory: URL(fileURLWithPath: CommandLine.arguments.last!))
        try await islandTests(resourceDirectory: URL(fileURLWithPath: CommandLine.arguments.last!))
        print("AT-HF-47 automatic PASS; AT-HF-48 PASS; cache/backoff/size/instance PASS")
    }
    func network(_ args: [String]) async throws {
        let mode = args[1], directory = URL(fileURLWithPath: args[2]), endpoint = args[3]
        let store = try LocalStore(directory: directory), client = GateClient(store: store)
        var welcomes = 0, retries: [Int] = []
        client.onStatus = { print("STATUS \($0.text)"); fflush(stdout) }
        client.onFrame = { frame in if frame["type"] as? String == "welcome" { welcomes += 1 } }
        client.onRetry = { retries.append($0); print("RETRY \($0)"); fflush(stdout) }
        if mode == "--network-pair" { try client.pair(address: endpoint, code: "test_code-12", device: "test-device") }
        else { client.resume() }
        try await waitFor(10) { client.status == .connected && store.settings.applied == 4 }
        try check(GateKeychain().read(account: store.settings.credentialAccount) != nil, "AT24 keychain item exists")
        let json = try String(contentsOf: store.settingsURL, encoding: .utf8)
        try check(!json.contains("token") && !json.contains(GateKeychain().read(account: store.settings.credentialAccount)!), "AT24 local json has no token")
        if mode == "--network-too-large" { try await waitFor { client.status == .tooLarge } }
        if mode == "--network-outage" {
            try await waitFor(40) { welcomes >= 2 }
            try check(retries.prefix(4) == [1,2,4,8], "AT25 actual retries increase during ten-second outage")
        }
        if mode == "--network-resume" { print("AT-HF-24 restart welcome PASS") }
        if mode == "--network-outage" { print("AT-HF-25 PASS") }
        await pause(0.15)
        client.stop()
        if mode == "--network-cleanup" { GateKeychain().delete(account: store.settings.credentialAccount) }
    }
}
@main enum AppTests {
    static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let delegate = TestDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
