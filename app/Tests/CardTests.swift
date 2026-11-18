import AppKit

/// AT90 observes card contents and real controls; source values are literal, not copied from rendering helpers.
@MainActor func cardTests(outputDirectory:URL?=nil) async throws {
    NSApp.appearance=NSAppearance(named:.aqua)
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),client=GateClient(store:store,credentials:MemoryCredentials()),controller=try testConversation(client:client),model=controller.model
    if outputDirectory != nil {try client.pair(address:try homeRequire(ProcessInfo.processInfo.environment["HEJO_CAPTURE_ADDRESS"],"AT90 fake connection"),code:"test_code-12",device:"fake capture");try await waitFor{controller.canSend}}
    defer{client.stop()}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[],"color":"#EEEE00"],["id":"beta","name":"직원 B","aliases":[],"color":"#007AFF"]]])
    let instant=Date(timeIntervalSince1970:1794000000);controller.clock={instant}
    var seq=0
    @discardableResult func post(_ text:String,role:String="employee",employee:String="alpha",thread:String=UUID().uuidString.lowercased(),files:[MessageFile]=[],labels:[String]=[])throws->ConversationMessage {
        seq+=1;let id=UUID().uuidString.lowercased(),frame:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":employee,"thread":thread,"role":role,"text":text,"files":try JSONSerialization.jsonObject(with:JSONEncoder().encode(files)),"buttons":labels.map{["id":UUID().uuidString.lowercased(),"label":$0,"kind":"reply","style":"default"]},"reply_state":NSNull(),"ts":ISO8601DateFormatter().string(from:instant)]
        try store.append(frame);controller.receive(frame);return model.messages[id]!
    }
    let root=try post("**할 일**\n검토해 주세요.\n\n**자세한 내용**\n> 인용 안의 [문서](https://example.invalid/note)\n> > 안쪽 인용",labels:["승인","거절","의견","확인"])
    let owner=try post("내 글",role:"owner"),other=try post("직원이 쓴 글")
    let ui=ConversationView(controller:controller);ui.reduceMotion={true};ui.motionTime={1};ui.frame=CGRect(x:0,y:0,width:850,height:850);ui.chooseEmployee("alpha")
    let window=NSWindow(contentRect:ui.frame,styleMask:.borderless,backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=ui;window.orderFrontRegardless();defer{window.orderOut(nil)}
    func content(_ message:ConversationMessage)->NativeThreadCard.Content {ui.threadContent(.init(key:message.key,title:"",preview:"",latestSeq:message.latestSeq))}
    func actions(_ message:ConversationMessage)->[NativeThreadCard.Action] {content(message).actions}
    let split=content(root).top
    try check(split.count==3,"AT90 head buttons detail ordering")
    if case .post(let head)=split[0],case .accessory(_,_,let make)=split[1],case .post(let detail)=split[2] {
        try check(head.text.string.contains("할 일") && !head.text.string.contains("자세한 내용") && detail.continuation && detail.text.string.contains("자세한 내용"),"AT90 bold action split keeps detail after buttons")
        let controls=make();controls.frame=CGRect(x:0,y:0,width:500,height:32);controls.layoutSubtreeIfNeeded()
        let buttons=homeDescendants(controls,FileChip.self).filter{$0.replyWord != nil}
        try check(buttons.count==4 && buttons.allSatisfy{$0.intrinsicContentSize==CGSize(width:36,height:30)},"AT90 four optical reply glyph boxes 36x30")
        try check(homeDescendants(controls,NSScrollView.self).count==1,"AT90 explicit reply labels use horizontal scrolling")
    } else {throw TestFailure.assertion("AT90 split piece kinds")}
    try check(!actions(other).contains{$0.identifier.hasPrefix("delete-")} && actions(owner).contains{$0.identifier.hasPrefix("delete-")},"AT90 no replies deletes only my post")
    try post("답글",thread:other.key.thread);ui.chooseThread(owner.key)
    try check(!actions(other).contains{$0.identifier.hasPrefix("delete-")},"AT90 replied unselected thread has no delete")
    ui.chooseThread(other.key)
    try check(actions(other).contains{$0.identifier.hasPrefix("delete-")},"AT90 replied selected thread has delete")
    ui.clipboardBoard=NSPasteboard.withUniqueName()
    let quiet=CardText.quiet(dark:false),branch=try homeRequire(actions(root).first{$0.title=="분기"},"AT90 branch")
    try check(branch.color==quiet && actions(root).first{$0.title=="복사"}?.color==quiet && actions(other).first{$0.title=="삭제"}?.color==quiet,"AT90 all card actions share source quiet color \(branch.color) / \(quiet) / \(actions(other).map{($0.title,$0.color)})")
    try homeRequire(actions(root).first{$0.title=="복사"},"AT90 copy action").invoke()
    try check(actions(root).first{$0.title=="복사됨"}?.color == .controlAccentColor && ui.clipboardBoard.string(forType:.string)?.hasPrefix("@직원 A 스레드")==true,"AT90 copied action accent and actual copy prefix")
    if outputDirectory != nil {await controller.branch(root.key);try check(actions(root).first{$0.title=="분기"}?.color == .controlAccentColor,"AT90 asked branch accent")}
    await controller.deleteThread(other.key)
    try check(actions(other).first{$0.title=="정말 삭제"}?.color == .systemRed && actions(other).first{$0.title=="정말 삭제"}?.label=="스레드 삭제 확인","AT90 delete confirmation red and accessibility only")
    controller.clock={instant.addingTimeInterval(7)}
    let card=NativeThreadCard(frame:.zero),layout=NativeThreadCard.layout(content(other),width:560);card.frame=CGRect(x:0,y:0,width:584,height:layout.height);card.configure(layout);ui.addSubview(card);card.layoutSubtreeIfNeeded()
    try check(homeDescendants(card,NSButton.self).filter{$0.accessibilityIdentifier().hasPrefix("branch-") || $0.accessibilityIdentifier().hasPrefix("delete-")}.allSatisfy{$0.toolTip==nil},"AT90 footer actions have no tooltip")
    let selected=model.selected,draft=controller.draft.text
    if let event=NSEvent.mouseEvent(with:.leftMouseDown,location:card.convert(CGPoint(x:layout.foot.midX+12,y:layout.foot.midY),to:nil),modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:1){card.mouseDown(with:event)}
    try check(model.selected==selected && controller.draft.text==draft,"AT90 footer gap does not fold or select")
    card.removeFromSuperview()
    // A pile toggles its view only. It must not move the destination or take a draft with it.
    for _ in 0..<3 {try post("답",thread:root.key.thread)}
    ui.chooseThread(other.key);controller.setText("남겨 둔 초안")
    let before=model.selected,place=controller.composeKey
    if let pile=content(root).replies?.first,case .stack(_,_,let toggle,_)=pile {toggle()}else{throw TestFailure.assertion("AT90 pile exists")}
    try check(model.selected==before && controller.composeKey==place && controller.draft.text=="남겨 둔 초안","AT90 pile preserves draft destination")
    let file=MessageFile(fileID:UUID().uuidString.lowercased(),name:"sample.pdf",mime:"application/pdf",size:2048)
    try check(FileTile(file:file).detail=="2.0KB · PDF" && FileTile(file:file).tileSize.height==43 && CardText.sizeText(900)=="900B" && CardText.sizeText(48128)=="47KB" && CardText.sizeText(1258291)=="1.2MB" && CardText.sizeText(0).isEmpty,"AT90 source size and PDF words")
    let checkedFile=try post("☐ 파일 확인",files:[file]),checkedText=try post("☐ 일반 글")
    if case .post(let withFile)=content(checkedFile).top[0],case .post(let normal)=content(checkedText).top[0] {try check(withFile.textHelp=="체크박스를 누르면 내 확인 상태를 저장합니다." && normal.textHelp==nil,"AT90 check help appears only in source file-line path")}
    try check(FileTile(file:MessageFile(fileID:"fake-pdf",name:"SAMPLE.PDF",mime:"application/octet-stream",size:2048)).detail=="2.0KB · PDF","AT90 source PDF extension fallback")
    let blankEdges=try post("\n\n본문\n\n"),ownerEdges=try post("\n내 글\n",role:"owner")
    if case .post(let employee)=content(blankEdges).top[0],case .post(let mine)=content(ownerEdges).top[0] {try check(employee.text.string=="본문" && mine.text.string=="\n내 글\n","AT90 employee edges trimmed while own whitespace remains")}
    let wide=NSImage(size:CGSize(width:440,height:180)),tall=NSImage(size:CGSize(width:110,height:360))
    try check(FileTile.imageSize(wide)==CGSize(width:220,height:90) && FileTile.imageSize(tall)==CGSize(width:55,height:180) && FileTile.imageSize(nil)==CGSize(width:160,height:110) && FileTile.frameSize(tall)==CGSize(width:220,height:180) && FileTile.imageSize(NSImage(size:CGSize(width:32,height:64)))==CGSize(width:90,height:180),"AT90 thumbnails preserve aspect within 220x180")
    let chip=AttachmentChip(name:"long document.pdf"){};chip.frame=CGRect(origin:.zero,size:chip.intrinsicContentSize);chip.layoutSubtreeIfNeeded();try check(chip.remove.accessibilityLabel()=="long document.pdf 빼기" && chip.remove.image != nil,"AT90 attachment removal is a separate accessible control")
    let choices=ReplyChecklist(items:["일정","가격","문의"],selected:[],canSkip:true),checklist=ReplyChecklistView(choices){_ in}
    checklist.frame=CGRect(x:0,y:0,width:500,height:90);checklist.layoutSubtreeIfNeeded();let options=homeDescendants(checklist,FileChip.self).filter{$0.title.hasPrefix("☐")}
    try check(Set(options.map{$0.frame.minY}).count==1,"AT90 wide checklist is a single row")
    checklist.frame.size.width=150;checklist.layoutSubtreeIfNeeded();try check(Set(options.map{$0.frame.minY}).count==2,"AT90 narrow checklist has two columns")
    try check(options.allSatisfy{$0.frame.size==CGSize(width:61,height:24)} && homeDescendants(checklist,FileChip.self).first{$0.title=="건너뛰기"}?.frame.size==CGSize(width:69,height:24) && homeDescendants(checklist,FileChip.self).first{$0.title=="작성"}?.frame.size==CGSize(width:47,height:24),"AT90 source bordered checklist dimensions and padding")
    options.first?.invoke?();try check(options.first?.contentTintColor == .controlAccentColor,"AT90 selected checklist accent")
    let text=CardText.linkifiedNative(MessageFormat.renderNative("https://example.invalid/doc). obsidian://open?vault=demo",bodySize:14))
    var links:[URL]=[];text.enumerateAttribute(.link,in:NSRange(location:0,length:text.length)){value,_,_ in if let url=value as? URL{links.append(url)}}
    try check(links.count==2 && links[0].absoluteString=="https://example.invalid/doc" && links[1].scheme=="obsidian" && !CardText.mayOpen(URL(string:"file:blocked")!),"AT90 bare link punctuation and safe obsidian opening")
    for dark in [false,true] {for hue:Double in [0,60,120,200,300] {
        let p=CharacterPalette.make(hue:hue,dark:dark),back:Double=dark ? 0.45:0.55
        try check(PaletteRGB.contrast(p.name,.init(r:back,g:back,b:back))>=4.5 && PaletteRGB.contrast(p.link,p.background)>=4.5,"AT90 adjusted name and link contrast")
    }}
    try check(CardText.fittedRules("  "+String(repeating:"─",count:16)+"\n본문 ────")==String(repeating:"─",count:15)+"\n본문 ────","AT90 rule-only long line fitted")
    try check(StreamReveal.visiblePrefix("글 <span style=\"c")=="글 " && StreamReveal.visiblePrefix("글 <http")=="글 " && StreamReveal.visiblePrefix("[문서](https://exam")=="문서","AT90 incomplete formatting and open link tail")
    var stream=root;stream.id="fake-stream";stream.text=String(repeating:"가",count:301);stream.streaming=true
    var reveal=StreamReveal();reveal.receive([stream],now:0)
    try check(reveal.frame(stream.id,now:0,immediately:false)?.count==1 && reveal.frame(stream.id,now:1,immediately:false)?.count==151 && reveal.frame(stream.id,now:2,immediately:false)?.count==301,"AT90 stream reveal 150 characters per second")
    var ending=StreamReveal();ending.receive([stream],now:0);_ = ending.frame(stream.id,now:0.5,immediately:false)
    stream.streaming=false;ending.receive([stream],now:0.5)
    try check(ending.revealing(stream.id) && ending.frame(stream.id,now:1,immediately:false)?.count==151 && ending.frame(stream.id,now:2,immediately:false)?.count==301,"AT90 final journal body finishes bounded local reveal without second message")
    let sentinel=NSMutableAttributedString(string:"\u{200B}",attributes:[.font:NSFont.systemFont(ofSize:1)]);CardText.uniformSize(sentinel)
    try check((sentinel.attribute(.font,at:0,effectiveRange:nil) as? NSFont)?.pointSize==1,"AT90 hidden layout sentinel is not enlarged by uniformSize")
    let copy=ThreadTools.copy([root],key:root.key,name:{_ in "방"},group:true)
    try check(copy.hasPrefix("#방 스레드") && ThreadTools.copy([root],key:root.key,name:{_ in "직원 A"}).hasPrefix("@직원 A 스레드"),"AT90 copy group and direct prefixes")
    let work=WorkingControlRow(since:instant.addingTimeInterval(-10),activity:"답변을 작성하고 있습니다",clock:{instant},animationTime:{0},reduceMotion:{true},stop:{})
    work.frame=CGRect(x:0,y:0,width:500,height:22);work.layoutSubtreeIfNeeded();try check(work.button.frame.size==CGSize(width:18,height:18) && abs(work.button.frame.minX-work.row.elapsedRect.maxX-6)<0.1 && work.row.elapsedText=="10초","AT90 work stop geometry and seconds")
    let long=try post("긴 스레드")
    do {let notify=controller.onChange;controller.onChange=nil;defer{controller.onChange=notify}
        for _ in 0..<50 {try post("답",thread:long.key.thread)}
    };ui.refresh()
    try check(actions(long).first{$0.title=="분기"}?.color == .systemOrange,"AT90 fifty replies branch orange")
    let flowing=try post("첫 글");ui.history.enter(nil)
    try check(ui.history.followsAnswer,"AT90 followed-stream fixture starts at bottom")
    let longBody="# 흘러오는 제목\n"+String(repeating:"긴 답글을 이어서 읽습니다. ",count:45)
    seq+=1;let partial:[String:Any]=["v":1,"type":"edit","seq":seq,"msg_id":flowing.id,"text":longBody,"final":false];try store.append(partial);controller.receive(partial);ui.refresh()
    let during=content(flowing)
    if case .post(let post)=during.top[0] {
        var sizes=Set<CGFloat>();post.text.enumerateAttribute(.font,in:NSRange(location:0,length:post.text.length)){font,_,_ in if let font=font as? NSFont {sizes.insert(font.pointSize)}}
        try check(sizes==[14] && post.streaming,"AT90 streaming heading has uniform body size")
    }else{throw TestFailure.assertion("AT90 streaming post")}
    seq+=1;let final:[String:Any]=["v":1,"type":"edit","seq":seq,"msg_id":flowing.id,"text":longBody,"final":true];try store.append(final);controller.receive(final);ui.refresh()
    if case .post(let post)=content(flowing).top[0] {try check(post.foldTitle=="접기","AT90 followed stream remains unfolded after final")}
    let elsewhere=try post(longBody,employee:"beta")
    for final in [false,true] {seq+=1;let frame:[String:Any]=["v":1,"type":"edit","seq":seq,"msg_id":elsewhere.id,"text":longBody,"final":final];try store.append(frame);controller.receive(frame);ui.refresh()}
    if case .post(let post)=content(elsewhere).top[0] {try check(post.foldTitle=="더 보기","AT90 unseen other-room stream is not marked as followed or kept unfolded")}
    let transparent=NSImage(size:CGSize(width:8,height:8));transparent.lockFocus();NSColor.clear.setFill();CGRect(x:0,y:0,width:8,height:8).fill(using:.copy);transparent.unlockFocus()
    let face=NSImage(size:CGSize(width:34,height:34));face.lockFocus();NSColor.white.setFill();CGRect(x:0,y:0,width:34,height:34).fill();ProfileAvatar(color:.systemRed,image:transparent).draw(in:CGRect(x:0,y:0,width:34,height:34),name:"직원 A");face.unlockFocus()
    let pixel=try homeRequire(NSBitmapImageRep(data:face.tiffRepresentation!)?.colorAt(x:17,y:17)?.usingColorSpace(.sRGB),"AT90 transparent avatar pixel")
    try check(pixel.redComponent>0.99 && pixel.greenComponent>0.99 && pixel.blueComponent>0.99,"AT90 photo has no profile color underneath")
    let thought=try post("생각 중…\n문서를 확인하고 있습니다")
    try check(content(thought).top.contains{if case .accessory(_,let h,let make)=$0{return h==34 && make() is TypingBubbleView};return false},"AT90 thinking uses compact face and name bubble")
    if let outputDirectory {
        try check(controller.canSend,"AT90 captures connected")
        let imageFile=MessageFile(fileID:UUID().uuidString.lowercased(),name:"missing.png",mime:"image/png",size:64)
        let missing=try post("사진",files:[imageFile]);_ = content(missing)
        try await waitFor(8) {content(missing).top.contains {piece in
            if case .accessory(_,_,let make)=piece {return homeDescendants(make(),FileTile.self).contains{ $0.failed }};return false
        }}
        let failed=content(missing).top.compactMap{piece->FileTile? in if case .accessory(_,_,let make)=piece {return homeDescendants(make(),FileTile.self).first};return nil}.first
        try check(failed?.failed==true,"AT90 actual HTTP 404 shows thumbnail failure")
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        let captureRoot=try post(root.text,labels:["승인","거절","의견","확인"]);ui.chooseThread(captureRoot.key)
        // A compact original/product comparison gallery from the real card assembly and controls.
        for (style,appearance) in [("light",NSAppearance.Name.aqua),("dark",.darkAqua)] {
            NSApp.appearance=NSAppearance(named:appearance);ui.appearance=NSAppearance(named:appearance)
            let canvas=CardCaptureCanvas(frame:CGRect(x:0,y:0,width:640,height:720));canvas.appearance=NSAppearance(named:appearance);canvas.dark=style=="dark"
            window.contentView=canvas;window.setContentSize(CGSize(width:640,height:720));canvas.frame=CGRect(x:0,y:0,width:640,height:720);window.appearance=canvas.appearance;window.backgroundColor=style=="light" ? .white:NSColor(white:0.12,alpha:1)
            canvas.effectiveAppearance.performAsCurrentDrawingAppearance {
                let rootCard=NativeThreadCard(frame:.zero),value=ui.threadContent(.init(key:captureRoot.key,title:"",preview:"",latestSeq:seq)),measured=NativeThreadCard.layout(value,width:616)
                rootCard.frame=CGRect(x:0,y:8,width:640,height:measured.height);rootCard.configure(measured);canvas.addSubview(rootCard)
                let sample=MessageFile(fileID:"fake-pdf",name:"sample.pdf",mime:"application/pdf",size:2048),pdf=FileTile(file:sample);pdf.frame=CGRect(x:24,y:440,width:240,height:43);canvas.addSubview(pdf)
                let picture=NSImage(size:CGSize(width:440,height:180));picture.lockFocus();NSColor(srgbRed:0,green:0.72,blue:0.77,alpha:1).setFill();CGRect(x:0,y:0,width:440,height:180).fill();picture.unlockFocus()
                let tile=FileTile(file:MessageFile(fileID:"fake-photo",name:"sample.png",mime:"image/png",size:0));tile.picture=picture;tile.frame=CGRect(x:24,y:500,width:220,height:90);canvas.addSubview(tile)
                let failure=FileTile(file:imageFile);failure.failed=true;failure.frame=CGRect(x:290,y:500,width:160,height:110);canvas.addSubview(failure)
                let reply=ReplyChecklistView(choices){_ in};reply.frame=CGRect(x:24,y:630,width:500,height:56);canvas.addSubview(reply)
                canvas.layoutSubtreeIfNeeded();canvas.displayIfNeeded()
            }
            await pause(0.1)
            let rep=try homeRequire(canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds),"AT90 bitmap");canvas.cacheDisplay(in:canvas.bounds,to:rep)
            try rep.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task39-hejo-"+style+".png"))
        }
    }
    print("AT-HF-90 APP PASS")
}

final class CardCaptureCanvas:NSView {
    var dark=false
    override var isFlipped:Bool{true}
    override func draw(_ rect:NSRect){(dark ? NSColor(white:0.12,alpha:1):.white).setFill();bounds.fill()}
}
