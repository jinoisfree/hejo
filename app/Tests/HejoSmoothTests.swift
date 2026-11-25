import AppKit
import CryptoKit

#if HEJO_PERF_TESTING
private func smoothUUID(_ value: Int) -> String { String(format: "00000000-0000-4000-8000-%012d", value) }
private func smoothThread(_ room: Int, _ thread: Int) -> ConversationKey {
    ConversationKey(employee: "fixture-\(room)", thread: smoothUUID(1 + room * 100 + thread))
}
private func smoothMessage(_ room: Int, _ thread: Int, _ post: Int) -> String {
    smoothUUID(10_001 + room * 400 + thread * 4 + post)
}
private func smoothWrite(_ value: Any, _ url: URL) throws {
    var data = try JSONSerialization.data(withJSONObject: value, options: [.sortedKeys, .prettyPrinted])
    data.append(10); try data.write(to: url, options: .atomic)
}
private func smoothFrames() -> [[String: Any]] {
    let now = Date(timeIntervalSince1970: 1_767_225_600), formatter = ISO8601DateFormatter()
    var result: [[String: Any]] = [["v": 1, "type": "welcome", "head_seq": 3200,
        "employees": (0..<8).map { ["id": "fixture-\($0)", "name": "시험 직원 \($0)", "aliases": []] as [String: Any] }]]
    for room in 0..<8 { for thread in 0..<100 { for post in 0..<4 {
        let length = [200, 800, 3000][thread % 3]
        let prefix = "시험 \(room)-\(thread)-\(post)\n- 목록 항목\n☐ 확인 항목\n```swift\nlet value = 42\n```\n[시험 링크](https://example.invalid/fixture)\n"
        let padding = String(repeating: "합성 문장으로 화면 배치를 확인합니다. ", count: length)
        let text = prefix + String(padding.prefix(length - prefix.count))
        let seq = 1 + room * 400 + thread * 4 + post
        result.append(["v": 1, "type": "message", "seq": seq, "msg_id": smoothMessage(room, thread, post),
            "employee": "fixture-\(room)", "thread": smoothThread(room, thread).thread,
            "role": post == 0 && thread % 2 == 0 ? "owner" : "employee", "text": text,
            "files": [], "buttons": [], "reply_state": "closed", "ts": formatter.string(from: now.addingTimeInterval(Double(seq)))])
    } } }
    result.append(["v": 1, "type": "sync_done", "through": 3200, "more": false])
    return result
}

@MainActor private final class SmoothFixture {
    let directory: URL, store: LocalStore, controller: ConversationController, view: ConversationView, window: NSWindow
    var sequence = 3200
    var time = 10.0
    init(_ frames: [[String: Any]]) throws {
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        store = try LocalStore(directory: directory)
        controller = try testConversation(client: GateClient(store: store, credentials: MemoryCredentials()))
        controller.stop(); controller.clock = { Date(timeIntervalSince1970: 1_767_232_800) }
        for frame in frames { if frame["seq"] is Int { try store.append(frame) }; controller.receive(frame) }
        sequence=controller.model.applied
        controller.model.select(smoothThread(0, 99), notify: false, markRead: false)
        view = ConversationView(controller: controller, clipboardArea: directory.appendingPathComponent("clipboard"),
            islandModel: IslandModel(clock: { Date(timeIntervalSince1970: 1_767_232_800) }))
        window = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 840, height: 760), styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view; view.frame = CGRect(x: 0, y: 0, width: 840, height: 760)
        view.reduceMotion = { true }; view.motionTime = { [weak self] in self?.time ?? 10 }
        view.history.automaticallyTicks = false; view.history.clock = { [weak self] in self?.time ?? 10 }
        view.chooseEmployee("fixture-0"); layout()
    }
    func layout() { view.layoutSubtreeIfNeeded(); view.history.layoutSubtreeIfNeeded() }
    func edit(_ id: String, _ text: String, final: Bool) throws {
        sequence += 1
        let frame: [String: Any] = ["v": 1, "type": "edit", "seq": sequence, "msg_id": id, "text": text, "final": final]
        try store.append(frame); controller.receive(frame); layout()
    }
    func dispose() {
        controller.onChange = nil; controller.onRevealThread = nil; controller.stop(); controller.client.stop()
        view.removeFromSuperview(); window.contentView = nil; window.orderOut(nil)
        try? FileManager.default.removeItem(at: directory)
    }
}
@MainActor private func smoothPosts(_ view: ConversationView) -> [NativeThreadCard.Post] {
    view.history.contents.flatMap { $0.top + ($0.replies ?? []) }.compactMap { if case .post(let post) = $0 { return post }; return nil }
}
@MainActor private func smoothPile(_ view: ConversationView, thread: String) throws -> () -> Void {
    guard let card = view.history.contents.first(where: { $0.id == thread }) else { throw TestFailure.assertion("SM missing thread") }
    for piece in card.top + (card.replies ?? []) { if case .stack(_, _, let toggle, _) = piece { return toggle } }
    if let action = card.actions.first(where: { $0.identifier == "fold-" + thread }) { return action.invoke }
    throw TestFailure.assertion("SM missing pile action")
}

/// Same workload, actual AppKit handlers and synchronous layout; independent stores for all six runs.
@MainActor private func smoothMeasure(_ frames: [[String: Any]], output: URL, paired: Bool = false) throws -> [[String: Any]] {
    var runs: [[String: Any]] = []
    func cpuTime() -> Double {
        var stamp = timespec()
        precondition(clock_gettime(CLOCK_THREAD_CPUTIME_ID, &stamp) == 0)
        return Double(stamp.tv_sec) + Double(stamp.tv_nsec) / 1_000_000_000
    }
    for run in 0...(paired ? 1 : 5) {
        print("SM_STAGE measurement run=\(run)"); fflush(stdout)
        let f = try SmoothFixture(frames); defer { f.dispose() }
        var times: [String: Double] = [:], cpu: [String: Double] = [:], counters: [String: Any] = [:]
        func measure(_ name: String, _ action: () throws -> Void) rethrows {
            HejoSmoothProbe.reset()
            let startCPU = paired ? cpuTime() : 0
            let start = ProcessInfo.processInfo.systemUptime
            try action(); f.layout()
            times[name] = ProcessInfo.processInfo.systemUptime - start
            if paired { cpu[name] = cpuTime() - startCPU }
            counters[name] = ["bodies": HejoSmoothProbe.bodies, "heights": HejoSmoothProbe.heights, "refreshes": HejoSmoothProbe.refreshes, "assessments": HejoSmoothProbe.assessments, "calendars": HejoSmoothProbe.calendars, "thinking":HejoSmoothProbe.thinking, "times":HejoSmoothProbe.times, "phases": HejoSmoothProbe.phases,"date_derivations":HejoSmoothProbe.dates,"member_merges":HejoSmoothProbe.memberMerges,"assessment_inputs":HejoSmoothProbe.assessmentInputs]
        }
        measure("select") { f.view.chooseThread(smoothThread(0, 95)) }
        try measure("pile_open") { try smoothPile(f.view, thread: smoothThread(0, 94).thread)() }
        try measure("pile_close") { try smoothPile(f.view, thread: smoothThread(0, 94).thread)() }
        measure("new_post") { f.view.createThread() }
        f.view.chooseEmployee("fixture-1"); f.layout()
        measure("room_revisit") { f.view.chooseEmployee("fixture-0") }
        measure("room_first") { f.view.chooseEmployee("fixture-2") }
        f.view.chooseEmployee("fixture-0"); f.layout()
        try measure("receive") { try f.edit(smoothMessage(0, 99, 3), String(repeating: "흘러오는 합성 답변 ", count: 40), final: false) }
        measure("notification_prepare") {
            f.view.performUpdates { f.view.openFromBubble(smoothThread(0, 60)); f.controller.model.setVisible(true) }
        }
        f.view.chooseEmployee("fixture-0"); f.layout()
        var scroll: [Double] = []
        f.view.history.enter(nil)
        var y = f.view.history.contentView.bounds.minY
        while y > 0 {
            y = max(0, y - 60)
            let start = ProcessInfo.processInfo.systemUptime
            f.view.history.readerInput(wheel: true)
            f.view.history.contentView.scroll(to: CGPoint(x: 0, y: y)); f.view.history.reflectScrolledClipView(f.view.history.contentView)
            f.layout(); f.view.history.displayIfNeeded()
            scroll.append(ProcessInfo.processInfo.systemUptime - start)
        }
        var observation: [String: Any] = ["run": run, "warm_up": run == 0, "seconds": times,
                                          "counts": counters, "scroll_seconds": scroll]
        if paired { observation["cpu_seconds"] = cpu }
        runs.append(observation)
        try smoothWrite(runs, output.appendingPathComponent("performance.json"))
    }
    return runs
}

