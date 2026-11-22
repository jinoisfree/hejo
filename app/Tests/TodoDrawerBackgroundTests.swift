import AppKit

private final class DrawerBackdropProbe: NSView {
    var color = NSColor.magenta { didSet { needsDisplay=true } }
    override func draw(_ dirtyRect: NSRect) { color.setFill(); bounds.fill() }
}

/// AT-FF-40/41: sample real parent captures as well as the drawer's own alpha.
@MainActor func todoDrawerBackgroundTests(resourceDirectory: URL) throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let previousStore=ChatAppearance.store
    defer { ChatAppearance.bind(previousStore) }
    let store=try LocalStore(directory:directory)
    ChatAppearance.bind(store)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.deadlineSender={ _ in }
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    let view=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"))
    let pet=PetController(store:store,atlas:try SpriteAtlas(resourceDirectory:resourceDirectory))
    defer { disposeDrawerFixture(pet,controller,view) }
    pet.reducedMotion={true};pet.pet.animationsAllowed=false
    var screen=CGRect(x:0,y:0,width:1440,height:900)
    pet.displays={ [PetDisplay(frame:screen,visible:screen)] }
    pet.pet.installConversation(view);pet.installDrawer(view)
    pet.onExpansionChanged={ controller.model.setVisible($0) }
    pet.placePet(at:CGPoint(x:650,y:700));pet.showChat();pet.setDrawerOpen(true)
    let probe=DrawerBackdropProbe(frame:.zero)
    pet.pet.conversation.addSubview(probe,positioned:.below,relativeTo:view.todoDrawer)
    let sample=CGPoint(x:8,y:200) // Empty margin, away from text/cards and rounded corners.
    func capture(_ surface:NSView,at point:CGPoint) throws -> NSColor {
        surface.layoutSubtreeIfNeeded()
        guard let bitmap=surface.bitmapImageRepForCachingDisplay(in:surface.bounds) else {throw TestFailure.assertion("FF drawer bitmap allocation")}
        surface.cacheDisplay(in:surface.bounds,to:bitmap)
        let x=Int((point.x-surface.bounds.minX)*CGFloat(bitmap.pixelsWide)/surface.bounds.width)
        let y=Int((point.y-surface.bounds.minY)*CGFloat(bitmap.pixelsHigh)/surface.bounds.height)
        guard let pixel=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB) else {throw TestFailure.assertion("FF drawer bitmap sample")}
        return pixel
    }
    func distance(_ a:NSColor,_ b:NSColor)->CGFloat {
        let a=a.usingColorSpace(.deviceRGB)!,b=b.usingColorSpace(.deviceRGB)!
        return abs(a.redComponent-b.redComponent)+abs(a.greenComponent-b.greenComponent)+abs(a.blueComponent-b.blueComponent)
    }
    var themePixels:[NSColor]=[]
    for overlay in [true,false] {
        pet.setDrawerOpen(false)
        screen=CGRect(x:0,y:0,width:overlay ? 700:1440,height:900)
        pet.placePet(at:CGPoint(x:overlay ? 100:650,y:700))
        pet.setDrawerOpen(true);pet.stepPlacement()
        try check(pet.placementTarget?.drawerOverlay==overlay,"FF fixture uses the actual requested drawer placement")
        try check(view.todoDrawer.superview===pet.pet.conversation && !view.todoDrawer.isHidden,"FF drawer is installed and visible in the actual PetView")
        probe.frame=pet.pet.conversation.bounds
        for theme in [ChatTheme.dark,.light] {
            view.todoDrawer.needsDisplay=false
            try ChatAppearance.change(theme:theme)
            try check(view.todoDrawer.needsDisplay,"FF ChatAppearance.didChange invalidates the drawer background")
            pet.applyChatAppearance();pet.pet.updateScrim()
            pet.pet.conversation.layoutSubtreeIfNeeded()
            let expected=view.todoDrawer.backgroundColor.withAlphaComponent(1)
            let parentPoint=view.todoDrawer.convert(sample,to:pet.pet.conversation)
            var pixels:[NSColor]=[]
            for backdrop in [NSColor.magenta,.green] {
                probe.color=backdrop
                let pixel=try capture(pet.pet.conversation,at:parentPoint)
                try check(abs(pixel.alphaComponent-1)<0.001,"FF drawer parent pixel is opaque")
                try check(distance(pixel,expected)<0.025,"FF drawer pixel reuses the conversation tint")
                try check(distance(pixel,backdrop)>0.8,"FF drawer pixel excludes the room-list probe color")
                pixels.append(pixel)
            }
            try check(distance(pixels[0],pixels[1])<0.005,"FF room-list color changes cannot bleed through the drawer")
            let ownPixel=try capture(view.todoDrawer,at:sample)
            try check(abs(ownPixel.alphaComponent-1)<0.001 && distance(ownPixel,expected)<0.025,"FF drawer itself paints an opaque background")
            if overlay {themePixels.append(pixels[0])}
            print("AT-FF-\(overlay ? 40:41) \(theme.rawValue) PIXEL PASS alpha=\(ownPixel.alphaComponent)")
        }
    }
    try check(distance(themePixels[0],themePixels[1])>1,"FF dark and light drawer backgrounds differ")
    probe.removeFromSuperview()
}
