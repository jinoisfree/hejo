import AppKit

@MainActor func downloadsTests() throws {
    let root=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:root)}
    try FileManager.default.createDirectory(at:root,withIntermediateDirectories:true)
    let store=DownloadFileStore(root:root.appendingPathComponent("Downloads")),date=Calendar(identifier:.gregorian).date(from:DateComponents(year:2026,month:1,day:2,hour:3,minute:4))!
    let stamp="2026-01-02 0304"
    try check(store.destination(room:"ignored",name:"note.txt",date:date,id:"abc-12").lastPathComponent==stamp+" note (abc12).txt","AT95 original stamped name keeps alphanumeric ID before extension")
    try check(DownloadFileStore.named(" /:hidden\n.txt ",id:"abc-12")=="__hidden_ (abc12).txt" && DownloadFileStore.named(".hidden",id:"a")=="_hidden (a)" && DownloadFileStore.named("",id:"a")=="이름 없음 (a)","AT95 original unsafe/hidden/empty names")
    let long=DownloadFileStore.named(String(repeating:"한",count:100)+".pdf",id:"abc-12")
    try check(long.utf8.count<=200 && long.hasSuffix(" (abc12).pdf"),"AT95 UTF-8 budget retains short extension")
    let source=root.appendingPathComponent("note.txt");try Data("first".utf8).write(to:source)
    let first=try store.keep(copyOf:source,room:"",date:date),same=try store.keep(copyOf:source,room:"",date:date)
    try check(first==same && first.lastPathComponent==stamp+" note.txt","AT95 identical sent copy is reused")
    try Data("second".utf8).write(to:source)
    let second=try store.keep(copyOf:source,room:"",date:date)
    try check(second.lastPathComponent==stamp+" note 2.txt" && (try Data(contentsOf:first))==Data("first".utf8),"AT95 different sent bytes get number without overwrite")
    try check(try store.keep(copyOf:first,room:"",date:date)==first,"AT95 file already inside Downloads is left there")
    try check(GateHTTP.maxFileBytes==50*1024*1024,"AT95 hejo keeps fifty MiB limit")
    print("AT-HF-95 FILE STORE PASS")
}

@MainActor func downloadsNetwork(_ args:[String]) async throws {
    let home=URL(fileURLWithPath:args[2]),store=try LocalStore(directory:home)
    let client=GateClient(store:store,credentials:MemoryCredentials())
    let downloads=home.appendingPathComponent("Downloads"),controller=try testConversation(client:client,downloads:downloads)
    defer {client.stop()}
    try client.pair(address:args[3],code:"test_code-12",device:"fake download test")
    try await waitFor{controller.canSend && controller.model.messages.count==3}
    var opened:URL?;controller.onOpenFile={opened=$0}
    let posts=controller.model.messages.values.sorted{$0.seq<$1.seq},file=posts[0].files[0],other=posts[1].files[0]
    let date=ThreadTools.date(posts[0].timestamp)
    let first=controller.files.downloads.destination(room:"alpha",name:"note.txt",date:date,id:file.fileID)
    async let opening=controller.open(file,employee:"alpha",date:date)
    async let duplicate=controller.open(file,employee:"alpha",date:date)
    let (firstOpened,duplicateHandled)=await (opening,duplicate)
    try check(firstOpened && duplicateHandled,"AT95 concurrent first clicks share one fetch without a spurious error")
    try check(opened==first && (try Data(contentsOf:first))==Data("received".utf8),"AT95 actual HTTP download saves original bytes to stamped user path")
    // The fixture fails if a previously saved file is requested a second time.
    controller.notice="파일을 저장하지 못했어요. 시험 오류"
    opened=nil;let again=await controller.open(file,employee:"alpha",date:date);try check(again && opened==first && controller.notice.isEmpty,"AT95 second open reuses local copy")
    opened=nil;let otherOpened=await controller.open(other,employee:"alpha",date:ThreadTools.date(posts[1].timestamp));try check(otherOpened && opened != first && opened?.lastPathComponent.contains(other.fileID.replacingOccurrences(of:"-",with:""))==true,"AT95 same name different ID stays distinct")
    opened=nil;let foreign=await controller.open(file,employee:"beta",date:date);try check(!foreign && opened==nil,"AT95 saved copy never bypasses employee scope")
    // A file occupying the directory path reliably fails even when the test account can write chmod-locked folders.
    let blocked=home.appendingPathComponent("blocked");try Data("not a directory".utf8).write(to:blocked)
    let fallback=try testConversation(client:client,downloads:blocked)
    // Keep the real client's callback on the original controller for the sending checks below.
    client.onFrame={ [weak controller] in controller?.receive($0) }
    var cached:URL?;fallback.onOpenFile={cached=$0}
    let missing=posts[2].files[0]
    let fallbackOpened=await fallback.open(missing,employee:"alpha",date:ThreadTools.date(posts[2].timestamp));try check(fallbackOpened,"AT95 unwritable Downloads still opens downloaded cache")
    try check(cached?.path.hasPrefix(store.directory.appendingPathComponent("cache/files").path+"/")==true && fallback.notice.hasPrefix("파일을 저장하지 못했어요. "),"AT95 original failure wording plus cache fallback")
    let source=home.appendingPathComponent("sent.txt");try Data("sent bytes".utf8).write(to:source)
    controller.model.select(ConversationKey(employee:"alpha",thread:posts[0].key.thread))
    controller.clock={date}
    controller.addAttachments([source]);controller.setText("accept");await controller.sendCurrent()
    let kept=controller.files.downloads.destination(room:"",name:"sent.txt",date:date)
    try await waitFor{!controller.sending && FileManager.default.fileExists(atPath:kept.path)}
    try check((try Data(contentsOf:kept))==Data("sent bytes".utf8),"AT95 confirmed send keeps copy on this Mac")
    try Data("rejected bytes".utf8).write(to:source)
    controller.addAttachments([source]);controller.setText("reject");await controller.sendCurrent()
    try await waitFor{!controller.sending && !controller.failures.isEmpty}
    try check(!FileManager.default.fileExists(atPath:downloads.appendingPathComponent(kept.deletingPathExtension().lastPathComponent+" 2.txt").path),"AT95 rejected send never keeps a sent copy")
    print("AT-HF-95 NETWORK PASS")
}