/// AT-SM-03 observes actual rendered prefixes and every explicitly clocked follow position.
@MainActor private func smoothStream(_ frames: [[String: Any]], output: URL, checking: Bool) throws {
    let f = try SmoothFixture(frames); defer { f.dispose() }
    f.view.reduceMotion = { false }; f.view.history.reduceMotion = { false }
    f.view.history.enter(nil); f.view.history.readerInput(wheel: false)
    let id = smoothMessage(0, 99, 3)
    var observations: [[String: Any]] = []
    for frame in 0..<4 {
        HejoSmoothProbe.reset()
        try f.edit(id, String(repeating: "합성 스트리밍 답변 \(frame)\n", count: 8 + frame * 8), final: frame == 3)
        for tick in 0..<31 {
            if tick > 0 { f.time += 1.0 / 30; HejoSmoothProbe.reset(); f.view.refresh(); f.layout() }
            if checking {
                try check(HejoSmoothProbe.bodies.keys.allSatisfy { $0 == id } && HejoSmoothProbe.heights.keys.allSatisfy { $0 == id }, "AT-SM-03 unchanged post rebuilt")
            }
            f.view.history.advanceFollow()
            let text = smoothPosts(f.view).first { $0.id == id }?.text.string ?? "<missing>"
            observations.append(["frame": frame, "tick": tick, "text": text, "y": Double(f.view.history.contentView.bounds.minY)])
        }
    }
    if checking {
        f.time += 4; f.view.refresh(); f.layout()
        let expected = String(repeating:"합성 스트리밍 답변 3\n",count:32).trimmingCharacters(in:.newlines)
        try check(smoothPosts(f.view).first{$0.id==id}?.text.string==expected,"AT-SM-03 completed final body")
    }
    for _ in 0..<120 { f.time += 1.0 / 60; f.view.history.advanceFollow() }
    let gap = f.view.history.table.bounds.maxY - f.view.history.contentView.bounds.maxY
    try check(abs(gap) < 1, "AT-SM-03 settled follow reaches bottom")
    try smoothWrite(["observations": observations, "settled_gap": Double(gap)], output.appendingPathComponent("stream.json"))
}

/// AT-SM-04/06: real PetController snapshot order, actual run loop and all transition timestamps.
@MainActor private func smoothTransitions(_ frames: [[String: Any]], output: URL, resources: URL, checking: Bool, screenSample: Int? = nil) async throws {
    var results: [[String: Any]] = []
    for run in screenSample.map({ [0, $0] }) ?? Array(0...5) {
        print("SM_STAGE transition run=\(run)"); fflush(stdout)
        let f = try SmoothFixture(frames)
        let pet = PetController(store: f.store, atlas: try SpriteAtlas(resourceDirectory: resources))
        if screenSample != nil {
            guard let screen = NSScreen.main else { throw TestFailure.assertion("S3 requires a real AppKit screen") }
            pet.placePet(at: CGPoint(x: screen.visibleFrame.midX, y: screen.visibleFrame.midY))
            pet.show()
            try check(pet.panel.isVisible && pet.panel.screen != nil,"S3 panel must attach to a real display")
        } else {
            pet.displays = { [PetDisplay(frame: CGRect(x: 0, y: 0, width: 2400, height: 2200), visible: CGRect(x: 0, y: 40, width: 2400, height: 2100))] }
        }
        pet.preferredChatSize = CGSize(width: 840, height: 760)
        pet.pet.installConversation(f.view); pet.installDrawer(f.view)
        pet.onExpansionChanged = { f.controller.model.setVisible($0) }
        pet.reducedMotion = { false }; f.view.reduceMotion = { true }; f.view.history.reduceMotion = { false }
        f.view.history.clock = { ProcessInfo.processInfo.systemUptime }
        let target = smoothThread(run == 2 ? 1 : 0, run == 4 ? 10 : run == 3 ? 99 : 60)
        if run == 1 { f.view.chooseHome(); f.controller.model.select(target, notify: false, inHome: true, markRead: false) }
        var snapshotY = Double.nan, snapshotExpected = Double.nan, before = 0, duringRefresh = 0, duringScroll = 0
        HejoSmoothProbe.snapshot = {
            f.layout(); snapshotY = Double(f.view.history.contentView.bounds.minY)
            if let rect = f.view.history.frame(for: target.thread) {
                snapshotExpected = Double(min(max(0, rect.midY - f.view.history.contentView.bounds.height / 2), max(0, f.view.history.table.bounds.height - f.view.history.contentView.bounds.height)))
            }
        }
        var activity: NSObjectProtocol?
        defer { if let activity { ProcessInfo.processInfo.endActivity(activity) } }
        HejoSmoothProbe.transitionPath = ""
        HejoSmoothProbe.started = {
            before = HejoSmoothProbe.refreshes
            HejoSmoothProbe.reset()
            if screenSample != nil && ProcessInfo.processInfo.environment["HEJO_S3_LATENCY"] == "1" {
                activity = ProcessInfo.processInfo.beginActivity(options: [.latencyCritical,.userInitiated],
                                                                reason: "Hejo transition timing control")
            }
        }
        HejoSmoothProbe.reset()
        HejoSmoothProbe.events=[]
        let observer=HejoSmoothProbe.profiling ? CFRunLoopObserverCreateWithHandler(nil,CFRunLoopActivity.allActivities.rawValue,true,0) {_,activity in
            HejoSmoothProbe.event("runloop_\(activity.rawValue)",ProcessInfo.processInfo.systemUptime)
        }:nil
        if let observer {CFRunLoopAddObserver(CFRunLoopGetMain(),observer,.commonModes)}
        if HejoSmoothProbe.profiling {print("SM_PROFILE_ACTIVE run=\(run)");fflush(stdout)}
        pet.showChat { f.view.openFromBubble(target) }
        let deadline = ProcessInfo.processInfo.systemUptime + 1
        while HejoSmoothProbe.transitionEnd == nil && ProcessInfo.processInfo.systemUptime < deadline { await pause(0.005) }
        if let observer {CFRunLoopRemoveObserver(CFRunLoopGetMain(),observer,.commonModes)}
        if HejoSmoothProbe.profiling {try smoothWrite(HejoSmoothProbe.events,output.appendingPathComponent("profile-\(run).json"))}
        if let token = activity { ProcessInfo.processInfo.endActivity(token); activity = nil }
        duringRefresh = HejoSmoothProbe.refreshes; duringScroll = HejoSmoothProbe.scrollStarts
        let start = HejoSmoothProbe.transitionStart, steps = HejoSmoothProbe.transitionSteps, end = HejoSmoothProbe.transitionEnd
        await pause(0.8)
        let finalY = Double(f.view.history.contentView.bounds.minY)
        let gaps = zip([start ?? .nan] + steps, steps).map { $1 - $0 }
        let valid = start != nil && end != nil && steps.count >= 6 && gaps.count == steps.count && gaps.allSatisfy { $0 >= 0 && $0 <= 0.050 } && end! - start! <= 0.350
        let placement = snapshotY.isFinite && snapshotExpected.isFinite && abs(snapshotY - snapshotExpected) < 1
        results.append(["run": run, "warm_up": run == 0, "start": start as Any? ?? NSNull(), "steps": steps, "end": end as Any? ?? NSNull(), "gaps": gaps,
            "path": HejoSmoothProbe.transitionPath, "real_screen": screenSample != nil && pet.panel.screen != nil,
            "frame_pass": valid, "snapshot_y": snapshotY.isFinite ? snapshotY : -1, "expected_y": snapshotExpected.isFinite ? snapshotExpected : -1,
            "final_y": finalY, "placement_pass": placement, "before_refreshes": before, "during_refreshes": duringRefresh, "during_scroll_starts": duringScroll])
        try smoothWrite(results, output.appendingPathComponent("transitions.json"))
        HejoSmoothProbe.snapshot = nil; HejoSmoothProbe.started = nil
        disposeDrawerFixture(pet, f.controller, f.view); f.dispose()
        // Preserve all five samples even when one fails; the runner rejects every failed sample.

    }
}

