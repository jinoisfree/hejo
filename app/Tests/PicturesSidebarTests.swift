import AppKit
import ImageIO
import UniformTypeIdentifiers

@MainActor func pictureNetwork(_ args:[String]) async throws {
    let store=try LocalStore(directory:URL(fileURLWithPath:args[2])),client=GateClient(store:store,credentials:MemoryCredentials())
    let chat=try testConversation(client:client)
    defer { client.stop() }
    try client.pair(address:args[3],code:"test_code-12",device:"Picture test")
    try await waitFor { client.isConnected && chat.model.employees.count==1 }
    let image=NSImage(size:CGSize(width:400,height:200));image.lockFocus();NSColor.green.setFill();CGRect(x:0,y:0,width:400,height:200).fill();image.unlockFocus()
    let input=try PictureCodec.png(image.tiffRepresentation!)
    try await chat.files.setPicture(kind:"employee",id:"alpha",data:input)
    try await waitFor { chat.model.employees.first?.avatarCustom==true }
    _=chat.avatar("alpha")
    try await waitFor { chat.avatar("alpha").image != nil }
    try check(chat.avatar("alpha").image?.size==CGSize(width:64,height:64),"AT68 decoded memory thumbnail")
    for _ in 0..<5 { _=chat.avatar("alpha") }
    let legacy=try await chat.files.picture("/v1/pictures/employee/alpha?v=large")
    try check(legacy.count>512*1024,"AT68 legacy picture GET is independent from upload size limit")
    if args.count>4 { try await pictureCapture(chat:chat,directory:URL(fileURLWithPath:args[4])) }
    do { _=try await chat.files.picture("/v1/pictures/employee/alpha?v=redirect");throw TestFailure.assertion("redirect followed") } catch FileTransferFailure.unavailable { }
    do { _=try await chat.files.picture("https://invalid.example/v1/pictures/employee/alpha");throw TestFailure.assertion("external picture URL accepted") } catch FileTransferFailure.invalidFile { }
    try await chat.files.setPicture(kind:"employee",id:"alpha",data:nil)
    try await waitFor { chat.model.employees.first?.avatarCustom==false }
    try check(chat.avatar("alpha").image==nil,"AT68 delete invalidates displayed avatar")
    print("AT68 app picture HTTP/cache PASS")
}

@MainActor private func pictureCapture(chat:ConversationController,directory:URL) async throws {
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    let thread="11111111-1111-4111-8111-111111111111"
    for seq in 1...5 {
        try chat.model.apply(["v":1,"type":"message","seq":seq,"msg_id":UUID().uuidString.lowercased(),"employee":"alpha","thread":thread,"role":seq==1 ? "owner" : "employee","text":seq==1 ? "사진과 배치를 확인해 주세요" : "사진 표시 시험 \(seq)","files":[],"buttons":[],"ts":"2026-01-01T00:00:00Z"])
    }
    chat.model.select(employee:"alpha");chat.model.pin("alpha",slot:1);chat.model.toggleSection("1")
    try chat.model.apply(["type":"typing","employee":"alpha","thread":thread,"on":true,"ttl_seconds":60])
    let view=ConversationView(controller:chat,clipboardArea:chat.client.store.directory.appendingPathComponent("clip"))
    let window=NSWindow(contentRect:CGRect(x:0,y:0,width:760,height:600),styleMask:[.titled],backing:.buffered,defer:false)
    window.title="hejo · 가짜 명부 사진·배치 시험";window.contentView=view;window.center();window.orderFrontRegardless()
    func save(_ target:NSView,_ name:String) throws {
        target.layoutSubtreeIfNeeded();target.displayIfNeeded()
        let rep=target.bitmapImageRepForCachingDisplay(in:target.bounds)!;target.cacheDisplay(in:target.bounds,to:rep)
        try rep.representation(using:.png,properties:[:])!.write(to:directory.appendingPathComponent(name))
    }
    await pause(0.4);try save(view,"hejo-tabs.png")
    view.setSidebarWidth(212);view.layoutSubtreeIfNeeded();await pause(0.4);try save(view,"hejo-list.png")
    try save(view.employeeTable,"hejo-sidebar.png")
    let bubble=FoldedBubbleView(frame:CGRect(x:0,y:0,width:360,height:58));bubble.avatar=chat.avatar("alpha");bubble.sender="Test alpha";bubble.headline="hejo · Test alpha";bubble.detail="사진 표시 시험"
    let bubbleWindow=NSWindow(contentRect:bubble.bounds,styleMask:.borderless,backing:.buffered,defer:false);bubbleWindow.contentView=bubble;bubbleWindow.orderFrontRegardless()
    await pause(0.1);try save(bubble,"hejo-folded-bubble.png")
    window.orderOut(nil);bubbleWindow.orderOut(nil)
}

