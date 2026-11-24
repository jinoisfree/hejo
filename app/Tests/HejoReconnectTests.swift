import AppKit
import CryptoKit

// The socket probe is called ONLY by the runner's instrumented build copy, just after
// the real receive returns. Production sources carry no measurement hooks.
@MainActor var reconnectSocketReceived: (([String: Any], Double) -> Void)?
func hrID(_ n: Int) -> String { String(format: "00000000-0000-4000-8000-%012d", n) }
func hrSHA(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
func hrWrite(_ value: Any, _ url: URL) throws {
    try JSONSerialization.data(withJSONObject: value, options: [.prettyPrinted, .sortedKeys]).write(to: url)
}
let hrNow = ThreadTools.date("2026-01-01T12:00:00Z")
func hrPost(_ seq: Int, _ id: Int, _ employee: Int, _ thread: Int, _ text: String) -> [String: Any] {
    ["v":1,"type":"message","seq":seq,"msg_id":hrID(id),"employee":"fixture-\(employee)","thread":hrID(thread),
     "role":"employee","text":text,"files":[],"buttons":[],"reply_state":NSNull(),"ts":"2026-01-01T12:00:00Z"]
}
func hrWelcome(_ head: Int) -> [String: Any] {
    ["v":1,"type":"welcome","device_id":hrID(900001),"gate_version":"0.1.0","head_seq":head,
     "employees":(0..<8).map { ["id":"fixture-\($0)","name":"직원 \($0)","aliases":[]] as [String:Any] }]
}
func hrDone(_ seq: Int, head: Int? = nil, more: Bool = false) -> [String: Any] {
    ["v":1,"type":"sync_done","ref":"fixture","through":seq,"head_seq":head ?? seq,"more":more]
}
func hrInitial() -> [[String: Any]] {
    var result = [hrWelcome(800)]
    for employee in 0..<8 { for thread in 0..<25 { for post in 0..<4 {
        let seq = employee * 100 + thread * 4 + post + 1
        let text = thread % 4 == 0 ? "승인해줘" : thread % 4 == 1 ? "새 알림" : thread % 4 == 2 ? "완료한 작업" : "진행 내용"
        var frame = hrPost(seq, 10000 + seq, employee, 1 + employee * 25 + thread, text)
        if thread % 4 == 2 { frame["reply_state"] = "closed" }
        if thread % 4 == 3 && post == 0 { frame["role"] = "owner" }
        result.append(frame)
    } } }
    result.append(hrDone(800)); return result
}
func hrBacklog(_ n: Int) -> [[String: Any]] {
    var frames = [hrWelcome(800+n)]
    for i in 0..<n {
        let group = i / 5, seq = 801+i, id = 20000+group
        if i % 5 == 0 {
            frames.append(hrPost(seq,id,group % 8,1+(group % 8)*25+(group/8)%25,"밀린 글 \(group)"))
        } else {
            frames.append(["v":1,"type":"edit","seq":seq,"msg_id":hrID(id),"text":"밀린 글 \(group) · 편집 \(i % 5)","final":i % 5 == 4])
        }
    }
    frames.append(hrDone(800+n)); return frames
}
@MainActor func hrStore(_ directory: URL) throws -> LocalStore {
    let store = try LocalStore(directory:directory)
    let items = Dictionary(uniqueKeysWithValues:(0..<330).map { i in
        ("read:fixture-\(i % 8):\(hrID(1+i))", StateEntry(v:"0",at:1,dev:"fixture-device"))
    })
    try store.update { $0.stateDevice="fixture-device"; $0.memberStates=["":StateDocument(items:items)] }
    return store
}
@MainActor final class HRRig {
    let client: GateClient, controller: ConversationController
    let view: ConversationView, window: NSWindow
    var count = 0, shownApplied = -1, shownUnread = -1
    init(_ store: LocalStore) throws {
        client=GateClient(store:store,credentials:MemoryCredentials())
        controller=try testConversation(client:client); controller.stop();controller.clock={hrNow}
        // No renderer is connected while loading the common 800-record fixture.
        for frame in hrInitial() {
            if frame["seq"] != nil {try store.append(frame)}
            controller.receive(frame)
        }
        controller.model.select(ConversationKey(employee:"fixture-0",thread:hrID(1)))
        view=ConversationView(controller:controller,clipboardArea:store.directory.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{hrNow}))
        view.frame=CGRect(x:0,y:0,width:840,height:760);view.reduceMotion={true};view.motionTime={10}
        window=NSWindow(contentRect:view.frame,styleMask:[.titled],backing:.buffered,defer:false)
        window.contentView=view;window.orderFront(nil);view.layoutSubtreeIfNeeded()
        let redraw=controller.onChange
        controller.onChange={ [weak self] in
            redraw?();guard let self else{return};self.count+=1
            self.shownApplied=self.controller.model.applied;self.shownUnread=self.controller.model.visibleUnreadTotal
        }
    }
    func dispose() {controller.onChange=nil;controller.onRevealThread=nil;controller.stop();client.stop();window.contentView=nil;window.orderOut(nil)}
    func assertScreen(_ n: Int) throws {
        try check(controller.model.applied==800+n && shownApplied==800+n,"HR-01 head reflected before return")
        try check(shownUnread==controller.model.visibleUnreadTotal,"HR-01 sidebar unread reflects final model")
        // Select each employee and inspect actual cards/posts against the model after the boundary.
        for employee in 0..<8 {
            view.chooseEmployee("fixture-\(employee)")
            for group in 0..<(n/5) where group % 8 == employee {
                let key=ConversationKey(employee:"fixture-\(employee)",thread:hrID(1+employee*25+(group/8)%25))
                guard let card=view.history.contents.first(where:{$0.id==key.thread}) else {throw TestFailure.assertion("HR-01 missing final card")}
                let texts=(card.top+(card.replies ?? [])).compactMap { piece -> String? in if case .post(let post)=piece{return post.text.string};return nil }
                try check(texts.contains("밀린 글 \(group) · 편집 4"),"HR-01 actual card has final edit")
            }
        }
    }
}
@MainActor final class HRMeasurement {
    let rig: HRRig
    var began = 0.0, ended = 0.0, costs = [Double](), probes = [[String:Any]]()
    private var submitted = Set<Int>()
    init(_ rig: HRRig) {self.rig=rig}
    func returned(_ frame: [String:Any], start: Double) {
        let end=ProcessInfo.processInfo.systemUptime
        costs.append(end-start)
        let applied=rig.controller.model.applied
        if frame["type"] as? String == "welcome" {began=start}
        if frame["type"] as? String == "sync_done" {ended=end}
        let offset=applied-800
        guard [75,150,225].contains(offset),submitted.insert(offset).inserted else{return}
        let submittedAt=end
        DispatchQueue.main.async { [self] in
            let started=ProcessInfo.processInfo.systemUptime, before=rig.controller.model.applied
            if offset==150 {rig.view.chooseEmployee("fixture-1")}
            else {rig.view.editor.editor.insertText("x",replacementRange:NSRange(location:0,length:0))}
            probes.append(["offset":offset,"submitted_at":submittedAt,"submitted_applied":applied,"started_at":started,
                           "started_applied":before,"queue_seconds":started-submittedAt,"action_seconds":ProcessInfo.processInfo.systemUptime-started,
                           "effect":offset==150 ? rig.controller.model.selected?.employee=="fixture-1" : rig.controller.draft.text.contains("x")])
        }
    }
    func row(_ run: Int) -> [String:Any] {
        ["run":run,"warm_up":run==0,"wall_seconds":ended-began,"receive_seconds":costs,"receive_max":costs.max() ?? -1,
         "notifications":rig.count,"head":1100,"applied":rig.controller.model.applied,"probes":probes]
    }
}
@MainActor func hrSemantic(_ output: URL, home: URL) async throws {
    let rig=try HRRig(hrStore(home.appendingPathComponent("semantic")))
    defer {rig.dispose()}
    let client=rig.client, c=rig.controller, m=c.model
    var frames=hrBacklog(20);frames.removeLast()
    frames.append(["v":1,"type":"state","seq":821,"msg_id":hrID(20000),"reply_state":"closed"])
    frames.append(["v":1,"type":"delete","seq":822,"msg_id":hrID(20001)])
    frames.append(["v":1,"type":"room","seq":823,"room":["id":hrID(900002),"title":"시험 방","description":"","members":["fixture-0","fixture-1"],"lead":"fixture-0","archived":false]])
    frames[0]=hrWelcome(823);frames.append(hrDone(823))
    for frame in frames {try await client.receive(frame)}
    try await client.receive(hrPost(824,30000,2,51,"평상시 글"))
    c.setPaused(true)
    try await client.receive(hrPost(825,30001,3,76,"정지 중 글"))
    try await client.receive(["v":1,"type":"edit","seq":826,"msg_id":hrID(30001),"text":"정지 해제 최종","final":true])
    c.setPaused(false)
    rig.view.chooseEmployee("fixture-1")
    let selected=ConversationKey(employee:"fixture-1",thread:hrID(26));m.select(selected)
    c.setText("보존할 초안",for:selected)
    _=await c.sendText("가짜 연결 오류",key:selected) // disconnected: local failure path only
    let messages=m.messages.values.sorted{$0.seq<$1.seq}.map { item -> [String:Any] in
        ["id":item.id,"text":item.text,"seq":item.seq,"latest_seq":item.latestSeq,"role":item.role,"employee":item.key.employee,
         "thread":item.key.thread,"state":item.replyState as Any? ?? NSNull(),"finalized":item.finalized,"streaming":item.streaming]
    }
    let threads=(0..<200).map { i -> [String:Any] in
        let key=ConversationKey(employee:"fixture-\(i/25)",thread:hrID(i+1))
        return ["employee":key.employee,"thread":key.thread,"timeline":m.timeline(key).map(\.id),"unread":m.unread(key),
                "bell":m.bell(key) as Any? ?? NSNull(),"questions":m.notices(key.employee,now:hrNow).map(\.id),"draft":c.draft(for:key).text]
    }
    try hrWrite(["messages":messages,"threads":threads,"applied":m.applied,"stored":client.store.settings.applied,
                 "cache_sha256":hrSHA(Data(contentsOf:client.store.cacheURL)),"selected_employee":m.selected?.employee ?? "",
                 "selected_thread":m.selected?.thread ?? "","sending":c.sending,"failures":c.failures.map(\.reason),
                 "notice":c.notice,"transfer_failure":c.transferFailure?.message ?? "","groups":m.groups.keys.sorted()],output)
}
@MainActor func hejoReconnect(_ args: [String]) async throws {
    let output=URL(fileURLWithPath:args[2]), mode=args[3]
    guard let homeValue=ProcessInfo.processInfo.environment["HERMES_HOME"],FileManager.default.fileExists(atPath:homeValue+"/hejo-reconnect-isolated") else {throw TestFailure.assertion("isolated home required")}
    let home=URL(fileURLWithPath:homeValue)
    if mode=="semantic" {try await hrSemantic(output.appendingPathComponent("observed.json"),home:home);return}
    try hrWrite(["initial":hrInitial(),"backlog":hrBacklog(300)],output.appendingPathComponent("input.json"))
    if mode=="synthetic" {
        var counts=[[String:Any]](), rows=[[String:Any]]()
        for n in [20,100,300] {
            let rig=try HRRig(hrStore(home.appendingPathComponent("count-\(n)")))
            for frame in hrBacklog(n) {try await rig.client.receive(frame)}
            let count=rig.count;try rig.assertScreen(n);rig.dispose();counts.append(["n":n,"notifications":count])
        }
        try hrWrite(counts,output.appendingPathComponent("counts.json"))
        for run in 0...5 {
            let rig=try HRRig(hrStore(home.appendingPathComponent("run-\(run)"))), measurement: HRMeasurement
            measurement=HRMeasurement(rig)
            for frame in hrBacklog(300) {
                try await withCheckedThrowingContinuation { (done:CheckedContinuation<Void,Error>) in
                    DispatchQueue.main.async {
                        Task { @MainActor in
                            do {let start=ProcessInfo.processInfo.systemUptime;try await rig.client.receive(frame);measurement.returned(frame,start:start);done.resume()}
                            catch {done.resume(throwing:error)}
                        }
                    }
                }
            }
            try await waitFor {measurement.probes.count==3}
            rows.append(measurement.row(run));try rig.assertScreen(300);rig.dispose()
            try hrWrite(rows,output.appendingPathComponent("performance.json"))
            print("HR SYNTHETIC run=\(run) seconds=\(rows.last!["wall_seconds"]!)");fflush(stdout)
        }
    } else if mode=="socket" {
        var rows=[[String:Any]]()
        for run in 0...5 {
            let store=try hrStore(home.appendingPathComponent("socket-\(run)"))
            try store.select(address:args[4],device:"fixture-device")
            let rig=try HRRig(store), measurement=HRMeasurement(rig)
            var firstDone=false, reconnecting=false
            let forward=rig.client.onFrame
            rig.client.onFrame={frame in forward?(frame);if frame["type"] as? String=="sync_done",rig.client.connectionEpoch==1 {firstDone=true}}
            rig.client.onStatus={status in
                rig.controller.notifyChange()
                if firstDone,case .disconnected=status {reconnecting=true}
            }
            reconnectSocketReceived={frame,start in
                if rig.client.connectionEpoch>=2 {measurement.returned(frame,start:start)}
            }
            // Memory credentials only. The fake server closes the first socket after sync_done.
            try await rig.client.adopt(address:args[4],device:"fixture-device",token:"fixture-credential")
            try await waitFor(90) {measurement.ended>0}
            try await waitFor {measurement.probes.count==3}
            try check(firstDone && reconnecting && rig.client.connectionEpoch==2,"HR actual loop disconnected and reconnected")
            rows.append(measurement.row(run));try rig.assertScreen(300)
            reconnectSocketReceived=nil;rig.dispose()
            try hrWrite(rows,output.appendingPathComponent("socket-performance.json"))
            print("HR SOCKET run=\(run) seconds=\(rows.last!["wall_seconds"]!)");fflush(stdout)
        }
    }
}
