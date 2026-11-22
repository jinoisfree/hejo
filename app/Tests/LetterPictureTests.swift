import AppKit
import ImageIO

@MainActor func letterPictureTests(resourceDirectory:URL) async throws {
    func bitmap(_ data:Data) throws -> NSBitmapImageRep {
        guard let image=NSBitmapImageRep(data:data) else {throw TestFailure.assertion("FF letter PNG decode")}
        try check(image.pixelsWide==256 && image.pixelsHigh==256 && data.count<=PictureCodec.maximum,"AT-FF-51 PNG size and upload limit")
        return image
    }
    func differs(_ pixel:NSColor,_ expected:PaletteRGB)->Bool {
        // colorAt reports these sRGB bitmap samples as calibrated RGB. Converting
        // that NSColor again changes the samples; compare the encoded components.
        let c=pixel
        return max(abs(Double(c.redComponent)-expected.r),abs(Double(c.greenComponent)-expected.g),abs(Double(c.blueComponent)-expected.b))>2.0/255
    }
    func inkBounds(_ image:NSBitmapImageRep,color:UserBubbleColor) throws -> CGRect? {
        let palette=UserBubblePalette(color:color,dark:false)
        var minX=256,minY=256,maxX = -1,maxY = -1,solidInk=false
        for y in 0..<256 {for x in 0..<256 {
            let c=image.colorAt(x:x,y:y)!
            try check(abs(c.alphaComponent-1)<0.001,"AT-FF-51 picture pixels opaque")
            if differs(c,palette.background) {
                minX=min(minX,x);minY=min(minY,y);maxX=max(maxX,x);maxY=max(maxY,y)
                if !differs(c,palette.foreground) {solidInk=true}
            }
        }}
        if maxX<0 {return nil}
        try check(solidInk,"AT-FF-51 letter color follows UserBubblePalette")
        return CGRect(x:minX,y:minY,width:maxX-minX+1,height:maxY-minY+1)
    }
    for color in UserBubbleColor.allCases {
        for text in ["가",""] {
            let image=try bitmap(PictureCodec.letterPicture(color:color,text:text))
            for (x,y) in [(2,2),(253,2),(2,253),(253,253)] {try check(!differs(image.colorAt(x:x,y:y)!,color.resolved(dark:false)),"AT-FF-51 light-theme background corners: \(color.rawValue) text=\(text) actual=\(image.colorAt(x:x,y:y)!) expected=\(color.resolved(dark:false))")}
            let ink=try inkBounds(image,color:color)
            try check(text.isEmpty ? ink==nil:ink != nil,"AT-FF-51 empty input is a solid color; nonempty has visible letters")
        }
    }
    let emoji=try bitmap(PictureCodec.letterPicture(color:.blue,text:"👨‍👩‍👧‍👦"))
    let emojiBounds=try inkBounds(emoji,color:.blue)
    try check(emojiBounds != nil,"AT-FF-52 composed grapheme renders using the same monochrome foreground rule")
    var heights:[CGFloat]=[]
    for text in ["가","AB","가나다라마바사","가나다라마바사아자차"] {
        let image=try bitmap(PictureCodec.letterPicture(color:.blue,text:text))
        let ink=try inkBounds(image,color:.blue)!
        try check(ink.minX>=46 && ink.minY>=46 && ink.maxX<=210 && ink.maxY<=210,"AT-FF-52 glyph pixels remain inside eighteen percent safe margins")
        heights.append(ink.height)
    }
    try check(heights[1]<=heights[0] && heights[2]<=heights[1] && heights[3]<=heights[2],"AT-FF-52 long text shrinks to fit")
    try check(PictureCodec.pictureText("👨‍👩‍👧‍👦가나다라마바사아").count==8,"AT-FF-52 eight graphemes, not Unicode scalars")
    let truncated=try bitmap(PictureCodec.letterPicture(color:.red,text:"가나다라마바사아자차"))
    let eight=try bitmap(PictureCodec.letterPicture(color:.red,text:"가나다라마바사아"))
    try check(truncated.bitmapData != nil && (0..<256).allSatisfy {y in (0..<256).allSatisfy {x in truncated.colorAt(x:x,y:y)==eight.colorAt(x:x,y:y)}},"AT-FF-52 overlong input is truncated before drawing")

    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:directory)}
    let store=try LocalStore(directory:directory),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    defer {controller.client.stop()}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"가짜 직원","aliases":[],"avatar_custom":false]]])
    controller.model.toggleSection(nil)
    let view=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"))
    let group=Room(id:"11111111-1111-4111-8111-111111111111",title:"가짜 방",members:["alpha","beta"],lead:"alpha",picture:nil,description:"",archived:false)
    let menus=[view.employeeMenu(row:view.rowIndex(for:"alpha")!),view.groupMenu(group),view.homeMenu()]
    func invoke(_ item:NSMenuItem) {
        if let action=item.action,let target=item.target {_ = NSApp.sendAction(action,to:target,from:item)}
    }
    for menu in menus {
        let children=menu.items.first{$0.title=="사진 바꾸기…"}?.submenu
        try check(children?.items.map(\.title)==["사진 고르기…","색과 글자로 만들기…"],"AT-FF-50 same two choices in employee, group and home menus")
    }
    let oldPresent=LetterPictureDialog.present,oldResponse=OptionWindows.alertResponse,oldActivate=OptionWindows.activate,oldLevel=OptionWindows.petLevel
    defer {LetterPictureDialog.present=oldPresent;OptionWindows.alertResponse=oldResponse;OptionWindows.activate=oldActivate;OptionWindows.petLevel=oldLevel}
    var activations=0;OptionWindows.activate={activations+=1}
    LetterPictureDialog.present={OptionWindows.runModal($0)}
    var uploads:[(String,String,Data?)]=[]
    controller.pictureSender={kind,id,png in uploads.append((kind,id,png));return "/v1/pictures/"+kind+"/"+id+"?rev=fake"}
    var expectedInitial="가"
    OptionWindows.alertResponse={alert in
        let controls=alert.accessoryView as! LetterPictureControls
        try! check(controls.swatches.map{$0.toolTip!}==UserBubbleColor.allCases.map(\.title),"AT-FF-51 same swatch order and names")
        try! check(controls.text.stringValue==expectedInitial && controls.preview.image != nil,"AT-FF-51 initial name grapheme and preview")
        controls.text.stringValue="가나다라마바사아자차";controls.controlTextDidChange(Notification(name:NSControl.textDidChangeNotification))
        try! check(controls.text.stringValue.count==8,"AT-FF-52 UI limits graphemes")
        controls.setColor(.green);return .alertFirstButtonReturn
    }
    for (index,menu) in menus.enumerated() {
        expectedInitial=index==2 ? String(controller.model.name(HomeRoom.id).prefix(1)):"가"
        invoke(menu.items.first{$0.title=="사진 바꾸기…"}!.submenu!.items[1])
        try await waitFor {uploads.count==index+1}
    }
    try check(uploads.map{$0.0}==["employee","room","room"] && uploads.map{$0.1}==["alpha",group.id,HomeRoom.pictureID],"AT-FF-53 all menu targets reach the existing picture sender")
    for upload in uploads { _ = try bitmap(upload.2!) }
    let saved=controller.model.home.settings.picture
    OptionWindows.alertResponse={_ in .alertSecondButtonReturn}
    invoke(menus[2].items.first{$0.title=="사진 바꾸기…"}!.submenu!.items[1])
    await pause(0.02)
    try check(uploads.count==3 && controller.model.home.settings.picture==saved,"AT-FF-53 cancel sends nothing and preserves model")
    OptionWindows.alertResponse={_ in .alertFirstButtonReturn}
    controller.pictureSender={_,_,_ in throw FileTransferFailure.unavailable}
    view.chooseLetterPicture(kind:"employee",id:"alpha",name:"가짜 직원")
    try await waitFor {controller.notice=="사진을 바꾸지 못했어요. 연결을 확인해 주세요."}
    OptionWindows.alertResponse={_ in try! store.update{$0.address="changed.invalid"};return .alertFirstButtonReturn}
    controller.pictureSender={kind,id,png in uploads.append((kind,id,png));return nil}
    view.chooseLetterPicture(kind:"employee",id:"alpha",name:"가짜 직원");await pause(0.02)
    try check(uploads.count==3,"AT-FF-54 account/address change while dialog is open prevents stale upload")
    print("AT-FF-50..54 LETTER PICTURE PASS")
}
