import AppKit

/// AT-HF-61~65 exercise the native surface without an operating gateway or member account.
@MainActor func task17Tests(resourceDirectory: URL) async throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try LocalStore(directory: directory)
    let atlas = try SpriteAtlas(resourceDirectory: resourceDirectory)
    let controller = PetController(store: store, atlas: atlas)
    let display = PetDisplay(frame: CGRect(x: 0, y: 0, width: 1600, height: 1400),
                             visible: CGRect(x: 0, y: 40, width: 1600, height: 1320))
    controller.displays = { [display] }
    controller.reducedMotion = { true }
    controller.placePet(at: CGPoint(x: 700, y: 950))
    controller.showChat()
    let normal = PetController.defaultChatSize
    try check(controller.preferredChatSize == normal, "AT61 initial native size")
    controller.pet.onResize?(.far, CGPoint(x: 0, y: -80)); controller.endPetDrag()
    let resized = controller.preferredChatSize
    try check(resized.height > normal.height && store.settings.chatHeight == Double(resized.height), "AT61 resize persists")
    let restored = PetController(store: try LocalStore(directory: directory), atlas: atlas)
    try check(restored.preferredChatSize == resized, "AT61 restart restores size")
    let header = ConversationHeaderDrag(frame: CGRect(x: 0, y: 0, width: 200, height: 40))
    let headerWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 200, height: 40), styleMask: .borderless, backing: .buffered, defer: false)
    headerWindow.contentView = header
    header.onDoubleClick = { controller.toggleChatWidth() }
    let doubleClick = NSEvent.mouseEvent(with: .leftMouseUp, location: CGPoint(x: 10, y: 10), modifierFlags: [], timestamp: 0,
                                          windowNumber: headerWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 2, pressure: 1)!
    header.mouseDown(with: doubleClick); header.mouseUp(with: doubleClick)
    try check(controller.preferredChatSize.width > resized.width, "AT61 header double click widens")
    controller.toggleChatWidth()
    try check(controller.preferredChatSize.width == normal.width, "AT61 second double click restores width")
    controller.fitOpenThread(800)
    try check(controller.placementTarget!.globalBubble.height > resized.height, "AT61 open thread expands")
    controller.fitOpenThread(nil)
    try check(controller.placementTarget!.globalBubble.height <= resized.height, "AT61 fold returns height")
    controller.resetChatSize()
    try check(controller.preferredChatSize == normal && store.settings.chatWidth == Double(normal.width), "AT61 reset size")

    controller.collapseChat()
    var clock = ProcessInfo.processInfo.systemUptime
    controller.pet.bubbleNow = { clock }; controller.pet.activityNow = { clock }
    let key = ConversationKey(employee: "employee-test", thread: UUID().uuidString.lowercased())
    controller.pet.bubbleNotice = BubbleReveal.Notice(kind:.reply,headline:"가짜 직원 · 새 메시지",detail:"새 글 첫 줄",key:key,sender:"가짜 직원",until:Date(timeIntervalSince1970:clock+12))
    try check(!controller.pet.foldedBubble.isHidden && controller.pet.foldedBubble.detail == "새 글 첫 줄", "AT62 first line shown")
    clock += 12.1; controller.pet.updateFoldedBubble()
    try check(controller.pet.foldedBubble.isHidden, "AT62 superseded by AT81 twelve-second timeout")
    controller.pet.bubbleStatus = "일하는 직원 1명"
    controller.pet.foldedBubble.onHover?(true)
    try check(!controller.pet.foldedBubble.isHidden && controller.pet.foldedBubble.detail == "새 글 첫 줄", "AT62 hover retains actionable notice")
    var opened: ConversationKey?
    controller.pet.onBubbleOpen = { opened = $0 }
    controller.pet.foldedBubble.onOpen?()
    try check(opened == key, "AT62 bubble opens its thread")
    controller.pet.foldedBubble.onHover?(false)
    controller.pet.bubbleAlwaysShown = true
    try check(!controller.pet.foldedBubble.isHidden, "AT62 always shown retains last bubble")

    controller.pet.noteActivity()
    controller.pet.hasAsked = true; controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .phone, "AT63 asked phone")
    controller.pet.hasAsked = false; controller.pet.isTyping = true; controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .laptop, "AT63 typing laptop")
    controller.pet.isTyping = false; controller.pet.noteSend(); controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .wave, "AT63 send wave")
    clock += PetActivity.waveDuration + 0.01
    controller.pet.sendFailed = true; controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .failure, "AT63 failure pose")
    controller.pet.sendFailed = false; clock += PetActivity.idleDelay
    controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .doze, "AT63 three-minute doze")
    controller.pet.noteActivity(); controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .idle, "AT63 local action wakes pet")
    controller.pet.isPaused = true; controller.pet.updateActivityPresentation(at: clock)
    try check(controller.pet.activityPose == .idle, "AT63 pause still")
    controller.pet.isPaused = false
    controller.screenAwake = { false }
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidSleepNotification, object: nil)
    try check(!controller.pet.animationsAllowed, "AT63 sleeping screen halts animation")
    controller.screenAwake = { true }
    NSWorkspace.shared.notificationCenter.post(name: NSWorkspace.screensDidWakeNotification, object: nil)
    try check(controller.pet.animationsAllowed, "AT63 waking screen resumes animation")
    controller.panel.orderOut(nil)

    let settings = PetSettingsWindow()
    var name = "", scale = 0.0, bubble = false
    settings.onName = { name = $0 }; settings.onScale = { scale = $0 }; settings.onBubble = { bubble = $0 }
    try check(settings.tabs.numberOfTabViewItems == 4 && settings.tabs.tabViewItems.map(\.label) == ["일반", "화면과 펫", "계정", "연결과 동기화"] &&
              settings.scaleSlider.minValue == 25 && settings.scaleSlider.maxValue == 200, "AT64 native settings pages and range")
    settings.nameField.stringValue = "hejo-test"
    _ = settings.nameField.sendAction(settings.nameField.action, to: settings.nameField.target)
    settings.scaleSlider.doubleValue = 50
    _ = settings.scaleSlider.sendAction(settings.scaleSlider.action, to: settings.scaleSlider.target)
    settings.bubbleCheck.state = .on; settings.bubbleCheck.performClick(nil); settings.bubbleCheck.performClick(nil)
    try check(name == "hejo-test" && scale == 50 && bubble, "AT64 settings controls dispatch")
    var accountOpened = false, loggedOut = false
    settings.onOpenAccount = { accountOpened = true }; settings.onLogout = { loggedOut = true }
    settings.openAccount.performClick(nil); settings.logout.performClick(nil)
    settings.updateConnection("가짜 공항 연결됨")
    try check(accountOpened && loggedOut && settings.connectionStatus.stringValue == "가짜 공항 연결됨", "AT64 account page actions and live status")
    let statusMenu = AppDelegate().makeStatusMenu()
    let titles = statusMenu.items.map { $0.isSeparatorItem ? "|" : $0.title }
    try check(titles.count == 10 && titles[0...5] == ["대화 열기", "|", "펫 숨기기", "잠시 쉬기", "|", "설정…"] &&
              titles[6].hasPrefix("hejo ") && titles[6].contains("(빌드 ") && !statusMenu.items[6].isEnabled &&
              titles[7...9] == ["업데이트 확인…", "|", "hejo 종료"], "AT64 status menu exact order with AT84 update command")
    controller.resizePet(percent: scale)
    try check(controller.pet.petScale == 0.5, "AT64 pet scale applies")
    controller.resetPosition()
    try check(store.settings.petX != nil && store.settings.petY != nil, "AT64 reset position persists")
    controller.show(); controller.panel.orderOut(nil)
    try check(!controller.panel.isVisible, "AT64 hide pet")
    controller.show(); try check(controller.panel.isVisible, "AT64 show pet")
    controller.panel.orderOut(nil)

    let chat = try ConversationController(client: GateClient(store: store, credentials: MemoryCredentials()))
    let view = ConversationView(controller: chat, clipboardArea: directory.appendingPathComponent("clipboard"))
    let panel = PetPanel(contentRect: CGRect(x: 0, y: 0, width: 500, height: 500), styleMask: [.borderless, .nonactivatingPanel], backing: .buffered, defer: false)
    panel.contentView = view; panel.chatExpanded = true
    var folded = false
    panel.onCollapse = { if !view.closeSearchIfOpen() { folded = true } }
    view.toggleSearch()
    let escape = NSEvent.keyEvent(with: .keyDown, location: .zero, modifierFlags: [], timestamp: 0,
                                  windowNumber: panel.windowNumber, context: nil, characters: "\u{1b}", charactersIgnoringModifiers: "\u{1b}", isARepeat: false, keyCode: 53)!
    panel.sendEvent(escape)
    try check(!view.isSearchOpen && !folded, "AT65 first Escape closes search")
    panel.sendEvent(escape)
    try check(folded, "AT65 second Escape folds chat")
    let originalMenu = NSApp.mainMenu
    AppDelegate().installEditMenu()
    let redo = NSApp.mainMenu?.items.flatMap { $0.submenu?.items ?? [] }.first { $0.title == "다시 실행" }
    try check(redo?.action == Selector(("redo:")) && redo?.keyEquivalent == "z" &&
              redo?.keyEquivalentModifierMask == [.command, .shift], "AT65 menu binds Cmd-Shift-Z to redo")
    NSApp.mainMenu = originalMenu
    let undo = UndoManager(); undo.groupsByEvent = false; var input = ""
    func change(_ value: String) {
        let previous = input; undo.registerUndo(withTarget: undo) { _ in change(previous) }; input = value
    }
    undo.beginUndoGrouping(); change("가짜 입력"); undo.endUndoGrouping()
    undo.beginUndoGrouping(); change("다음 입력"); undo.endUndoGrouping()
    undo.undo(); try check(input == "가짜 입력", "AT65 undo")
    undo.redo(); try check(input == "다음 입력", "AT65 redo restores input")
    print("AT-HF-61 PASS; AT-HF-62 PASS; AT-HF-63 PASS; AT-HF-64 PASS; AT-HF-65 PASS")
    try await task17MenuTests(directory: directory)
}