@MainActor private func smoothTransitionBoundaries(_ frames:[[String:Any]],output:URL,resources:URL) async throws {
    let f=try SmoothFixture(frames)
    let pet=PetController(store:f.store,atlas:try SpriteAtlas(resourceDirectory:resources))
    defer{disposeDrawerFixture(pet,f.controller,f.view);f.dispose()}
    pet.displays={ [PetDisplay(frame:CGRect(x:0,y:0,width:2400,height:2200),visible:CGRect(x:0,y:40,width:2400,height:2100))] }
    pet.preferredChatSize=CGSize(width:840,height:760);pet.pet.installConversation(f.view);pet.installDrawer(f.view)
    pet.onExpansionChanged={f.controller.model.setVisible($0)}
    pet.reducedMotion={false};f.view.reduceMotion={true};f.view.history.reduceMotion={false}
    f.view.history.clock={ProcessInfo.processInfo.systemUptime}
    pet.showChat{f.view.openFromBubble(smoothThread(0,99))}
    await pause(0.05)
    let before=HejoSmoothProbe.refreshes
    let id=smoothMessage(0,99,3),text="전환 중 수신한 합성 답변"
    try f.edit(id,text,final:true)
    let received=HejoSmoothProbe.refreshes-before
    try check(received>0 && smoothPosts(f.view).first{$0.id==id}?.text.string==text,"AT-SM-04 actual receive remains visible during transition")
    await waitForTransition(pet,progress:1);await pause(0.5)
    HejoSmoothProbe.reset()
    pet.showChat{f.view.openFromBubble(smoothThread(0,60))}
    await pause(0.03)
    let openScrolls=HejoSmoothProbe.scrollStarts
    try check(openScrolls>0,"AT-SM-04 already-open scroll remains animated")
    await pause(0.8)
    pet.reducedMotion={true};f.view.history.reduceMotion={true}
    pet.collapseChat();HejoSmoothProbe.reset()
    let target=smoothThread(1,60)
    pet.showChat{f.view.openFromBubble(target)};f.layout()
    let rect=f.view.history.frame(for:target.thread)!
    let expected=min(max(0,rect.midY-f.view.history.contentView.bounds.height/2),max(0,f.view.history.table.bounds.height-f.view.history.contentView.bounds.height))
    let difference=abs(f.view.history.contentView.bounds.minY-expected)
    try check(difference<1 && HejoSmoothProbe.scrollStarts==0,"AT-SM-04 reduced motion immediate placement")
    try smoothWrite(["receive_refreshes":received,"received_text":text,"already_open_scrolls":openScrolls,"reduced_position_difference":Double(difference),"pass":true],output.appendingPathComponent("transition-boundaries.json"))
}

/// AT-SM-01: calls and counts are the contract; unchanged visible posts must do no text work.
@MainActor private func smoothReuse(_ frames: [[String: Any]]) throws {
    let f = try SmoothFixture(frames); defer { f.dispose() }
    var seen = Set(smoothPosts(f.view).map(\.id))
    func action(_ name: String, _ run: () throws -> Void) throws {
        HejoSmoothProbe.reset(); try run(); f.layout()
        try check(HejoSmoothProbe.bodies.allSatisfy { !seen.contains($0.key) && $0.value <= 1 }, "AT-SM-01 formatting " + name)
        try check(HejoSmoothProbe.heights.allSatisfy { !seen.contains($0.key) && $0.value <= 1 }, "AT-SM-01 measuring " + name)
        seen.formUnion(smoothPosts(f.view).map(\.id))
    }
    try action("same") { f.view.refresh() }
    try action("select/open") { f.view.chooseThread(smoothThread(0, 95)) }
    try action("fold") { f.view.chooseThread(smoothThread(0, 95)) }
    try action("new post") { f.view.createThread() }
    try action("other thread") { f.view.chooseThread(smoothThread(0, 94)) }
    print("AT-SM-01 PASS")
}

/// Decoration is an NSObject with identity equality. Compare every stored rendering field instead.
private func smoothAttributedEqual(_ left: NSAttributedString, _ right: NSAttributedString) -> Bool {
    func values(_ source: NSAttributedString) -> NSAttributedString {
        let result=NSMutableAttributedString(attributedString:source)
        source.enumerateAttribute(TextLayout.decoration,in:NSRange(location:0,length:source.length)) { value,range,_ in
            if let decoration=value as? TextLayout.Decoration {
                let quotes=decoration.quotes.map{["run":$0.run,"color":$0.color] as [String:Any]}
                result.addAttribute(TextLayout.decoration,value:["box":decoration.box ?? -1,"quotes":quotes] as NSDictionary,range:range)
            }
        }
        return result
    }
    return values(left).isEqual(to:values(right))
}

