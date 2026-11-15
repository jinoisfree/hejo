import AppKit

@MainActor final class AppDelegate: NSObject, NSApplicationDelegate, NSMenuDelegate {
    private var instance: InstanceLock?
    private var store: LocalStore!
    private var client: GateClient!
    private var pet: PetController!
    private var conversation: ConversationController!
    private var conversationView: ConversationView!
    private var connection: LoginWindow!
    private var item: NSStatusItem!
    private var statusItem: NSMenuItem!
    private var loginItem: NSMenuItem!
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(at: AppIdentity.support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            instance = try InstanceLock(directory: AppIdentity.support); store = try LocalStore()
            client = GateClient(store: store); pet = PetController(store: store, atlas: try SpriteAtlas())
            conversation = try ConversationController(client: client)
            conversationView = ConversationView(controller: conversation)
            pet.pet.installConversation(conversationView)
            pet.preferredChatSize = CGSize(width: PetLayout.expandedSize.width + ConversationSidebar.width, height: PetLayout.expandedSize.height)
            conversationView.onCollapse = { [weak self] in self?.pet.collapseChat() }
            conversationView.onUnread = { [weak self] count in self?.pet.pet.unreadCount = count }
            conversationView.onSidebarWidth = { [weak self] delta in
                guard let self, let current = self.pet.placementTarget else { return }
                self.pet.preferredChatSize.width += delta; self.pet.placePet(at: current.anchorOrigin)
            }
            var headerDragOrigin: CGPoint?
            var headerDragPointer: CGPoint?
            for header in [conversationView.headerDrag, conversationView.brandDrag] {
                header.onBegan = { [weak self] point in headerDragPointer = point; headerDragOrigin = self?.pet.placementTarget?.anchorOrigin }
                header.onChanged = { [weak self] point in
                    if let start = headerDragPointer, let origin = headerDragOrigin { self?.pet.movePet(to: CGPoint(x: origin.x + point.x-start.x, y: origin.y+point.y-start.y)) }
                }
                header.onEnded = { [weak self] in self?.pet.endPetDrag(); headerDragOrigin = nil; headerDragPointer = nil }
            }
            conversationView.refresh()
            pet.onExpansionChanged = { [weak self] expanded in self?.conversation.model.setVisible(expanded) }
            connection = LoginWindow(client: client)
            connection.onSignedIn = { [weak self] _, me in self?.applyMemberSettings(me.settings) }
            installEditMenu()
            let menu = NSMenu(); menu.delegate = self; menu.autoenablesItems = false
            menu.addItem(withTitle: "대화 열기", action: #selector(openChat), keyEquivalent: "").target = self
            statusItem = menu.addItem(withTitle: "공항 연결 전", action: nil, keyEquivalent: ""); statusItem.isEnabled = false
            menu.addItem(.separator())
            menu.addItem(withTitle: "로그인·계정…", action: #selector(settings), keyEquivalent: ",").target = self
            menu.addItem(withTitle: "로그아웃", action: #selector(signOut), keyEquivalent: "").target = self
            menu.addItem(withTitle: "펫 이름…", action: #selector(rename), keyEquivalent: "").target = self
            loginItem = menu.addItem(withTitle: "로그인 시 실행", action: #selector(login), keyEquivalent: ""); loginItem.target = self
            menu.addItem(withTitle: "로그인 항목 설정…", action: #selector(loginSettings), keyEquivalent: "").target = self
            menu.addItem(.separator()); menu.addItem(withTitle: "종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = MenuBarIcon.image(description: "hejo"); item.menu = menu
            pet.pet.onMenu = { [weak self] event in guard let self else { return }; NSMenu.popUpContextMenu(menu, with: event, for: self.pet.pet) }
            client.onStatus = { [weak self] status in
                self?.statusItem.title = status.text; self?.pet.pet.statusLabel.stringValue = status.text; self?.connection.update(status); self?.conversationView.refresh()
                if status == .wrongCode || status == .revoked { self?.connection.present() }
            }
            pet.show()
            if store.settings.address.isEmpty || !store.settings.signsInAutomatically {
                // Without automatic sign-in every launch starts at the login screen (saved id/password still fill in).
                Task { if !store.settings.address.isEmpty { await client.signOut() }; connection.present() }
            } else { client.resume(); Task { await syncMemberSettings() } }
        } catch GateFailure.alreadyRunning {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: AppIdentity.bundleID) where app.processIdentifier != ProcessInfo.processInfo.processIdentifier { app.activate(options: []) }
            NSApp.terminate(nil)
        } catch { let alert = NSAlert(); alert.messageText = "hejo를 시작하지 못했어요"; alert.informativeText = "앱 파일과 저장 공간을 확인해 주세요."; alert.runModal(); NSApp.terminate(nil) }
    }
    private func installEditMenu() {
        let main = NSMenu(), app = NSMenu(), edit = NSMenu(title: "편집")
        let appItem = NSMenuItem(); appItem.submenu = app; main.addItem(appItem)
        app.addItem(withTitle: "hejo 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        for (title, selector, key) in [("실행 취소", "undo:", "z"), ("오려두기", "cut:", "x"), ("복사", "copy:", "c"), ("붙여넣기", "paste:", "v"), ("모두 선택", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        NSApp.mainMenu = main
    }
    func applicationWillTerminate(_ notification: Notification) {
        client?.stop()
        // Without automatic sign-in, quitting signs this Mac out.
        if let store, !store.settings.signsInAutomatically { GateKeychain().delete(account: store.settings.credentialAccount) }
    }
    func menuWillOpen(_ menu: NSMenu) {
        let presentation = LoginLaunchPresentation.resolve(LoginLaunch.state, installed: LoginLaunch.isInstalled())
        loginItem.state = presentation.checked ? .on : .off; loginItem.isEnabled = presentation.canChange; loginItem.toolTip = presentation.message
    }
    /// Member settings live at the hub so every Mac this member signs in on looks the same.
    private func applyMemberSettings(_ settings: [String: String]) {
        guard let name = settings["petName"], !name.isEmpty else { return }
        try? store.update { $0.petName = PetIdentity.normalized(name) }
        pet.pet.setAccessibilityLabel("hejo · \(store.settings.petName) · 대화 열기")
    }
    private func syncMemberSettings() async {
        for _ in 0..<20 where client.bearer == nil { try? await Task.sleep(nanoseconds: 500_000_000) }
        guard let address = store.settings.hubAddress, let token = client.bearer,
              let me = try? await HubClient(address: address).me(token: token) else { return }
        applyMemberSettings(me.settings)
    }
    private func saveMemberSettings() {
        guard let address = store.settings.hubAddress, let token = client.bearer else { return }
        let settings = ["petName": store.settings.petName]
        Task { try? await HubClient(address: address).save(settings: settings, token: token) }
    }
    @objc private func openChat() { pet.showChat() }
    @objc private func signOut() { Task { await client.signOut(); connection.present() } }
    @objc private func settings() { connection.present() }
    @objc private func loginSettings() { LoginLaunch.openSettings() }
    @objc private func login() {
        do { try LoginLaunch.setEnabled(LoginLaunch.state != .enabled) }
        catch { let alert = NSAlert(); alert.messageText = "로그인 항목을 확인해 주세요"; alert.informativeText = LoginLaunchPresentation.resolve(LoginLaunch.state, installed: LoginLaunch.isInstalled(), failed: true).message; alert.runModal() }
    }
    @objc private func rename() {
        let alert = NSAlert(); alert.messageText = "펫 이름"; let field = NSTextField(string: store.settings.petName)
        field.frame = CGRect(x: 0, y: 0, width: 240, height: 24); alert.accessoryView = field
        alert.addButton(withTitle: "저장"); alert.addButton(withTitle: "취소")
        if alert.runModal() == .alertFirstButtonReturn {
            try? store.update { $0.petName = PetIdentity.normalized(field.stringValue) }
            pet.pet.setAccessibilityLabel("hejo · \(store.settings.petName) · 대화 열기")
            saveMemberSettings()
        }
    }
}
