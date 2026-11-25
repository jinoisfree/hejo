#if HEJO_HISTORY_BASELINE
import AppKit

// In-memory credentials: the diagnostic must never touch the login keychain.
private final class HistoryCredentials: GateCredentialStore {
    func read(account: String) -> String? { nil }
    func save(_ token: String, account: String) -> Bool { true }
    func delete(account: String) {}
}
@MainActor private final class HistoryDelegate: NSObject, NSApplicationDelegate {
    var client: GateClient!
    var controller: ConversationController!
    var view: ConversationView!
    var window: NSWindow!
    var start = ProcessInfo.processInfo.systemUptime
    var firstDisplay: Double?
    var eventDelays = [Double]()
    var frameCount = 0
    var timer: DispatchSourceTimer?
    var didSwitch = false
    var output: URL!
    var expected = 0
    var semantics: HistorySemantics?
    var finishing = false
    func applicationDidFinishLaunching(_ notification: Notification) {
        var stage = "config"
        do {
            guard CommandLine.arguments.count == 2 else { throw GateFailure.protocolError }
            let configURL = URL(fileURLWithPath: CommandLine.arguments[1])
            let config = try JSONSerialization.jsonObject(with: Data(contentsOf: configURL)) as! [String: Any]
            let root = configURL.deletingLastPathComponent().standardizedFileURL
            stage = "isolation-root"
            guard config["fixture"] as? String == "history-baseline", root.path.hasPrefix(FileManager.default.temporaryDirectory.resolvingSymlinksInPath().path) else { throw GateFailure.storage }
            output = root.appendingPathComponent("result.json")
            expected = config["count"] as! Int
            stage = "store"
            let store = try LocalStore(directory: root.appendingPathComponent("app"))
            if config["semantic"] as? Bool == true {
                try store.select(address: config["address"] as! String, device: "History fixture")
                try store.update { $0.stateAccount = "fixture-member"; $0.stateDevice = "fixture-device" }
            }
            ChatAppearance.bind(store)
            client = GateClient(store: store, credentials: HistoryCredentials())
            stage = "controller"
            controller = try ConversationController(client: client, downloads: root.appendingPathComponent("downloads"))
            controller.clock = { Date(timeIntervalSince1970: 1767225600) }
            if config["semantic"] as? Bool == true { semantics = HistorySemantics(controller) }
            view = ConversationView(controller: controller, clipboardArea: root.appendingPathComponent("clipboard"))
            window = NSWindow(contentRect: NSRect(x: 80, y: 80, width: 700, height: 600), styleMask: [.titled], backing: .buffered, defer: false)
            window.isReleasedWhenClosed = false; window.contentView = view; window.orderFrontRegardless()
            let receive = client.onFrame
            client.onFrame = { [weak self] frame in
                receive?(frame)
                guard let self else { return }
                self.frameCount += 1
                if let kind = frame["type"] as? String, ["welcome", "message", "edit", "state", "delete", "room", "room_deleted", "sync_done"].contains(kind) {
                    self.semantics?.snapshot(kind + ":" + String(frame["seq"] as? Int ?? 0))
                }
                if self.firstDisplay == nil, !self.controller.model.messages.isEmpty {
                    self.view.layoutSubtreeIfNeeded(); self.window.displayIfNeeded()
                    self.firstDisplay = ProcessInfo.processInfo.systemUptime - self.start
                }
            }
            start = ProcessInfo.processInfo.systemUptime
            timer = DispatchSource.makeTimerSource(queue: DispatchQueue(label: "history-input-events"))
            timer?.schedule(deadline: .now(), repeating: 0.25)
            timer?.setEventHandler { [weak self] in
                let queued = ProcessInfo.processInfo.systemUptime
                DispatchQueue.main.async {
                    guard let self else { return }
                    self.eventDelays.append(ProcessInfo.processInfo.systemUptime - queued)
                    if self.semantics == nil { self.controller.setText("격리 입력") }
                    if self.semantics == nil, !self.didSwitch, !self.controller.model.rooms.isEmpty {
                        self.view.chooseEmployee("alpha"); self.didSwitch = true
                    }
                    if self.client.replayComplete, !self.finishing { self.finishing = true; Task { await self.finish() } }
                }
            }
            timer?.resume()
            stage = "pair"
            try client.pair(address: config["address"] as! String, code: config["code"] as! String, device: "History fixture")
        } catch { print("HISTORY_SETUP_FAILED stage=\(stage) domain=\((error as NSError).domain) code=\((error as NSError).code)"); exit(1) }
    }
    func finish() async {
        timer?.cancel(); client.stop()
        do {
            guard semantics != nil || controller.model.messages.count == expected else { throw GateFailure.protocolError }
            var usage = rusage(); getrusage(RUSAGE_SELF, &usage)
            var result: [String: Any] = ["messages": controller.model.messages.count, "frames": frameCount,
                "applied": client.store.settings.applied, "elapsed": ProcessInfo.processInfo.systemUptime - start,
                "firstDisplay": firstDisplay ?? -1, "mainQueueDelays": eventDelays,
                "cacheBytes": try Data(contentsOf: client.store.cacheURL).count,
                "peakRSSBytes": usage.ru_maxrss,
                "userCPUSeconds": Double(usage.ru_utime.tv_sec) + Double(usage.ru_utime.tv_usec) / 1_000_000,
                "systemCPUSeconds": Double(usage.ru_stime.tv_sec) + Double(usage.ru_stime.tv_usec) / 1_000_000]
            if let semantics { result["semantic"] = try await semantics.finish(view: view) }
            try JSONSerialization.data(withJSONObject: result, options: [.sortedKeys]).write(to: output)
            window.orderOut(nil); exit(0)
        } catch { print("HISTORY_RESULT_FAILED"); exit(1) }
    }
}
@main private enum HistoryMain {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let delegate = HistoryDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
#endif
