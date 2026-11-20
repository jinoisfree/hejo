import AppKit
import Sparkle

@MainActor final class AppUpdate: NSObject {
    static let firstCheck: TimeInterval = 30, interval: TimeInterval = 6 * 60 * 60
    private let client: UpdateReleaseClient
    private let reminder: UpdateReminder
    let notices: UpdateNoticeSettings
    private let installation: UpdateInstallation
    private let installer: UpdateInstalling
    private let installed: () -> Bool
    private let current: () -> (version: String, build: String)
    private let now: () -> Date
    private let present: @MainActor (NSAlert) -> NSApplication.ModalResponse
    private var stopped = false, automaticCheckPending = false
    private var generation = 0
    private var task: URLSessionDataTask?
    private(set) var busy = false
    private(set) var timer: Timer?
    private(set) var knownRelease: UpdateRelease?
    var onChange: (() -> Void)?
    var notifyInstalled: (String) -> Void = { _ in }
    var menuTitle: String { knownRelease.map { "업데이트 \($0.version) 설치…" } ?? "업데이트 확인…" }
    var canCheck: Bool { !stopped && !busy && !installer.isBusy }
    init(defaults: UserDefaults = .standard, client: UpdateReleaseClient = UpdateReleaseClient(), installer: UpdateInstalling? = nil,
         installed: @escaping () -> Bool = { LoginLaunch.isInstalled() },
         current: @escaping () -> (String, String) = {
             (Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppIdentity.version,
              Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "")
         }, now: @escaping () -> Date = { Date() },
         present: @escaping @MainActor (NSAlert) -> NSApplication.ModalResponse = { alert in NSApp.activate(ignoringOtherApps: true); return alert.runModal() }) {
        self.client = client; self.installer = installer ?? SparkleInstaller(defaults: defaults)
        reminder = UpdateReminder(defaults: defaults); notices = UpdateNoticeSettings(defaults: defaults)
        installation = UpdateInstallation(defaults: defaults)
        self.installed = installed; self.current = current; self.now = now; self.present = present
        super.init()
        self.installer.onFailure = { [weak self] error in self?.inform(error.localizedDescription) }
        self.installer.onChange = { [weak self] in self?.onChange?() }
    }
    func start() {
        guard installed(), !stopped, timer == nil else { return }
        let value = current()
        if installation.installed(version: value.version, build: value.build) { notifyInstalled("hejo \(value.version)으로 업데이트됨") }
        let timer = Timer(timeInterval: Self.interval, repeats: true) { [weak self] _ in
            DispatchQueue.main.async { self?.check(manual: false) }
        }
        timer.fireDate = now().addingTimeInterval(Self.firstCheck)
        RunLoop.main.add(timer, forMode: .common); self.timer = timer
    }
    func stop() {
        stopped = true; generation += 1; timer?.invalidate(); timer = nil
        task?.cancel(); task = nil; client.close(); installer.stop()
    }
    func noticesChanged() {
        if !notices.enabled, automaticCheckPending {
            generation += 1; task?.cancel(); task = nil; automaticCheckPending = false; busy = false
        }
        onChange?()
    }
    private func allows(_ manual: Bool) -> Bool {
        UpdateNoticePolicy.allows(manual: manual, enabled: notices.enabled, reminderAllows: reminder.allowsCheck(manual: false, now: now()))
    }
    @objc func checkNow() {
        check(manual: true, installing: knownRelease)
    }
    func check(manual: Bool, installing: UpdateRelease? = nil) {
        guard !stopped, !busy, !installer.isBusy, allows(manual) else { return }
        guard installed() else { if manual { inform("응용 프로그램 폴더에 설치한 뒤 업데이트할 수 있어요.") }; return }
        busy = true; automaticCheckPending = !manual; generation += 1; onChange?()
        let epoch = generation
        task = client.latest { [weak self] result in
            DispatchQueue.main.async {
                guard let self, !self.stopped, epoch == self.generation else { return }
                self.task = nil; self.busy = false; self.automaticCheckPending = false; self.onChange?()
                guard self.allows(manual) else { return }
                switch result {
                case .success(let release):
                    guard SUStandardVersionComparator().compareVersion(release.version, toVersion: self.current().version) == .orderedDescending else {
                        self.knownRelease = nil; self.onChange?()
                        if manual { self.inform("최신 버전이에요 (\(self.current().version))") }; return
                    }
                    self.knownRelease = release; self.onChange?()
                    if let installing, installing == release {self.begin(release);return}
                    self.busy = true
                    let response = self.present(Self.automaticAlert(version: release.version))
                    self.busy = false; self.onChange?()
                    guard !self.stopped, self.allows(manual) else { return }
                    if response == .alertSecondButtonReturn { self.reminder.hideToday(now: self.now()) }
                    else if response == .alertFirstButtonReturn { self.begin(release) }
                case .failure(let error):
                    if manual { self.inform((error as? UpdateFailure ?? .invalidRelease).localizedDescription) }
                }
            }
        }
    }
    private func begin(_ release: UpdateRelease) {
        guard !stopped, !busy, !installer.isBusy else { return }
        guard installed() else { inform("응용 프로그램 폴더에 설치한 뒤 업데이트할 수 있어요."); return }
        do { try installer.begin(release); onChange?() }
        catch { inform((error as? UpdateFailure ?? .invalidRelease).localizedDescription) }
    }
    static func automaticAlert(version: String) -> NSAlert {
        let alert = NSAlert(); alert.alertStyle = .informational
        alert.messageText = "hejo 새 버전 \(version)"
        alert.informativeText = "새 업데이트가 있어요. 지금 업데이트할까요?\n업데이트하면 새 버전을 받아 지금 앱과 바꾸고 다시 실행해요. 설정과 대화 기록은 그대로예요."
        alert.addButton(withTitle: "업데이트"); alert.addButton(withTitle: "오늘 다시 보지 않음"); alert.addButton(withTitle: "나중에")
        alert.buttons[2].keyEquivalent = "\u{1b}"; return alert
    }
    private func inform(_ message: String) {
        let alert = NSAlert(); alert.messageText = "hejo 업데이트"; alert.informativeText = message
        alert.addButton(withTitle: "확인"); _ = present(alert)
    }
}
