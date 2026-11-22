import AppKit

/// Native settings controls. Persistence and device registration remain with the caller.
@MainActor final class PetSettingsWindow: NSObject, NSTabViewDelegate {
    let window: NSWindow
    let tabs = NSTabView(frame: CGRect(x: 0, y: 0, width: 620, height: 640))
    let telegramSection = TelegramSettingsSection()
    let nameField = NSTextField(string: "")
    let nameHint = NSTextField(labelWithString: "1~20자 · 저장하면 모든 화면에 적용됩니다.")
    let scaleSlider = NSSlider(value: 100, minValue: 25, maxValue: 200, target: nil, action: nil)
    let scaleValue = NSTextField(labelWithString: "100%")
    let bubbleCheck = NSButton(checkboxWithTitle: "말풍선 항상 보이기", target: nil, action: nil)
    let bubbleReplyCheck = NSButton(checkboxWithTitle: "말풍선에서 바로 답하기", target: nil, action: nil)
    let threeTapCheck = NSButton(checkboxWithTitle: ThreeTapController.title, target: nil, action: nil)
    let tapCopyButton = NSButton(title: "수정 요청문 복사", target: nil, action: nil)
    let loginCheck = NSButton(checkboxWithTitle: "로그인 시 실행", target: nil, action: nil)
    let loginSettings = NSButton(title: "로그인 항목 설정 열기", target: nil, action: nil)
    let updateNoticesCheck = NSButton(checkboxWithTitle: "업데이트 알림 받기", target: nil, action: nil)
    let updateButton = NSButton(title: "업데이트 확인…", target: nil, action: nil)
    let updateAvailable = NSTextField(labelWithString: "")
    let loginStatus = NSTextField(wrappingLabelWithString: "")
    let accountName = NSTextField(labelWithString: "로그인 전")
    let connectionStatus = NSTextField(labelWithString: "서버 연결 전")
    let openAccount = NSButton(title: "로그인·계정 창 열기", target: nil, action: nil)
    let logout = NSButton(title: "로그아웃", target: nil, action: nil)
    let syncLayout = NSButton(title: "화면 배치 동기화…", target: nil, action: nil)
    let homePicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let previewButton = NSButton(title: "동작 미리보기", target: nil, action: nil)
    let pointerButton = NSButton(title: "마우스 시선 미리보기", target: nil, action: nil)
    var onThreeTap: (() -> Void)?, onConnections: (() -> Void)?, onSyncLayout: (() -> Void)?
    var onAppUpdate: (() -> Void)?, onUpdateNotices: ((Bool) -> Void)?
    var onName: ((String) -> Void)?, onScale: ((Double) -> Void)?, onBubble: ((Bool) -> Void)?
    var onBubbleReply: ((Bool) -> Void)?, onLogin: ((Bool) -> Void)?
    var onResetChat: (() -> Void)?, onResetPosition: (() -> Void)?
    var onOpenAccount: (() -> Void)?, onLogout: (() -> Void)?
    var onPreview: (() -> Void)?, onPointer: (() -> Void)?, onHome: ((String) -> Void)?
    let hooksButton = NSButton(title:"승인 알림 연결 안내",target:nil,action:nil)
    var onHooks: (() -> Void)?
    var requestPasteboard: NSPasteboard = .general
    private(set) var appearanceControls: ChatAppearanceControls!
    private var tapFailure: ThreeTapFailure?

