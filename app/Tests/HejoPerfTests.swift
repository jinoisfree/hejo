import AppKit
import CryptoKit
import Darwin

/// TASK-01A observes unmodified production paths. Expected results live in a frozen fixture;
/// this harness never creates or updates the expected file.
@MainActor func hejoPerf(input: URL, output: URL, measure: Bool, startInHome: Bool = false) async throws {
    let fm = FileManager.default
    guard let home = ProcessInfo.processInfo.environment["HERMES_HOME"],
          fm.fileExists(atPath: home + "/hejo-perf-isolated") else {
        throw TestFailure.assertion("HEJO-PERF requires its isolated home marker")
    }
    let data = try Data(contentsOf: input)
    let fixture = try JSONSerialization.jsonObject(with: data) as! [String: Any]
    let operations = fixture["operations"] as! [[String: Any]]
    let now = Date(timeIntervalSince1970: fixture["now"] as! Double)
    let keys = (fixture["keys"] as! [[String: String]]).map { ConversationKey(employee: $0["room"]!, thread: $0["thread"]!) }
    let knownThreads = Set(keys.map(\.thread))
    let directory = URL(fileURLWithPath: home).appendingPathComponent(UUID().uuidString)
    defer { try? fm.removeItem(at: directory) }
    let store = try LocalStore(directory: directory)
    let client = GateClient(store: store, credentials: MemoryCredentials())
    let controller = try testConversation(client: client)
    // Disable unrelated wall-clock polling, never a production execution path.
    controller.stop()
    defer { controller.stop(); client.stop() }
    var clock = now
    controller.clock = { clock }
    let model = controller.model
    func keyValue(_ key: ConversationKey?) -> Any {
        guard let key else { return NSNull() }
        return ["room": key.employee, "thread": knownThreads.contains(key.thread) ? key.thread : "<generated-thread>"]
    }
    func notices(_ room: String, at: Date? = nil) -> [[String: Any]] {
        model.notices(room, now: at).map { ["id": $0.id, "title": $0.title, "questions": $0.questions, "messages": $0.messages] }
    }
    var snapshots = [[String: Any]]()
    for op in operations {
        let action = op["action"] as! String
        var outcome = "ok"
        switch action {
        case "frame":
            do { _ = try await client.receive(op["frame"] as! [String: Any]) }
            catch GateFailure.protocolError { outcome = "protocol_error" }
            catch { throw error }
        case "controller": controller.receive(op["frame"] as! [String: Any])
        case "select": model.select(keys[op["key"] as! Int])
        case "visible": model.setVisible(op["value"] as! Bool)
        case "draft": controller.setText(op["text"] as! String, for: keys[op["key"] as! Int])
        case "bell": model.toggleBell(keys[op["key"] as! Int])
        case "read": model.markNoticeRead(keys[op["key"] as! Int])
        case "confirm": model.confirm(model.messages[op["message"] as! String]!)
        case "mute": model.toggleMute(op["room"] as! String)
        case "home": model.configureHome { $0.channel = op["channel"] as? String }; model.selectHome()
        case "clock": clock = Date(timeIntervalSince1970: op["value"] as! Double)
        case "expire": model.expireTyping(now: .distantFuture)
        case "send-disconnected": outcome = await controller.sendText("fixture send", key: keys[0]) ? "sent" : "failed"
        default: throw TestFailure.assertion("Unknown HEJO-PERF operation")
        }
        let messages = model.messages.values.sorted { $0.seq < $1.seq }.map { m -> [String: Any] in
            ["id": m.id, "key": keyValue(m.key), "speaker": m.speaker, "role": m.role, "text": m.text,
             "seq": m.seq, "latest_seq": m.latestSeq, "streaming": m.streaming, "finalized": m.finalized,
             "state": m.replyState as Any? ?? NSNull(), "confirmed": model.confirmed(m.id)]
        }
        let threads = keys.map { key -> [String: Any] in
            let state = model.assessment(key), draft = controller.draft(for: key)
            return ["key": keyValue(key), "timeline": model.timeline(key).map(\.id), "unread": model.unread(key),
                    "bell": model.bell(key) as Any? ?? NSNull(), "request": state.request?.id as Any? ?? NSNull(),
                    "pending": state.pending?.id as Any? ?? NSNull(), "working": state.working,
                    "settled": state.settled, "approved": state.approved, "buttons": state.buttons.sorted(),
                    "draft": draft.text, "picks": draft.picks.sorted(), "typing": model.typing[key] != nil]
        }
        let roomIDs = Set(model.rooms.map(\.id) + keys.map(\.employee) + [HomeRoom.id]).sorted()
        let rooms = roomIDs.map { room -> [String: Any] in
            ["id": room, "notices": notices(room), "explicit_notices": notices(room, at: now),
             "unread": model.unread(employee: room), "muted": model.muted.contains(room),
             "threads": model.threads(employee: room).map { ["thread": $0.key.thread, "title": $0.title, "preview": $0.preview, "latest_seq": $0.latestSeq] as [String: Any] }]
        }
        snapshots.append(["step": op["label"]!, "outcome": outcome, "applied": model.applied,
                          "stored": store.settings.applied, "selected": keyValue(model.selected),
                          "visible": model.visible, "home": model.isHome, "home_scope": model.homeScope.sorted(),
                          "notice": controller.notice, "failures": controller.failures.count,
                          "messages": messages, "threads": threads, "rooms": rooms])
    }
    try fm.createDirectory(at: output, withIntermediateDirectories: true)
    try perfWrite(["input_sha256": perfSHA(data), "snapshots": snapshots], output.appendingPathComponent("observed.json"))
    print("HEJO_PERF_SEMANTIC_OBSERVED steps=\(snapshots.count)"); fflush(stdout)
    if measure { try await hejoPerfMeasure(fixture["workload"] as! [String: Any], home: directory, output: output, startInHome: startInHome) }
}