@MainActor private func smoothCompare(_ f:SmoothFixture,_ label:String) throws {
        f.view.refresh(); f.layout()
        let onChange=f.controller.onChange,onReveal=f.controller.onRevealThread,key=f.controller.model.selected,home=f.controller.model.isHome,compose=f.controller.composeKey
        let fresh=ConversationView(controller:f.controller,clipboardArea:f.directory.appendingPathComponent("reference"),islandModel:IslandModel(clock:{Date(timeIntervalSince1970:1_767_232_800)}))
        defer { f.controller.onChange=onChange;f.controller.onRevealThread=onReveal }
        let window=NSWindow(contentRect:f.view.frame,styleMask:[.titled],backing:.buffered,defer:false)
        window.contentView=fresh;fresh.frame=f.view.frame;fresh.appearance=f.view.appearance
        defer {window.contentView=nil;window.orderOut(nil)}
        fresh.smoothCopyInputs(from:f.view)
        if let key {f.controller.model.select(key,notify:false,inHome:home,markRead:false)}
        f.controller.composeKey=compose
        fresh.refresh();fresh.layoutSubtreeIfNeeded();fresh.history.layoutSubtreeIfNeeded()
        let a=f.view.history.layouts,b=fresh.history.layouts
        try check(a.map{$0.content.id}==b.map{$0.content.id},"AT-SM-02 card IDs " + label)
        for (left,right) in zip(a,b) {
            try check(left.height==right.height && left.placed.count==right.placed.count,"AT-SM-02 card height " + label + left.content.id)
            for (x,y) in zip(left.placed,right.placed) {
                try check(x.frame==y.frame && x.text==y.text,"AT-SM-02 post position " + label + left.content.id)
                if case .post(let first)=x.piece,case .post(let second)=y.piece {
                    try check(first.id==second.id && first.mine==second.mine && first.pending==second.pending && first.streaming==second.streaming && first.time==second.time && first.speaker==second.speaker && first.foldTitle==second.foldTitle && first.nameColor==second.nameColor && smoothAttributedEqual(first.text,second.text),"AT-SM-02 body/attributes " + label + first.id)
                }
            }
        }
    }

/// AT-SM-02: new View, empty body cache, same model and presentation inputs; compare actual layouts.
@MainActor private func smoothInvalidation(_ frames: [[String: Any]]) async throws {
    let f = try SmoothFixture(frames); defer { f.dispose(); ChatAppearance.bind(nil) }
    ChatAppearance.bind(f.store)
    func compare(_ label:String)throws {try smoothCompare(f,label)}
    let id=smoothMessage(0,99,3)
    try f.edit(id,"☐ 바꾼 글\n"+String(repeating:"긴 합성 답글\n",count:35),final:true);try compare("edit")
    if let post=smoothPosts(f.view).first(where:{$0.id==id}),post.foldTitle != nil {post.fold();try compare("long unfold")}
    if let post=smoothPosts(f.view).first(where:{$0.id==id}),post.foldTitle != nil {post.fold();try compare("long fold")}
    for i in 1...3 {try f.edit(id,"☐ 수신 \(i)\n"+String(repeating:"단계별 합성 답변\n",count:10*i),final:false);try compare("stream \(i)")}
    try f.edit(id,"☐ 최종 합성 답변\n**완료**",final:true);try compare("stream completion")
    if let post=smoothPosts(f.view).first(where:{$0.id==id}),let url=post.text.attribute(.link,at:0,effectiveRange:nil) as? URL {post.openLink(url)}
    try compare("check toggle")
    for query in ["합성","최종",""] {
        f.view.openSearch();f.view.search.stringValue=query
        if let message=f.controller.model.messages[id] {f.view.revealHistorySearch(message.key,id:message.id)}
        try compare("search " + query)
    }
    _=f.view.closeSearchIfOpen();f.view.chooseEmployee("fixture-0")
    for dark in [true,false] {f.view.appearance=NSAppearance(named:dark ? .darkAqua:.aqua);try compare("theme")}
    try ChatAppearance.change(fontSize:18);try compare("font")
    try ChatAppearance.change(color:.green);try compare("bubble palette")
    try ChatAppearance.change(fontSize:14,color:.blue)
    for width in [CGFloat(600),840] {f.window.setContentSize(CGSize(width:width,height:760));f.view.frame.size.width=width;try compare("width")}
    var roster=(0..<8).map{["id":"fixture-\($0)","name":"시험 직원 \($0)","aliases":[],"color":$0==0 ? "#cc3344":"#3366aa"] as [String:Any]}
    f.controller.receive(["type":"roster","employees":roster]);try compare("sender color")
    f.view.chooseEmployee("fixture-1");try compare("other room")
    f.view.chooseEmployee("fixture-0");try compare("return room")
    try f.edit(id,"같은 식별자의 다른 본문",final:true);try compare("same id")
    f.sequence+=1;let deletion:[String:Any]=["v":1,"type":"delete","seq":f.sequence,"msg_id":id]
    try f.store.append(deletion);f.controller.receive(deletion);try compare("delete")
    _=try await f.controller.client.receive(frames[0])
    _=try await f.controller.client.receive(["v":1,"type":"sync_done","through":f.store.settings.applied,"more":false])
    f.view.chooseEmployee("fixture-0");f.layout()
    let before=f.view.history.contents.filter{!$0.id.hasPrefix("line:")}.count
    var clicked=false
    if let older=f.view.history.contents.first(where:{$0.id=="line:older"}) {
        for piece in older.top {if case .accessory(_,_,let make)=piece,let button=homeDescendants(make(),FileChip.self).first {
            try check(button.isEnabled,"AT-SM-02 older control enabled");button.invoke?();clicked=true
        }}
    }
    f.layout()
    try check(clicked && f.view.history.contents.filter{!$0.id.hasPrefix("line:")}.count>before,"AT-SM-02 actual older button expands window")
    try compare("older button")
    for room in 0..<8 {f.view.chooseEmployee("fixture-\(room)");try compare("capacity room \(room)")}
    try check(f.view.smoothBodyCacheCount<=ConversationView.smoothBodyCacheCapacity && NativeThreadCard.smoothMeasurementCount<=NativeThreadCard.smoothMeasurementCapacity,"AT-SM-02 cache capacities")
    // Populate the actual optimistic dictionary, then deliver its acknowledgement; no send API/socket.
    f.view.chooseEmployee("fixture-7");f.view.openFromBubble(smoothThread(7,99))
    let pendingID=f.controller.smoothStagePending(smoothThread(7,99),text:"무송신 합성 전이 카드")
    try check(smoothPosts(f.view).contains{$0.pending},"AT-SM-02 actual pending card exists")
    try compare("pending whole card")
    f.sequence+=1
    let ack:[String:Any]=["v":1,"type":"message","seq":f.sequence,"msg_id":smoothUUID(990002),"client_msg_id":pendingID,"employee":"fixture-7","thread":smoothThread(7,99).thread,"role":"owner","text":"무송신 합성 전이 카드","files":[],"buttons":[],"ts":"2026-01-01T02:00:00Z"]
    try f.store.append(ack);f.controller.receive(ack);f.layout()
    try check(!smoothPosts(f.view).contains{$0.pending} && smoothPosts(f.view).contains{$0.id==smoothUUID(990002)},"AT-SM-02 actual ack replaces pending card")
    try compare("ack whole card")
    for count in [0,1] {
        let small=[frames[0]]+Array(frames.dropFirst().prefix(count))
        let tiny=try SmoothFixture(small);defer{tiny.dispose()}
        tiny.view.chooseEmployee("fixture-0");try smoothCompare(tiny,"small room \(count)")
    }
    roster.removeAll()
    print("AT-SM-02 PASS")
}

