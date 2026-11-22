import AppKit

private final class PicturePickerFixture:NSOpenPanel {
    var chosen:URL?
    override var url:URL? {chosen}
}

private final class OptionLevelWindow:NSWindow {
    var levelChanges=0
    override var level:NSWindow.Level {
        get {super.level}
        set {levelChanges+=1;super.level=newValue}
    }
}

// AT-FF-64: visible options follow app activation without retaining or updating closed windows.
@MainActor private func optionWindowActivationTests() throws {
    let oldLevel=OptionWindows.petLevel,oldActivate=OptionWindows.activate
    let oldActive=OptionWindows.isActive
    defer {OptionWindows.petLevel=oldLevel;OptionWindows.activate=oldActivate;OptionWindows.isActive=oldActive}
    OptionWindows.activate={};OptionWindows.isActive={true}
    for petLevel in [NSWindow.Level.floating,NSWindow.Level(rawValue:NSWindow.Level.mainMenu.rawValue+1)] {
        OptionWindows.petLevel={petLevel}
        let window=OptionLevelWindow(contentRect:CGRect(x:0,y:0,width:100,height:100),styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false
        let chooser=NSOpenPanel()
        defer {window.close();chooser.close()}
        OptionWindows.show(window)
        OptionWindows.prepare(chooser);chooser.makeKeyAndOrderFront(nil)
        try check(window.isVisible && chooser.isVisible,"AT-FF-64 standalone and real photo chooser are open")
        OptionWindows.updateLevels(active:false)
        try check(window.level == .normal && chooser.level == .normal,"AT-FF-64 inactive options return to normal")
        OptionWindows.updateLevels(active:true)
        try check(window.level.rawValue==petLevel.rawValue+1 && chooser.level.rawValue==petLevel.rawValue+1,"AT-FF-64 active options return above the pet")
        window.close();chooser.close()
        let changes=window.levelChanges,closedChooserLevel=chooser.level
        OptionWindows.updateLevels(active:false);OptionWindows.updateLevels(active:true)
        try check(window.levelChanges==changes && chooser.level==closedChooserLevel,"AT-FF-64 closed options receive no level updates")
    }
    weak var released:NSWindow?
    autoreleasepool {
        let window=NSWindow(contentRect:CGRect(x:0,y:0,width:100,height:100),styleMask:[.titled],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;released=window
        OptionWindows.show(window);window.close()
    }
    try check(released == nil,"AT-FF-64 option tracking does not retain a closed window")
    print("AT-FF-64 OPTION ACTIVATION PASS")
}

private final class RaiseCountingWindow:NSWindow {
    var raises=0
    override func makeKeyAndOrderFront(_ sender:Any?){raises+=1;super.makeKeyAndOrderFront(sender)}
    override func orderFront(_ sender:Any?){raises+=1;super.orderFront(sender)}
    override func orderFrontRegardless(){raises+=1;super.orderFrontRegardless()}
}

// AT-AL-06: what hejo does to its own windows when the app becomes inactive (the two calls of applicationDidResignActive).
@MainActor private func optionWindowDeactivationTests() async throws {
    let oldLevel=OptionWindows.petLevel,oldActivate=OptionWindows.activate
    defer {OptionWindows.petLevel=oldLevel;OptionWindows.activate=oldActivate}
    let oldActive=OptionWindows.isActive
    defer {OptionWindows.isActive=oldActive}
    OptionWindows.petLevel={.floating};OptionWindows.activate={};OptionWindows.isActive={true}
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:dir)}
    let store=try LocalStore(directory:dir),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let option=RaiseCountingWindow(contentRect:CGRect(x:0,y:0,width:100,height:100),styleMask:[.titled],backing:.buffered,defer:false)
    option.isReleasedWhenClosed=false
    let connections=ConnectionsWindow(controller:controller),model=connections.model
    defer {model.close();connections.window.close();option.close()}
    let document:[String:Any]=["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[["id":"app:synthetic","service":"synology","label":"시험 연결","group":"mac","state":"unknown","reason":"VALUES_REQUIRED","checked_at":"2026-01-01T00:00:00Z","capabilities":[],"rules":[],"actions":[["id":"app_connect","label":"이어서 하기","primary":true]]]]]]]
    model.send={frame in frame["type"] as? String=="connections" ? ["document":document]:["reply":["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"password","label":"비밀번호","secure":true]]]]]}
    model.confirm={true}
    await model.refresh();model.detail="app:synthetic"
    connections.setPreferredLevel(OptionWindows.level(active:true));connections.show()
    OptionWindows.show(option)
    await model.perform("app_connect");await pause(0.15)
    guard let sheet=connections.window.attachedSheet else{throw TestFailure.assertion("AT-AL-06 missing connection input sheet")}
    try check(option.isVisible && sheet.isVisible && option.level.rawValue==NSWindow.Level.floating.rawValue+1 && connections.window.level.rawValue==NSWindow.Level.floating.rawValue+1,"AT-AL-06 option, connections and input sheet start above the pet")
    let raised=option.raises
    connections.setPreferredLevel(OptionWindows.level(active:false));OptionWindows.updateLevels(active:false)
    await pause(0.15)
    try check(option.level == .normal && connections.window.level == .normal && sheet.isVisible,"AT-AL-06 inactive option and connections windows are normal with the sheet still open")
    try check(option.raises==raised,"AT-AL-06 deactivation never raises an option window again")
    connections.setPreferredLevel(OptionWindows.level(active:true));OptionWindows.updateLevels(active:true)
    try check(option.level.rawValue==NSWindow.Level.floating.rawValue+1 && connections.window.level.rawValue==NSWindow.Level.floating.rawValue+1,"AT-AL-06 reactivation returns both windows above the pet")
    print("AT-AL-06 OPTION DEACTIVATION PASS")
}

// AT-AL-06U: a window opened while the app is not actually active (activation refused or still pending) must not
// float above the user's current app; it rises only when the app really becomes active.
@MainActor private func optionWindowInactiveOpenTests() throws {
    let oldLevel=OptionWindows.petLevel,oldActivate=OptionWindows.activate,oldActive=OptionWindows.isActive
    defer {OptionWindows.petLevel=oldLevel;OptionWindows.activate=oldActivate;OptionWindows.isActive=oldActive}
    OptionWindows.petLevel={.floating};OptionWindows.activate={};OptionWindows.isActive={false}
    let option=NSWindow(contentRect:CGRect(x:0,y:0,width:100,height:100),styleMask:[.titled],backing:.buffered,defer:false)
    let chooser=NSOpenPanel()
    option.isReleasedWhenClosed=false
    defer {option.close();chooser.close()}
    OptionWindows.show(option);OptionWindows.prepare(chooser);chooser.makeKeyAndOrderFront(nil)
    try check(option.isVisible && chooser.isVisible,"AT-AL-06U option window and chooser are open")
    try check(option.level == .normal && chooser.level == .normal,"AT-AL-06U windows opened while the app is inactive stay normal")
    OptionWindows.isActive={true};OptionWindows.updateLevels(active:true)
    try check(option.level.rawValue==NSWindow.Level.floating.rawValue+1 && chooser.level.rawValue==NSWindow.Level.floating.rawValue+1,"AT-AL-06U the app becoming active raises them above the pet")
    OptionWindows.updateLevels(active:false)
    try check(option.level == .normal && chooser.level == .normal,"AT-AL-06U inactive again returns them to normal")
    print("AT-AL-06U INACTIVE OPEN PASS")
}

@MainActor func optionWindowTests(resourceDirectory:URL) async throws {
    try optionWindowActivationTests()
    try optionWindowInactiveOpenTests()
    try await optionWindowDeactivationTests()
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:directory)}
    let store=try LocalStore(directory:directory),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"가짜 직원","aliases":[],"avatar_custom":false]]])
    controller.model.toggleSection(nil)
    let view=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"))
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer {disposeDrawerFixture(pet,controller,view)}
    pet.pet.installConversation(view);pet.installDrawer(view);pet.reducedMotion={true};pet.showChat()
    let oldLevel=OptionWindows.petLevel,oldActivate=OptionWindows.activate,oldAlert=OptionWindows.alertResponse,oldLetter=LetterPictureDialog.present
    let oldActive=OptionWindows.isActive
    defer {OptionWindows.petLevel=oldLevel;OptionWindows.activate=oldActivate;OptionWindows.isActive=oldActive;OptionWindows.alertResponse=oldAlert;LetterPictureDialog.present=oldLetter}
    OptionWindows.petLevel={pet.panel.level};OptionWindows.isActive={true}
    var activations=0
    OptionWindows.activate={activations+=1}
    let group=Room(id:"11111111-1111-4111-8111-111111111111",title:"가짜 방",members:["alpha","beta"],lead:"alpha")
    let menus=[view.employeeMenu(row:view.rowIndex(for:"alpha")!),view.groupMenu(group),view.homeMenu()]
    let source=directory.appendingPathComponent("fixture.png")
    try PictureCodec.letterPicture(color:.blue,text:"가").write(to:source)
    var uploads=0
    controller.pictureSender={_,_,_ in uploads+=1;return "/v1/pictures/room/fake"}
    for level in [NSWindow.Level.floating,NSWindow.Level(rawValue:NSWindow.Level.mainMenu.rawValue+1)] {
        pet.panel.level=level
        try check(OptionWindows.level(active:false) == .normal,"AT-FF-63 shared inactive connection preference stays normal")
        try check(OptionWindows.level(active:true).rawValue==level.rawValue+1,"AT-FF-60 shared active level is pet plus one")
        for response in [NSApplication.ModalResponse.cancel,.OK] {
            for menu in menus {
                let chooser=PicturePickerFixture();chooser.chosen=source
                view.picturePicker={chooser}
                let start=activations,before=uploads
                var completions=0
                view.choosePictureFile={panel,done in
                    try! check(activations>start && panel.level.rawValue>pet.panel.level.rawValue,"AT-FF-60 activation and height precede photo presentation")
                    try! check(panel.prompt=="넣기" && !panel.canChooseDirectories && !panel.allowsMultipleSelection,"AT-FF-54 existing photo chooser configuration")
                    completions+=1;done(response)
                }
                (menu.items.first{$0.title=="사진 바꾸기…"}!.submenu!.items[0] as! RoomActionItem).trigger()
                if response == .OK {try await waitFor {uploads==before+1}} else {await pause(0.01);try check(uploads==before,"AT-FF-60 cancel does not upload")}
                try check(completions==1,"AT-FF-60 injected cancel/insert completes exactly once")
            }
        }
        OptionWindows.alertResponse={alert in
            try! check(alert.window.level.rawValue>pet.panel.level.rawValue,"AT-FF-61 native alert uses shared option height")
            return .alertSecondButtonReturn
        }
        let start=activations
        _=RoomDialogs.present(NSAlert())
        LetterPictureDialog.present={OptionWindows.runModal($0)}
        _=try LetterPictureDialog.choose(name:"가짜 방")
        try check(activations>=start+2,"AT-FF-61 room and letter dialogs activate the app")
        let settings=PetSettingsWindow()
        settings.present(name:"가짜 펫",percent:100,bubble:true)
        try check(settings.window.level.rawValue>pet.panel.level.rawValue,"AT-FF-61 actual settings presentation uses shared height")
        settings.window.orderOut(nil);settings.window.close()
        let auxiliary=NSWindow(contentRect:CGRect(x:0,y:0,width:100,height:100),styleMask:[.titled],backing:.buffered,defer:false)
        auxiliary.isReleasedWhenClosed=false;OptionWindows.show(auxiliary)
        try check(auxiliary.level.rawValue>pet.panel.level.rawValue,"AT-FF-61 shared standalone window presentation")
        auxiliary.close()
    }
    print("AT-FF-60..61 OPTION WINDOW PASS; AT-FF-63 regression in full suite")
}
