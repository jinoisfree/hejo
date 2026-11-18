import AppKit

@MainActor enum HooksHelp {
    static let title = "승인 대기 알림 연결"
    static let explanation = "기본 연결은 Codex와 Claude Code의 로컬 작업 기록을 읽습니다. 승인 대기를 정확히 알리려면 공식 훅을 추가하세요. 앱에 포함된 연결 안내에서 적용할 설정을 먼저 확인할 수 있습니다."
    static func present() {
        let alert = NSAlert(); alert.messageText = title; alert.informativeText = explanation
        for title in ["연결 안내 열기", "닫기", "연결", "연결 해제"] { alert.addButton(withTitle:title) }
        let choice = alert.runModal()
        if choice == .alertFirstButtonReturn {
            if let url = Bundle.main.url(forResource:"연결안내",withExtension:"html") { NSWorkspace.shared.open(url) }
        } else if choice.rawValue >= NSApplication.ModalResponse.alertThirdButtonReturn.rawValue {
            guard let script = Bundle.main.url(forResource:"configure_hooks",withExtension:"py") else { return }
            let process = Process(); process.executableURL = URL(fileURLWithPath:"/usr/bin/python3")
            process.arguments = [script.path,"--app",Bundle.main.bundleURL.path,choice == .alertThirdButtonReturn ? "--apply":"--disconnect"]
            process.standardOutput = FileHandle.nullDevice; process.standardError = FileHandle.nullDevice
            do { try process.run(); process.waitUntilExit() } catch { let failed=NSAlert();failed.messageText=title;failed.informativeText="설정과 연결 기록을 확인해 주세요.";failed.runModal();return }
            let result = NSAlert(); result.messageText = title
            result.informativeText = process.terminationStatus == 0 ? (choice == .alertThirdButtonReturn ? "Codex 공식 훅은 /hooks에서 신뢰 검토가 필요합니다. 기존 작업을 중단하거나 재시작하지 않습니다.":"연결 해제") : "기존 설정 보존을 위해 중단. 기존 내용과 추가 항목을 검토한 뒤 별도로 병합해야 합니다."
            result.addButton(withTitle:"닫기"); result.runModal()
        }
    }
}