@MainActor private func task17MenuTests(directory: URL) async throws {
    let home = directory.appendingPathComponent("menus")
    let store = try LocalStore(directory: home)
    let chat = try ConversationController(client: GateClient(store: store, credentials: MemoryCredentials()))
    let view = ConversationView(controller: chat, clipboardArea: directory.appendingPathComponent("menus-clipboard"))
    let model = chat.model
    func menu(_ employee: String) -> NSMenu {
        let layout=model.sidebar
        if layout.stacked.contains(where:{$0.id==employee}) { if !layout.stack.open { model.toggleSection(nil) } }
        else if let section=layout.sections.first(where:{$0.id==layout.zone(employee)}),!section.open { model.toggleSection(section.id) }
        return view.employeeMenu(row:view.rowIndex(for:employee)!)
    }
    let first = "employee-one", second = "employee-two", third = "employee-three"
    let roster: [[String: Any]] = [
        ["id": first, "name": "첫째", "aliases": []],
        ["id": second, "name": "둘째", "aliases": []],
        ["id": third, "name": "셋째", "aliases": []]
    ]
    try model.apply(["v":1,"type":"roster","employees":roster])
    model.select(employee:first) // This menu fixture explicitly opens a direct room; first launch now opens Home.
    model.toggleSection(nil)
    func titles(_ menu: NSMenu) -> [String] { menu.items.map { $0.isSeparatorItem ? "|" : $0.title } }
    let menuWindow = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 700, height: 620), styleMask: .borderless, backing: .buffered, defer: false)
    menuWindow.contentView = view; view.frame = menuWindow.contentView!.bounds; view.layoutSubtreeIfNeeded()
    let rowPoint = CGPoint(x: 20, y: view.employeeTable.rect(ofRow: view.rowIndex(for:second)!).midY)
    let menuEvent = NSEvent.mouseEvent(with: .rightMouseDown, location: view.employeeTable.convert(rowPoint, to: nil), modifierFlags: [], timestamp: 0,
                                       windowNumber: menuWindow.windowNumber, context: nil, eventNumber: 0, clickCount: 1, pressure: 1)!
    try check(titles(view.employeeTable.menu(for: menuEvent)!) == titles(menu(second)), "AT67 right click resolves employee menu")
    try check(titles(menu(second)) == ["맨 위에 고정", "2번째 자리에 고정", "3번째 자리에 고정", "4번째 자리에 고정", "5번째 자리에 고정", "|", "알림 끄기", "|", "목록에서 빼기"], "AT67 employee menu exact order")
    try check(!titles(menu(first)).contains("대화 열기"), "AT67 current employee has no open command")
    try check(titles(view.blankMenu()).isEmpty, "AT67 blank menu exact order")
    try check(titles(view.headerMenu()) == ["제목과 설명 편집…", "|", "이 대화의 알림 끄기", "방 목록 보이기 / 숨기기", "방 목록 너비 전환", "전체 검색 (⌘F)", "모두 읽음", "|", "펫으로 접기"], "AT79 replaces AT67 header with original workspace menu order")
    (menu(third).items.first { $0.title == "맨 위에 고정" } as? RoomActionItem)?.trigger()
    (menu(second).items.first { $0.title == "2번째 자리에 고정" } as? RoomActionItem)?.trigger()
    try check(model.displayRooms.map(\.id).prefix(2) == [third, second], "AT67 pins retain insertion order")
    let threadA = UUID().uuidString.lowercased(), threadB = UUID().uuidString.lowercased()
    func message(_ seq: Int, employee: String, thread: String, state: String? = nil) -> [String: Any] {
        var row: [String: Any] = ["v":1,"type":"message","seq":seq,"msg_id":UUID().uuidString.lowercased(),"employee":employee,"thread":thread,
                                  "text":"가짜 글 \(seq)","role":"employee","ts":"2026-01-01T00:00:00Z","files":[],"buttons":[]]
        if let state { row["reply_state"] = state }
        return row
    }
    try model.apply(message(1, employee: second, thread: threadA))
    try model.apply(message(2, employee: second, thread: threadB))
    try check(model.unread(employee: second) == 2, "AT67 unread spans threads")
    view.chooseEmployee(second);(view.headerMenu().items.first { $0.title == "모두 읽음" } as? RoomActionItem)?.trigger()
    try check(model.unread(employee: second) == 0 && model.memberState.read("thread:" + second + "/" + threadA) == 1 && model.memberState.read("thread:" + second + "/" + threadB) == 2, "AT67 all threads marked read")
    try check(model.memberState.read("read:" + second) == 2, "AT74 all-read advances the shared room position as well")
    (menu(second).items.first { $0.title == "알림 끄기" } as? RoomActionItem)?.trigger()
    try check(model.muted.contains(second), "AT67 mute command")
    try model.apply(message(3, employee: second, thread: threadA, state: "asked"))
    try check(model.unread(employee: second) == 1 && model.visibleUnreadTotal == 0, "AT67 muted badge retained but pet badge suppressed")
    try check(chat.islandInput.unread == 0, "AT67 muted unread excluded from island owner count")
    view.refresh()
    let mutedCell = view.tableView(view.employeeTable, viewFor: view.employeeTable.tableColumns.first, row: view.rowIndex(for:second)!) as? EmployeeSidebarCell
    try check(mutedCell?.muted == true && mutedCell?.unread == 1, "AT67 muted badge gray model")
    let islandModel = IslandModel()
    islandModel.update(.init(status: .connected))
    islandModel.update(.init(messages: Array(model.messages.values), muted: model.muted))
    let island = islandModel.snapshot()
    try check(island.parts.first(where: { $0.kind == .owner })?.redDot == true && island.expanded != .owner, "AT67 asked counted without muted highlight")
    (menu(second).items.first { $0.title == "목록에서 빼기" } as? RoomActionItem)?.trigger()
    try check(model.hidden.contains(second) && !model.displayRooms.map(\.id).contains(second) && model.messages.count == 3, "AT67 hide preserves messages")
    let restore = view.addMenu().items.first { $0.title == "@둘째" }
    try check(restore != nil, "AT89 hidden rooms are inline in add menu")
    (restore as? RoomActionItem)?.trigger()
    try check(!model.hidden.contains(second), "AT67 restore hidden room")
    model.hide(second)
    try model.apply(message(4, employee: second, thread: threadA))
    try check(!model.hidden.contains(second) && model.messages.count == 4, "AT67 new message reveals hidden room")
    model.hide(first)
    let saved = model.memberState.items
    try check(saved["pin:" + third]?.v == "1" && saved["mute:" + second]?.v == "1" && saved["hide:" + first]?.v == "1", "AT67 member state entries")
    let reload = try ConversationModel(store: LocalStore(directory: home))
    try check(reload.pinned == [third] && reload.muted == [second] && reload.hidden == [first], "AT67 durable member state round trip")
    model.hide(second); model.hide(third)
    try check(model.displayRooms.isEmpty && model.selected == nil && model.messages.count == 4, "AT67 hiding last room clears selection without deleting history")
    print("AT-HF-67 PASS")
}

