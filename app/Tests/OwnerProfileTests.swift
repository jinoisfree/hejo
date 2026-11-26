import AppKit

private let profileName = "길동"
private let profileStamp = "2026-01-01T00:00:00Z"
private let profileThread = "11111111-1111-4111-8111-111111111111"
private let profileRoster: [[String:Any]] = [["id":"alpha","name":"알파","aliases":[]]]
private let tableWords = String(repeating:"길게 적은 표 안쪽 글 ",count:6)
private let codeWords = String(repeating:"a",count:190) + "END0123456"
let richBody = """
| 항목 | 내용 | 상태 |
| --- | --- | --- |
| 짧은 칸 | \(tableWords) | 완료 |

```
\(codeWords)
```
"""

@MainActor private func profileController(_ root:URL) throws -> ConversationController {
    try testConversation(client: GateClient(store:try LocalStore(directory:root),credentials:MemoryCredentials()))
}

private func profileMessage(_ seq:Int, role:String, text:String, thread:String = profileThread) -> [String:Any] {
    ["v":1,"type":"message","seq":seq,"msg_id":UUID().uuidString,"employee":"alpha","thread":thread,"role":role,
     "text":text,"files":[],"buttons":[],"reply_state":NSNull(),"ts":profileStamp]
}

@MainActor private func profileLayout(_ pieces:[NativeThreadCard.Piece], width:CGFloat) -> NativeThreadCard.Layout {
    let content = NativeThreadCard.Content(id:"profile-layout",top:pieces,replies:nil,rail:nil,actions:[],deleting:nil,
        style:.init(inset:18,fill:0,stroke:nil,lineWidth:0,background:.windowBackgroundColor),
        bell:nil,onBell:{},clickCard:{},textClick:nil,bubbleWidth:width*ChatMetrics.bubbleWidthFraction,
        quiet:.secondaryLabelColor,expanded:true)
    return NativeThreadCard.layout(content,width:width)
}

private func post(_ piece:NativeThreadCard.Piece) throws -> NativeThreadCard.Post {
    guard case .post(let post) = piece else { throw TestFailure.assertion("AT-OP expected message post") }
    return post
}

@MainActor private func profileCard(_ layout:NativeThreadCard.Layout) -> NativeThreadCard {
    let card = NativeThreadCard(frame:NSRect(x:0,y:0,width:layout.width+2*ChatMetrics.horizontalInset,height:layout.height))
    card.configure(layout)
    card.layoutSubtreeIfNeeded()
    return card
}

@MainActor private func profileBitmap(_ view:NSView) throws -> NSBitmapImageRep {
    view.layoutSubtreeIfNeeded()
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else {
        throw TestFailure.assertion("AT-OP AppKit snapshot")
    }
    view.cacheDisplay(in:view.bounds,to:bitmap)
    return bitmap
}

