import AppKit
import Darwin
import ServiceManagement

/// Keep status interpretation separate from registration and the filesystem.
enum LoginLaunchState: String {
    case enabled, requiresApproval, notRegistered, notFound, unknown
}
struct LoginLaunchPresentation: Equatable {
    let checked: Bool
    let canChange: Bool
    let message: String
    let showsSettings: Bool

    static func resolve(_ state: LoginLaunchState, installed: Bool, failed: Bool = false) -> Self {
        guard installed else {
            return Self(checked: false, canChange: false,
                        message: "응용 프로그램 폴더에 설치한 뒤 사용할 수 있어요", showsSettings: false)
        }
        if failed {
            return Self(checked: state == .enabled, canChange: true,
                        message: "등록을 마치지 못했어요. 로그인 항목 설정을 확인해 주세요.", showsSettings: true)
        }
        switch state {
        case .enabled:
            return Self(checked: true, canChange: true, message: "로그인하면 펫이 자동으로 나타나요.", showsSettings: false)
        case .requiresApproval:
            return Self(checked: false, canChange: true, message: "시스템 설정에서 로그인 항목을 허용해 주세요.", showsSettings: true)
        case .notRegistered:
            return Self(checked: false, canChange: true, message: "로그인 시 자동으로 실행하지 않아요.", showsSettings: false)
        case .notFound, .unknown:
            return Self(checked: false, canChange: true, message: "로그인 항목을 확인하지 못했어요. 설정을 확인해 주세요.", showsSettings: true)
        }
    }
}

enum LoginLaunch {
    static var applicationFolders: [URL] {
        [URL(fileURLWithPath: "/Applications", isDirectory: true),
         FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Applications", isDirectory: true)]
    }

    static func isInstalled(bundle: URL = Bundle.main.bundleURL, folders: [URL] = applicationFolders) -> Bool {
        let parent = bundle.resolvingSymlinksInPath().deletingLastPathComponent().path
        return bundle.pathExtension == "app" && folders.contains { $0.resolvingSymlinksInPath().path == parent }
    }

    static var state: LoginLaunchState {
        switch SMAppService.mainApp.status {
        case .enabled: return .enabled
        case .requiresApproval: return .requiresApproval
        case .notRegistered: return .notRegistered
        case .notFound: return .notFound
        @unknown default: return .unknown
        }
    }
    static func setEnabled(_ enabled: Bool) throws {
        guard isInstalled() else { throw NSError(domain: "hejo.LoginLaunch", code: 1,
            userInfo: [NSLocalizedDescriptionKey: "응용 프로그램 폴더에 설치한 뒤 사용할 수 있어요"]) }
        if enabled {
            if state != .enabled { try SMAppService.mainApp.register() }
        } else { try SMAppService.mainApp.unregister() }
    }
    static func openSettings() { SMAppService.openSystemSettingsLoginItems() }
}