@MainActor func picturesSidebarTests() throws {
    let source=CGContext(data:nil,width:600,height:300,bitsPerComponent:8,bytesPerRow:0,space:CGColorSpace(name:CGColorSpace.sRGB)!,bitmapInfo:CGImageAlphaInfo.premultipliedLast.rawValue)!
    source.setFillColor(NSColor.red.cgColor);source.fill(CGRect(x:0,y:0,width:600,height:300))
    source.setFillColor(NSColor.green.cgColor);source.fill(CGRect(x:150,y:0,width:300,height:300))
    for type in [UTType.png, .jpeg, .heic] {
        let encoded=NSMutableData(),writer=CGImageDestinationCreateWithData(encoded,type.identifier as CFString,1,nil)!
        CGImageDestinationAddImage(writer,source.makeImage()!,nil)
        try check(CGImageDestinationFinalize(writer),"AT68 input encoder \(type.identifier)")
        let result=try PictureCodec.png(encoded as Data),image=NSBitmapImageRep(data:result)!
        try check(image.pixelsWide==256 && image.pixelsHigh==256 && result.count<=512*1024,"AT68 256 PNG from \(type.identifier)")
        let center=image.colorAt(x:128,y:128)!.usingColorSpace(.sRGB)!
        try check(center.greenComponent>0.8 && center.redComponent<0.2,"AT68 center square instead of stretching edges")
    }
    let fallback=NSImage(cgImage:source.makeImage()!,size:CGSize(width:600,height:300)),thumbnail=NSImage(size:CGSize(width:64,height:64))
    thumbnail.lockFocus();ProfileAvatar(image:fallback).draw(in:CGRect(x:0,y:0,width:64,height:64),name:"Test");thumbnail.unlockFocus()
    let sample=NSBitmapImageRep(data:thumbnail.tiffRepresentation!)!.colorAt(x:8,y:32)!.usingColorSpace(.sRGB)!
    try check(sample.greenComponent>0.8 && sample.redComponent<0.2,"AT68 nonsquare fallback photo fills without stretching")
    do { _=try PictureCodec.png(Data("not image".utf8));throw TestFailure.assertion("AT68 nonimage accepted") } catch FileTransferFailure.invalidFile { }
    try check(PictureCodec.color(name:"Test employee",hex:nil)==PictureCodec.color(name:"Test employee",hex:nil),"AT68 deterministic name color")
    let color=PictureCodec.color(name:"Test employee",hex:"#12ABCD").usingColorSpace(.sRGB)!
    try check(abs(color.redComponent-18/255.0)<0.001 && abs(color.blueComponent-205/255.0)<0.001,"AT68 normalized roster color")
    let legacy=try JSONDecoder().decode(Employee.self,from:Data("{\"id\":\"alpha\",\"name\":\"Test\",\"aliases\":[]}".utf8))
    try check(legacy.avatarCustom==nil,"AT68 old roster retains missing capability")

    var layout=SidebarLayout()
    layout.sections[0].open=true
    layout.stack.open=true
    layout.items=[.init(id:"home",name:"Home",kind:.home)]
    layout.items += [4,2,0,3,1].map { .init(id:"d\($0)",name:"Direct \($0)",kind:.direct,members:["d\($0)"],rank:$0) }
    for index in 0..<3 {
        var item=SidebarLayout.Item(id:"g\(index)",name:"Group \(index)",kind:.group)
        item.members=["d0","d1"];item.latest=Double(index+1);item.unread=index==1 ? 200 : 2
        item.questions=1;item.alerts=1;item.muted=index==1;layout.items.append(item)
    }
    layout.pins=["d0":1,"g0":3]
    try check(layout.group("1").map(\.id)==["d0","g2","g0","g1"],"AT69 slots one and three filled, rest newest")
    try check(layout.stacked.map(\.id)==["d1","d2","d3","d4"],"AT69 unpinned directs roster order")
    try check(layout.rows.first?.id=="home" && layout.rows.last?.id=="d4","AT69 home first, stack last")
    try check(layout.rows.first(where:{$0.kind == .stack})?.name=="DM","AT85 approved default DM name")
    try check(layout.canMove("d0",to:"2") && !layout.canMove("d1",to:"2") && !layout.canMove("home",to:"2"),"AT69 move guards")
    let header=layout.rows.first(where:{$0.id=="section:1"})!
    try check(header.unread==4 && header.signals==["unread","question","alert"] && header.faces==["d0","d1"],"AT69 muted group omitted from totals and ordered signals")
    try check(SidebarLayout.badge(101)=="99+","AT69 tab badge cap")
    let cell=EmployeeSidebarCell(frame:CGRect(x:0,y:0,width:212,height:58))
    var signaled=SidebarLayout.Item(id:"fixture",name:"Test",kind:.group);signaled.questions=2;signaled.alerts=3
    cell.list=true;cell.row = .init(kind:.room,id:"fixture",name:"Test",items:[signaled])
    cell.refreshChrome();cell.layoutSubtreeIfNeeded()
    let surface=NSImage(size:cell.bounds.size);surface.lockFocus();cell.layer?.render(in:NSGraphicsContext.current!.cgContext);surface.unlockFocus()
    let bitmap=NSBitmapImageRep(data:surface.tiffRepresentation!)!
    var yellow=false,blue=false
    for y in 0..<bitmap.pixelsHigh { for x in 0..<bitmap.pixelsWide {
        guard let color=bitmap.colorAt(x:x,y:y)?.usingColorSpace(.sRGB),color.alphaComponent>0.9 else { continue }
        yellow = yellow || (color.redComponent>0.8 && color.greenComponent>0.6 && color.blueComponent<0.3)
        blue = blue || (color.redComponent<0.3 && color.blueComponent>0.7 && color.greenComponent>0.3)
    } }
    try check(yellow && blue,"AT69 actual room drawing includes question and alert counters")
    let deletion=layout.deletion("1")!
    try check(deletion.title=="‘section 1’ 섹션을 삭제할까요?" && deletion.body=="섹션만 없어지고 방은 그대로예요. 안에 있는 방 4개는 ‘section 2’로 옮겨져요.","AT69 22판 exact deletion dialog")
    layout.pins=["g0":5]
    try check(layout.group("1").count==3 && Set(layout.group("1").map(\.id))==Set(["g0","g1","g2"]),"AT69 sparse slot beyond room count loses no rooms")
    layout.sections=Array(layout.sections.prefix(1));try check(layout.deletion("1")==nil,"AT69 keep final section")

    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let store=try LocalStore(directory:directory), chat=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let model=chat.model,view=ConversationView(controller:chat,clipboardArea:directory.appendingPathComponent("clip"))
    try model.apply(["type":"roster","employees":[["id":"alpha","name":"Test alpha","aliases":[],"color":"#12ABCD","avatar_custom":false],["id":"beta","name":"Test beta","aliases":[]]]])
    model.toggleSection(nil)
    func titles(_ employee:String)->[String] { view.employeeMenu(row:view.rowIndex(for:employee)!).items.map(\.title) }
    try check(titles("alpha").contains("사진 바꾸기…") && !titles("alpha").contains("사진 지우기"),"AT68 false custom changes only")
    try check(!titles("beta").contains("사진 바꾸기…") && !titles("beta").contains("사진 지우기"),"AT68 legacy hides both write menus")
    try model.apply(["type":"roster","employees":[["id":"alpha","name":"Test alpha","aliases":[],"avatar_custom":true]]])
    try check(titles("alpha").contains("사진 지우기"),"AT68 true custom exposes delete")
    model.pin("alpha",slot:6);try check(model.pinned.isEmpty,"AT69 sixth slot rejected")
    model.pin("alpha",slot:3);model.move("alpha",to:"2")
    try check(model.sidebar.zone("alpha")=="2" && model.sidebar.group("2").map(\.id)==["alpha"],"AT69 durable room move")
    model.removeSection("2")
    try check(model.sidebar.zone("alpha")=="1" && model.sidebar.sections.count==2,"AT69 removal moves to first remaining")
    model.addSection();try check(model.sidebar.sections.count==3 && model.sidebar.sections.last?.id=="5","AT69 empty section after existing sections")
    model.editSection("5",name:String(repeating:"a",count:40));try check(model.sidebar.sections.last?.name.count==30,"AT69 section name length")
    try check(view.addMenu().items.map(\.title)==["새 방 만들기…","새 섹션 만들기","","목록에서 뺀 방","뺀 방이 없어요"],"AT69 room addition plus menu")
    let replica=try ConversationModel(store:LocalStore(directory:directory))
    try check(replica.sidebar.sections==model.sidebar.sections && replica.sidebar.pins==model.sidebar.pins,"AT69 reopen uses MemberState")
    print("AT-HF-68 automatic PASS; AT-HF-69 automatic PASS")
}