@MainActor func task17Capture(resourceDirectory: URL, outputDirectory: URL) async throws {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let store = try LocalStore(directory: directory)
    let controller = PetController(store: store, atlas: try SpriteAtlas(resourceDirectory: resourceDirectory))
    if let screen = NSScreen.main {
        controller.displays = { [PetDisplay(frame: screen.frame, visible: screen.visibleFrame)] }
        controller.placePet(at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY))
    }
    controller.reducedMotion = { true }
    controller.pet.bubbleAlwaysShown = true
    controller.pet.bubbleNotice = BubbleReveal.Notice(kind:.reply,headline:"가짜 직원 · 새 메시지",detail:"가짜 시험 글 첫 줄",key:ConversationKey(employee:"employee-test",thread:UUID().uuidString.lowercased()),sender:"가짜 직원",until:Date().addingTimeInterval(12))
    controller.show()
    await pause(0.5)
    func capture(_ window: NSWindow, name: String) throws {
        let command = Process()
        command.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
        command.arguments = ["-x", "-l", String(window.windowNumber), outputDirectory.appendingPathComponent(name).path]
        try command.run(); command.waitUntilExit()
        try check(command.terminationStatus == 0, "screencapture \(name)")
    }
    try capture(controller.panel, name: "task17-bubble.png")
    controller.panel.orderOut(nil)
    let settings = PetSettingsWindow()
    settings.present(name: "hejo", percent: 100, bubble: true)
    settings.tabs.selectTabViewItem(at: 1)
    await pause(0.5)
    try capture(settings.window, name: "task17-settings.png")
    settings.present(name: "hejo", percent: 100, bubble: true, account: "가짜 회원", status: "가짜 공항 연결됨")
    settings.tabs.selectTabViewItem(at: 2)
    await pause(0.3)
    try capture(settings.window, name: "task17-account.png")
    settings.window.orderOut(nil)
    print("TASK17_SCREENCAPTURE_OK")
}

