import AppKit

/// Native settings for the pet and this Mac's presentation. The caller owns persistence.
@MainActor final class PetSettingsWindow: NSObject {
    let window: NSWindow
    let tabs = NSTabView(frame: CGRect(x: 0, y: 0, width: 430, height: 310))
    let nameField = NSTextField(frame: CGRect(x: 24, y: 215, width: 250, height: 25))
    let scaleSlider = NSSlider(value: 100, minValue: 25, maxValue: 200, target: nil, action: nil)
    let scaleValue = NSTextField(labelWithString: "100%")
    let bubbleCheck = NSButton(checkboxWithTitle: "말풍선 항상 보이기", target: nil, action: nil)
    let bubbleReplyCheck=NSButton(checkboxWithTitle:"말풍선에서 바로 답하기",target:nil,action:nil)
    let threeTapCheck = NSButton(checkboxWithTitle: ThreeTapController.title, target: nil, action: nil)
    var onThreeTap: (() -> Void)?
    var onBubbleReply:((Bool)->Void)?
    let loginCheck = NSButton(checkboxWithTitle: "로그인 시 실행", target: nil, action: nil)
    let updateNoticesCheck = NSButton(checkboxWithTitle: "업데이트 알림 받기", target: nil, action: nil)
    let updateButton = NSButton(title: "업데이트 확인…", target: nil, action: nil)
    let updateAvailable = NSTextField(labelWithString: "")
    var onAppUpdate: (() -> Void)?, onUpdateNotices: ((Bool) -> Void)?
    let loginStatus = NSTextField(wrappingLabelWithString: "")
    let accountName = NSTextField(labelWithString: "로그인 전")
    let connectionStatus = NSTextField(labelWithString: "서버 연결 전")
    let openAccount = NSButton(title: "로그인·계정 창 열기", target: nil, action: nil)
    let logout = NSButton(title: "로그아웃", target: nil, action: nil)
    let syncLayout = NSButton(title: "화면 배치 동기화…", target: nil, action: nil)
    var onConnections:(()->Void)?
    var onSyncLayout: (() -> Void)?
    var onName: ((String) -> Void)?, onScale: ((Double) -> Void)?, onBubble: ((Bool) -> Void)?, onLogin: ((Bool) -> Void)?
    var onResetChat: (() -> Void)?, onResetPosition: (() -> Void)?
    var onOpenAccount: (() -> Void)?, onLogout: (() -> Void)?