/// Independent replay plus direct pure-function references, including full returned messages.
@MainActor private func smoothDerived(_ frames:[[String:Any]],output:URL) throws {
    let f=try SmoothFixture(frames);defer{f.dispose()}
    HejoSmoothProbe.reset();f.view.refresh();f.layout()
    try check(HejoSmoothProbe.assessments.isEmpty && HejoSmoothProbe.calendars.isEmpty,"AT-SM-10 unchanged derivations")
    let key=smoothThread(0,99),id=smoothUUID(990001)
    f.sequence+=1
    let added:[String:Any]=["v":1,"type":"message","seq":f.sequence,"msg_id":id,"employee":key.employee,"thread":key.thread,"role":"employee","text":"승인해 주세요. 내일 시험 일정","files":[],"buttons":[],"ts":"2026-01-01T12:00:00Z"]
    HejoSmoothProbe.reset();try f.store.append(added);f.controller.receive(added);f.layout()
    try check(HejoSmoothProbe.assessments==[key.readKey:1] && HejoSmoothProbe.calendars==[id:1],"AT-SM-10 one changed thread/post")
    // Smaller boundary sequence, independent stores and Views; original workload remains frozen.
    let seed=[frames[0]]+Array(frames.dropFirst().prefix(4))
    let live=try SmoothFixture(seed);defer{live.dispose()}
    var operations:[(SmoothFixture)throws->Void]=[],labels:[String]=[]
    func same(_ a:ThreadAssessment.Result,_ b:ThreadAssessment.Result)->Bool {
        a.request==b.request && a.pending==b.pending && a.buttons==b.buttons && a.working==b.working && a.settled==b.settled && a.approved==b.approved && a.color==b.color
    }
    func observe(_ a:SmoothFixture,_ b:SmoothFixture,_ label:String)throws {
        a.view.refresh();a.layout();b.view.refresh();b.layout()
        let x=a.controller.model,y=b.controller.model
        try check(x.sidebar.items==y.sidebar.items,"AT-SM-10 sidebar "+label)
        try check(x.sidebar.rows.map{$0.stableID}==y.sidebar.rows.map{$0.stableID},"AT-SM-10 row order "+label)
        for room in x.rooms.map(\.id)+[HomeRoom.id] {
            try check(x.notices(room)==y.notices(room),"AT-SM-10 notices "+label+room)
            for thread in x.threads(employee:room) {
                let lines=y.timeline(thread.key),direct=ThreadAssessment.assess(lines,confirmed:Set(lines.filter{y.confirmed($0.id)}.map(\.id)))
                try check(same(x.assessment(thread.key),direct) && same(x.assessment(thread.key),y.assessment(thread.key)),"AT-SM-10 assessment "+label+thread.key.readKey)
                try check(x.bell(thread.key)==y.bell(thread.key),"AT-SM-10 bell "+label)
            }
        }
        for message in x.messages.values {
            let reference=y.messages[message.id]!
            try check(x.date(message.timestamp)==ThreadTools.date(reference.timestamp),"AT-SM-10 parsed date "+label+message.id)
            try check(x.thinking(message)==ThreadTools.thinking(reference.text),"AT-SM-10 thinking "+label+message.id)
            let direct:[BubbleReveal.Action]=reference.role=="owner" || reference.pending ? []:BubbleReveal.Action.content(reference.text,events:b.controller.calendarEvents,at:ThreadTools.date(reference.timestamp)).filter(\.isCalendar)
            try check(a.controller.calendarActions(for:message)==direct && a.controller.calendarActions(for:message)==b.controller.calendarActions(for:reference),"AT-SM-10 calendar "+label+message.id)
        }
        for post in smoothPosts(a.view) {
            guard let message=x.messages[post.id] else{continue}
            let parser=ISO8601DateFormatter();parser.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
            let stamp=parser.date(from:message.timestamp) ?? ISO8601DateFormatter().date(from:message.timestamp)
            let expected=message.pending ? "보내는 중":stamp.map{DateFormatter.localizedString(from:$0,dateStyle:.none,timeStyle:.short)} ?? ""
            try check(post.time==expected,"AT-SM-10 display time "+label+message.id)
        }
        try check(a.controller.drawerSnapshot.counts==b.controller.drawerSnapshot.counts,"AT-SM-10 drawer "+label)
    }
    func step(_ label:String,_ operation:@escaping(SmoothFixture)throws->Void)throws {
        operations.append(operation);try operation(live)
        let fresh=try SmoothFixture(seed);defer{fresh.dispose()}
        fresh.controller.onChange=nil
        for op in operations {try op(fresh)}
        try observe(live,fresh,label);labels.append(label)
    }
    func frame(_ label:String,_ fields:[String:Any])throws {
        try step(label){fixture in fixture.sequence+=1;var value=fields;value["v"]=1;value["seq"]=fixture.sequence;try fixture.store.append(value);fixture.controller.receive(value)}
    }
    let post=smoothMessage(0,0,3),root=smoothMessage(0,0,0)
    try step("empty room"){$0.view.chooseEmployee("fixture-7")}
    try step("return"){$0.view.chooseEmployee("fixture-0")}
    try frame("thinking prefix",["type":"edit","msg_id":post,"text":"◐ 생각 중…\n합성 단계","final":false])
    try frame("stream",["type":"edit","msg_id":post,"text":"승인해 주세요. 내일 시험 일정","final":false])
    try frame("final/buttons/checklist",["type":"edit","msg_id":post,"text":"승인해 주세요. 내일 시험 일정","final":true,"buttons":[["id":"approve","label":"승인","kind":"approve","style":"normal"]],"checklist":["items":["합성"],"selected":[],"can_skip":true]])
    try frame("state answered",["type":"state","msg_id":post,"reply_state":"answered"])
    try frame("state open",["type":"state","msg_id":post,"reply_state":"open"])
    try frame("owner button answer",["type":"message","msg_id":smoothUUID(990003),"employee":"fixture-0","thread":smoothThread(0,0).thread,"role":"owner","text":"승인","answer_to":post,"files":[],"buttons":[],"ts":"2026-01-01T01:00:00Z"])
    try frame("group create",["type":"room","room":["id":"fixture-group","title":"합성 방","members":["fixture-0"],"lead":"fixture-0"]])
    try frame("group archive",["type":"room","room":["id":"fixture-group","title":"합성 방","members":["fixture-0"],"lead":"fixture-0","archived":true]])
    try step("confirm"){try $0.controller.model.memberState.set(["confirm:"+post:"1"])}
    try step("unconfirm"){try $0.controller.model.memberState.set(["confirm:"+post:nil])}
    try step("read"){$0.controller.model.markNoticeRead(smoothThread(0,0))}
    try step("mute"){$0.controller.model.toggleMute("fixture-0")}
    let date=ThreadTools.date("2026-01-02T12:00:00Z")
    let event=CalendarEntry(identifier:"fixture-event",calendarID:"fixture-calendar",title:"시험 일정",start:date,end:date.addingTimeInterval(3600))
    try step("calendar add"){$0.controller.calendarEvents=[event]}
    try step("calendar change"){var value=event;value.title="다른 시험 일정";$0.controller.calendarEvents=[value]}
    try step("calendar delete"){$0.controller.calendarEvents=[]}
    for delta in [-1.0,86399,86400,86401] {
        try step("time \(delta)"){fixture in fixture.controller.clock={ThreadTools.date("2026-01-01T00:00:01Z").addingTimeInterval(delta)}}
    }
    try frame("delete",["type":"delete","msg_id":post])
    try frame("same id new content",["type":"message","msg_id":post,"employee":"fixture-0","thread":smoothThread(0,0).thread,"role":"employee","text":"새 내용","files":[],"buttons":[],"ts":"2026-01-01T02:00:01Z"])
    try frame("same id timestamp update",["type":"message","msg_id":post,"employee":"fixture-0","thread":smoothThread(0,0).thread,"role":"employee","text":"바뀐 본문과 시각","files":[],"buttons":[],"ts":"2026-01-01T03:00:01Z"])
    try step("roster"){$0.controller.receive(["type":"roster","employees":[["id":"fixture-0","name":"바뀐 시험 직원","aliases":[]]]])}
    try frame("delete thread",["type":"delete","scope":"thread","room":"fixture-0","thread":smoothThread(0,0).thread])
    try check(live.controller.model.timeline(smoothThread(0,0)).isEmpty,"AT-SM-10 delete to empty")
    try step("duplicate/reconnect replay"){fixture in
        fixture.controller.receive(seed[0])
        for value in seed.dropFirst() {fixture.controller.receive(value)}
        fixture.controller.receive(["type":"sync_done","through":fixture.controller.model.applied,"more":false])
    }
    _=root
    for room in 0..<8 {f.view.chooseEmployee("fixture-\(room)");f.layout()}
    for thread in 0..<100 {f.sequence+=1;f.controller.receive(["type":"delete","seq":f.sequence,"scope":"thread","room":"fixture-0","thread":smoothThread(0,thread).thread])}
    try check(f.controller.model.smoothAssessmentKeys.count<=f.controller.model.smoothAssessmentCapacity && !f.controller.model.smoothAssessmentKeys.contains{$0.employee=="fixture-0"},"AT-SM-10 assessment removal/cap")
    try check(f.controller.model.smoothThinkingKeys.count<=f.controller.model.smoothThinkingCapacity && f.controller.model.smoothThinkingKeys.allSatisfy{f.controller.model.messages[$0] != nil},"AT-SM-10 thinking removal/cap")
    try check(f.controller.smoothCalendarKeys.count<=f.controller.smoothCalendarCapacity && f.controller.smoothCalendarKeys.allSatisfy{f.controller.model.messages[$0] != nil},"AT-SM-10 calendar removal/cap")
    // An actual alert (no owner root/request) must change at the exact 24-hour boundary.
    var alert=frames[1];alert["role"]="employee";alert["text"]="합성 새 소식";alert["reply_state"]=NSNull()
    var alertEdges:[[String:Any]]=[]
    for delta in [-1.0,86399,86400,86401] {
        let edge=try SmoothFixture([frames[0],alert]);defer{edge.dispose()}
        let stamp=ThreadTools.date(alert["ts"] as! String)
        edge.controller.clock={stamp.addingTimeInterval(delta)}
        let present=edge.controller.model.notices("fixture-0").filter{!$0.questions}.flatMap(\.messages).contains(alert["msg_id"] as! String)
        try check(present==(delta>=0 && delta<86400),"AT-SM-10 actual alert boundary \(delta)")
        alertEdges.append(["delta":delta,"present":present])
    }
    let stamps=["2026-01-01T00:00:00Z","2026-01-01T00:00:00.123Z","2026-01-01T00:00:00+09:00","invalid"]
    for stamp in stamps {_=live.controller.model.date(stamp)}
    HejoSmoothProbe.reset()
    for stamp in stamps {try check(live.controller.model.date(stamp)==ThreadTools.date(stamp),"AT-SM-10 date unchanged reference")}
    try check(HejoSmoothProbe.dates==0,"AT-SM-10 unchanged date derivations")
    for n in 0...live.controller.model.smoothDateCapacity {_=live.controller.model.date("invalid-fixture-\(n)")}
    try check(live.controller.model.smoothDateCount<=live.controller.model.smoothDateCapacity,"AT-SM-10 date bound")
    try smoothWrite(alertEdges,output.appendingPathComponent("alert-boundaries.json"))
    try smoothWrite(["pass":true,"changes":labels,"unchanged_assessments":0,"unchanged_calendars":0],output.appendingPathComponent("derived.json"))
    print("AT-SM-10 PASS");fflush(stdout)
}