@MainActor func task17MenuCapture(outputDirectory: URL, kind: String) async throws {
    try FileManager.default.createDirectory(at: outputDirectory, withIntermediateDirectories: true)
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: home) }
    let store = try LocalStore(directory: home)
    let chat = try ConversationController(client: GateClient(store: store, credentials: MemoryCredentials()))
    let view = ConversationView(controller: chat, clipboardArea: home.appendingPathComponent("clipboard"))
    try chat.model.apply(["v":1,"type":"roster","employees":[["id":"employee-test","name":"가짜 직원","aliases":[]]]])
    let window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 700, height: 570), styleMask: [.titled,.closable], backing: .buffered, defer: false)
    window.title = "hejo · 메뉴 시험"; window.center(); window.contentView = view
    window.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
    await pause(0.3)
    func show(_ menu: NSMenu, name: String, point: CGPoint) throws {
        let group = DispatchGroup(); group.enter()
        DispatchQueue.global().asyncAfter(deadline: .now() + 0.5) {
            let command = Process(); command.executableURL = URL(fileURLWithPath: "/usr/sbin/screencapture")
            command.arguments = ["-x", outputDirectory.appendingPathComponent(name).path]
            try? command.run(); command.waitUntilExit(); group.leave()
        }
        let cancel = Timer(timeInterval: 1.3, repeats: false) { _ in menu.cancelTracking() }
        RunLoop.main.add(cancel, forMode: .eventTracking)
        RunLoop.main.add(cancel, forMode: .default)
        _ = menu.popUp(positioning: nil, at: point, in: view)
        group.wait()
        try check(FileManager.default.fileExists(atPath: outputDirectory.appendingPathComponent(name).path), "menu screencapture \(name)")
    }
    switch kind {
    case "employee": view.controller.model.toggleSection(nil);try show(view.employeeMenu(row:view.sidebarRows.firstIndex{$0.kind == .room}!), name: "task17-menu-employee.png", point: CGPoint(x: 40, y: 95))
    case "blank": try show(view.blankMenu(), name: "task17-menu-blank.png", point: CGPoint(x: 40, y: 245))
    case "header": try show(view.headerMenu(), name: "task17-menu-header.png", point: CGPoint(x: 360, y: 34))
    default: throw TestFailure.assertion("unknown menu capture kind")
    }
    window.orderOut(nil)
    print("TASK17_MENU_SCREENCAPTURE_OK")
}
