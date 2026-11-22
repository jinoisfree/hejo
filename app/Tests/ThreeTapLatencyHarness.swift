#if HEJO_THREE_TAP_DIAGNOSTIC
import AppKit

// The diagnostic builder appends this extension to AppDelegate.swift, so the fixture can
// assemble its private dependencies without adding a test-only production initializer.
// openBubble/refreshPetActivity, the real reader/controller and all window code stay intact.
private final class LatencyCredentials: GateCredentialStore {
    func read(account: String) -> String? { nil }
    func save(_ token: String, account: String) -> Bool { false }
    func delete(account: String) {}
}
/// Substitute only the framework's device enumeration/registration. Injection invokes the
/// exact C callback registered by ThreeTapReader.start(), on a background reading queue.
private enum LatencyTrackpad {
    static let device = NSObject()
    static var pointer: UnsafeMutableRawPointer { Unmanaged.passUnretained(device).toOpaque() }
    static var callback: ThreeTapReader.Callback?
    static let queue = DispatchQueue(label: "hejo.diagnostic-trackpad")
    static let create: @convention(c) () -> Unmanaged<CFArray>? = {
        var value: UnsafeRawPointer? = UnsafeRawPointer(pointer)
        var callbacks = kCFTypeArrayCallBacks
        return Unmanaged.passRetained(CFArrayCreate(nil, &value, 1, &callbacks))
    }
    static let register: @convention(c) (UnsafeMutableRawPointer, ThreeTapReader.Callback) -> Void = { _, frame in callback = frame }
    static let unregister: @convention(c) (UnsafeMutableRawPointer, ThreeTapReader.Callback) -> Void = { _, _ in callback = nil }
    static let start: @convention(c) (UnsafeMutableRawPointer, Int32) -> Void = { _, _ in }
    static let stop: @convention(c) (UnsafeMutableRawPointer) -> Void = { _ in }
    static let running: @convention(c) (UnsafeMutableRawPointer) -> Bool = { _ in true }
    static let dimensions: @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<Int32>, UnsafeMutablePointer<Int32>) -> Int32 = { _, rows, columns in rows.pointee = 20; columns.pointee = 20; return 0 }
    static let deviceID: @convention(c) (UnsafeMutableRawPointer, UnsafeMutablePointer<UInt64>) -> Int32 = { _, id in id.pointee = 1; return 0 }
    static func reader() -> ThreeTapReader {
        ThreeTapReader(loadLibrary: { pointer }, resolveSymbol: { _, symbol in
            switch symbol {
            case "MTDeviceCreateList": return unsafeBitCast(create, to: UnsafeMutableRawPointer.self)
            case "MTRegisterContactFrameCallback": return unsafeBitCast(register, to: UnsafeMutableRawPointer.self)
            case "MTUnregisterContactFrameCallback": return unsafeBitCast(unregister, to: UnsafeMutableRawPointer.self)
            case "MTDeviceStart": return unsafeBitCast(start, to: UnsafeMutableRawPointer.self)
            case "MTDeviceStop": return unsafeBitCast(stop, to: UnsafeMutableRawPointer.self)
            case "MTDeviceIsRunning": return unsafeBitCast(running, to: UnsafeMutableRawPointer.self)
            case "MTDeviceGetSensorDimensions": return unsafeBitCast(dimensions, to: UnsafeMutableRawPointer.self)
            case "MTDeviceGetDeviceID": return unsafeBitCast(deviceID, to: UnsafeMutableRawPointer.self)
            default: return nil
            }
        })
    }
    static func injectTap() {
        guard let frame = callback else { return }
        queue.async {
            let data = UnsafeMutableRawPointer.allocate(byteCount: 3 * 96, alignment: 8)
            defer { data.deallocate() }
            data.initializeMemory(as: UInt8.self, repeating: 0, count: 3 * 96)
            for index in 0..<3 {
                let contact = data.advanced(by: index * 96)
                contact.storeBytes(of: Int32(index), toByteOffset: 16, as: Int32.self)
                contact.storeBytes(of: Int32(4), toByteOffset: 20, as: Int32.self)
                contact.storeBytes(of: Float(0.2 + Double(index) * 0.1), toByteOffset: 32, as: Float.self)
                contact.storeBytes(of: Float(0.5), toByteOffset: 36, as: Float.self)
            }
            _ = frame(pointer, data, 3, ProcessInfo.processInfo.systemUptime, 0)
            Thread.sleep(forTimeInterval: 0.08)
            _ = frame(pointer, nil, 0, ProcessInfo.processInfo.systemUptime, 1)
        }
    }
}
extension AppDelegate {
    fileprivate func startLatencyFixture(directory: URL, resources: URL) throws {
        store = try LocalStore(directory: directory)
        try store.update { $0.threeTapEnabled = true; $0.threeTapLookupExplained = true }
        ChatAppearance.bind(store)
        bubble = BubbleReveal(store: store)
        client = GateClient(store: store, credentials: LatencyCredentials())
        pet = PetController(store: store, atlas: try SpriteAtlas(resourceDirectory: resources))
        conversation = try ConversationController(client: client, downloads: directory.appendingPathComponent("Downloads"))
        conversation.receive(["type":"roster", "employees":[["id":"alpha", "name":"직원 A", "aliases":[]]]])
        let key = ConversationKey(employee: "alpha", thread: "11111111-1111-4111-8111-111111111111")
        for index in 1...20 {
            conversation.receive(["v":1, "type":"message", "seq":index, "msg_id":UUID().uuidString.lowercased(),
                                  "employee":key.employee, "thread":key.thread, "role":"employee",
                                  "text":"진단용 대화입니다. 창을 열고 닫는 시간을 측정합니다.", "files":[], "buttons":[],
                                  "reply_state":NSNull(), "ts":"2026-01-01T00:00:00Z"])
        }
        bubbleReply = BubbleReplyCard(controller: conversation); pet.pet.installBubbleReply(bubbleReply)
        conversationView = ConversationView(controller: conversation)
        conversationView.homePetImage = pet.pet.atlas.image(row: 0, frame: 0)
        pet.pet.installConversation(conversationView); pet.installDrawer(conversationView)
        pet.installWeb(WebPaneModel(downloads: conversation.files.downloads.root))
        // These are the same click/expansion callbacks as normal launch, with a fixed fake target.
        pet.pet.onClick = { [weak self] in
            guard let self else { return }
            if self.pet.chatExpanded { self.pet.collapseChat() } else { self.openBubble(key) }
        }
        pet.onExpansionChanged = { [weak self] expanded in
            if !expanded { self?.conversationView.folded() }
            self?.conversation.model.setVisible(expanded)
            if expanded { self?.conversation.model.memberState.activate() }
            self?.refreshPetActivity()
        }
        let previousChange = conversation.onChange
        conversation.onChange = { [weak self] in previousChange?(); self?.refreshPetActivity() }
        pet.onFocus = { [weak self] in
            guard let self else { return }; self.pet.panel.makeFirstResponder(self.conversationView.editor.editor)
        }
        conversationView.refresh(); pet.canCollapse = { [weak self] in self?.conversationView.pickingFiles != true }
        threeTap = try ThreeTapController(store: store, live: true, reader: LatencyTrackpad.reader(), lookupUsesThreeFingers: { false }, machineName: { "진단용 Mac" })
        threeTap.onTap = { [weak self] in self?.pet.threeFingerTapped() }
        threeTap.onNotice = { _, _ in print("DIAGNOSTIC_READER_NOTICE") }
        threeTap.start(); pet.show()
    }
    fileprivate func stopLatencyFixture() { threeTap?.stop(); pet?.panel.orderOut(nil); client?.stop() }
    fileprivate var latencyReaderReady: Bool { threeTap.health == .ready }
    fileprivate var latencyReaderAbsent: Bool { threeTap.health == .absent }
}

