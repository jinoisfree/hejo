import AppKit

@MainActor func drawerOutsidePlacementTests(resourceDirectory:URL) throws {
    let width=PetController.drawerWidth
    for origin:CGFloat in [0,-1600] {
        let screen=CGRect(x:origin,y:0,width:1440,height:900)
        let base=PetPlacement(globalSprite:CGRect(x:origin+100,y:600,width:192,height:208),
                              globalBubble:CGRect(x:origin+12,y:100,width:428,height:500),expanded:true)
        let moved=base.withLeading(width,visibleFrame:screen)
        let shift=(screen.minX+12)-(base.globalBubble.minX-width)
        try check(!moved.drawerOverlay && moved.leading==width,"AT-FF-90 drawer uses outside leading")
        try check(moved.contentBubble==base.contentBubble.offsetBy(dx:shift,dy:0) && moved.globalSprite==base.globalSprite.offsetBy(dx:shift,dy:0),"AT-FF-90 sprite and unchanged chat size move together")
        try check(moved.globalBubble.minX>=screen.minX+12 && moved.globalBubble.maxX<=screen.maxX-12,"AT-FF-90 both outer margins fit the selected display")
        try check(moved.anchorOrigin==base.anchorOrigin,"AT-FF-90 temporary movement preserves anchor")
        let exact=CGRect(x:origin,y:0,width:base.globalBubble.width+width+24,height:900)
        try check(!base.withLeading(width,visibleFrame:exact).drawerOverlay,"AT-FF-90 exact right margin is inclusive")
        let narrow=base.withLeading(width,visibleFrame:exact.insetBy(dx:0.5,dy:0))
        try check(narrow.drawerOverlay && narrow.leading==0 && narrow.globalBubble==base.globalBubble && narrow.globalSprite==base.globalSprite && narrow.anchorOrigin==base.anchorOrigin,"AT-FF-92 insufficient total width preserves overlay and original placement")
        let fits=PetPlacement(globalSprite:base.globalSprite,globalBubble:base.globalBubble.offsetBy(dx:400,dy:0),expanded:true)
        let unchanged=fits.withLeading(width,visibleFrame:screen)
        try check(!unchanged.drawerOverlay && unchanged.contentBubble==fits.contentBubble && unchanged.globalSprite==fits.globalSprite && unchanged.anchorOrigin==fits.anchorOrigin,"AT-FF-93 already fitting outside placement stays unchanged")
    }
    print("AT-FF-90/92/93 PLACEMENT BOUNDARIES PASS")

    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.deadlineSender={_ in}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    let view=ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer {disposeDrawerFixture(pet,controller,view)}
    let screen=CGRect(x:0,y:0,width:1440,height:900)
    pet.displays={ [PetDisplay(frame:screen,visible:screen)] };pet.reducedMotion={true};pet.pet.animationsAllowed=false
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.placePet(at:CGPoint(x:200,y:700));pet.showChat();pet.placePet(at:CGPoint(x:200,y:700));pet.endPetDrag()
    let closed=pet.panel.frame,base=pet.placementTarget!,savedX=store.settings.petX,savedY=store.settings.petY
    let shift=(screen.minX+12)-(base.globalBubble.minX-width)
    for _ in 0..<3 {
        pet.setDrawerOpen(true);pet.stepPlacement();view.layoutSubtreeIfNeeded()
        let opened=pet.placementTarget!
        try check(!opened.drawerOverlay && opened.contentBubble==base.contentBubble.offsetBy(dx:shift,dy:0) && opened.globalSprite==base.globalSprite.offsetBy(dx:shift,dy:0),"AT-FF-91 native controller shifts the pet and chat right once")
        try check(pet.panel.frame.maxX==closed.maxX+shift && pet.panel.frame.minX==closed.minX+shift-width,"AT-FF-91 native panel includes outside drawer after translation")
        try check(view.todoDrawer.superview===pet.pet.conversation && view.todoDrawer.frame.maxX<=view.frame.minX && pet.pet.drawerScrim.isHidden,"AT-FF-91 actual drawer remains outside conversation without scrim")
        try check(opened.anchorOrigin==base.anchorOrigin && store.settings.petX==savedX && store.settings.petY==savedY,"AT-FF-91 opening does not save display translation")
        let persisted=try LocalStore(directory:home)
        try check(persisted.settings.petX==savedX && persisted.settings.petY==savedY,"AT-FF-91 on-disk position stays unchanged")
        pet.setDrawerOpen(false);pet.stepPlacement()
        try check(pet.panel.frame==closed && pet.placementTarget!.globalSprite==base.globalSprite && store.settings.petX==savedX && store.settings.petY==savedY,"AT-FF-91 closing restores exact panel and pet position")
    }
    print("AT-FF-91 NATIVE OUTSIDE AND RESTORE PASS; AT-FF-93 regression in full suite")
}
