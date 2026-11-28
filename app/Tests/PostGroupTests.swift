import AppKit

/// Drives real conversation projection with fake roster/message frames and temporary storage.
@MainActor private final class PostGroupFixture {
    let client:GateClient
    let controller:ConversationController
    let ui:ConversationView
    let key=ConversationKey(employee:"alpha",thread:UUID().uuidString.lowercased())
    private var seq=0

    init(directory:URL) async throws {
        client=GateClient(store:try LocalStore(directory:directory),credentials:MemoryCredentials())
        controller=try testConversation(client:client)
        try await client.receive(["v":1,"type":"welcome","employees":[["id":"alpha","name":"Alpha","aliases":[]],["id":"beta","name":"Beta","aliases":[]]]])
        ui=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"))
        ui.reduceMotion={true};ui.motionTime={1};ui.frame=CGRect(x:0,y:0,width:850,height:850)
        ui.chooseEmployee("alpha")
    }

    @discardableResult func post(_ text:String,role:String="employee",speaker:String="alpha",file:Bool=false,buttons:Bool=false)->String {
        seq+=1
        let id=UUID().uuidString.lowercased()
        controller.receive(["v":1,"type":"message","seq":seq,"msg_id":id,"room":key.employee,"employee":speaker,"thread":key.thread,"role":role,"text":text,
            "files":file ? [["file_id":UUID().uuidString.lowercased(),"name":"a.txt","mime":"text/plain","size":1]]:[],
            "buttons":buttons ? [["id":UUID().uuidString.lowercased(),"label":"확인","kind":"reply","style":"default"]]:[],
            "ts":"2026-01-01T00:00:01Z"])
        return id
    }
    func typing(_ speaker:String="alpha",on:Bool=true) {
        controller.receive(["v":1,"type":"typing","room":key.employee,"employee":speaker,"thread":key.thread,"on":on,"ttl_seconds":600])
    }
    func edit(_ id:String,text:String,final:Bool) {
        seq+=1;controller.receive(["v":1,"type":"edit","seq":seq,"msg_id":id,"text":text,"final":final])
    }
    func content(expanded:Bool=true) throws -> NativeThreadCard.Content {
        ui.refresh()
        func current() throws -> NativeThreadCard.Content {
            guard let content=ui.history.contents.first(where:{$0.id==key.thread}) else {throw TestFailure.assertion("AT-PG fixture thread missing")}
            return content
        }
        if expanded,let pile=try current().replies?.first,case .stack(_,_,let toggle,_)=pile {toggle();ui.refresh()}
        let content=try current()
        if expanded {try check(stacks(content).isEmpty,"AT-PG expanded prerequisite: no stack")}
        return content
    }
}

private func posts(_ content:NativeThreadCard.Content)->[NativeThreadCard.Post] {
    (content.replies ?? []).compactMap{if case .post(let post)=$0 {return post};return nil}
}
private func stacks(_ content:NativeThreadCard.Content)->[String] {
    (content.replies ?? []).compactMap{if case .stack(_,let title,_,_)=$0 {return title};return nil}
}
@MainActor private func typingHeads(_ content:NativeThreadCard.Content)->[TypingBubbleView] {
    (content.replies ?? []).compactMap{if case .accessory(_,34,let make)=$0 {return make() as? TypingBubbleView};return nil}
}
@MainActor private func workRows(_ content:NativeThreadCard.Content)->Int {
    (content.replies ?? []).filter{if case .accessory(_,_,let make)=$0 {return make() is WorkingControlRow};return false}.count
}
private func expectPosts(_ content:NativeThreadCard.Content,_ expected:[(String,Bool)],_ label:String) throws {
    let actual=posts(content)
    try check(actual.map(\.id)==expected.map{$0.0} && actual.map(\.continuation)==expected.map{$0.1},label)
}

