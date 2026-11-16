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
    private var hideItem: NSMenuItem?
    private var pauseItem: NSMenuItem?
    private var currentAccount = ""
    private var petSettings: PetSettingsWindow?
    private var bubble: BubbleReveal!
    private var bubbleTimer: Timer?
    private var bubbleReply:BubbleReplyCard!
    private var wasSending = false
    private var settingsRevision = 0
    private var settingsTask: Task<Void, Never>?
    private var activityMonitor: Any?
    private var pendingURLs:[URL]=[]
    func application(_ application:NSApplication,open urls:[URL]) {
        guard conversation != nil else {pendingURLs += urls;return}
        for url in urls where url.scheme?.lowercased()=="hejo" {conversation.openLink(url);pet.showChat()}
    }
    func applicationDidFinishLaunching(_ notification: Notification) {
        do {
            try FileManager.default.createDirectory(at: AppIdentity.support, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            instance = try InstanceLock(directory: AppIdentity.support); store = try LocalStore()
            bubble = BubbleReveal(store:store)
            client = GateClient(store: store); pet = PetController(store: store, atlas: try SpriteAtlas())
            conversation = try ConversationController(client: client)
            bubbleReply=BubbleReplyCard(controller:conversation);pet.pet.installBubbleReply(bubbleReply)
            pet.pet.bubbleReplyAllowed=store.settings.bubbleReplyEnabled ?? true
            pet.pet.avatarForEmployee = { [weak self] id in self?.conversation.avatar(id) ?? ProfileAvatar(color:PictureCodec.color(name:id,hex:nil)) }
            conversationView = ConversationView(controller: conversation)
            pet.pet.installConversation(conversationView)
            conversationView.onCollapse = { [weak self] in self?.pet.collapseChat() }
            conversationView.onOpenThreadHeight = { [weak self] height in self?.pet.fitOpenThread(height) }
            pet.panel.onWorkspaceKey = { [weak self] event in self?.conversationView.handleWorkspaceKey(event) ?? false }
            pet.panel.onCollapse = { [weak self] in guard let self else { return }; if !self.conversationView.closeSearchIfOpen() { self.pet.collapseChat() } }
            pet.pet.onBubbleOpen = { [weak self] key in guard let self else {return};self.openBubble(key) }
            pet.pet.onBubbleAction = { [weak self] action in self?.performBubbleAction(action) }
            bubbleTimer=Timer(timeInterval:0.25,repeats:true){ [weak self] _ in Task { @MainActor in self?.refreshPetActivity() } }
            RunLoop.main.add(bubbleTimer!,forMode:.common)
            let previousChange = conversation.onChange
            conversation.onChange = { [weak self] in previousChange?(); self?.refreshPetActivity() }
            conversationView.onUnread = { [weak self] count in self?.pet.pet.unreadCount = count }
            conversationView.onSidebarWidth = { [weak self] delta in
                guard let self, let current = self.pet.placementTarget else { return }
                self.pet.preferredChatSize.width += delta; self.pet.placePet(at: current.anchorOrigin)
                self.pet.saveChatSize()
            }
            var headerDragOrigin: CGPoint?
            var headerDragPointer: CGPoint?
            for header in [conversationView.headerDrag, conversationView.brandDrag] {
                header.onBegan = { [weak self] point in headerDragPointer = point; headerDragOrigin = self?.pet.placementTarget?.anchorOrigin }
                header.onChanged = { [weak self] point in
                    if let start = headerDragPointer, let origin = headerDragOrigin { self?.pet.movePet(to: CGPoint(x: origin.x + point.x-start.x, y: origin.y+point.y-start.y)) }
                }
                header.onEnded = { [weak self] in self?.pet.endPetDrag(); headerDragOrigin = nil; headerDragPointer = nil }
                header.onDoubleClick = { [weak self] in self?.pet.toggleChatWidth() }
            }
            conversationView.refresh()
            pet.onExpansionChanged = { [weak self] expanded in self?.conversation.model.setVisible(expanded); if expanded { self?.conversation.model.memberState.activate() };self?.refreshPetActivity() }
            connection = LoginWindow(client: client)
            connection.onSignedIn = { [weak self] _, me in self?.currentAccount = me.account; self?.petSettings?.accountName.stringValue = me.account; self?.applyMemberSettings(me.settings) }
            installEditMenu()
            let menu = makeStatusMenu()
            item = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
            item.button?.image = MenuBarIcon.image(description: "hejo"); item.menu = menu
            pet.pet.onMenu = { [weak self] event in guard let self else { return }; NSMenu.popUpContextMenu(menu, with: event, for: self.pet.pet) }
            activityMonitor = NSEvent.addLocalMonitorForEvents(matching: [.keyDown, .leftMouseDown, .rightMouseDown, .leftMouseDragged]) { [weak self] event in
                self?.pet?.pet.noteActivity()
                return event
            }
            client.onStatus = { [weak self] status in
                self?.pet.pet.statusLabel.stringValue = status.text; self?.petSettings?.updateConnection(status.text); self?.connection.update(status); self?.conversationView.refresh()
                self?.refreshPetActivity()
                if status == .wrongCode || status == .revoked { self?.connection.present() }
            }
            pet.show()
            if !pendingURLs.isEmpty {let urls=pendingURLs;pendingURLs=[];application(NSApp,open:urls)}
            if store.settings.address.isEmpty || !store.settings.signsInAutomatically {
                // Without automatic sign-in every launch starts at the login screen (saved id/password still fill in).
                Task { if !store.settings.address.isEmpty { await client.signOut() }; connection.present() }
            } else { client.resume(); Task { await syncMemberSettings() } }
        } catch GateFailure.alreadyRunning {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: AppIdentity.bundleID) where app.processIdentifier != ProcessInfo.processInfo.processIdentifier { app.activate(options: []) }
            NSApp.terminate(nil)
        } catch { let alert = NSAlert(); alert.messageText = "hejo를 시작하지 못했어요"; alert.informativeText = "앱 파일과 저장 공간을 확인해 주세요."; alert.runModal(); NSApp.terminate(nil) }
    }
    func installEditMenu() {
        let main = NSMenu(), app = NSMenu(), edit = NSMenu(title: "편집")
        let appItem = NSMenuItem(); appItem.submenu = app; main.addItem(appItem)
        app.addItem(withTitle: "hejo 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        for (title, selector, key) in [("실행 취소", "undo:", "z"), ("오려두기", "cut:", "x"), ("복사", "copy:", "c"), ("붙여넣기", "paste:", "v"), ("모두 선택", "selectAll:", "a")] {
            edit.addItem(withTitle: title, action: Selector(selector), keyEquivalent: key)
        }
        let redo = edit.addItem(withTitle: "다시 실행", action: Selector(("redo:")), keyEquivalent: "z")
        redo.keyEquivalentModifierMask = [.command, .shift]
        NSApp.mainMenu = main
    }
    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu(); menu.delegate = self; menu.autoenablesItems = false
        menu.addItem(withTitle: "대화 열기", action: #selector(openChat), keyEquivalent: "").target = self
        menu.addItem(.separator())
        hideItem = menu.addItem(withTitle: "펫 숨기기", action: #selector(togglePet), keyEquivalent: ""); hideItem?.target = self
        pauseItem = menu.addItem(withTitle: "잠시 쉬기", action: #selector(togglePause), keyEquivalent: ""); pauseItem?.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "설정…", action: #selector(showOptions), keyEquivalent: ",").target = self
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppIdentity.version
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        let versionItem = menu.addItem(withTitle: "hejo \(version) (빌드 \(build))", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        menu.addItem(.separator())
        menu.addItem(withTitle: "hejo 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        hideItem?.title = pet?.panel.isVisible == false ? "펫 보이기" : "펫 숨기기"
        pauseItem?.title = pet?.pet.isPaused == true ? "다시 움직이기" : "잠시 쉬기"
    }
    func applicationWillTerminate(_ notification: Notification) {
        if let activityMonitor { NSEvent.removeMonitor(activityMonitor) }
        bubbleTimer?.invalidate();client?.stop()
        // Without automatic sign-in, quitting signs this Mac out.
        if let store, !store.settings.signsInAutomatically { GateKeychain().delete(account: store.settings.credentialAccount) }
    }
    /// Member settings live at the hub so every Mac this member signs in on looks the same.
    private func applyMemberSettings(_ settings: [String: String]) {
        let name = settings["petName"].flatMap { $0.isEmpty ? nil : PetIdentity.normalized($0) } ?? store.settings.petName
        let size = settings["petScale"].flatMap(Double.init).map { min(200,max(25,$0)) } ?? store.settings.petScalePercent ?? 100
        let always = settings[BubbleReveal.settingsKey].map { $0 == "true" } ?? store.settings.bubbleAlwaysShown ?? false
        try? store.update { $0.petName = name; $0.petScalePercent = size; $0.bubbleAlwaysShown = always }
        let replyEnabled=settings[BubbleReply.settingsKey].map{$0=="true"} ?? store.settings.bubbleReplyEnabled ?? true
        try? store.update{$0.bubbleReplyEnabled=replyEnabled};pet.pet.bubbleReplyAllowed=replyEnabled;petSettings?.bubbleReplyCheck.state=replyEnabled ? .on:.off
        pet.resizePet(percent: size); pet.pet.bubbleAlwaysShown = always; pet.pet.bubbleName = name
        if let address = store.settings.hubAddress, let token = client.bearer, !currentAccount.isEmpty {
            do {
                try conversation.model.memberState.join(member: currentAccount, hub: address, legacy: settings)
                conversation.model.memberState.configure(hub: HubClient(address: address), token: token)
            } catch { conversation.model.memberState.onFailure?(true) }
        }
        pet.pet.setAccessibilityLabel("hejo · \(store.settings.petName) · 대화 열기")
    }
    private func syncMemberSettings() async {
        for _ in 0..<20 where client.bearer == nil { try? await Task.sleep(nanoseconds: 500_000_000) }
        guard let address = store.settings.hubAddress, let token = client.bearer,
              let me = try? await HubClient(address: address).me(token: token) else { return }
        currentAccount = me.account; petSettings?.accountName.stringValue = me.account; applyMemberSettings(me.settings)
    }
    private func saveMemberSettings() {
        settingsRevision += 1
        guard settingsTask == nil else { return }
        settingsTask = Task { [weak self] in
            guard let self else { return }
            repeat {
                let revision = self.settingsRevision
                guard let address = self.store.settings.hubAddress, let token = self.client.bearer else { break }
                let hub = HubClient(address: address)
                do {
                    var settings = try await hub.me(token: token).settings
                    settings["petName"] = self.store.settings.petName
                    settings["petScale"] = String(Int(self.store.settings.petScalePercent ?? 100))
                    settings[BubbleReveal.settingsKey] = self.store.settings.bubbleAlwaysShown == true ? "true" : "false"
                    settings[BubbleReply.settingsKey] = self.store.settings.bubbleReplyEnabled != false ? "true":"false"
                    if self.store.settings.stateJoined?[self.conversation.model.memberState.account] == true {
                        for key in ["pinned", "muted", "hidden"] { settings.removeValue(forKey: key) }
                    }
                    try await hub.save(settings: settings, token: token)
                } catch { break }
                if revision == self.settingsRevision { break }
            } while true
            self.settingsTask = nil
        }
    }
    private func refreshPetActivity() {
        guard let pet, let conversation, let client else { return }
        let model = conversation.model
        let input=conversation.islandInput
        let messages=Array(model.messages.values)
        let questions=Set(model.employees.flatMap{model.notices($0.id).filter(\.questions).flatMap(\.messages)})
        let readIDs=Set(messages.filter{ message in
            let key=message.key
            return message.latestSeq<=max(model.memberState.read("read:"+key.employee),model.memberState.read("thread:"+key.employee+"/"+key.thread))
        }.map(\.id))
        let jumped=bubble.update(.init(messages:messages,questions:questions,typing:model.typing,names:input.names,muted:model.muted,readIDs:readIDs,opened:model.selected,chatOpen:pet.chatExpanded,paused:pet.pet.isPaused,ready:client.replayComplete,failure:input.failure),now:Date())
        if jumped {pet.pet.requestReplyJump()}
        var notice=bubble.notice
        if bubble.persistenceFailed {notice.detail="알림을 저장하지 못했어요. 저장 공간을 확인해 주세요."}
        if notice.key==nil,notice.kind == .failure,let key=bubbleReply.target?.key,conversation.bubbleProblems[key] != nil,!model.timeline(key).isEmpty {notice.key=key}
        let target=notice.key.flatMap{key->BubbleReplyTarget? in
            guard !model.timeline(key).isEmpty else{return nil}
            return BubbleReplyTarget(key:key,speaker:model.name(key.employee),working:conversation.working(key),queued:model.employees.first{$0.id==key.employee}?.queued ?? false)
        }
        if let target,target.working,conversation.interruptions[target.key] != nil {notice.detail=BubbleReply.interruptedSubtitle;notice.kind = .writing}
        pet.pet.bubbleReplyConnected=conversation.canSend
        bubbleReply.aim(target)
        pet.pet.bubbleNotice=notice
        if !conversation.canSend || pet.chatExpanded || pet.pet.isPaused || !pet.pet.bubbleReplyAllowed {pet.pet.updateBubbleReply(pointerOver:false)}
        let asked = questions.filter{ id in model.messages[id].map{!model.muted.contains($0.key.employee)} ?? false }.count
        let working = Set(model.typing.filter{$0.value>Date() && !model.muted.contains($0.key.employee)}.keys.map(\.employee)).count
        pet.pet.hasAsked = asked > 0; pet.pet.isTyping = working > 0
        pet.pet.sendFailed = bubble.notice.kind == .failure
        pet.pet.bubbleStatus = "일하는 직원 \(working)명 · 사장 차례 \(asked)건"
        if conversation.sending && !wasSending { pet.pet.noteSend() }
        wasSending = conversation.sending
    }
    private func openBubble(_ key:ConversationKey?) {
        if let key {conversationView.openFromBubble(key)}
        bubble.dismiss();pet.showChat();refreshPetActivity()
    }
    private func performBubbleAction(_ action:BubbleReveal.Action) {
        switch action {
        case .openChat:openBubble(pet.pet.bubbleTarget)
        case .link(let url):
            guard ["https","http"].contains(url.scheme?.lowercased() ?? "") else{return}
            NSWorkspace.shared.open(url);bubble.dismiss();refreshPetActivity()
        case .remindLater:
            if !bubble.remindLater(now:Date()) {pet.pet.bubbleStatus="나중에 알림을 저장하지 못했어요. 저장 공간을 확인해 주세요."}
            refreshPetActivity()
        }
    }
    @objc private func openChat() { pet.showChat() }
    @objc private func signOut() { conversation.model.memberState.disconnect(); currentAccount = ""; petSettings?.accountName.stringValue = "로그인 전"; Task { await client.signOut(); petSettings?.updateConnection(client.status.text); connection.present() } }
    @objc private func showOptions() {
        if petSettings == nil {
            let settings = PetSettingsWindow()
            settings.onName = { [weak self] value in self?.setPetName(value) }
            settings.onScale = { [weak self] value in self?.setPetScale(value) }
            settings.onBubbleReply={ [weak self] enabled in
                guard let self else{return};try? self.store.update{$0.bubbleReplyEnabled=enabled};self.pet.pet.bubbleReplyAllowed=enabled;self.refreshPetActivity();self.saveMemberSettings()
            }
            settings.onBubble = { [weak self] value in self?.setBubbleAlwaysShown(value) }
            settings.onLogin = { [weak self] value in self?.setLoginEnabled(value) }
            settings.onResetChat = { [weak self] in self?.pet.resetChatSize() }
            settings.onResetPosition = { [weak self] in self?.pet.resetPosition() }
            settings.onOpenAccount = { [weak self] in self?.connection.present() }
            settings.onLogout = { [weak self] in self?.signOut() }
            settings.onSyncLayout = { [weak self] in self?.synchronizeLayout() }
            petSettings = settings
        }
        petSettings?.bubbleReplyCheck.state=store.settings.bubbleReplyEnabled != false ? .on:.off
        petSettings?.present(name: store.settings.petName, percent: store.settings.petScalePercent ?? 100,
                             bubble: store.settings.bubbleAlwaysShown ?? false, account: currentAccount, status: client.status.text)
    }
    func applicationDidBecomeActive(_ notification: Notification) { conversation?.model.memberState.activate() }
    private func synchronizeLayout() {
        let state = conversation.model.memberState
        Task {
            // Probe the hub before showing confirmation; a cached connection is not sufficient.
            guard let fetch = state.fetch, (try? await fetch(nil)) != nil else {
                PetSettingsWindow.layoutConfirmation(connected: false).runModal(); return
            }
            guard PetSettingsWindow.layoutConfirmation(connected: true).runModal() == .alertFirstButtonReturn else { return }
            do { try await state.makeLayoutStandard(); await state.sync() }
            catch { state.onFailure?(true) }
        }
    }
    @objc private func togglePet() { if pet.panel.isVisible { pet.panel.orderOut(nil) } else { pet.show() } }
    @objc private func togglePause() { pet.pet.isPaused.toggle(); pet.pet.noteActivity() }
    private func setLoginEnabled(_ enabled: Bool) {
        do { try LoginLaunch.setEnabled(enabled) }
        catch { let alert = NSAlert(); alert.messageText = "로그인 항목을 확인해 주세요"; alert.informativeText = LoginLaunchPresentation.resolve(LoginLaunch.state, installed: LoginLaunch.isInstalled(), failed: true).message; alert.runModal() }
    }
    private func setPetName(_ value: String) {
        let name = PetIdentity.normalized(value)
        try? store.update { $0.petName = name }
        pet.pet.bubbleName = name
        pet.pet.setAccessibilityLabel("hejo · \(name) · 대화 열기")
        saveMemberSettings()
    }
    private func setPetScale(_ value: Double) {
        try? store.update { $0.petScalePercent = min(200,max(25,value)) }
        pet.resizePet(percent: value); saveMemberSettings()
    }
    private func setBubbleAlwaysShown(_ value: Bool) {
        try? store.update { $0.bubbleAlwaysShown = value }
        pet.pet.bubbleAlwaysShown = value; saveMemberSettings()
    }
}