    override init() {
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 430, height: 310), styleMask: [.titled, .closable, .miniaturizable], backing: .buffered, defer: false)
        super.init()
        window.title = "hejo 설정"; window.center(); window.isReleasedWhenClosed = false
        window.contentView = tabs
        let general = NSTabViewItem(identifier: "general"); general.label = "일반"
        let generalView = NSView(frame: tabs.bounds)
        loginCheck.frame = CGRect(x: 24, y: 215, width: 250, height: 25)
        loginCheck.target = self; loginCheck.action = #selector(changeLogin)
        loginStatus.font = .systemFont(ofSize: 11); loginStatus.textColor = .secondaryLabelColor
        loginStatus.frame = CGRect(x: 24, y: 165, width: 365, height: 42)
        let loginSettings = NSButton(title: "로그인 항목 설정 열기", target: self, action: #selector(openLoginSettings))
        loginSettings.frame = CGRect(x: 24, y: 125, width: 185, height: 30)
        generalView.addSubview(loginCheck); generalView.addSubview(loginStatus); generalView.addSubview(loginSettings)
        updateNoticesCheck.frame = CGRect(x: 24, y: 90, width: 300, height: 25)
        updateNoticesCheck.target = self; updateNoticesCheck.action = #selector(changeUpdateNotices)
        updateButton.frame = CGRect(x: 24, y: 45, width: 185, height: 30)
        updateButton.target = self; updateButton.action = #selector(checkAppUpdate)
        updateAvailable.frame = CGRect(x: 24, y: 15, width: 365, height: 20)
        updateAvailable.font = .systemFont(ofSize: 12); updateAvailable.textColor = .secondaryLabelColor
        for view in [updateNoticesCheck, updateButton, updateAvailable] { generalView.addSubview(view) }
        general.view = generalView; tabs.addTabViewItem(general)

        let pet = NSTabViewItem(identifier: "pet"); pet.label = "화면과 펫"
        let petView = NSView(frame: tabs.bounds)
        func label(_ text: String, _ frame: CGRect) {
            let view = NSTextField(labelWithString: text); view.frame = frame; petView.addSubview(view)
        }
        label("펫 이름", CGRect(x: 24, y: 244, width: 90, height: 20))
        nameField.target = self; nameField.action = #selector(changeName)
        let saveName = NSButton(title: "저장", target: self, action: #selector(changeName))
        saveName.frame = CGRect(x: 285, y: 212, width: 76, height: 30)
        petView.addSubview(nameField); petView.addSubview(saveName)
        label("펫 크기", CGRect(x: 24, y: 170, width: 100, height: 20))
        scaleSlider.frame = CGRect(x: 24, y: 137, width: 290, height: 26)
        scaleSlider.isContinuous = false; scaleSlider.target = self; scaleSlider.action = #selector(changeScale)
        scaleValue.frame = CGRect(x: 328, y: 141, width: 58, height: 20)
        petView.addSubview(scaleSlider); petView.addSubview(scaleValue)
        bubbleCheck.frame = CGRect(x: 24, y: 96, width: 240, height: 25)
        bubbleCheck.target = self; bubbleCheck.action = #selector(changeBubble)
        petView.addSubview(bubbleCheck)
        bubbleReplyCheck.frame=CGRect(x:24,y:72,width:300,height:25);bubbleReplyCheck.target=self;bubbleReplyCheck.action=#selector(changeBubbleReply);petView.addSubview(bubbleReplyCheck)
        threeTapCheck.frame = CGRect(x: 24, y: 47, width: 380, height: 25)
        threeTapCheck.target = self; threeTapCheck.action = #selector(changeThreeTap)
        petView.addSubview(threeTapCheck)
        let resetChat = NSButton(title: "대화창 크기 초기화", target: self, action: #selector(resetChatSize))
        resetChat.frame = CGRect(x: 24, y: 10, width: 160, height: 30)
        let resetPet = NSButton(title: "펫 위치 초기화", target: self, action: #selector(resetPetPosition))
        resetPet.frame = CGRect(x: 195, y: 10, width: 130, height: 30)
        petView.addSubview(resetChat); petView.addSubview(resetPet)
        pet.view = petView; tabs.addTabViewItem(pet)

        let account = NSTabViewItem(identifier: "account"); account.label = "계정"
        let accountView = NSView(frame: tabs.bounds)
        func accountLabel(_ title: String, y: CGFloat) {
            let label = NSTextField(labelWithString: title); label.frame = CGRect(x: 24, y: y, width: 350, height: 20); accountView.addSubview(label)
        }
        accountLabel("아이디", y: 246)
        accountName.frame = CGRect(x: 24, y: 218, width: 350, height: 22)
        accountLabel("서버 연결 상태", y: 180)
        connectionStatus.frame = CGRect(x: 24, y: 152, width: 350, height: 22)
        openAccount.frame = CGRect(x: 24, y: 85, width: 185, height: 32)
        openAccount.target = self; openAccount.action = #selector(openAccountWindow)
        logout.frame = CGRect(x: 220, y: 85, width: 100, height: 32)
        logout.target = self; logout.action = #selector(logoutAccount)
        for view in [accountName, connectionStatus, openAccount, logout] { accountView.addSubview(view) }
        account.view = accountView; tabs.addTabViewItem(account)

        let sync = NSTabViewItem(identifier: "sync"); sync.label = "연결과 동기화"
        let syncView = NSView(frame: tabs.bounds)
        syncLayout.frame = CGRect(x: 24, y: 210, width: 200, height: 32)
        syncLayout.target = self; syncLayout.action = #selector(synchronizeLayout)
        let tools=NSButton(title:"직원별 도구 연결…",target:self,action:#selector(openConnections));tools.frame=CGRect(x:24,y:160,width:200,height:32);syncView.addSubview(tools)
        syncView.addSubview(syncLayout); sync.view = syncView; tabs.addTabViewItem(sync)
    }
    func present(name: String, percent: Double, bubble: Bool, account: String = "", status: String = "서버 연결 전") {
        nameField.stringValue = name
        scaleSlider.doubleValue = percent; scaleValue.stringValue = "\(Int(percent))%"
        bubbleCheck.state = bubble ? .on : .off
        let presentation = LoginLaunchPresentation.resolve(LoginLaunch.state, installed: LoginLaunch.isInstalled())
        loginCheck.state = presentation.checked ? .on : .off; loginCheck.isEnabled = presentation.canChange
        loginStatus.stringValue = presentation.message
        accountName.stringValue = account.isEmpty ? "로그인 전" : account
        connectionStatus.stringValue = status
        window.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
    }
    @objc private func changeName() { onName?(nameField.stringValue) }
    @objc private func changeScale() { scaleValue.stringValue = "\(Int(scaleSlider.doubleValue))%"; onScale?(scaleSlider.doubleValue) }
    @objc private func changeBubbleReply(){onBubbleReply?(bubbleReplyCheck.state == .on)}
    @objc private func changeThreeTap() { onThreeTap?() }
    func updateThreeTap(_ controller: ThreeTapController) {
        threeTapCheck.state = controller.enabled && controller.health.failure == nil ? .on : .off
        threeTapCheck.isEnabled = controller.health.failure == nil
        threeTapCheck.toolTip = controller.health.failure.map { "작동을 멈췄어요: " + $0 }
            ?? (controller.health == .absent ? "트랙패드가 연결되면 사용할 수 있어요." : "")
    }
    @objc private func changeBubble() { onBubble?(bubbleCheck.state == .on) }
    @objc private func changeLogin() { onLogin?(loginCheck.state == .on) }
    @objc private func changeUpdateNotices() { onUpdateNotices?(updateNoticesCheck.state == .on) }
    @objc private func checkAppUpdate() { onAppUpdate?() }
    func updateAppUpdates(_ updates: AppUpdate) {
        updateNoticesCheck.state = updates.notices.enabled ? .on : .off
        updateButton.title = updates.knownRelease == nil ? "업데이트 확인…" : "업데이트"
        updateButton.isEnabled = updates.canCheck
        updateAvailable.stringValue = updates.knownRelease.map { "새 버전 \($0.version)이 있어요" } ?? ""
    }
    @objc private func openLoginSettings() { LoginLaunch.openSettings() }
    @objc private func resetChatSize() { onResetChat?() }
    @objc private func resetPetPosition() { onResetPosition?() }
    func updateConnection(_ text: String) { connectionStatus.stringValue = text }
    @objc private func openAccountWindow() { onOpenAccount?() }
    @objc private func logoutAccount() { onLogout?() }
    @objc private func openConnections(){onConnections?()}
    @objc private func synchronizeLayout() { onSyncLayout?() }
    static func layoutConfirmation(connected: Bool) -> NSAlert {
        let alert = NSAlert()
        if connected {
            alert.messageText = "이 Mac 화면을 다른 Mac에도 맞출까요?"
            alert.informativeText = "같은 hejo 계정으로 로그인한 다른 Mac의 섹션·방 순서·접힘·숨김·알림 끄기·사진이 이 Mac과 같아져요. 읽음 표시는 어느 Mac에서 읽었든 그대로 합쳐져요."
            alert.addButton(withTitle: "맞추기"); alert.addButton(withTitle: "취소")
        } else {
            alert.messageText = "아직 맞출 수 없어요"
            alert.informativeText = "hejo에 연결된 뒤 다시 해 주세요."
        }
        return alert
    }
}