    override convenience init() {self.init(previewName:"hejo",palette:{CharacterPalette.make(hue:nil,dark:$0)})}
    init(previewName:String,palette:@escaping(Bool)->CharacterPalette) {
        window = NSWindow(contentRect: tabs.frame, styleMask: [.titled, .closable], backing: .buffered, defer: false)
        super.init()
        window.title = "hejo 설정"; window.isReleasedWhenClosed = false
        window.contentView = tabs; tabs.autoresizingMask = [.width, .height]
        func note(_ text: String) -> NSTextField {
            let label = NSTextField(wrappingLabelWithString: text)
            label.font = .systemFont(ofSize: 12); label.textColor = .secondaryLabelColor
            label.frame = CGRect(x: 24, y: 0, width: 312, height: 48); return label
        }
        func title(_ text: String, y: CGFloat) -> NSTextField {
            let label = NSTextField(labelWithString: text); label.font = .systemFont(ofSize: 14, weight: .semibold)
            label.frame = CGRect(x: 24, y: y, width: 200, height: 20); return label
        }
        func button(_ view: NSButton, _ action: Selector) -> NSButton {
            view.target = self; view.action = action; view.bezelStyle = .rounded
            view.frame = CGRect(x: 24, y: 0, width: 312, height: 32); return view
        }
        func check(_ view: NSButton, _ action: Selector) -> NSButton {
            view.target = self; view.action = action; view.frame = CGRect(x: 24, y: 0, width: 312, height: 26); return view
        }
        func page(_ label: String, _ blocks: [[NSView]]) {
            let item = NSTabViewItem(identifier: label); item.label = label; item.view = SettingsPages.make(blocks: blocks); tabs.addTabViewItem(item)
        }
        loginCheck.target = self; loginCheck.action = #selector(changeLogin)
        loginCheck.frame = CGRect(x: 24, y: 510, width: 312, height: 24)
        loginStatus.font = .systemFont(ofSize: 11); loginStatus.textColor = .secondaryLabelColor
        loginStatus.frame = CGRect(x: 24, y: 460, width: 312, height: 44)
        _ = button(loginSettings, #selector(openLoginSettings)); loginSettings.frame = CGRect(x: 24, y: 421, width: 220, height: 30)
        updateAvailable.font = .systemFont(ofSize: 12); updateAvailable.textColor = .secondaryLabelColor
        updateAvailable.frame = CGRect(x: 24, y: 0, width: 312, height: 20)
        page("일반", [[loginCheck, loginStatus, loginSettings], [check(updateNoticesCheck, #selector(changeUpdateNotices))],
                    [button(updateButton, #selector(checkAppUpdate))], [updateAvailable]])
        nameField.placeholderString = "펫 이름을 입력하세요"; nameField.setAccessibilityLabel("펫 이름")
        nameField.target = self; nameField.action = #selector(changeName)
        nameField.frame = CGRect(x: 24, y: 203, width: 220, height: 26)
        let save = button(NSButton(title: "이름 저장", target: nil, action: nil), #selector(changeName))
        save.frame = CGRect(x: 249, y: 200, width: 92, height: 32)
        nameHint.font = .systemFont(ofSize: 11); nameHint.textColor = .secondaryLabelColor
        nameHint.frame = CGRect(x: 24, y: 175, width: 312, height: 17)
        scaleValue.alignment = .right; scaleValue.font = .monospacedDigitSystemFont(ofSize: 13, weight: .medium)
        scaleValue.frame = CGRect(x: 254, y: 125, width: 82, height: 20)
        scaleSlider.frame = CGRect(x: 22, y: 86, width: 316, height: 26)
        scaleSlider.isContinuous = true; scaleSlider.target = self; scaleSlider.action = #selector(changeScale)
        scaleSlider.setAccessibilityLabel("펫 크기")
        scaleSlider.toolTip = "캐릭터만 25%부터 200%까지 조절 · 말풍선 크기는 고정"
        let endpoints: [NSView] = [("25%", CGFloat(24)), ("200%", CGFloat(294))].map { text, x in
            let label = NSTextField(labelWithString: text); label.font = .systemFont(ofSize: 11); label.textColor = .secondaryLabelColor
            label.frame = CGRect(x: x, y: 65, width: 44, height: 16); return label
        }
        let sizeHint = note("말풍선 크기는 그대로 유지됩니다.")
        sizeHint.font = .systemFont(ofSize: 11); sizeHint.frame = CGRect(x: 24, y: 26, width: 216, height: 17)
        let reset = button(NSButton(title: "기본 크기", target: nil, action: nil), #selector(resetPetSize))
        reset.frame = CGRect(x: 247, y: 19, width: 94, height: 32)
        let theme=NSSegmentedControl(labels:["시스템 설정","라이트","다크"],trackingMode:.selectOne,target:nil,action:nil)
        theme.setAccessibilityLabel("대화창 테마")
        let opacity=NSSlider(value:65,minValue:55,maxValue:100,target:nil,action:nil)
        let opacityValue=NSTextField(labelWithString:"65%")
        opacityValue.font = .monospacedDigitSystemFont(ofSize:13,weight:.medium)
        let resetSize=button(NSButton(title:"대화창 크기 초기화",target:nil,action:nil),#selector(resetChatSize))
        appearanceControls=ChatAppearanceControls(theme:theme,opacity:opacity,opacityValue:opacityValue,resetSize:resetSize,name:previewName,palette:palette)
        page("화면과 펫", [[appearanceControls],
            [title("펫 이름", y: 241), nameField, save, nameHint],
            [title("펫 크기", y: 125), scaleValue, scaleSlider, sizeHint, reset] + endpoints,
            [check(bubbleCheck, #selector(changeBubble))], [check(bubbleReplyCheck, #selector(changeBubbleReply))],
            [check(threeTapCheck, #selector(changeThreeTap))],
            [button(NSButton(title: "펫 위치 초기화", target: nil, action: nil), #selector(resetPetPosition))]])
        homePicker.frame = CGRect(x: 24, y: 0, width: 312, height: 30)
        homePicker.setAccessibilityLabel("고정 채널"); homePicker.target = self; homePicker.action = #selector(changeHome)
        let homeTitle=title("고정 채널", y:38);homeTitle.frame=CGRect(x:24,y:38,width:312,height:22)
        page("연결과 동기화", [[telegramSection], [button(NSButton(title: "에이전트 연결…", target: nil, action: nil), #selector(openConnections))],
            [button(hooksButton, #selector(showHooks))], [homeTitle, homePicker], [button(syncLayout, #selector(synchronizeLayout))],
            [note("이 Mac의 섹션·순서·접힘·숨김·사진을 다른 Mac에도 적용합니다. 다른 Mac에만 있는 배치·사진은 지웁니다.")]])
        page("고급", [[button(previewButton, #selector(preview))], [button(pointerButton, #selector(previewPointer))], [button(tapCopyButton, #selector(copyTapRequest))]])
        tapCopyButton.isHidden = true
        accountName.frame = CGRect(x: 24, y: 0, width: 312, height: 22)
        connectionStatus.frame = CGRect(x: 24, y: 0, width: 312, height: 22)
        page("계정", [[title("아이디", y: 30), accountName], [title("서버 연결 상태", y: 30), connectionStatus],
            [button(openAccount, #selector(openAccountWindow))], [button(logout, #selector(logoutAccount))]])
        tabs.delegate = self; refreshHome(rooms: [], selected: nil)
    }
    func present(name: String, percent: Double, bubble: Bool, account: String = "", status: String = "서버 연결 전") {
        nameField.stringValue = name; nameHint.stringValue = "1~20자 · 저장하면 모든 화면에 적용됩니다."; nameHint.textColor = .secondaryLabelColor
        scaleSlider.doubleValue = percent; scaleValue.stringValue = "\(Int(percent))%"; bubbleCheck.state = bubble ? .on : .off
        appearanceControls.refresh()
        refreshLogin(); accountName.stringValue = account.isEmpty ? "로그인 전" : account; connectionStatus.stringValue = status
        if let screen = NSScreen.screens.first(where: { $0.frame.contains(NSEvent.mouseLocation) }) ?? window.screen ?? NSScreen.main { fit(to: screen.visibleFrame) }
        OptionWindows.show(window)
    }
    func fit(to visible: CGRect) {
        let titleBar = window.frame.height - window.contentRect(forFrameRect: window.frame).height
        window.setContentSize(CGSize(width: 620, height: OptionsLayout.viewportHeight(visibleHeight: visible.height, titleBarHeight: titleBar)))
        window.setFrameOrigin(CGPoint(x: visible.midX-window.frame.width/2, y: visible.midY-window.frame.height/2)); scrollToTop()
    }
    func tabView(_ tabView: NSTabView, didSelect tabViewItem: NSTabViewItem?) { scrollToTop() }
    func scrollToTop() {
        guard let scroll = tabs.selectedTabViewItem?.view as? NSScrollView, let document = scroll.documentView else { return }
        scroll.layoutSubtreeIfNeeded(); document.scroll(.zero)
    }
    func refreshLogin(_ value: LoginLaunchPresentation? = nil) {
        let value = value ?? LoginLaunchPresentation.resolve(LoginLaunch.state, installed: LoginLaunch.isInstalled())
        loginCheck.state = value.checked ? .on : .off; loginCheck.isEnabled = value.canChange
        loginStatus.stringValue = value.message; loginSettings.isHidden = !value.showsSettings
    }
    func refreshHome(rooms: [Room], selected: String?) {
        let choices = [("기본(홈 방 기본)", "")] + rooms.filter { $0.kind == .group && $0.archived != true }.map { ("#"+$0.title, $0.id) }
        if homePicker.itemTitles != choices.map(\.0) || homePicker.itemArray.map({ $0.representedObject as? String ?? "" }) != choices.map(\.1) {
            homePicker.removeAllItems(); for (title, id) in choices { homePicker.addItem(withTitle: title); homePicker.lastItem?.representedObject = id }
        }
        homePicker.selectItem(at: choices.firstIndex { $0.1 == selected } ?? 0)
    }
    @objc private func changeName() {
        // Never rewrite a field while an input method still owns its marked text.
        guard (window.firstResponder as? NSTextInputClient)?.hasMarkedText() != true else { return }
        if let message = PetIdentity.validationMessage(for: nameField.stringValue) { nameHint.stringValue = message; nameHint.textColor = .systemRed; return }
        let name = PetIdentity.normalized(nameField.stringValue); nameField.stringValue = name
        nameHint.stringValue = "이름을 저장했어요. 모든 화면에 적용했습니다."; nameHint.textColor = .secondaryLabelColor; onName?(name)
    }
    @objc private func changeScale() { scaleValue.stringValue = "\(Int(scaleSlider.doubleValue.rounded()))%"; onScale?(scaleSlider.doubleValue) }
    @objc private func resetPetSize() { scaleSlider.doubleValue = 100; changeScale() }
    @objc private func changeHome() { onHome?(homePicker.selectedItem?.representedObject as? String ?? "") }
    @objc private func preview() { onPreview?() }
    @objc private func previewPointer() { onPointer?() }
    @objc private func copyTapRequest() { if let tapFailure { ThreeTapController.copy(tapFailure, to: requestPasteboard) } }
    @objc private func showHooks() { onHooks?() }
    @objc private func changeBubbleReply() { onBubbleReply?(bubbleReplyCheck.state == .on) }
    @objc private func changeThreeTap() { onThreeTap?() }
    func updateThreeTap(_ controller: ThreeTapController) {
        threeTapCheck.state = controller.enabled && controller.health.failure == nil ? .on : .off
        threeTapCheck.isEnabled = controller.health.failure == nil
        threeTapCheck.toolTip = controller.health.failure.map { "작동을 멈췄어요: " + $0 } ?? (controller.health == .absent ? "트랙패드가 연결되면 사용할 수 있어요." : "")
        tapFailure = controller.failure; tapCopyButton.isHidden = tapFailure == nil
    }
    @objc private func changeBubble() { onBubble?(bubbleCheck.state == .on) }
    @objc private func changeLogin() { onLogin?(loginCheck.state == .on) }
    @objc private func changeUpdateNotices() { onUpdateNotices?(updateNoticesCheck.state == .on) }
    @objc private func checkAppUpdate() { onAppUpdate?() }
    func updateAppUpdates(_ updates: AppUpdate) {
        updateNoticesCheck.state = updates.notices.enabled ? .on : .off
        updateButton.title = updates.knownRelease == nil ? "업데이트 확인…" : "업데이트"; updateButton.isEnabled = updates.canCheck
        updateAvailable.stringValue = updates.knownRelease.map { "새 버전 \($0.version)이 있어요" } ?? ""
    }
    @objc private func openLoginSettings() { LoginLaunch.openSettings() }
    @objc private func resetChatSize() { onResetChat?() }
    @objc private func resetPetPosition() { onResetPosition?() }
    func updateConnection(_ text: String) { connectionStatus.stringValue = text }
    @objc private func openAccountWindow() { onOpenAccount?() }
    @objc private func logoutAccount() { onLogout?() }
    @objc private func openConnections() { onConnections?() }
    @objc private func synchronizeLayout() { onSyncLayout?() }
    static func layoutResult(saved: Bool, connected: Bool) -> NSAlert {
        let done = NSAlert()
        if !saved { done.messageText = "아직 맞출 수 없어요"; done.informativeText = "hejo에 연결된 뒤 다시 해 주세요." }
        else if !connected { done.messageText = "이 Mac에 저장했어요"; done.informativeText = "공유하는 Mac에 연결되지 않았어요. 연결되면 다른 Mac에도 반영되도록 다시 한 번 해 주세요." }
        else { done.messageText = "맞췄어요"; done.informativeText = "다른 Mac에는 몇 초 안에 반영돼요." }
        return done
    }
    static func layoutConfirmation(connected: Bool) -> NSAlert {
        guard connected else { return layoutResult(saved: false, connected: false) }
        let alert = NSAlert(); alert.messageText = "이 Mac 화면을 다른 Mac에도 맞출까요?"
        alert.informativeText = "같은 hejo 계정으로 로그인한 다른 Mac의 섹션·방 순서·접힘·숨김·알림 끄기·사진이 이 Mac과 같아져요. 읽음 표시는 어느 Mac에서 읽었든 그대로 합쳐져요."
        alert.addButton(withTitle: "맞추기"); alert.addButton(withTitle: "취소"); return alert
    }
}