/// AT-PG-01...11,13: names follow visible timeline adjacency; work controls and time help survive grouping.
@MainActor func postGroupTests() async throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    func fixture() async throws -> PostGroupFixture {try await PostGroupFixture(directory:home.appendingPathComponent(UUID().uuidString))}

    // AT-PG-01,11: file-first answers share one head; time help yields to checkbox help.
    do {
        let f=try await fixture();f.post("첫 글",role:"owner")
        let file=f.post("",file:true),text=f.post("끝났어요")
        var content=try f.content()
        try expectPosts(content,[(file,false),(text,true)],"AT-PG-01 file then text")
        let p=posts(content)
        try check(p[0].textHelp==nil && p[1].textHelp==p[1].time && !p[1].time.isEmpty,"AT-PG-11 grouped time help only")
        f.post("추가 답글");let checked=f.post("☐ 확인",file:true)
        content=try f.content()
        let c=try homeRequire(posts(content).first{$0.id==checked},"AT-PG-11 checkbox post")
        try check(c.continuation && c.textHelp=="체크박스를 누르면 내 확인 상태를 저장합니다.","AT-PG-11 checkbox help wins")
    }
    // AT-PG-02: an owner or a different employee ends the preceding group.
    for middle in ["owner","beta"] {
        let f=try await fixture();f.post("첫 글",role:"owner")
        let a=f.post("A1"),m=f.post("중간 글",role:middle=="owner" ? "owner":"employee",speaker:middle=="beta" ? "beta":"alpha"),b=f.post("A2")
        try expectPosts(f.content(),[(a,false),(m,false),(b,false)],"AT-PG-02 \(middle) breaks group")
    }
    // AT-PG-03: the top post cannot lend its head to the first reply.
    do {
        let f=try await fixture(),root=f.post("R"),a=f.post("A1"),b=f.post("A2"),content=try f.content()
        try expectPosts(content,[(a,false),(b,true)],"AT-PG-03 reply boundary")
        try check(content.top.contains{if case .post(let p)=$0 {return p.id==root && !p.continuation};return false},"AT-PG-03 top keeps head")
    }
    // AT-PG-04: a hidden predecessor is never a visible head; expansion restores the run.
    do {
        let f=try await fixture();f.post("첫 글",role:"owner")
        let ids=(1...4).map{f.post("A\($0)")},folded=try f.content(expanded:false)
        try check(stacks(folded)==["이전 답글 3개"],"AT-PG-04 folded stack")
        try expectPosts(folded,[(ids[3],false)],"AT-PG-04 folded last starts group")
        try expectPosts(f.content(),[(ids[0],false),(ids[1],true),(ids[2],true),(ids[3],true)],"AT-PG-04 expanded adjacency")
    }
    // AT-PG-05: assert the exact folded input before checking two nonadjacent visible posts.
    for middle in ["beta","alpha"] {
        let f=try await fixture();f.post("첫 글",role:"owner")
        let a=f.post("확인해 주세요",buttons:true)
        f.post("가운데 글",speaker:middle);let b=f.post("마지막 글"),content=try f.content(expanded:false)
        try check(stacks(content)==["이전 답글 1개"],"AT-PG-05 \(middle) prerequisite: one hidden reply")
        try check(posts(content).map(\.id)==[a,b],"AT-PG-05 \(middle) prerequisite: exactly A1, A2")
        try expectPosts(content,[(a,false),(b,false)],"AT-PG-05 \(middle) hidden predecessor breaks group")
    }
    // AT-HB-34 / AT-PG-06: a question stays whole and grouped with its preceding employee.
    do {
        let f=try await fixture();f.post("첫 글",role:"owner")
        let a=f.post("A1"),s=f.post("**할 일**\n검토해 주세요.\n\n**자세한 내용**\n설명입니다.",buttons:true)
        try expectPosts(f.content(),[(a,false),(s,true)],"AT-PG-06 whole question")
    }
    // AT-PG-07: typing after the employee's file contributes only the work row.
    do {
        let f=try await fixture();f.post("첫 글",role:"owner");let file=f.post("",file:true);f.typing()
        let content=try f.content()
        try expectPosts(content,[(file,false)],"AT-PG-07 file post")
        try check(typingHeads(content).isEmpty && workRows(content)==1,"AT-PG-07 no duplicate typing head")
    }
    // AT-PG-08(a,b,c,e): missing, owner, different employee, and multiple typing employees.
    for scenario in ["none","owner","beta","both"] {
        let f=try await fixture();f.post("첫 글",role:"owner")
        if scenario=="owner" {f.post("A1");f.post("O",role:"owner")}
        if scenario=="beta" {f.post("B1",speaker:"beta")}
        if scenario=="both" {f.post("A1");f.typing("beta")}
        f.typing();let content=try f.content(),heads=typingHeads(content)
        try check(heads.count==1 && heads[0].accessibilityLabel()?.hasPrefix(scenario=="both" ? "Beta ":"Alpha ")==true,"AT-PG-08 \(scenario) exact typing head")
        try check(workRows(content)==1,"AT-PG-08 \(scenario) work row")
    }
    // AT-PG-08(d): use the real local send path to establish the private interruption state.
    try await postGroupInterruptionTest(directory:home.appendingPathComponent("interruption"))

    // AT-PG-09: thinking has no piece within a run and retains its head after an owner.
    for precedingOwner in [false,true] {
        let f=try await fixture();f.post("첫 글",role:"owner")
        let previous=f.post(precedingOwner ? "O":"A1",role:precedingOwner ? "owner":"employee"),thought=f.post("🤔 생각 중...")
        let content=try f.content()
        try expectPosts(content,[(previous,precedingOwner)],"AT-PG-09 thinking is not a post")
        try check(typingHeads(content).count==(precedingOwner ? 1:0) && workRows(content)==1,"AT-PG-09 thinking head and work row")
        if !precedingOwner {try check(!(content.replies ?? []).contains{if case .accessory(let id,_,_)=$0 {return id.hasPrefix(thought)};return false},"AT-PG-09 grouped thought has zero pieces")}
    }
    // AT-PG-10: a thinking head also owns the next ordinary answer.
    do {
        let f=try await fixture();f.post("첫 글",role:"owner");f.post("🤔 생각 중...");let text=f.post("T"),content=try f.content()
        try check(typingHeads(content).count==1,"AT-PG-10 thinking head remains")
        try expectPosts(content,[(text,true)],"AT-PG-10 answer follows thinking head")
    }
    // AT-PG-13: inspect every file -> typing -> thought -> streaming edit -> final edit transition.
    do {
        let f=try await fixture();f.post("첫 글",role:"owner");let file=f.post("",file:true)
        func stage(_ number:Int,_ expected:[(String,Bool)],work:Int) throws {
            let content=try f.content()
            let heads=posts(content).filter{$0.speaker=="Alpha" && !$0.continuation}.count + typingHeads(content).filter{$0.accessibilityLabel()?.hasPrefix("Alpha ")==true}.count
            try check(heads==1,"AT-PG-13 stage \(number) exactly one Alpha head")
            try check(workRows(content)==work,"AT-PG-13 stage \(number) work row")
            try expectPosts(content,expected,"AT-PG-13 stage \(number) posts")
        }
        try stage(1,[(file,false)],work:0)
        f.typing();try stage(2,[(file,false)],work:1)
        let thought=f.post("🤔 생각 중...");try stage(3,[(file,false)],work:1)
        f.edit(thought,text:"작성 중인 답",final:false);try stage(4,[(file,false),(thought,true)],work:1)
        f.edit(thought,text:"끝났어요",final:true);f.typing(on:false);try stage(5,[(file,false),(thought,true)],work:0)
        let final=try homeRequire(posts(f.content()).last,"AT-PG-13 final answer")
        try check(final.textHelp==final.time && !final.time.isEmpty,"AT-PG-13 final time help")
    }
    print("AT-PG-01...11,13 PASS")
}