/// Exercise durable local edits, acknowledgements, remote snapshots and both account paths.
@MainActor private func smoothMemberState(_ frames:[[String:Any]],output:URL) async throws {
    let seed=[frames[0]]+Array(frames.dropFirst().prefix(4))
    let f=try SmoothFixture(seed);defer{f.dispose()}
    let state=f.controller.model.memberState,post=smoothMessage(0,0,3)
    var rows:[[String:Any]]=[]
    func observe(_ label:String)throws {
        let direct=MemberState.merge(state.document.items,state.pending)
        let reopened=try LocalStore(directory:f.directory)
        let fresh=MemberState(store:reopened)
        let replay=try SmoothFixture(seed);defer{replay.dispose()}
        try replay.store.update{$0.memberStates=f.store.settings.memberStates;$0.pendingState=f.store.settings.pendingState;$0.stateAccount=f.store.settings.stateAccount}
        let x=f.controller.model,y=replay.controller.model
        try check(x.sidebar.items==y.sidebar.items && x.sidebar.rows.map{$0.stableID}==y.sidebar.rows.map{$0.stableID},"AT-SM-10 state sidebar "+label)
        for room in x.rooms.map(\.id) {
            try check(x.notices(room)==y.notices(room),"AT-SM-10 state notices "+label)
            for thread in x.threads(employee:room) {
                let a=x.assessment(thread.key),b=y.assessment(thread.key)
                try check(a.request==b.request && a.pending==b.pending && a.buttons==b.buttons && a.working==b.working && a.settled==b.settled && a.approved==b.approved && x.bell(thread.key)==y.bell(thread.key),"AT-SM-10 state assessment "+label)
            }
        }
        try check(f.controller.drawerSnapshot.counts==replay.controller.drawerSnapshot.counts,"AT-SM-10 state drawer "+label)
        try check(state.items==direct && state.items==fresh.items,"AT-SM-10 state merge "+label)
        for key in Set(direct.keys).union(["confirm:"+post,"thread:fixture-0/"+smoothThread(0,0).thread]) {
            try check(state.value(key)==fresh.value(key) && state.read(key)==fresh.read(key),"AT-SM-10 state query "+label)
        }
        try check(f.controller.model.confirmed(post)==(direct["confirm:"+post]?.v != nil),"AT-SM-10 confirmed "+label)
        HejoSmoothProbe.reset()
        for _ in 0..<20 {_=state.items;_=state.value("confirm:"+post)}
        try check(HejoSmoothProbe.memberMerges==0,"AT-SM-10 unchanged merge "+label)
        f.view.refresh();f.layout()
        try check(HejoSmoothProbe.assessmentInputs.values.allSatisfy{$0<=1},"AT-SM-10 render input collection once "+label)
        try smoothCompare(f,"state "+label)
        rows.append(["change":label,"items":direct.count,"unchanged_merges":0])
    }
    try observe("initial")
    _=state.items;HejoSmoothProbe.reset()
    try f.store.update {let key=$0.stateAccount ?? "";if $0.memberStates==nil {$0.memberStates=[:]};var doc=$0.memberStates?[key] ?? StateDocument();doc.rev+=1;$0.memberStates?[key]=doc}
    // A revision-only receipt leaves the merge inputs unchanged (nil/empty representation may differ).
    _=state.items
    HejoSmoothProbe.reset()
    try f.store.update {let key=$0.stateAccount ?? "";$0.memberStates?[key]?.rev+=1}
    _=state.items
    try check(HejoSmoothProbe.memberMerges==0,"AT-SM-10 revision only no remerge")
    try state.set(["confirm:"+post:"1","thread:fixture-0/"+smoothThread(0,0).thread:"4"],at:10)
    try observe("pending local edit")
    try state.set(["confirm:"+post:nil],at:11);try observe("pending replaced")
    var remote=StateDocument(rev:1,items:state.pending)
    state.fetch={_ in remote};state.push={sent in remote.rev+=1;remote.items=MemberState.merge(remote.items,sent);return remote}
    await state.sync()
    try check(state.pending.isEmpty,"AT-SM-10 acknowledged queue removed");try observe("send acknowledgement")
    remote.rev+=1;remote.items["confirm:"+post]=StateEntry(v:"1",at:12,dev:"remote-fixture")
    await state.sync();try observe("remote receive")
    try state.join(member:"fixture-b",hub:"fixture-hub",legacy:[:]);try observe("account join")
    try state.set(["confirm:"+post:"1"],at:20);try observe("other account pending")
    try f.store.update{$0.stateAccount=""};try observe("account restore via store update")
    try f.store.select(address:"fixture.invalid",device:"fixture");try observe("store select clears account")
    let reloaded=try LocalStore(directory:f.directory), replica=MemberState(store:reloaded)
    try check(replica.items==MemberState.merge(replica.document.items,replica.pending),"AT-SM-10 store reload")
    try smoothWrite(rows,output.appendingPathComponent("member-state.json"))
    print("AT-SM-10 MEMBER_STATE PASS");fflush(stdout)
}

