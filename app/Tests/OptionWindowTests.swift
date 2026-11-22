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
    defer {OptionWindows.petLevel=oldLevel;OptionWindows.activate=oldActivate}
    OptionWindows.activate={}
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

@MainActor func optionWindowTests(resourceDirectory:URL) async throws {
    try optionWindowActivationTests()
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
    defer {OptionWindows.petLevel=oldLevel;OptionWindows.activate=oldActivate;OptionWindows.alertResponse=oldAlert;LetterPictureDialog.present=oldLetter}
    OptionWindows.petLevel={pet.panel.level}
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