@MainActor func assertRichBody(_ layout:NativeThreadCard.Layout) throws {
    let item = layout.placed[0], card = profileCard(layout)
    guard let view = homeDescendants(card,NSTextView.self).first,
          let manager = view.layoutManager, let storage = view.textStorage, let container = view.textContainer else {
        throw TestFailure.assertion("AT-OP-26 actual TextKit text view")
    }
    manager.ensureLayout(for:container)
    let glyphs = manager.glyphRange(for:container)
    let laid = manager.characterRange(forGlyphRange:glyphs,actualGlyphRange:nil)
    let text = storage.string as NSString
    let codeRange = text.range(of:codeWords)
    try check(laid == NSRange(location:0,length:text.length) && codeRange.location != NSNotFound &&
              !storage.string.contains("…"),"AT-OP-26 full glyph range and unchanged 200-character code")
    let codeGlyphs = manager.glyphRange(forCharacterRange:codeRange,actualCharacterRange:nil)
    let lastGlyphs = manager.glyphRange(forCharacterRange:NSRange(location:NSMaxRange(codeRange)-1,length:1),actualCharacterRange:nil)
    let last = manager.boundingRect(forGlyphRange:lastGlyphs,in:container)
    try check(lastGlyphs.length>0 && !last.isEmpty && last.maxX<=item.text.width+0.5 && last.maxY<=item.text.height+0.5,
              "AT-OP-26 final code glyph \(last) outside displayed text \(item.text.size), container \(container.containerSize)")
    var count = 0, allFit = true, cells: [String:Int] = [:], longCell: String?
    let longRange = text.range(of:tableWords.trimmingCharacters(in:.whitespaces))
    manager.enumerateLineFragments(forGlyphRange:glyphs) { _,used,_,range,_ in
        if NSIntersectionRange(range,codeGlyphs).length>0 { count += 1 }
        if range.length>0 {
            allFit = allFit && used.maxX<=item.text.width+0.5 &&
                manager.truncatedGlyphRange(inLineFragmentForGlyphAt:range.location).location==NSNotFound
            let chars = manager.characterRange(forGlyphRange:range,actualGlyphRange:nil)
            if chars.location < storage.length,
               let style = storage.attribute(.paragraphStyle,at:chars.location,effectiveRange:nil) as? NSParagraphStyle,
               let cell = style.textBlocks.first as? NSTextTableBlock {
                let bounds = manager.boundsRect(for:cell,at:range.location,effectiveRange:nil)
                let key = "\(cell.startingRow):\(cell.startingColumn)"
                cells[key,default:0] += 1
                if NSIntersectionRange(chars,longRange).length>0 { longCell=key }
                allFit = allFit && !bounds.isEmpty && used.minX>=bounds.minX-0.5 && used.maxX<=bounds.maxX+0.5 &&
                    bounds.minX>=(-0.5) && bounds.maxX<=item.text.width+0.5
            }
        }
    }
    try check(count>=2 && allFit && cells.count==6 && longCell.map{cells[$0,default:0]>=2}==true,
              "AT-OP-26 code lines \(count), allFit \(allFit), cells \(cells), long cell \(longCell ?? "none")")
    let scrolls = homeDescendants(card,NSScrollView.self)
    try check(scrolls.allSatisfy{!$0.hasHorizontalScroller && ($0.documentView?.frame.width ?? 0)<=$0.contentSize.width+0.5}
              && item.bubble.maxX<=layout.width-layout.content.style.inset+0.5,
              "AT-OP-26 no horizontal scroll or overflow")
}