@MainActor private final class LatencyDelegate: NSObject, NSApplicationDelegate {
    let product = AppDelegate()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    var timer: Timer?
    var window: NSWindow!
    var label: NSTextField!
    var injected = 0
    var lastInjection = 0.0
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            guard CommandLine.arguments.count == 2, let trace = ThreeTapDiagnostics.output,
                  !FileManager.default.fileExists(atPath: trace.path) else { throw NSError(domain: "diagnostic-arguments", code: 1) }
            try product.startLatencyFixture(directory: directory, resources: URL(fileURLWithPath: CommandLine.arguments[1]))
            window = NSWindow(contentRect: NSRect(x: 100, y: 100, width: 560, height: 130), styleMask: [.titled], backing: .buffered, defer: false)
            window.title = "hejo 세 손가락 탭 진단 · 프레임 주입"
            window.isReleasedWhenClosed = false
            label = NSTextField(wrappingLabelWithString: "자동 측정 중입니다. 직접 탭하지 마세요.\n열기 10회 + 닫기 10회")
            label.frame = NSRect(x: 20, y: 20, width: 520, height: 90); window.contentView?.addSubview(label)
            window.orderFrontRegardless()
            let start = ProcessInfo.processInfo.systemUptime
            timer = Timer.scheduledTimer(withTimeInterval: 0.25, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated {
                    guard let self else { return }
                    let rows = (try? String(contentsOf: trace))?.split(separator: "\n") ?? []
                    self.label.stringValue = "자동 프레임 주입: \(rows.count)/20회 기록\n열기 10회 + 닫기 10회\n가짜 대화 · 네트워크 연결 없음"
                    let now = ProcessInfo.processInfo.systemUptime
                    if rows.count >= 20 { print("INJECTED_TRACE_COMPLETE rows=\(rows.count)"); self.finish(0) }
                    else if now - start > 120 { print("INJECTED_TRACE_TIMEOUT rows=\(rows.count)"); self.finish(2) }
                    else if rows.count == self.injected, now - self.lastInjection >= 1.2, now - start >= 2 {
                        self.injected += 1; self.lastInjection = now; LatencyTrackpad.injectTap()
                    }
                }
            }
            print("INJECTED_TRACE_READY"); fflush(stdout)
        } catch { print("INJECTED_TRACE_SETUP_FAILED"); finish(1) }
    }
    func finish(_ code: Int32) {
        timer?.invalidate(); product.stopLatencyFixture(); window?.orderOut(nil)
        try? FileManager.default.removeItem(at: directory)
        exit(code)
    }
}
@main private enum LatencyMain {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let delegate = LatencyDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif
