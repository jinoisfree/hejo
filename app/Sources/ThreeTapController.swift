import AppKit
import Darwin

@MainActor
final class ThreeTapController: NSObject, NSWindowDelegate {
    static let title = "세 손가락 탭으로 대화창 여닫기"
    static let healthyText = "macOS 업데이트가 있었지만 세 손가락 탭은 정상 동작해요. 그대로 쓰면 돼요."
    static let lookupText = "시스템 설정 > 트랙패드에서 찾아보기를 세게 클릭으로 바꾸면 겹치지 않아요."
    private let store: LocalStore
    private let live: Bool
    private let reader: ThreeTapReading
    private let now: () -> Double
    private let lookupUsesThreeFingers: () -> Bool
    private let machineName: () -> String
    private var check: ThreeTapCheck
    private var wake: NSObjectProtocol?
    private(set) var noticeAlert: NSAlert?
    private var noticeFailure: ThreeTapFailure?
    private var pendingNotices: [(String, ThreeTapFailure?)] = []
    private var lastTap = -Double.infinity
    private(set) var enabled: Bool
    private(set) var health: ThreeTapHealth = .absent
    var onChange: (() -> Void)?
    var onTap: (() -> Void)?
    var onNotice: ((String, ThreeTapFailure?) -> Void)?
    var os: String, build: String, app: String, appBuild: String
    private var osKey: String { os + "|" + build }
    var failure: ThreeTapFailure? {
        health.failure.map { ThreeTapFailure(mac: machineName(), os: os, build: build, app: app, appBuild: appBuild, stage: $0) }
    }
    init(store: LocalStore, live: Bool, reader: ThreeTapReading = ThreeTapReader(),
         now: @escaping () -> Double = { ProcessInfo.processInfo.systemUptime },
         lookupUsesThreeFingers: @escaping () -> Bool = {
             ["com.apple.AppleMultitouchTrackpad", "com.apple.driver.AppleBluetoothMultitouch.trackpad"].contains {
                 (UserDefaults.standard.persistentDomain(forName: $0)?["TrackpadThreeFingerTapGesture"] as? Int) == 2
             }
         }, machineName: @escaping () -> String = { Host.current().localizedName ?? "Mac" }) throws {
        self.store = store; self.live = live; self.reader = reader
        self.now = now; self.lookupUsesThreeFingers = lookupUsesThreeFingers; self.machineName = machineName
        enabled = store.settings.threeTapEnabled ?? true
        check = ThreeTapCheck(lastOS: store.settings.threeTapCheckedOS, failures: Set(store.settings.threeTapFailures ?? []), pendingUpdate: store.settings.threeTapPendingUpdate ?? false)
        let version = ProcessInfo.processInfo.operatingSystemVersion
        os = "\(version.majorVersion).\(version.minorVersion).\(version.patchVersion)"
        var count = 0; sysctlbyname("kern.osversion", nil, &count, nil, 0)
        var bytes = [CChar](repeating: 0, count: max(1, count)); sysctlbyname("kern.osversion", &bytes, &count, nil, 0)
        build = String(cString: bytes)
        app = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "unknown"
        appBuild = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "unknown"
        super.init()
        check.begin(os: osKey)
        try store.update { $0.threeTapCheckedOS = check.lastOS; $0.threeTapPendingUpdate = check.pendingUpdate }
    }
    func start() {
        guard live, enabled, health.failure == nil else { return }
        reader.onHealth = { [weak self] state in self?.receive(state) }
        reader.onTap = { [weak self] in self?.tapped() }
        reader.start()
        if wake == nil {
            wake = NSWorkspace.shared.notificationCenter.addObserver(forName: NSWorkspace.didWakeNotification, object: nil, queue: .main) { [weak self] _ in
                MainActor.assumeIsolated { self?.reader.reconnect() }
            }
        }
    }
    func stop() {
        reader.stop()
        if let wake { NSWorkspace.shared.notificationCenter.removeObserver(wake); self.wake = nil }
    }
    func toggle() {
        guard health.failure == nil else { return }
        guard persist({ $0.threeTapEnabled = !enabled }) else { return }
        enabled.toggle()
        if enabled { start(); warnLookup() } else { stop() }
        onChange?()
    }
    func tapped() {
        let time = now()
        guard enabled, health == .ready, time-lastTap >= ThreeTapGesture.cooldown else { return }
        lastTap = time; onTap?()
    }
    func receive(_ state: ThreeTapHealth) {
        guard health.failure == nil else { return }
        health = state
        if case .failed = state { stop() }
        let notice = check.receive(state, os: osKey, failureKey: failure?.key ?? "")
        _ = persist {
            $0.threeTapCheckedOS = check.lastOS
            $0.threeTapPendingUpdate = check.pendingUpdate
            $0.threeTapFailures = Array(check.failures).sorted()
        }
        onChange?()
        if notice == .failure, let failure {
            onNotice?("세 손가락 탭을 잠시 껐어요. 수정 요청문을 복사해 다른 작업 대화에 붙여 넣어 주세요.", failure)
        } else if notice == .healthy { onNotice?(Self.healthyText, nil) }
        if state == .ready { warnLookup() }
    }
    private func warnLookup() {
        guard live, store.settings.threeTapLookupExplained != true else { return }
        if lookupUsesThreeFingers(), persist({ $0.threeTapLookupExplained = true }) {
            onNotice?(Self.lookupText, nil)
        }
    }
    private func persist(_ change: (inout LocalSettings) -> Void) -> Bool {
        do { try store.update(change); return true }
        catch { onNotice?("설정을 저장하지 못했어요. 저장 공간을 확인해 주세요.", nil); return false }
    }
    func showNotice(_ text: String, failure: ThreeTapFailure?) {
        if let noticeAlert {
            if noticeAlert.informativeText != text || noticeFailure != failure {
                if !pendingNotices.contains(where: { $0.0 == text && $0.1 == failure }) { pendingNotices.append((text, failure)) }
            }
            return
        }
        let alert = makeAlert(text, failure: failure)
        noticeAlert = alert; noticeFailure = failure
        alert.layout(); alert.window.delegate = self; alert.window.isReleasedWhenClosed = false
        for (index, button) in alert.buttons.enumerated() {
            button.tag = index; button.target = self; button.action = #selector(noticeButton(_:))
        }
        alert.window.center(); OptionWindows.show(alert.window)
    }
    @objc private func noticeButton(_ button: NSButton) {
        if button.tag == 0, let noticeFailure { Self.copy(noticeFailure) }
        noticeAlert?.window.close()
    }
    func windowWillClose(_ notification: Notification) {
        guard let window = notification.object as? NSWindow, window === noticeAlert?.window else { return }
        noticeAlert = nil; noticeFailure = nil
        if !pendingNotices.isEmpty {
            let next = pendingNotices.removeFirst()
            DispatchQueue.main.async { [weak self] in self?.showNotice(next.0, failure: next.1) }
        }
    }
    func makeAlert(_ text: String, failure: ThreeTapFailure?) -> NSAlert {
        let alert = NSAlert(); alert.messageText = "세 손가락 탭"
        alert.informativeText = text
        if let failure {
            let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 480, height: 230))
            let request = NSTextView(frame: scroll.bounds)
            request.string = failure.request; request.isEditable = false; request.isSelectable = true
            request.font = .systemFont(ofSize: 13); request.textContainerInset = NSSize(width: 8, height: 8)
            request.isVerticallyResizable = true; request.autoresizingMask = [.width]
            request.textContainer?.widthTracksTextView = true
            scroll.hasVerticalScroller = true; scroll.borderType = .bezelBorder; scroll.documentView = request
            alert.accessoryView = scroll
        }
        alert.alertStyle = failure == nil ? .informational : .warning
        if failure != nil { alert.addButton(withTitle: "수정 요청문 복사") }
        alert.addButton(withTitle: "닫기")
        return alert
    }
    static func copy(_ failure: ThreeTapFailure, to pasteboard: NSPasteboard = .general) { pasteboard.clearContents(); pasteboard.setString(failure.request, forType: .string) }
}