@MainActor func ownerProfileTests(output:URL? = nil) throws {
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let controller = try profileController(directory), model = controller.model
    let view = ConversationView(controller:controller)
    view.frame.size = NSSize(width:760,height:580)
    let settings = PetSettingsWindow()
    settings.ownerProfile.bind(controller)
    let section = settings.ownerProfile
    let labels = homeDescendants(section,NSTextField.self).map(\.stringValue)
    try check(labels.contains("내 프로필") && labels.contains("비우면 '사장'으로 보여요") &&
              labels.contains("직원 대화와 디스코드에도 이 이름이 쓰여요") && section.name.placeholderString=="이름" &&
              section.save.title=="이름 저장" && section.choose.title=="사진 고르기…" && section.remove.title=="사진 지우기" &&
              !section.save.isEnabled && !section.choose.isEnabled && !section.remove.isEnabled,"AT-OP-20 disconnected controls")

    func frame(_ type:String, owner:[String:String]? = nil) -> [String:Any] {
        var value: [String:Any] = ["type":type,"employees":profileRoster]
        if let owner { value["owner"] = owner }
        return value
    }
    try model.apply(frame("welcome"))
    try check(model.owner==nil && model.ownerName=="사장","AT-OP-24 legacy welcome")
    try model.apply(frame("welcome",owner:["name":profileName]))
    try model.apply(frame("roster"))
    try check(model.ownerName==profileName,"AT-OP-24 legacy roster preserves name")
    try model.apply(frame("welcome"))
    try model.apply(frame("roster",owner:["name":profileName]))

    let initial = profileMessage(1,role:"owner",text:"첫 글")
    try model.apply(initial)
    let first = try homeRequire(model.threads(employee:"alpha").first,"AT-OP owner thread")
    let root = try post(view.threadContent(first).top.first { if case .post = $0 { return true };return false }!)
    try check(root.speaker==profileName,"AT-OP-22 roster refreshes the owner header")
    try check(ProfileAvatar.initial(root.speaker)=="길" && root.avatar.image==nil,"AT-OP-32 initial of configured owner")

    view.onOwnerProfile = { settings.window.orderFront(nil); settings.focusOwnerProfile() }
    var mine = try post(view.threadContent(first).top.first { if case .post = $0 { return true };return false }!)
    mine.avatar.image = NSImage(size:NSSize(width:34,height:34),flipped:false){ rect in NSColor.systemBlue.setFill();rect.fill();return true }
    let cardWithMenu = profileCard(profileLayout([.post(mine)],width:600))
    let ownerFace = cardWithMenu.value!.placed[0].aside
    let click = NSPoint(x:ownerFace.midX+ChatMetrics.horizontalInset,y:ownerFace.midY)
    let menu = try homeRequire(cardWithMenu.ownerProfileMenu(at:click),"AT-OP-21 owner avatar menu")
    let action = try homeRequire(menu.items.first as? RoomActionItem,"AT-OP-21 action")
    try check(action.title=="내 프로필…","AT-OP-21 action title")
    action.trigger()
    try check(settings.window.isVisible && settings.tabs.selectedTabViewItem?.identifier as? String=="계정" && section.name.currentEditor() != nil &&
              settings.window.firstResponder === section.name.currentEditor(),"AT-OP-21 settings opens at the name field")
    settings.window.orderOut(nil)

    try model.apply(profileMessage(2,role:"owner",text:"이어서 보낸 글"))
    func ownerPosts() throws -> [NativeThreadCard.Post] {
        let thread = try homeRequire(model.threads(employee:"alpha").first,"AT-OP thread")
        let content = view.threadContent(thread)
        return (content.top+(content.replies ?? [])).compactMap { if case .post(let post) = $0 { return post };return nil }
    }
    try check(try ownerPosts().filter(\.mine).map(\.continuation)==[false,true],"AT-OP-30 adjacent owner messages share a header")
    try model.apply(profileMessage(3,role:"employee",text:"중간 답장"))
    try model.apply(profileMessage(4,role:"owner",text:"새 글"))
    view.chooseThread(first.key)
    try check(try ownerPosts().filter(\.mine).map(\.continuation)==[false,true,false],"AT-OP-30 employee breaks the owner continuation")

    var employee = NativeThreadCard.Post(id:"employee",mine:false,text:NSAttributedString(string:"알파의 답장",attributes:[.font:NSFont.systemFont(ofSize:14)]),
        speaker:"알파",time:"오전 9:00",avatar:mine.avatar,nameColor:.labelColor,openLink:{_ in})
    var follow = employee; follow.id="follow";follow.continuation=true
    var ownerFollow = mine; ownerFollow.id="owner-follow";ownerFollow.continuation=true
    ownerFollow.text = NSAttributedString(string:"이어서 보낸 글",attributes:mine.text.attributes(at:0,effectiveRange:nil))
    for width:CGFloat in [360,600] {
        let geometry = profileLayout([.post(employee),.post(follow),.post(mine),.post(ownerFollow)],width:width)
        let a = geometry.placed[0],b = geometry.placed[1],c = geometry.placed[2],d = geometry.placed[3]
        let inset = geometry.content.style.inset
        try check(a.aside == NSRect(x:inset,y:a.aside.minY,width:34,height:34) &&
                  a.name.minX>a.aside.maxX && a.time.minX>a.name.maxX && a.aside.intersects(NSRect(x:a.aside.minX,y:a.time.minY,width:1,height:a.time.height)) &&
                  a.time.minY<a.name.maxY && a.bubble.minY>=max(a.name.maxY,a.time.maxY) &&
                  b.aside.isEmpty && b.name.isEmpty && b.time.isEmpty && a.bubble.minX==b.bubble.minX,"AT-OP-36 employee header and continuation")
        try check(c.aside.maxX==width-inset && c.aside.size==NSSize(width:34,height:34) &&
                  c.name.maxX<c.aside.minX && c.time.maxX<c.name.minX && c.bubble.minY>=max(c.name.maxY,c.time.maxY) &&
                  d.aside.isEmpty && d.name.isEmpty && d.time.isEmpty && c.bubble.maxX==d.bubble.maxX,"AT-OP-29 owner header mirrored and aligned")
        for dark in [false,true] {
            let palette = UserBubblePalette(dark:dark,pending:false)
            try check(NativeThreadCard.bubbleColor(for:mine,style:geometry.content.style,dark:dark)==palette.background.nsColor.withAlphaComponent(palette.alpha),
                      "AT-OP-27 owner bubble uses UserBubblePalette")
        }
        for item in [a,c] {
            try check(item.bubble.insetBy(dx:ChatMetrics.bubbleInset.width,dy:ChatMetrics.bubbleInset.height)==item.text &&
                      ChatMetrics.bubbleCorner==12,"AT-OP-27 shared corner and padding")
        }
    }
    var sending = mine; sending.pending=true;sending.time="보내는 중";sending.interrupted=true
    let sendLayout = profileLayout([.post(sending)],width:360).placed[0]
    try check(try post(sendLayout.piece).time=="보내는 중" && sendLayout.time.maxY<=sendLayout.bubble.minY &&
              sendLayout.fold.minY>sendLayout.bubble.maxY,"AT-OP-31 pending header and interrupted caption")

    var fixture = ConversationMessage(id:"rich",key:first.key,role:"employee",text:richBody,files:[],buttons:[],
        replyState:nil,seq:5,latestSeq:5,timestamp:profileStamp,clientMessageID:nil)
    #if HEJO_PERF_TESTING
    let rich = view.smoothPostPieces(fixture)
    for width:CGFloat in [360,600] { try assertRichBody(profileLayout(rich,width:width)) }
    for (index,body) in ["첫 글","짧은 답글","연속 답글","작성 중","첨부한 글","# 제목\n- 항목 "+String(repeating:"내용 ",count:110)].enumerated() {
        fixture.id="employee-kind-\(index)";fixture.text=body;fixture.streaming=index==3
        fixture.files=index==4 ? [.init(fileID:"fixture",name:"sample.txt",mime:"text/plain",size:1)] : []
        var styled = try post(view.smoothPostPieces(fixture)[0]);styled.continuation=index==2
        let item = profileLayout([.post(styled)],width:360).placed[0]
        try check(!item.bubble.isEmpty && item.bubble.minX+12==item.text.minX && item.bubble.minY+8==item.text.minY &&
                  item.bubble.maxX>=item.text.maxX+12 && item.bubble.maxY>=item.text.maxY+8,"AT-OP-25 employee bubble \(index)")
    }
    #else
    let rich: [NativeThreadCard.Piece] = [.post(employee)]
    #endif

    let accessoryThread=UUID().uuidString
    var attachment = profileMessage(5,role:"employee",text:String(repeating:"긴 내용\n",count:30),thread:accessoryThread)
    attachment["files"]=[["file_id":"fixture","name":"sample.txt","mime":"text/plain","size":1]]
    attachment["buttons"]=[["id":"fixture-button","label":"확인","style":"primary","kind":"reply"]]
    attachment["reply_state"]="asked"
    try model.apply(attachment)
    let accessory = try homeRequire(model.threads(employee:"alpha").first{$0.key.thread==accessoryThread},"AT-OP-28 attachment thread")
    let accessoryLayout = NativeThreadCard.layout(view.threadContent(accessory),width:600)
    let accessoryBody = try homeRequire(accessoryLayout.placed.first{!$0.bubble.isEmpty},"AT-OP-28 employee bubble")
    let extras = accessoryLayout.placed.filter { if case .accessory(let id,_,_) = $0.piece { return id.hasSuffix(":buttons") || id == "fixture" };return false }
    try check(!accessoryBody.fold.isEmpty && accessoryBody.bubble.contains(accessoryBody.fold) &&
              extras.count==2 && extras.allSatisfy{$0.frame.minY>=accessoryBody.bubble.maxY},"AT-OP-28 fold inside, attachment and button outside")

    let preview = AppearancePreview(name:"알파",agent:.make(hue:nil,dark:false),mine:UserBubblePalette(dark:false),size:14,opacity:65,dark:false,measured:{_ in})
    _ = try profileBitmap(preview)
    try check(preview.ownerTimeFrame.maxX<preview.ownerNameFrame.minX && preview.ownerNameFrame.maxY<preview.mineBubble.minY &&
              preview.textFrames["agent"]==preview.agentBubble.insetBy(dx:12,dy:8) &&
              preview.textFrames["mine"]==preview.mineBubble.insetBy(dx:12,dy:8),"AT-OP-33 preview owner header and shared shape")

    let ownerMessage = try homeRequire(model.messages[initial["msg_id"] as! String],"AT-OP-34 source")
    for expected in [profileName,"사장"] {
        if expected=="사장" { try model.apply(frame("welcome")) }
        let copy = ThreadTools.copy([ownerMessage],key:first.key,name:model.name,ownerName:model.ownerName)
        let match = HistorySearchHit(id:ownerMessage.id,snippet:ownerMessage.text,role:"owner",speaker:"alpha",timestamp:profileStamp,
                                     key:.init(room:"alpha",thread:profileThread),notes:[],revision:1)
        let group = HistorySearchGroup(key:match.key,matches:[match],rootSnippet:ownerMessage.text,latest:profileStamp,exact:true)
        let workspace = WorkspaceResults(frame:.zero)
        workspace.showHistory([group],query:"글",selection:0,name:model.name,ownerName:model.ownerName,room:{$0})
        try check(view.searchSpeaker(role:"owner",speaker:"alpha")==expected && copy.contains("] "+expected+"\n") &&
                  homeDescendants(workspace,FileChip.self).contains{$0.title.hasPrefix(expected+"  ")},"AT-OP-34 owner name on search, copy, workspace")
    }
    try check(ProfileAvatar.initial(model.ownerName)=="사","AT-OP-32 fallback initial")

    if let output {
        try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
        for dark in [false,true] {
            let appearance = NSAppearance(named:dark ? .darkAqua:.aqua)!
            view.appearance = appearance
            employee.text = NSAttributedString(string:"표와 코드 예시",attributes:[.font:NSFont.systemFont(ofSize:14),.foregroundColor:NSColor.labelColor])
            var richPost = try post(rich[0])
            #if HEJO_PERF_TESTING
            fixture.id="profile-rich-sample";fixture.text=richBody;fixture.streaming=false;fixture.files=[]
            richPost = try post(view.smoothPostPieces(fixture)[0])
            #endif
            richPost.continuation=true
            let rendered = profileCard(profileLayout([.post(employee),.post(richPost),.post(mine),.post(ownerFollow)],width:600))
            rendered.appearance = appearance
            let bitmap = try profileBitmap(rendered)
            let png = try homeRequire(bitmap.representation(using:.png,properties:[:]),"AT-OP PNG evidence")
            try png.write(to:output.appendingPathComponent(dark ? "owner-chat-dark.png":"owner-chat-light.png"))
        }
    }
    print("AT-OP-20,21,22,24–34,36 PASS")
}