private func perfSHA(_ data: Data) -> String { SHA256.hash(data: data).map { String(format: "%02x", $0) }.joined() }
private func perfWrite(_ object: Any, _ url: URL) throws {
    var data = try JSONSerialization.data(withJSONObject: object, options: [.sortedKeys, .prettyPrinted, .fragmentsAllowed])
    data.append(10)
    try data.write(to: url, options: .atomic)
}
private func perfCPU() -> Double {
    var value = rusage(); getrusage(RUSAGE_SELF, &value)
    return Double(value.ru_utime.tv_sec + value.ru_stime.tv_sec) + Double(value.ru_utime.tv_usec + value.ru_stime.tv_usec) / 1_000_000
}

@MainActor private func hejoPerfMeasure(_ config: [String: Any], home: URL, output: URL, startInHome: Bool = false) async throws {
    let rooms = config["rooms"] as! Int, count = config["threads_per_room"] as! Int, posts = config["posts_per_thread"] as! Int
    let now = Date(timeIntervalSince1970: config["now"] as! Double)
    let formatter = ISO8601DateFormatter()
    func uuid(_ n: Int) -> String { String(format: "00000000-0000-4000-8000-%012d", n) }
    var frames = [[String: Any]](), seq = 0
    let roster = (0..<rooms).map { ["id": "fixture-\($0)", "name": "직원 \($0)", "aliases": []] as [String: Any] }
    frames.append(["v": 1, "type": "welcome", "employees": roster, "head_seq": rooms * count * posts])
    for room in 0..<rooms {
        for thread in 0..<count {
            for post in 0..<posts {
                seq += 1
                let kind = thread % 4
                let text = kind == 0 ? "승인해줘" : kind == 1 ? "새 알림" : kind == 2 ? "완료한 작업" : "진행 내용"
                frames.append(["v": 1, "type": "message", "seq": seq, "msg_id": uuid(10_000 + seq),
                               "employee": "fixture-\(room)", "thread": uuid(1 + room * count + thread),
                               "role": kind == 3 && post == 0 ? "owner" : "employee", "text": text,
                               "files": [], "buttons": [], "reply_state": kind == 2 ? "closed" : NSNull(),
                               "ts": formatter.string(from: now.addingTimeInterval(Double(seq - rooms * count * posts)))])
            }
        }
    }
    // Streaming uses the journal's edit path; initial loading has no view attached.
    for room in 0..<rooms {
        seq += 1
        frames.append(["v": 1, "type": "edit", "seq": seq, "msg_id": uuid(10_000 + room * count * posts + posts * 4), "text": "진행 내용…", "final": false])
    }
    frames.append(["v": 1, "type": "sync_done", "through": seq, "more": false])
    let wire = try JSONSerialization.data(withJSONObject: frames, options: [.sortedKeys])
    try wire.write(to: output.appendingPathComponent("workload-frames.json"))
    let workloadHash = perfSHA(wire)
    var results = [[String: Any]]()
    // One warm-up and five independent stores/views, with identical frame order each time.
    for run in 0...5 {
        let store = try LocalStore(directory: home.appendingPathComponent("performance-\(run)"))
        let client = GateClient(store: store, credentials: MemoryCredentials())
        let controller = try testConversation(client: client)
        controller.stop(); controller.clock = { now }
        for frame in frames { _ = try await client.receive(frame) }
        if startInHome { controller.model.selectHome() }
        else { controller.model.select(ConversationKey(employee: "fixture-0", thread: uuid(1))) }
        let view = ConversationView(controller: controller, clipboardArea: store.directory.appendingPathComponent("clipboard"), islandModel: IslandModel(clock: { now }))
        view.frame = CGRect(x: 0, y: 0, width: 840, height: 760)
        view.reduceMotion = { true }
        view.motionTime = { 10 }
        let window = NSWindow(contentRect: view.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.contentView = view
        view.refresh(); view.layoutSubtreeIfNeeded()
        var receiveCosts = [Double](), refreshCosts = [Double]()
        var queuedAt = 0.0, inputLatency = -1.0, switchLatency = -1.0, switchCost = -1.0
        var inputBeforeEnd = false, switchBeforeEnd = false, ended = false
        let redraw = controller.onChange
        controller.onChange = {
            let begin = ProcessInfo.processInfo.systemUptime
            if queuedAt == 0 {
                queuedAt = begin
                // Queue real AppKit editor/room actions while the first receive is rendering.
                // This is a synthetic main-queue probe, not an OS keyboard or socket-rate measurement.
                DispatchQueue.main.async {
                    inputLatency = ProcessInfo.processInfo.systemUptime - queuedAt
                    view.editor.editor.insertText("x", replacementRange: NSRange(location: 0, length: 0))
                    inputBeforeEnd = !ended
                }
                DispatchQueue.main.async {
                    switchLatency = ProcessInfo.processInfo.systemUptime - queuedAt
                    let start = ProcessInfo.processInfo.systemUptime
                    view.chooseEmployee("fixture-1")
                    switchCost = ProcessInfo.processInfo.systemUptime - start
                    switchBeforeEnd = !ended
                }
            }
            redraw?()
            refreshCosts.append(ProcessInfo.processInfo.systemUptime - begin)
        }
        let cpu = perfCPU(), start = ProcessInfo.processInfo.systemUptime
        // Receive one frame per main-queue turn, as independent arrivals; no artificial sleeps.
        for index in 0..<4 {
            await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
                DispatchQueue.main.async {
                    let frame: [String: Any] = ["v": 1, "type": "edit", "seq": seq + index + 1,
                                               "msg_id": uuid(10_000 + posts * 4), "text": "진행 내용 \(index)", "final": index == 3]
                    let begin = ProcessInfo.processInfo.systemUptime
                    // Cache append then the production controller entry, with no live socket.
                    do { try store.append(frame) } catch { fatalError("isolated cache write failed") }
                    controller.receive(frame)
                    receiveCosts.append(ProcessInfo.processInfo.systemUptime - begin)
                    continuation.resume()
                }
            }
        }
        ended = true
        let elapsed = ProcessInfo.processInfo.systemUptime - start, cpuSeconds = perfCPU() - cpu
        let row: [String: Any] = ["run": run, "warm_up": run == 0, "workload_sha256": workloadHash,
                                "receive_seconds": receiveCosts, "refresh_seconds": refreshCosts,
                                "wall_seconds": elapsed, "cpu_seconds": cpuSeconds, "cpu_percent": 100 * cpuSeconds / elapsed,
                                "input_queue_seconds": inputLatency, "switch_queue_seconds": switchLatency, "switch_seconds": switchCost,
                                "input_before_end": inputBeforeEnd, "switch_before_end": switchBeforeEnd,
                                "messages": controller.model.messages.count, "frames_in_window": 4,
                                "rendered_cards": view.history.contents.filter { UUID(uuidString: $0.id) != nil }.count]
        results.append(row)
        try perfWrite(["config": config, "runs": results], output.appendingPathComponent("performance.json"))
        print("HEJO_PERF_RUN \(run) wall=\(elapsed) cpu=\(100 * cpuSeconds / elapsed) input=\(inputLatency) switch=\(switchLatency) refreshes=\(refreshCosts.count)"); fflush(stdout)
        controller.onChange = nil; controller.onRevealThread = nil; controller.stop(); client.stop()
        window.contentView = nil; window.orderOut(nil)
    }
}