/// Isolated loopback sink permits a send without inserting an owner echo between A1 and typing.
@MainActor private func postGroupInterruptionTest(directory:URL) async throws {
    try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
    let portFile=directory.appendingPathComponent("port"),process=Process()
    process.executableURL=URL(fileURLWithPath:ProcessInfo.processInfo.environment["HEJO_PYTHON"] ?? "/usr/bin/python3")
    process.arguments=["-c","""
import asyncio, sys
from pathlib import Path
from aiohttp import web
async def socket(request):
    ws = web.WebSocketResponse()
    await ws.prepare(request)
    await ws.receive_json()
    await ws.send_json(dict(v=1, type='welcome', employees=[dict(id='alpha', name='Alpha', aliases=[]), dict(id='beta', name='Beta', aliases=[])]))
    await ws.send_json(dict(v=1, type='sync_done', through=0, more=False))
    async for message in ws:
        pass
    return ws
async def main():
    app = web.Application()
    app.router.add_get('/v1/ws', socket)
    runner = web.AppRunner(app)
    await runner.setup()
    site = web.TCPSite(runner, '127.0.0.1', 0)
    await site.start()
    Path(sys.argv[1]).write_text(str(site._server.sockets[0].getsockname()[1]))
    await asyncio.Event().wait()
asyncio.run(main())
""",portFile.path]
    var environment=ProcessInfo.processInfo.environment;environment["HERMES_HOME"]=directory.path;process.environment=environment
    try process.run()
    defer {if process.isRunning {process.terminate()}}
    try await waitFor{FileManager.default.fileExists(atPath:portFile.path) || !process.isRunning}
    try check(process.isRunning,"AT-PG-08 interruption fixture running")
    let port=try String(contentsOf:portFile,encoding:.utf8),f=try await PostGroupFixture(directory:directory.appendingPathComponent("store"))
    defer {f.client.stop()}
    try f.client.pair(address:"ws://127.0.0.1:"+port,code:"test_code-12",device:"post-group-fixture")
    try await waitFor{f.controller.canSend}
    f.post("첫 글",role:"owner");let a=f.post("A1");f.typing()
    let sent=await f.controller.sendText("끼어들기",key:f.key)
    try check(sent,"AT-PG-08 interruption send accepted")
    // Settle the local pending echo through receive; leave the durable timeline as owner, A1.
    let pending=try homeRequire(f.controller.timeline(f.key).last(where:{$0.pending})?.clientMessageID,"AT-PG-08 pending send")
    f.controller.receive(["v":1,"type":"ack","client_msg_id":pending])
    let content=try f.content(),heads=typingHeads(content)
    try check(f.controller.interruptions[f.key] != nil,"AT-PG-08 prerequisite: interruption established")
    try expectPosts(content,[(a,false)],"AT-PG-08 prerequisite: last visible answer is Alpha")
    try check(heads.count==1 && heads[0].accessibilityLabel()?.hasPrefix("Alpha ")==true && workRows(content)==1,"AT-PG-08 interruption preserves typing head and work row")
}