/// AT-SM-09 preparation only. These controls drive the product Views with local synthetic frames.
@MainActor private func smoothManual(_ frames:[[String:Any]],output:URL,resources:URL) async throws {
    let f=try SmoothFixture(frames)
    let pet=PetController(store:f.store,atlas:try SpriteAtlas(resourceDirectory:resources))
    let controls=NSWindow(contentRect:CGRect(x:0,y:0,width:660,height:120),styleMask:[.titled,.closable],backing:.buffered,defer:false)
    controls.isReleasedWhenClosed=false
    defer{controls.orderOut(nil);disposeDrawerFixture(pet,f.controller,f.view);f.dispose()}
    pet.preferredChatSize=CGSize(width:840,height:760);pet.pet.installConversation(f.view);pet.installDrawer(f.view)
    pet.onExpansionChanged={expanded in if !expanded {f.view.folded()};f.controller.model.setVisible(expanded)}
    f.view.reduceMotion={false};f.view.history.reduceMotion={false};f.view.history.automaticallyTicks=true
    f.view.motionTime={ProcessInfo.processInfo.systemUptime};f.view.history.clock={ProcessInfo.processInfo.systemUptime}
    NSApp.setActivationPolicy(.regular)
    pet.showChat{f.view.openFromBubble(smoothThread(0,99))}
    let panel=NSView(frame:CGRect(x:0,y:0,width:660,height:120));controls.contentView=panel
    let help=NSTextField(labelWithString:"각 동작을 10번 관측하세요. 멈춤·튐·늦은 따라오기를 기록하세요.")
    help.frame=CGRect(x:12,y:84,width:636,height:22);panel.addSubview(help)
    let status=NSTextField(labelWithString:"서버 연결·전송 없음 · 닫으면 종료 · 자동 합격 판정 없음")
    status.frame=CGRect(x:12,y:8,width:636,height:22);panel.addSubview(status)
    let names=["스레드 선택","새 글 쓰기","알림 이동","답변 수신","방 전환","스크롤"]
    var counts=Array(repeating:0,count:names.count),records:[[String:Any]]=[]
    for (index,name) in names.enumerated() {
        let button=FileChip(title:name+" 0/10");button.frame=CGRect(x:12+index*106,y:42,width:102,height:30);panel.addSubview(button)
        button.invoke={
            Task { @MainActor in
                counts[index]+=1;let n=counts[index]
                do {
                    switch index {
                    case 0:f.view.chooseThread(smoothThread(0,90+n%10))
                    case 1:f.view.createThread();f.view.editor.editor.insertText("합성 관측 초안 \(n)",replacementRange:NSRange(location:NSNotFound,length:0))
                    case 2:pet.collapseChat();await pause(0.4);pet.showChat{f.view.openFromBubble(smoothThread(n%2,10+n%80))}
                    case 3:f.view.chooseEmployee("fixture-0");try f.edit(smoothMessage(0,99,3),String(repeating:"합성 수신 \(n)\n",count:10+n),final:n%2==0)
                    case 4:f.view.chooseEmployee("fixture-\(n%8)")
                    default:f.view.history.readerInput(wheel:true);let y=max(0,f.view.history.contentView.bounds.minY-60);f.view.history.contentView.scroll(to:CGPoint(x:0,y:y));f.view.history.reflectScrolledClipView(f.view.history.contentView)
                    }
                    f.layout();button.title=name+" \(n)/10"
                    records.append(["action":name,"iteration":n,"time":ProcessInfo.processInfo.systemUptime])
                    try smoothWrite(["counts":counts,"actions":records,"human_observation":"pending"],output.appendingPathComponent("manual-actions.json"))
                } catch {status.stringValue="관측 실행 실패: \(error)"}
            }
        }
    }
    controls.title="hejo 합성 관측 · 설치 앱과 별개";controls.center();controls.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
    print("AT-SM-09 READY window=\(pet.panel.windowNumber) controls=\(controls.windowNumber) timeout=300");fflush(stdout)
    try smoothWrite(["prepared":true,"executed":false,"human_observation":"pending","actions":names,"required_per_action":10],output.appendingPathComponent("manual-preparation.json"))
    let deadline=Date().addingTimeInterval(300)
    while controls.isVisible && Date()<deadline {await pause(0.2)}
}

