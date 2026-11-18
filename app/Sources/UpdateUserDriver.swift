import AppKit
import Sparkle

/// Every install is either the app's explicit button press or a fresh Sparkle consent prompt.
@MainActor final class UpdateUserDriver: SPUStandardUserDriver {
    var prepare: (@escaping (Bool) -> Void) -> Void = { $0(true) }
    var cancelled: () -> Void = {}
    var failure: (Error) -> Void = { _ in }
    var approved = false, consented = false
    func choose(_ choice: SPUUserUpdateChoice, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        guard choice == .install else {
            approved = false; cancelled()
            reply(state.stage == .installing ? .skip : choice); return
        }
        prepare { [weak self] ready in
            self?.approved = ready
            reply(ready ? .install : (state.stage == .installing ? .skip : .dismiss))
        }
    }
    override func showUpdateFound(with item: SUAppcastItem, state: SPUUserUpdateState, reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if consented { choose(.install, state: state, reply: reply); return }
        super.showUpdateFound(with: item, state: state) { [weak self] choice in
            guard let self else { reply(.skip); return }; self.choose(choice, state: state, reply: reply)
        }
    }
    override func showReady(toInstallAndRelaunch reply: @escaping (SPUUserUpdateChoice) -> Void) {
        if approved { reply(.install) }
        else {
            super.showReady(toInstallAndRelaunch: { [weak self] choice in
                guard let self else { reply(.skip); return }
                guard choice == .install else { self.cancelled(); reply(.skip); return }
                self.prepare { ready in self.approved = ready; reply(ready ? .install : .skip) }
            })
        }
    }
    override func showUpdaterError(_ error: Error, acknowledgement: @escaping () -> Void) {
        failure(error); acknowledgement()
    }
}

/// The SDK is the only owner of download, archive verification, app replacement and relaunch.
@MainActor protocol UpdateInstalling: AnyObject {
    var isBusy: Bool { get }
    var onFailure: ((Error) -> Void)? { get set }
    var onChange: (() -> Void)? { get set }
    func begin(_ release: UpdateRelease) throws
    func stop()
}

@MainActor final class SparkleInstaller: NSObject, UpdateInstalling, SPUUpdaterDelegate {
    private let settings: UpdateInstallation
    private var release: UpdateRelease?
    private var updater: SPUUpdater?
    private var driver: UpdateUserDriver?
    private var version: (String, String)?
    private var stopped = false, reported = false
    private(set) var isBusy = false
    var onFailure: ((Error) -> Void)?
    var onChange: (() -> Void)?
    init(defaults: UserDefaults = .standard) { settings = UpdateInstallation(defaults: defaults); super.init() }
    func begin(_ release: UpdateRelease) throws {
        guard !stopped else { throw UpdateFailure.closing }
        guard !isBusy else { return }
        self.release = release; version = nil; reported = false
        if updater == nil {
            let driver = UpdateUserDriver(hostBundle: .main, delegate: nil)
            driver.prepare = { [weak self] done in
                guard let self, !self.stopped, let (version, build) = self.version else { done(false); return }
                self.settings.preparing(version: version, build: build); done(true)
            }
            driver.cancelled = { [weak self] in self?.settings.cancelled() }
            driver.failure = { [weak self] error in self?.report(error) }
            self.driver = driver
            let updater = SPUUpdater(hostBundle: .main, applicationBundle: .main, userDriver: driver, delegate: self)
            updater.automaticallyChecksForUpdates = false
            updater.automaticallyDownloadsUpdates = false
            try updater.start(); self.updater = updater
        }
        driver?.approved = false; driver?.consented = true
        isBusy = true; onChange?(); updater?.checkForUpdates()
    }
    func stop() { stopped = true }
    func feedURLString(for updater: SPUUpdater) -> String? { release?.feedURL.absoluteString }
    func updater(_ updater: SPUUpdater, mayPerform updateCheck: SPUUpdateCheck) throws {
        guard !stopped, release != nil else { throw UpdateFailure.closing }
    }
    static func validate(_ item: SUAppcastItem, release: UpdateRelease) throws -> (String, String) {
        guard release.allows(file: item.fileURL, version: item.displayVersionString, size: item.contentLength,
                             installation: item.installationType, notes: item.releaseNotesURL,
                             information: item.infoURL, hasDeltas: !(item.deltaUpdates?.isEmpty ?? true)) else { throw UpdateFailure.invalidRelease }
        return (item.displayVersionString, item.versionString)
    }
    func updater(_ updater: SPUUpdater, shouldProceedWithUpdate item: SUAppcastItem, updateCheck: SPUUpdateCheck) throws {
        guard !stopped, let release else { throw UpdateFailure.closing }
        version = try Self.validate(item, release: release)
    }
    private func report(_ error: Error) {
        guard !reported, !stopped else { return }; reported = true
        onFailure?(UpdateFailure.invalidRelease)
    }
    func updater(_ updater: SPUUpdater, didFinishUpdateCycleFor updateCheck: SPUUpdateCheck, error: Error?) {
        isBusy = false
        if error != nil || driver?.approved != true { settings.cancelled() }
        driver?.consented = false; onChange?()
        if let error {
            let value = error as NSError
            if value.domain != SUSparkleErrorDomain || (value.code != Int(SUError.noUpdateError.rawValue) && value.code != Int(SUError.installationCanceledError.rawValue)) { report(error) }
        }
    }
}
