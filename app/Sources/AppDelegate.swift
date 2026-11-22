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
    private var updateItem: NSMenuItem?
    private var appUpdate: AppUpdate?
    private var currentAccount = ""
    private var toolsWindow:ConnectionsWindow?
    private var petSettings: PetSettingsWindow?
    private var threeTap: ThreeTapController!
    private var monitor: StatusMonitor?
    private let monitorQueue = DispatchQueue(label:"hejo.monitor")
    private var monitorTimer: Timer?
    private var monitorBusy = false
    private let dashboardModel = DashboardModel()
    private var dashboardWindow: NSWindow?
    private var workSnapshot: Snapshot?
    private var calendar: MacCalendar!
    private var calendarWindow: NSWindow?
    private var bubble: BubbleReveal!
    private var bubbleTimer: Timer?
    private var bubbleReply:BubbleReplyCard!
    private var wasSending = false
    private var loginChangeFailed = false
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
            instance = try InstanceLock(directory: AppIdentity.support); store = try LocalStore();ChatAppearance.bind(store)
            bubble = BubbleReveal(store:store)
            client = GateClient(store: store); pet = PetController(store: store, atlas: try SpriteAtlas())
            OptionWindows.petLevel = { [weak self] in self?.pet?.panel.level ?? .floating }
            conversation = try ConversationController(client: client)
            calendar = MacCalendar()
            calendar.onChange = { [weak self] events in self?.conversation.calendarEvents = events }
            bubbleReply=BubbleReplyCard(controller:conversation);pet.pet.installBubbleReply(bubbleReply)
            pet.pet.bubbleReplyAllowed=store.settings.bubbleReplyEnabled ?? true
            pet.pet.avatarForEmployee = { [weak self] id in self?.conversation.avatar(id) ?? ProfileAvatar(color:PictureCodec.color(name:id,hex:nil)) }
            conversationView = ConversationView(controller: conversation)
            conversationView.onConnections={ [weak self] profile in self?.showConnections(profile) }
            conversationView.homePetImage=pet.pet.atlas.image(row:0,frame:0)
            pet.pet.installConversation(conversationView)
            pet.installDrawer(conversationView)
            pet.installWeb(WebPaneModel(downloads: conversation.files.downloads.root))
            pet.web?.onExternal = { url in if url.isFileURL || CardText.mayOpen(url) { NSWorkspace.shared.open(url) } }
            conversationView.onCalendar = { [weak self] in self?.showRelatedCalendar($0) }
            conversationView.onOpenURL = { [weak self] url in self?.followLink(url) }
            conversation.onOpenFile = { [weak self] url in guard let self else { return }; if !self.pet.showBeside(url) { NSWorkspace.shared.open(url) } }
            pet.panel.onPageKey = { [weak self] event in guard let self, let web = self.pet.web, web.hasFocus(in: self.pet.panel) else { return false }; return web.handleShortcut(event) }
            conversationView.onCollapse = { [weak self] in self?.pet.collapseChat() }
            pet.onReadingResizeBegan={ [weak conversationView] in conversationView?.beginReadingResize() };pet.onReadingResizeEnded={ [weak conversationView] in conversationView?.endReadingResize() }
            conversationView.onOpenThreadHeight = { [weak self] height in self?.pet.fitOpenThread(height) }
            pet.panel.onWorkspaceKey = { [weak self] event in guard let self, self.pet.web?.hasFocus(in:self.pet.panel) != true else {return false}; return self.conversationView.handleWorkspaceKey(event) }
            pet.panel.onCollapse = { [weak self] in guard let self else { return }; if !self.conversationView.pickingFiles && !self.conversationView.closeSearchIfOpen() { self.pet.collapseChat() } }
            pet.pet.onBubbleOpen = { [weak self] key in guard let self else {return};self.openBubble(key) }
            pet.pet.onClick={ [weak self] in guard let self else{return};if self.pet.chatExpanded {self.pet.collapseChat()} else {self.openBubble(self.pet.pet.bubbleTarget)} }
            pet.pet.onBubbleAction = { [weak self] action in self?.performBubbleAction(action) }
            bubbleTimer=Timer(timeInterval:0.25,repeats:true){ [weak self] _ in Task { @MainActor in self?.refreshPetActivity(); self?.calendar.refresh() } }
            RunLoop.main.add(bubbleTimer!,forMode:.common)
            let previousChange = conversation.onChange
            conversation.onChange = { [weak self] in previousChange?(); self?.refreshPetActivity(); if let self { self.petSettings?.refreshHome(rooms:self.conversation.model.rooms,selected:self.conversation.model.home.settings.channel);self.petSettings?.imessageSection.refresh() } }
            conversationView.onUnread = { [weak self] count in self?.pet.pet.unreadCount = count }
            conversationView.onSidebarWidth = { [weak self] delta in
                guard let self, let current = self.pet.placementTarget else { return }
                self.pet.preferredChatSize.width += delta; self.pet.placePet(at: current.anchorOrigin)
                self.pet.saveChatSize()
            }
            for header in [conversationView.headerDrag,conversationView.brandDrag] {
                header.onBegan={ [weak self] point in self?.pet.beginChatDrag(at:point) }
                header.onChanged={ [weak self] point in self?.pet.moveChatDrag(to:point) }
                header.onEnded={ [weak self] in self?.pet.endChatDrag() }
                header.onDoubleClick={ [weak self] in self?.pet.toggleChatWidth() }
            }
            pet.onFocus={ [weak self] in guard let self else{return};self.pet.panel.makeFirstResponder(self.conversationView.editor.editor) }
            conversationView.refresh()
            pet.canCollapse={ [weak self] in self?.conversationView.pickingFiles != true }
            pet.onExpansionChanged = { [weak self] expanded in if !expanded {self?.conversationView.folded()};self?.conversation.model.setVisible(expanded); if expanded { self?.conversation.model.memberState.activate() };self?.refreshPetActivity() }
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
            threeTap = try ThreeTapController(store: store, live: true)
            threeTap.onTap = { [weak self] in self?.pet.threeFingerTapped() }
            threeTap.onChange = { [weak self] in
                guard let self else { return }; self.petSettings?.updateThreeTap(self.threeTap)
            }
            threeTap.onNotice = { [weak self] text, failure in
                DispatchQueue.main.async { [weak self] in self?.threeTap.showNotice(text, failure: failure) }
            }
            threeTap.start()
            configureUpdates(AppUpdate()); appUpdate?.start()
            calendar.refresh(requestAccess:true)
            dashboardModel.onSelect = { [weak self] id in self?.dashboardModel.selectedID=id;self?.dashboardModel.onChange?();self?.refreshPetActivity() }
            dashboardModel.onPause = { [weak self] in self?.togglePause() }
            dashboardModel.onRefresh = { [weak self] in self?.refreshWork(force:true) }
            dashboardModel.onPreview = { [weak self] in self?.pet.preview() }
            dashboardModel.onHooks = { [weak self] in self?.showHooksHelp() }
            monitor = StatusMonitor()
            monitorTimer = Timer(timeInterval:2,repeats:true) { [weak self] _ in Task { @MainActor in self?.refreshWork() } }
            RunLoop.main.add(monitorTimer!,forMode:.common);refreshWork(force:true)
            pet.show()
            if !pendingURLs.isEmpty {let urls=pendingURLs;pendingURLs=[];application(NSApp,open:urls)}
            if store.settings.address.isEmpty || !store.settings.signsInAutomatically {
                // Without automatic sign-in every launch starts at the login screen (saved id/password still fill in).
                Task { if !store.settings.address.isEmpty { await client.signOut() }; connection.present() }
            } else { client.resume(); Task { await syncMemberSettings() } }
        } catch GateFailure.alreadyRunning {
            for app in NSRunningApplication.runningApplications(withBundleIdentifier: AppIdentity.bundleID) where app.processIdentifier != ProcessInfo.processInfo.processIdentifier { app.activate(options: []) }
            NSApp.terminate(nil)
        } catch { let alert = NSAlert(); alert.messageText = "hejo를 시작하지 못했어요"; alert.informativeText = "앱 파일과 저장 공간을 확인해 주세요."; OptionWindows.runModal(alert); NSApp.terminate(nil) }
    }
    func installEditMenu() {NSApp.mainMenu=makeEditMenu()}
    func makeEditMenu()->NSMenu {
        let main = NSMenu(), app = NSMenu(), edit = NSMenu(title: "편집")
        let appItem = NSMenuItem(); appItem.submenu = app; main.addItem(appItem)
        app.addItem(withTitle: "hejo 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        let editItem = NSMenuItem(); editItem.submenu = edit; main.addItem(editItem)
        edit.addItem(withTitle:"실행 취소",action:Selector(("undo:")),keyEquivalent:"z")
        let redo=edit.addItem(withTitle:"실행 복귀",action:Selector(("redo:")),keyEquivalent:"z");redo.keyEquivalentModifierMask=[.command,.shift]
        edit.addItem(.separator())
        for (title,selector,key) in [("오려두기","cut:","x"),("복사하기","copy:","c"),("붙여넣기","paste:","v"),("전체 선택","selectAll:","a")] {edit.addItem(withTitle:title,action:Selector(selector),keyEquivalent:key)}
        return main
    }
    func makeStatusMenu() -> NSMenu {
        let menu = NSMenu(); menu.delegate = self; menu.autoenablesItems = false
        menu.addItem(withTitle: "대화 열기", action: #selector(openChat), keyEquivalent: "").target = self
        menu.addItem(withTitle:"작업 목록",action:#selector(showDashboard),keyEquivalent:"").target = self
        menu.addItem(withTitle:"내 캘린더",action:#selector(showCalendar),keyEquivalent:"").target = self
        menu.addItem(.separator())
        hideItem = menu.addItem(withTitle: "펫 숨기기", action: #selector(togglePet), keyEquivalent: ""); hideItem?.target = self
        pauseItem = menu.addItem(withTitle: "잠시 쉬기", action: #selector(togglePause), keyEquivalent: ""); pauseItem?.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "설정…", action: #selector(showOptions), keyEquivalent: ",").target = self
        menu.addItem(withTitle:"에이전트 연결…",action:#selector(openAgentConnections),keyEquivalent:"").target=self
        let version = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? AppIdentity.version
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "2"
        let versionItem = menu.addItem(withTitle: "hejo \(version) (빌드 \(build))", action: nil, keyEquivalent: "")
        versionItem.isEnabled = false
        updateItem = menu.addItem(withTitle: appUpdate?.menuTitle ?? "업데이트 확인…", action: #selector(checkAppUpdate), keyEquivalent: "")
        updateItem?.target = self
        menu.addItem(.separator())
        menu.addItem(withTitle: "hejo 종료", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        return menu
    }
    func menuNeedsUpdate(_ menu: NSMenu) {
        refreshUpdates()
        hideItem?.title = pet?.panel.isVisible == false ? "펫 보이기" : "펫 숨기기"
        pauseItem?.title = pet?.pet.isPaused == true ? "다시 시작" : "잠시 쉬기"
    }
    func applicationWillTerminate(_ notification: Notification) {
        appUpdate?.stop()
        threeTap?.stop()
        if let activityMonitor { NSEvent.removeMonitor(activityMonitor) }
        monitorTimer?.invalidate();bubbleTimer?.invalidate();client?.stop()
        // Without automatic sign-in, quitting signs this Mac out.
        if let store, !store.settings.signsInAutomatically { GateKeychain().delete(account: store.settings.credentialAccount) }
    }
    /// Member settings live at the hub so every Mac this member signs in on looks the same.
    private func applyMemberSettings(_ settings: [String: String]) {
        let name = settings["petName"].flatMap { PetIdentity.validationMessage(for:$0)==nil ? PetIdentity.normalized($0):nil } ?? store.settings.petName
        let size = settings["petScale"].flatMap(Double.init).map { min(200,max(25,$0)) } ?? store.settings.petScalePercent ?? 100
        let always = settings[BubbleReveal.settingsKey].map { $0 == "true" } ?? store.settings.bubbleAlwaysShown ?? false
        try? store.update { $0.petName = name; $0.petScalePercent = size; $0.bubbleAlwaysShown = always }
        let replyEnabled=settings[BubbleReply.settingsKey].map{$0=="true"} ?? store.settings.bubbleReplyEnabled ?? true
        try? store.update{$0.bubbleReplyEnabled=replyEnabled};pet.pet.bubbleReplyAllowed=replyEnabled;petSettings?.bubbleReplyCheck.state=replyEnabled ? .on:.off
        pet.resizePet(percent: size); pet.pet.bubbleAlwaysShown = always; pet.pet.bubbleName = name;dashboardModel.name=name;dashboardWindow?.title="hejo · \(name) · AI 작업"
        if let address = store.settings.hubAddress, let token = client.bearer, !currentAccount.isEmpty {
            do {
                try conversation.model.memberState.join(member: currentAccount, hub: address, legacy: settings)
                conversation.model.memberState.configure(hub: HubClient(address: address), token: token)
            } catch { conversation.model.memberState.onFailure?(true) }
        }
        pet.pet.setAccessibilityLabel("hejo · \(store.settings.petName) · 대화 열기")
        conversationView.refresh()
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
                do {try await Task.sleep(nanoseconds:1_500_000_000)} catch {break}
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
        guard !conversation.paused else { pet.pet.updateFoldedBubble(); return }
        let model = conversation.model
        let input=conversation.islandInput
        let messages=Array(model.messages.values)
        let questions=Set(model.rooms.flatMap{model.notices($0.id).filter(\.questions).flatMap(\.messages)})
        let readIDs=Set(messages.filter{ message in
            let key=message.key
            return message.latestSeq<=max(model.memberState.read("read:"+key.employee),model.memberState.read("thread:"+key.employee+"/"+key.thread))
        }.map(\.id))
        let jumped=bubble.update(.init(messages:messages,calendarEvents:conversation.calendarEvents,questions:questions,typing:model.typing,names:input.names,muted:model.petMuted,readIDs:readIDs,opened:model.selected,chatOpen:pet.chatExpanded,paused:pet.pet.isPaused,ready:client.replayComplete,tasks:dashboardModel.tasks,selectedTask:dashboardModel.selectedID,screenFocus:workSnapshot?.screenFocus,failure:input.failure),now:Date())
        if jumped {pet.pet.requestReplyJump()}
        var notice=bubble.notice
        if bubble.persistenceFailed {notice.detail="알림을 저장하지 못했어요. 저장 공간을 확인해 주세요."}
        // A failed inline reply keeps its existing draft target; it does not become an alert bubble.
        if notice.key==nil,notice.workState==nil,let old=bubbleReply.target,conversation.bubbleProblems[old.key] != nil,!model.petMuted.contains(old.key.employee),!model.timeline(old.key).isEmpty {notice.key=old.key}
        let target=notice.key.flatMap{key->BubbleReplyTarget? in
            guard !model.timeline(key).isEmpty else{return nil}
            return BubbleReplyTarget(key:key,speaker:model.name(key.employee),working:conversation.working(key),queued:model.employees.first{$0.id==key.employee}?.queued ?? false)
        }
        if let target,target.working,conversation.interruptions[target.key] != nil {notice.detail=BubbleReply.interruptedSubtitle;notice.kind = .writing}
        pet.pet.bubbleReplyConnected=conversation.canSend
        bubbleReply.aim(target)
        pet.pet.bubbleNotice=notice
        if !conversation.canSend || pet.chatExpanded || pet.pet.isPaused || !pet.pet.bubbleReplyAllowed {pet.pet.updateBubbleReply(pointerOver:false)}
        let working = Set(model.typing.filter{$0.value>Date() && !model.petMuted.contains($0.key.employee)}.keys.map(\.employee)).count
        pet.pet.hasAsked = notice.kind == .approval; pet.pet.isTyping = notice.kind == .writing && notice.workState == nil
        pet.pet.taskState=notice.workState ?? .idle;pet.pet.screenFocus=workSnapshot?.screenFocus
        pet.pet.sendFailed=notice.workState == .failed;pet.pet.homeConversation=model.isHome
        pet.pet.subtitleInterrupted=target.map{conversation.interruptions[$0.key] != nil && $0.working} ?? false
        pet.pet.bubbleStatus=""
        item?.button?.toolTip="hejo · \(store.settings.petName) · 작업 중 \(working)개 · 안 읽은 답 \(model.visibleUnreadTotal)개"
        if conversation.sending && !wasSending { pet.pet.noteSend() }
        wasSending = conversation.sending
    }
    private func openBubble(_ key:ConversationKey?) {
        pet.showChat { [self] in
            if let key { conversationView.openFromBubble(key) }
            bubble.dismiss()
        }
        refreshPetActivity()
    }
    private func followLink(_ url: URL) {
        // Gateway URLs never become authenticated WebKit requests. Resolve a known attachment through GateHTTP instead.
        if conversation.openAttachmentLink(url) { return }
        pet.openWebLink(url)
    }
    private func performBubbleAction(_ action:BubbleReveal.Action) {
        switch action {
        case .openChat:openBubble(pet.pet.bubbleTarget)
        case .link(let url):
            guard ["https","http"].contains(url.scheme?.lowercased() ?? "") else{return}
            followLink(url);bubble.dismiss();refreshPetActivity()
        case .calendar(let events):
            showRelatedCalendar(events)
        case .remindLater:
            if !bubble.remindLater(now:Date()) {pet.pet.bubbleStatus="나중에 알림을 저장하지 못했어요. 저장 공간을 확인해 주세요."}
            refreshPetActivity()
        }
    }
    private func refreshWork(force:Bool=false) {
        guard let monitor,!monitorBusy,pet?.pet.isPaused != true else {return}
        monitorBusy=true
        monitorQueue.async { [weak self] in
            let snapshot=monitor.poll(forceDiscovery:force)
            DispatchQueue.main.async {
                guard let self else{return};self.monitorBusy=false
                guard self.pet?.pet.isPaused != true else{return}
                self.workSnapshot=snapshot;self.dashboardModel.apply(snapshot);self.refreshPetActivity()
            }
        }
    }
    @objc func showDashboard() {
        dashboardModel.name=store.settings.petName;dashboardModel.paused=pet.pet.isPaused
        if dashboardWindow == nil {
            let window=NSWindow(contentRect:CGRect(x:0,y:0,width:710,height:610),styleMask:[.titled,.closable,.miniaturizable,.resizable],backing:.buffered,defer:false)
            window.titlebarAppearsTransparent=true;window.isReleasedWhenClosed=false
            window.contentView=Dashboard(model:dashboardModel);window.minSize=CGSize(width:680,height:560);window.center();dashboardWindow=window
        }
        dashboardWindow?.title="hejo · \(store.settings.petName) · AI 작업"
        dashboardModel.onChange?();if let dashboardWindow { OptionWindows.show(dashboardWindow) }
    }
    @objc func showHooksHelp() { HooksHelp.present() }
    @objc func showCalendar() { calendar.browse();presentCalendar() }
    private func showRelatedCalendar(_ events:[CalendarEntry]) { calendar.showRelated(events);presentCalendar() }
    private func presentCalendar() {
        if calendarWindow == nil {
            let window = NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:540),styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
            window.title = "내 캘린더 · hejo";window.isReleasedWhenClosed = false
            window.contentView = MacCalendarView(model:calendar);window.minSize = NSSize(width:660,height:480);window.center();calendarWindow = window
        }
        if let calendarWindow { OptionWindows.show(calendarWindow) }
    }
    @objc private func openChat() { pet.showChat() }
    @objc private func signOut() { conversation.model.memberState.disconnect(); currentAccount = ""; petSettings?.accountName.stringValue = "로그인 전"; Task { await client.signOut(); petSettings?.updateConnection(client.status.text); connection.present() } }
    @objc private func openAgentConnections() { showConnections() }
    private func showConnections(_ profile:String?=nil){
        if toolsWindow==nil {toolsWindow=ConnectionsWindow(controller:conversation)}
        toolsWindow?.window.appearance=pet.panel.appearance
        OptionWindows.activate();toolsWindow?.setPreferredLevel(OptionWindows.level(active:true))
        toolsWindow?.show(profile:profile);updateConnectionsLevel()
    }
    private func updateConnectionsLevel() { toolsWindow?.setPreferredLevel(OptionWindows.level(active:NSApp.isActive)) }
    func applicationDidResignActive(_ notification:Notification) { updateConnectionsLevel() }
    @objc private func showOptions() {
        if petSettings == nil {
            let profile=conversation.model.employees.first
            let settings = PetSettingsWindow(previewName:profile?.name ?? "hejo",palette:{[weak conversation] dark in conversation?.palette(profile?.id ?? "",dark:dark) ?? CharacterPalette.make(hue:nil,dark:dark)})
            settings.imessageSection.bind(client.imessage, rooms: { [weak conversation] in conversation?.imessageRooms ?? [] })
            settings.onName = { [weak self] value in self?.setPetName(value) }
            settings.onScale = { [weak self] value in self?.setPetScale(value) }
            settings.onBubbleReply={ [weak self] enabled in
                guard let self else{return};try? self.store.update{$0.bubbleReplyEnabled=enabled};self.pet.pet.bubbleReplyAllowed=enabled;self.refreshPetActivity();self.saveMemberSettings()
            }
            settings.onBubble = { [weak self] value in self?.setBubbleAlwaysShown(value) }
            settings.onThreeTap = { [weak self] in self?.threeTap.toggle() }
            settings.onAppUpdate = { [weak self] in self?.appUpdate?.checkNow() }
            settings.onUpdateNotices = { [weak self] enabled in
                self?.appUpdate?.notices.setEnabled(enabled); self?.appUpdate?.noticesChanged()
            }
            settings.onLogin = { [weak self] value in self?.setLoginEnabled(value) }
            settings.onResetChat = { [weak self] in self?.pet.resetChatSize() }
            settings.onResetPosition = { [weak self] in self?.pet.resetPosition() }
            settings.onOpenAccount = { [weak self] in self?.connection.present() }
            settings.onLogout = { [weak self] in self?.signOut() }
            settings.onHooks = { [weak self] in self?.showHooksHelp() }
            settings.onConnections={ [weak self] in self?.showConnections() }
            settings.onPreview = { [weak self] in self?.pet.preview() }
            settings.onPointer = { [weak self] in self?.pet.previewPointer() }
            settings.onHome = { [weak self] id in self?.conversation.model.configureHome { $0.channel=id.isEmpty ? nil:id } }
            settings.onSyncLayout = { [weak self] in self?.synchronizeLayout() }
            petSettings = settings
        }
        petSettings?.imessageSection.refresh()
        petSettings?.refreshHome(rooms:conversation.model.rooms,selected:conversation.model.home.settings.channel)
        petSettings?.bubbleReplyCheck.state=store.settings.bubbleReplyEnabled != false ? .on:.off
        petSettings?.updateThreeTap(threeTap)
        refreshUpdates()
        petSettings?.present(name: store.settings.petName, percent: store.settings.petScalePercent ?? 100,
                             bubble: store.settings.bubbleAlwaysShown ?? false, account: currentAccount, status: client.status.text)
    }
    func applicationDidBecomeActive(_ notification: Notification) { conversation?.model.memberState.activate();calendar?.refresh(force:true);petSettings?.refreshLogin(LoginLaunchPresentation.resolve(LoginLaunch.state,installed:LoginLaunch.isInstalled(),failed:loginChangeFailed));updateConnectionsLevel() }
    func configureUpdates(_ updates: AppUpdate) {
        appUpdate = updates
        updates.onChange = { [weak self] in self?.refreshUpdates() }
        updates.notifyInstalled = { [weak self] text in
            self?.bubble?.showInstalled(text, now: Date()); self?.refreshPetActivity()
        }
        refreshUpdates()
    }
    private func refreshUpdates() {
        guard let appUpdate else { return }
        updateItem?.title = appUpdate.menuTitle; updateItem?.isEnabled = appUpdate.canCheck
        petSettings?.updateAppUpdates(appUpdate)
    }
    @objc private func checkAppUpdate() { appUpdate?.checkNow() }
    private func synchronizeLayout() {
        let state = conversation.model.memberState
        Task {
            // Probe the hub before showing confirmation; a cached connection is not sufficient.
            guard let fetch = state.fetch, (try? await fetch(nil)) != nil else {
                OptionWindows.runModal(PetSettingsWindow.layoutConfirmation(connected: false)); return
            }
            guard OptionWindows.runModal(PetSettingsWindow.layoutConfirmation(connected: true)) == .alertFirstButtonReturn else { return }
            do {
                try await state.makeLayoutStandard(); await state.sync()
                OptionWindows.runModal(PetSettingsWindow.layoutResult(saved:true,connected:state.pending.isEmpty))
            } catch { state.onFailure?(true);OptionWindows.runModal(PetSettingsWindow.layoutResult(saved:false,connected:false)) }
        }
    }
    @objc private func togglePet() { if pet.panel.isVisible { pet.panel.orderOut(nil) } else { pet.show() } }
    @objc private func togglePause() { pet.pet.isPaused.toggle();dashboardModel.paused=pet.pet.isPaused;dashboardModel.onChange?();conversation.setPaused(pet.pet.isPaused);pet.pet.noteActivity();refreshPetActivity() }
    private func setLoginEnabled(_ enabled: Bool) {
        do { try LoginLaunch.setEnabled(enabled);loginChangeFailed=false } catch { loginChangeFailed=true }
        petSettings?.refreshLogin(LoginLaunchPresentation.resolve(LoginLaunch.state,installed:LoginLaunch.isInstalled(),failed:loginChangeFailed))
    }
    private func setPetName(_ value: String) {
        guard PetIdentity.validationMessage(for:value)==nil else{return}
        let name = PetIdentity.normalized(value)
        do {try store.update { $0.petName = name }} catch {petSettings?.nameHint.stringValue="설정을 저장하지 못했어요. 저장 공간을 확인해 주세요.";petSettings?.nameHint.textColor = .systemRed;return}
        pet.pet.bubbleName = name;dashboardModel.name=name;dashboardWindow?.title="hejo · \(name) · AI 작업"
        conversationView.refresh()
        pet.pet.setAccessibilityLabel("hejo · \(name) · 대화 열기")
        saveMemberSettings()
    }
    private func setPetScale(_ value: Double) {
        try? store.update { $0.petScalePercent = min(200,max(25,value.isFinite ? value.rounded():100)) }
        pet.resizePet(percent: value); saveMemberSettings()
    }
    private func setBubbleAlwaysShown(_ value: Bool) {
        try? store.update { $0.bubbleAlwaysShown = value }
        pet.pet.bubbleAlwaysShown = value; saveMemberSettings()
    }
}