/// Uses the same executable as the other app transport fixtures, with two actual clients.
@MainActor func ownerProfileTransport(_ args:[String]) async throws {
    let mode = args[2], endpoint = args[3], directory = URL(fileURLWithPath:args[4])
    let a = try profileController(directory.appendingPathComponent("A"))
    let b = try profileController(directory.appendingPathComponent("B"))
    defer { a.client.stop();b.client.stop() }
    var welcomeA = 0, welcomeB = 0
    var deviceA = "", deviceB = ""
    let receiveA = a.client.onFrame, receiveB = b.client.onFrame
    a.client.onFrame = { frame in
        receiveA?(frame)
        if frame["type"] as? String=="welcome" { welcomeA += 1; deviceA = frame["device_id"] as? String ?? "" }
    }
    b.client.onFrame = { frame in
        receiveB?(frame)
        if frame["type"] as? String=="welcome" { welcomeB += 1; deviceB = frame["device_id"] as? String ?? "" }
    }
    try await a.client.adopt(address:endpoint,device:"Profile test A",token:args[5])
    try await waitFor(5) { welcomeA==1 && a.client.isConnected && a.client.replayComplete }
    let settings = PetSettingsWindow(), section = settings.ownerProfile
    section.bind(a)
    try check(section.save.isEnabled && section.choose.isEnabled,"AT-OP-20 connected profile controls")
    if mode != "sync" {
        let old = a.model.owner
        try check(old?.name=="등록된 이름","AT-OP-23 original gate profile received")
        section.name.stringValue = profileName
        await section.saveName()
        let expected = mode=="400" ? "이름은 줄바꿈이나 제어 문자 없이 20자까지 쓸 수 있어요." :
            mode=="401" ? "출입증을 확인하지 못했어요. 다시 연결해 주세요." : "이름을 저장하지 못했어요. 연결을 확인해 주세요."
        try check(section.name.stringValue==profileName && section.problem.stringValue==expected && a.model.owner==old,
                  "AT-OP-23 HTTP \(mode) keeps draft and committed profile")
        print("AT-OP-23 \(mode) PASS")
        return
    }
    try await b.client.adopt(address:endpoint,device:"Profile test B",token:args[6])
    try await waitFor(5) { welcomeB==1 && b.client.isConnected && b.client.replayComplete }
    let epochA = a.client.connectionEpoch, epochB = b.client.connectionEpoch
    let initialA = deviceA, initialB = deviceB
    try check(!initialA.isEmpty && !initialB.isEmpty && initialA != initialB,"AT-OP-35 distinct connected devices")
    func stillConnected() throws {
        try check(a.client.isConnected && b.client.isConnected && a.model.ownerName==profileName && b.model.ownerName==profileName &&
                  a.client.connectionEpoch==epochA && b.client.connectionEpoch==epochB &&
                  welcomeA==1 && welcomeB==1 && deviceA==initialA && deviceB==initialB,
                  "AT-OP-35 profile changes require no reconnection")
    }
    func colorImage(_ color:NSColor,_ filename:String) throws -> URL {
        let image = NSImage(size:NSSize(width:64,height:64),flipped:false){ rect in color.setFill();rect.fill();return true }
        let data = try homeRequire(image.tiffRepresentation.flatMap(NSBitmapImageRep.init(data:))?.representation(using:.png,properties:[:]),"AT-OP-35 PNG fixture")
        let url = directory.appendingPathComponent(filename)
        try data.write(to:url)
        return url
    }
    func pixel(_ avatar:ProfileAvatar,_ component:Int) -> Bool {
        guard avatar.image != nil, let bitmap = NSBitmapImageRep(bitmapDataPlanes:nil,pixelsWide:34,pixelsHigh:34,bitsPerSample:8,
            samplesPerPixel:4,hasAlpha:true,isPlanar:false,colorSpaceName:.deviceRGB,bytesPerRow:0,bitsPerPixel:0),
              let context = NSGraphicsContext(bitmapImageRep:bitmap) else { return false }
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        avatar.draw(in:NSRect(x:0,y:0,width:34,height:34),name:profileName)
        NSGraphicsContext.restoreGraphicsState()
        guard let pixel = bitmap.colorAt(x:17,y:17)?.usingColorSpace(.sRGB) else { return false }
        let tolerance = CGFloat(8.0/255.0)
        return [pixel.redComponent,pixel.greenComponent,pixel.blueComponent].enumerated().allSatisfy {
            abs($0.element-($0.offset==component ? 1 : 0))<=tolerance
        }
    }
    let red = try colorImage(NSColor(srgbRed:1,green:0,blue:0,alpha:1),"red.png")
    let blue = try colorImage(NSColor(srgbRed:0,green:0,blue:1,alpha:1),"blue.png")
    let root = ConversationMessage(id:"owner-profile-fixture",key:.init(employee:"alpha",thread:profileThread),role:"owner",text:"프로필 시험",
        files:[],buttons:[],replyState:nil,seq:1,latestSeq:1,timestamp:profileStamp,clientMessageID:nil)
    #if HEJO_PERF_TESTING
    let viewA = ConversationView(controller:a), viewB = ConversationView(controller:b)
    #endif
    await section.selectPicture(red)
    section.name.stringValue = profileName
    await section.saveName()
    try await waitFor(5) { a.model.ownerName==profileName && b.model.ownerName==profileName && pixel(a.ownerAvatar(),0) && pixel(b.ownerAvatar(),0) }
    #if HEJO_PERF_TESTING
    try check(try post(viewA.smoothPostPieces(root)[0]).speaker==profileName &&
              post(viewB.smoothPostPieces(root)[0]).speaker==profileName,"AT-OP-35 both owner headers updated")
    #endif
    try check(section.remove.isEnabled,"AT-OP-20 connected photo can be removed")
    try stillConnected()
    let firstAddress = a.model.owner?.avatar
    await section.selectPicture(blue)
    try await waitFor(5) { a.model.owner?.avatar != firstAddress && a.model.owner?.avatar==b.model.owner?.avatar &&
                            pixel(a.ownerAvatar(),2) && pixel(b.ownerAvatar(),2) }
    try stillConnected()
    await section.selectPicture(nil)
    try await waitFor(5) { a.model.owner?.avatar==nil && b.model.owner?.avatar==nil &&
                            a.ownerAvatar().image==nil && b.ownerAvatar().image==nil &&
                            ProfileAvatar.initial(a.model.ownerName)=="길" && ProfileAvatar.initial(b.model.ownerName)=="길" }
    try stillConnected()
    print("AT-OP-20 connected controls PASS; AT-OP-35 red → blue → initial on both connected devices PASS")
}