/// Compare the card's calendar projection with the previous full bubble action path.
@MainActor private func smoothCalendarScenes(_ frames: [[String: Any]], output: URL) throws {
    let fixture = try SmoothFixture(frames)
    defer { fixture.dispose() }
    let controller = fixture.controller
    guard var message = controller.model.messages[smoothMessage(2, 0, 1)] else { throw TestFailure.assertion("S2 calendar fixture message") }
    message.text = "합성 검토 일정이 있어요. https://example.invalid/fixture"
    let date = ThreadTools.date(message.timestamp)
    let event = CalendarEntry(identifier:"fixture-event",calendarID:"fixture-calendar",title:"합성 검토",
                              start:date.addingTimeInterval(60),end:date.addingTimeInterval(3600))
    controller.calendarEvents = []
    func reference() -> [BubbleReveal.Action] {
        if message.role == "owner" || message.pending { return [] }
        return BubbleReveal.Action.content(message.text,events:controller.calendarEvents,
                                           at:ThreadTools.date(message.timestamp)).filter(\.isCalendar)
    }
    var observations: [[String: Any]] = []
    func observe(_ scene: String, omittedInput: [BubbleReveal.Action]? = nil) throws -> [BubbleReveal.Action] {
        let expected = reference()
        let actual = controller.calendarActions(for:message)
        try check(actual == expected,"S2 calendar old-path equivalence " + scene)
        if let omittedInput {
            try check(omittedInput != expected,"S2 calendar mutation must be detectable " + scene)
        }
        let ids = actual.flatMap { action -> [String] in
            if case .calendar(let matches) = action { return matches.map(\.identifier) }
            return []
        }
        observations.append(["scene":scene,"eventIDs":ids,"actions":actual.map(\.title),
                             "staleInputDiffers":omittedInput != nil])
        return actual
    }
    let empty = try observe("no calendars despite link")
    controller.calendarEvents = [event]
    let found = try observe("calendar arrives",omittedInput:empty)
    try check(found == [.calendar([event])],"S2 calendar is rendered alongside existing post link")
    message.text = "일정 이름이 없는 합성 글입니다."
    _ = try observe("body replacement",omittedInput:found)
    message.text = "합성 검토 일정이 있어요. https://example.invalid/fixture"
    _ = try observe("body restored")
    let originalDate = message.timestamp
    message.timestamp = "2027-01-01T00:00:00Z"
    _ = try observe("timestamp replacement",omittedInput:found)
    message.timestamp = originalDate
    _ = try observe("timestamp restored")
    message.role = "owner"
    _ = try observe("owner role",omittedInput:found)
    message.role = "employee"
    _ = try observe("employee restored")
    message.pending = true
    _ = try observe("pending",omittedInput:found)
    message.pending = false
    _ = try observe("acknowledged")
    controller.calendarEvents = []
    _ = try observe("calendar removed",omittedInput:found)
    try smoothWrite(observations, output.appendingPathComponent("calendar-scenes.json"))
}

/// Stable values from the actual card path, independently recorded by both builds.
@MainActor private func smoothColdCardSnapshot(_ frames: [[String: Any]], output: URL) throws {
    let fixture = try SmoothFixture(frames)
    defer { fixture.dispose() }
    fixture.view.chooseEmployee("fixture-2")
    fixture.layout()
    try smoothCompare(fixture, "first visit body, attributes and geometry")
    func color(_ value: NSColor) -> [CGFloat] {
        guard let rgb = value.usingColorSpace(.sRGB) else { return [] }
        return [rgb.redComponent, rgb.greenComponent, rgb.blueComponent, rgb.alphaComponent]
    }
    func attributes(_ value: Any) -> Any {
        if let value = value as? NSColor { return color(value) }
        if let value = value as? NSFont {
            return ["name":value.fontName,"size":value.pointSize,"traits":NSFontManager.shared.traits(of:value).rawValue] as [String: Any]
        }
        if let value = value as? URL { return value.absoluteString }
        if let value = value as? NSParagraphStyle {
            return ["alignment":value.alignment.rawValue,"lineSpacing":value.lineSpacing,"paragraphSpacing":value.paragraphSpacing,
                    "headIndent":value.headIndent,"tailIndent":value.tailIndent,"firstLineHeadIndent":value.firstLineHeadIndent,
                    "lineBreak":value.lineBreakMode.rawValue,"baseDirection":value.baseWritingDirection.rawValue,
                    "minimumLineHeight":value.minimumLineHeight,"maximumLineHeight":value.maximumLineHeight] as [String: Any]
        }
        if let value = value as? TextLayout.Decoration {
            return ["box":value.box ?? -1,"quotes":value.quotes.map { ["run":$0.run,"color":color($0.color)] as [String: Any] }] as [String: Any]
        }
        if let value = value as? NSNumber { return value }
        if let value = value as? String { return value }
        return String(reflecting: type(of: value))
    }
    let snapshot: [[String: Any]] = fixture.view.history.layouts.map { card in
        let pieces = card.placed.map { piece -> [String: Any] in
            var result: [String: Any] = ["frame":NSStringFromRect(piece.frame),"textFrame":NSStringFromRect(piece.text)]
            if case .post(let post) = piece.piece {
                var runs: [[String: Any]] = []
                post.text.enumerateAttributes(in: NSRange(location:0,length:post.text.length)) { values, range, _ in
                    let mapped = Dictionary(uniqueKeysWithValues: values.map { ($0.key.rawValue, attributes($0.value)) })
                    runs.append(["location":range.location,"length":range.length,"values":mapped])
                }
                result["post"] = ["id":post.id,"text":post.text.string,"speaker":post.speaker,"time":post.time,
                                  "color":color(post.nameColor),"fold":post.foldTitle ?? "",
                                  "mine":post.mine,"pending":post.pending,"streaming":post.streaming,
                                  "conversational":post.conversational,"continuation":post.continuation,"attributes":runs] as [String: Any]
            }
            return result
        }
        return ["id":card.content.id,"height":card.height,"pieces":pieces]
    }
    try check(!snapshot.isEmpty, "S2 empty cold-card snapshot")
    try smoothWrite(snapshot, output.appendingPathComponent("cold-cards.json"))
}

@MainActor func hejoSmooth(mode: String, output: URL, resources: URL) async throws {
    guard ProcessInfo.processInfo.environment["HERMES_HOME"]?.contains("hejo-sm-") == true else { throw TestFailure.assertion("SM requires isolated HERMES_HOME") }
    NSApp.appearance = NSAppearance(named: .aqua)
    try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)
    let frames = smoothFrames(), data = try JSONSerialization.data(withJSONObject: frames, options: [.sortedKeys])
    try data.write(to: output.appendingPathComponent("workload-frames.json"))
    try smoothWrite(["sha256": SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined(), "rooms": 8, "threads_per_room": 100, "posts_per_thread": 4, "lengths": [200,800,3000]], output.appendingPathComponent("workload.json"))
    if mode == "s2-scenes" {
        try smoothCalendarScenes(frames,output:output)
        try smoothColdCardSnapshot(frames,output:output)
        return
    }
    if mode == "s2-pair" {
        _ = try smoothMeasure(frames, output: output, paired: true)
        return
    }
    if mode == "manual" {try await smoothManual(frames,output:output,resources:resources);return}
    if mode.hasPrefix("s3-frame-"), let sample = Int(mode.dropFirst("s3-frame-".count)), (1...5).contains(sample) {
        try await smoothTransitions(frames,output:output,resources:resources,checking:false,screenSample:sample)
        return
    }
    if mode == "transitions" {try await smoothTransitions(frames,output:output,resources:resources,checking:true);try await smoothTransitionBoundaries(frames,output:output,resources:resources);return}
    if mode == "cards" {try await smoothInvalidation(frames);return}
    if mode == "derived" {try smoothDerived(frames,output:output);try await smoothMemberState(frames,output:output);return}
    if mode == "cache" || mode == "check" { try smoothReuse(frames); try await smoothInvalidation(frames) }
    _ = try smoothMeasure(frames, output: output)
    try smoothStream(frames, output: output, checking: mode != "baseline")
    if mode != "cache" { try await smoothTransitions(frames, output: output, resources: resources, checking: mode != "baseline") }
    if mode == "check" {try await smoothTransitionBoundaries(frames,output:output,resources:resources)}
    print("HEJO_SMOOTH_\(mode.uppercased())_RECORDED"); fflush(stdout)
}
#endif
