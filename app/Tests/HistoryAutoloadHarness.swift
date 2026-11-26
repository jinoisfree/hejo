#if HEJO_HISTORY_TRANSPORT_TEST
import AppKit
import Foundation

@MainActor enum HistoryAutoloadHarness {
    private struct Fixture: Decodable {
        let scenario: String
        let threads: [String]
        let chosen: String
        let rows: [String:[String]]
        let failure: String
        let port: Int
        let other: String?
        let otherRoot: String?
        let controlOrigin: CGFloat?
        let controlBodyTick: Int?
    }

    private struct LiveThread: Decodable {
        let thread: String
        let root: String
    }

    private struct Request: Decodable {
        var threadTarget: Bool?
        let kind: String
        let time: Double?
        let thread: String?
        let scope: String
        let anchor: String?
        let cursor: Bool
        let responseIDs: [String]?
        let action: String?
        let restoreID: String?
    }

    private struct Observation: Decodable {
        let requests: [Request]
        let held: Bool
        let sendHeld: Bool
        let streamFinal: Double?
        let streamTimes: [Double]?
        let streamInterleave: Double?
        let streamDisconnect: Double?
    }

#if HEJO_LEGACY_REFERENCE
    static func runLegacy(client: GateClient,args: [String]) async throws {
        let fixture = try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:URL(fileURLWithPath:args[6])))
        let home = URL(fileURLWithPath:args[3])
        let controller = try ConversationController(client:client,downloads:home.appendingPathComponent("downloads"))
        defer { controller.stop() }
        try client.pair(address:args[1],code:args[2],device:"Fixture legacy")
        let roots = Set(fixture.threads.compactMap { fixture.rows[$0]?.first })
        for _ in 0..<350 {
            if client.replayComplete && roots.isSubset(of:controller.model.messages.keys) { break }
            try await Task.sleep(nanoseconds:20_000_000)
        }
        guard client.replayComplete, roots.isSubset(of:controller.model.messages.keys) else {
            throw HistoryFailure.server("AT-ALD-18 legacy replay",retryable:false)
        }
        _ = NSApplication.shared
        let view = ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
        let window = NSWindow(contentRect:NSRect(x:0,y:0,width:900,height:950),styleMask:[.titled],backing:.buffered,defer:false)
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        view.chooseEmployee("alpha")
        view.refresh();view.layoutSubtreeIfNeeded()
        try await Task.sleep(nanoseconds:500_000_000)
        let displayed = Set(view.history.contents.flatMap { card in
            card.top.compactMap { piece -> String? in
                if case .post(let post) = piece { return post.id }
                return nil
            }
        })
        guard roots.isSubset(of:displayed), client.historySession == nil else {
            throw HistoryFailure.server("AT-ALD-18 legacy view",retryable:false)
        }
        print("AUTOLOAD PASS legacy")
    }
#endif

    static func run(client: GateClient, args: [String]) async throws {
        let fixture = try JSONDecoder().decode(Fixture.self,from:Data(contentsOf:URL(fileURLWithPath:args[6])))
        let home = URL(fileURLWithPath:args[3])
        var budget = HistoryResidentBudget()
        if ["evicted","prefetch-eviction"].contains(fixture.scenario) { budget.countLimit = 2 }
        if fixture.scenario == "jump-prefetch-budget" { budget.countLimit = 6 }
        let controller = try ConversationController(client:client,downloads:home.appendingPathComponent("downloads"),
                                                    residentBudget:budget)
        defer { controller.stop() }
        let model = controller.model
        let loader = controller.historyLoading
        let viewportCase = ["viewport","leave-room","refresh-fails","refresh-count","priority","retry-outside","evicted","prefetch-eviction"].contains(fixture.scenario)
        let height: CGFloat = fixture.scenario == "basic" ? 950 :
            fixture.scenario.hasPrefix("jump-prefetch") ? 350 : viewportCase ? 540 : 700
        let chosen = ConversationKey(employee:"alpha",thread:fixture.chosen)
        let first = ConversationKey(employee:"alpha",thread:fixture.threads[0])
        let rows = fixture.rows[first.thread]!
        let rootIDs = fixture.threads.map { fixture.rows[$0]![0] }
        let failing = ConversationKey(employee:"alpha",thread:fixture.failure)
        let failureRoot = fixture.rows[failing.thread]![0]
        let testURL = URL(string:"http://127.0.0.1:\(fixture.port)")!
        var clock = Date()
        controller.clock = { clock }

        func require(_ condition: @autoclosure () -> Bool, _ evidence: String) throws {
            if !condition() { throw HistoryFailure.server(evidence,retryable:false) }
        }
        func wait(_ evidence: String, _ condition: () async throws -> Bool) async throws {
            for _ in 0..<350 {
                if try await condition() { return }
                try await Task.sleep(nanoseconds:20_000_000)
            }
            let indices = rows.enumerated().filter { model.historyReplyIDs(first).contains($0.element) }.map(\.offset)
            throw HistoryFailure.server("timeout_\(evidence) replies=\(indices.first ?? -1)...\(indices.last ?? -1) busy=\(loader.busy) failure=\(String(describing:loader.failure))",retryable:false)
        }
        func observe() async throws -> Observation {
            let (data,_) = try await URLSession.shared.data(from:testURL.appendingPathComponent("observe"))
            return try JSONDecoder().decode(Observation.self,from:data)
        }
        @discardableResult func control(_ action: String) async throws -> Data {
            var request = URLRequest(url:testURL.appendingPathComponent("control").appendingPathComponent(action))
            request.httpMethod = "POST"
            let (data, response) = try await URLSession.shared.data(for:request)
            try require((response as? HTTPURLResponse)?.statusCode == 200,"fixture_control_\(action)")
            return data
        }
        func sendLiveMessage() async throws -> String {
            let response = try await control("live")
            guard let id = try JSONDecoder().decode([String:String].self,from:response)["id"] else {
                throw HistoryFailure.invalidResponse
            }
            return id
        }
        func bodyRequests(_ requests: [Request], for id: String) -> [Request] {
            requests.filter { $0.thread == id && $0.kind == "resolve" }
        }

        controller.setPaused(true)
        try client.pair(address:args[1],code:args[2],device:"Fixture autoload")
        try await wait("connection") { client.isConnected && !loader.busy && !model.history.refreshing }
        model.select(chosen,markRead:false)
        try await wait("chosen") { !loader.busy && !model.history.refreshing && model.selected == chosen }
        _ = NSApplication.shared
        let view = ConversationView(controller:controller,clipboardArea:home.appendingPathComponent("clipboard"))
        let window = NSWindow(contentRect:CGRect(x:0,y:0,width:900,height:height),styleMask:[.titled],backing:.buffered,defer:false)
        window.contentView = view
        window.orderFrontRegardless()
        defer { window.orderOut(nil) }
        view.history.reduceMotion = { true }
        let publishLoadViewport = view.history.onLoadViewport
        if fixture.scenario == "root-only" { view.history.onLoadViewport = nil }

        func layout() {
            view.layoutSubtreeIfNeeded()
            view.history.layoutSubtreeIfNeeded()
        }
        func rendered(_ id: String) -> Bool {
            view.history.contents.contains { card in
                (card.top + (card.replies ?? [])).contains { if case .post(let post) = $0 { return post.id == id }; return false }
            }
        }
        func replyPosts(_ id: String) -> [NativeThreadCard.Post] {
            view.history.contents.first { $0.id == id }?.replies?.compactMap { piece in
                if case .post(let post) = piece { return post }
                return nil
            } ?? []
        }
        func displayedReplies(_ id: String) -> [String] { replyPosts(id).map(\.id) }
        func clickCard(_ key: ConversationKey) throws {
            guard let card = view.history.contents.first(where:{ $0.id == key.thread }) else {
                throw HistoryFailure.invalidResponse
            }
            card.clickCard()
            layout()
        }
        func buttons(_ id: String, _ title: String) -> Int {
            guard let card = view.history.contents.first(where:{ $0.id == id }) else { return 0 }
            return (card.top + (card.replies ?? [])).reduce(0) { count, piece in
                if case .accessory(_,_,let make) = piece, (make() as? FileChip)?.title == title { return count + 1 }
                return count
            }
        }
        func labels(_ id: String) -> [String] {
            guard let card = view.history.contents.first(where:{$0.id==id}) else { return [] }
            return (card.top + (card.replies ?? [])).compactMap { piece in
                guard case .accessory(_,_,let make) = piece else { return nil }
                return (make() as? NSTextField)?.stringValue
            }
        }
        func pressRetry(_ id: String) throws {
            guard let card = view.history.contents.first(where:{ $0.id == id }) else {
                throw HistoryFailure.invalidResponse
            }
            for piece in card.top + (card.replies ?? []) {
                if case .accessory(_,_,let make) = piece, let button = make() as? FileChip, button.title == "다시 시도" {
                    button.invoke?()
                    return
                }
            }
            throw HistoryFailure.server("fixture_no_retry_button",retryable:false)
        }
        func scroll(_ y: CGFloat) {
            let list = view.history
            list.readerInput(wheel:false)
            let end = max(0,list.table.bounds.maxY-list.contentView.bounds.height)
            list.contentView.scroll(to:CGPoint(x:0,y:min(max(0,y),end)))
            list.reflectScrolledClipView(list.contentView)
            layout()
        }
        func visibleThreads(_ padding: CGFloat = 0) -> Set<String> {
            let viewport = view.history.contentView.bounds.insetBy(dx:0,dy:-padding)
            return Set(fixture.threads.filter { view.history.frame(for:$0)?.intersects(viewport) == true })
        }
        func visibleBodies() -> Set<String> {
            let list = view.history, viewport = list.contentView.bounds
            let marker = "history-body:"
            return Set(list.layouts.enumerated().flatMap { index, layout in
                let rect = list.table.rect(ofRow:index)
                return layout.anchors.compactMap { id, local -> String? in
                    guard viewport.intersects(local.offsetBy(dx:rect.minX,dy:rect.minY)) else { return nil }
                    return id.hasPrefix(marker) ? String(id.dropFirst(marker.count)):id
                }
            })
        }
        func requestOlderList() {
            let wheel = CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:1,wheel1:40,wheel2:0,wheel3:0)!
            view.history.scrollWheel(with:NSEvent(cgEvent:wheel)!)
        }
        func bottom() -> CGFloat { view.history.table.bounds.maxY-view.history.contentView.bounds.height }
        func frame(_ card: String, _ id: String) -> CGRect {
            view.history.frame(for:card,message:id) ?? .null
        }
        func y(_ card: String, _ id: String) -> CGFloat { frame(card,id).minY-view.history.contentView.bounds.minY }
        func settle() async throws {
            try await Task.sleep(nanoseconds:500_000_000)
            layout()
        }
        func noOldButtons() -> Bool {
            let former = ["원문 불러오기","긴 원문 불러오기","이전 답글 보기","최근 답글 보기","이전 본문 다시 불러오기"]
            return fixture.threads.allSatisfy { key in former.allSatisfy { buttons(key,$0) == 0 } }
        }

        view.refresh()
        layout()
        controller.setPaused(false)
        layout()

        switch fixture.scenario {
        case let name where name.hasPrefix("jump-input-"):
            let cold = name.contains("-cold-")
            let kindName = String(name.split(separator:"-").last ?? "")
            guard let kind = HistoryJumpInputHarness.ReadInput(rawValue:kindName) else {
                throw HistoryFailure.invalidResponse
            }
            view.history.onLoadViewport = nil
            try await wait("input queue idle") { !loader.busy && !model.history.refreshing }
            guard let context = model.history.context else { throw HistoryFailure.changed }
            let targetThread = fixture.threads[5]
            let target = ConversationKey(employee:first.employee,thread:targetThread)
            guard let targetMessage = fixture.rows[targetThread]?.first else { throw HistoryFailure.invalidResponse }
            var contrastPage: [String:Any]?
            for thread in fixture.threads {
                let key = ConversationKey(employee:first.employee,thread:thread)
                if cold && key == target && fixture.controlOrigin == nil { continue }
                let page = try await client.history.query(context:context,kind:"messages",scope:key.employee,
                    fields:["target":["room":key.employee,"thread":key.thread]])
                if cold && key == target { contrastPage = page; continue }
                try model.applyHistoryMessages(page,key:key,context:context,generation:model.history.generation)
            }
            let viewList = view.history
            viewList.reduceMotion = { false }
            view.refresh()
            layout()
            try await settle()
            try await wait("input starts idle") { !loader.busy && !model.history.refreshing }
            let card = TodoDrawerModel.Card(id:"move-before-input",kind:.alert,title:"Fixture",employee:target.employee,
                name:"Fixture",status:"",statusUrgent:false,trailing:"",key:target,messageID:targetMessage,order:clock,urgent:false)
            let frameInterval = 1.0/60
            var frameClock = ProcessInfo.processInfo.systemUptime
            viewList.clock = { frameClock }
            defer { viewList.clock = { ProcessInfo.processInfo.systemUptime } }
            if let controlOrigin = fixture.controlOrigin {
                scroll(controlOrigin)
            } else {
                let wheelTravel: CGFloat = cold && kind == .wheel ? 160:0
                scroll(bottom()-wheelTravel)
                if cold { try await control("jump-delay") }
                view.selectDrawerCard(card)
                for _ in 0..<(cold ? 12:6) {
                    try await Task.sleep(nanoseconds:16_666_667)
                    frameClock += frameInterval
                    viewList.advanceScroll()
                    layout()
                }
            }

            let preInput = viewList.contentView.bounds.minY
            try await HistoryJumpInputHarness.deliver(kind,in:window,to:viewList)
            var positions: [CGFloat] = []
            var appeared = -1
            for tick in 0..<(cold ? 100:61) {
                if tick > 0 { try await Task.sleep(nanoseconds:16_666_667) }
                frameClock += frameInterval
                if cold && tick == fixture.controlBodyTick,let contrastPage {
                    try model.applyHistoryMessages(contrastPage,key:target,context:context,generation:model.history.generation)
                    view.refresh()
                }
                viewList.advanceScroll()
                layout()
                positions.append(viewList.contentView.bounds.minY)
                if cold && appeared < 0 && rendered(targetMessage) { appeared = tick }
            }
            if cold { try require(appeared >= 0,"cold input target received") }
            let data = try JSONSerialization.data(withJSONObject:[
                "origin":preInput,"bodyTick":appeared,"samples":positions
            ])
            print("AT-JO-04 trajectory "+String(decoding:data,as:UTF8.self))
        case "jump-wait-drawer", "jump-wait-search", "jump-wait-notice",
             "jump-wait-bubble", "jump-wait-missing", "jump-wait-no-card", "jump-wait-replaced", "jump-wait-other", "jump-ready-other":
            view.history.onLoadViewport = nil
            try await wait("jump queue idle") { !loader.busy && !model.history.refreshing }
            guard let context = model.history.context else { throw HistoryFailure.changed }
            let cardOnly = fixture.scenario == "jump-wait-bubble"
            let readyAcross = fixture.scenario == "jump-ready-other"
            let acrossRooms = cardOnly || readyAcross || fixture.scenario == "jump-wait-other"
            let noCard = fixture.scenario == "jump-wait-no-card"
            let missing = noCard || fixture.scenario == "jump-wait-missing"
            let replaced = fixture.scenario == "jump-wait-replaced"
            let cold = cardOnly
                ? try JSONDecoder().decode(LiveThread.self,from:await control("jump-cold-room-thread")) : nil
            let absentThread = "00000000-0000-4000-8000-0000000003a3"
            let absentMessage = "00000000-0000-4000-8000-000000002ab3"
            let thread = noCard ? absentThread : cold?.thread ?? (acrossRooms ? fixture.other : fixture.threads[5])
            guard let thread else { throw HistoryFailure.invalidResponse }
            let key = ConversationKey(employee:acrossRooms ? "beta" : first.employee,thread:thread)
            let message = noCard ? absentMessage : cold?.root ?? (acrossRooms ? fixture.otherRoot : fixture.rows[thread]?.first)
            for id in fixture.threads where id != thread {
                let page = try await client.history.query(context:context,kind:"messages",scope:first.employee,
                                                          fields:["target":["room":first.employee,"thread":id]])
                try model.applyHistoryMessages(page,key:.init(employee:first.employee,thread:id),
                                               context:context,generation:model.history.generation)
            }
            if acrossRooms, !cardOnly {
                let roomPage = try await client.history.query(context:context,kind:"threads",scope:key.employee,fields:[:])
                let items = (roomPage["items"] as? [[String:Any]] ?? []).filter {
                    ($0["key"] as? [String:String])?["thread"] == key.thread
                }
                var targetPage = roomPage
                targetPage["items"] = items
                try model.applyHistoryThreads(targetPage,scope:key.employee,context:context,generation:model.history.generation)
                if readyAcross {
                    let recent = try await client.history.query(context:context,kind:"messages",scope:key.employee,
                        fields:["target":["room":key.employee,"thread":key.thread]])
                    try model.applyHistoryMessages(recent,key:key,context:context,generation:model.history.generation)
                }
            }
            try await control("jump-delay")
            view.refresh()
            layout()
            try await settle()
            try await wait("jump queue remains idle") { !loader.busy && !model.history.refreshing }
            let list = view.history
            let drawer = TodoDrawerModel.Card(id:"waiting-target",kind:.alert,title:"Fixture",employee:key.employee,
                name:"Fixture",status:"",statusUrgent:false,trailing:"",key:key,messageID:message,order:clock,urgent:false)
            func targetFrame() -> CGRect? {
                guard let card = list.frame(for:key.thread) else { return nil }
                if cardOnly { return card }
                if missing && loader.failure != nil { return card }
                guard let message,rendered(message) else { return nil }
                return list.frame(for:key.thread,message:message)
            }
            scroll(bottom())
            try require(targetFrame() == nil,"other-room target not visible in the old room")
            if cardOnly { try require(model.history.summaries[key] == nil,"card summary not received before E3") }
            if !acrossRooms {
                try require((list.frame(for:key.thread) != nil) != noCard,"card presence matches scenario")
            }
            let initial = list.contentView.bounds.minY
            let frameInterval = 1.0/60
            var frameTime = ProcessInfo.processInfo.systemUptime
            list.clock = { frameTime }
            list.reduceMotion = { false }
            defer { list.clock = { ProcessInfo.processInfo.systemUptime } }
            let start = ProcessInfo.processInfo.systemUptime
            switch fixture.scenario {
            case "jump-wait-bubble":
                view.openFromBubble(key)
            case "jump-wait-search":
                guard let message else { throw HistoryFailure.invalidResponse }
                view.revealHistorySearch(key,id:message)
            case "jump-wait-notice":
                guard let message,let notice = model.notices(first.employee).first(where: { $0.messages.contains(message) }) else {
                    throw HistoryFailure.invalidResponse
                }
                view.jumpNotice(notice)
            default:
                view.selectDrawerCard(drawer)
            }
            layout()
            if readyAcross {
                let initialFrame = targetFrame()
                let firstGap = initialFrame.map {
                    abs(list.contentView.bounds.minY - max(0,min($0.midY-list.contentView.bounds.height/2,max(0,bottom()))))
                }
                try await settle()
                try await wait("ready other room finishes") { !loader.busy && !model.history.refreshing }
                layout()
                let finalGap = targetFrame().map {
                    abs(list.contentView.bounds.minY - max(0,min($0.midY-list.contentView.bounds.height/2,max(0,bottom()))))
                }
                print("AT-JO-07 \(firstGap.map { $0 <= 1 } == true && finalGap.map { $0 <= 1 } == true ? "PASS":"FAIL") firstGap=\(String(describing:firstGap)) finalGap=\(String(describing:finalGap))")
                break
            }
            let entryOrigin = acrossRooms ? list.contentView.bounds.minY : initial
            var previousOrigin = entryOrigin
            var early: CGFloat = 0
            var drawFrame: Int?
            var replacementOrigin: CGFloat?
            var reachedReplacement = false
            let secondThread = fixture.threads[8]
            let secondMessage = fixture.rows[secondThread]?.first
            var afterSettleDrift: CGFloat = 0
            var lastUnsettled: Int?
            var previousDistance: CGFloat?
            var advances = 0
            var stationaryFrames = 3
            var rebounds = 0
            for tick in 1...120 {
                let remaining = start + Double(tick)*frameInterval - ProcessInfo.processInfo.systemUptime
                if remaining > 0 { try await Task.sleep(nanoseconds:UInt64(remaining * 1_000_000_000)) }
                frameTime += frameInterval
                list.advanceScroll()
                layout()
                let origin = list.contentView.bounds.minY
                if replaced {
                    if tick == 6 {
                        guard let secondMessage,rendered(secondMessage) else { throw HistoryFailure.invalidResponse }
                        let second = TodoDrawerModel.Card(id:"replacement-target",kind:.alert,title:"Fixture",
                            employee:first.employee,name:"Fixture",status:"",statusUrgent:false,trailing:"",
                            key:.init(employee:first.employee,thread:secondThread),messageID:secondMessage,order:clock,urgent:false)
                        view.selectDrawerCard(second)
                    } else if tick > 6,let secondMessage,let frame = list.frame(for:secondThread,message:secondMessage) {
                        let goal = max(0,min(frame.midY-list.contentView.bounds.height/2,max(0,bottom())))
                        let distance = abs(origin-goal)
                        if let previousDistance,distance-previousDistance > 0.5 { rebounds += 1 }
                        previousDistance = distance
                        if distance <= 1 { reachedReplacement = true }
                        if tick == 36 { replacementOrigin = origin }
                        if let replacementOrigin {
                            afterSettleDrift = max(afterSettleDrift,abs(origin-replacementOrigin))
                        }
                    }
                    continue
                }
                if let frame = targetFrame() {
                    if drawFrame == nil { drawFrame = tick }
                    let goal = max(0,min(frame.midY - list.contentView.bounds.height/2,max(0,bottom())))
                    let distance = abs(origin - goal)
                    if distance > 1 { lastUnsettled = tick }
                    if let previousDistance,distance - previousDistance > 0.5 { rebounds += 1 }
                    previousDistance = distance
                    if abs(origin - previousOrigin) > 0.5 {
                        if stationaryFrames >= 3 { advances += 1 }
                        stationaryFrames = 0
                    } else {
                        stationaryFrames += 1
                    }
                } else {
                    early = max(early,abs(origin - entryOrigin))
                }
                previousOrigin = origin
                print("WAIT sample=\(tick) origin=\(origin) distance=\(previousDistance.map { String(describing:$0) } ?? "absent")")
            }
            if replaced {
                let pass = reachedReplacement && replacementOrigin != nil && rebounds == 0 && afterSettleDrift <= 0.5
                print("AT-JO-05 \(pass ? "PASS":"FAIL") reachedSecond=\(reachedReplacement) rebounds=\(rebounds) drift=\(afterSettleDrift)")
                break
            }
            if noCard {
                let inlineError = list.contents.contains { $0.id.contains("history-status") }
                let passed = early <= 0.5 && drawFrame == nil && loader.failure != nil && !inlineError
                print("AT-JO-06 no card \(passed ? "PASS":"FAIL") maximumMotion=\(early) targetDrawn=\(drawFrame != nil) error=\(loader.failure != nil) inlineError=\(inlineError)")
                break
            }
            let settled = lastUnsettled.map { $0 + 1 } ?? drawFrame
            let hasSettled = drawFrame.flatMap { origin in settled.map { $0 - origin <= 18 && $0 < 120 } } ?? false
            let testID = missing ? "AT-JO-06 card" : fixture.scenario == "jump-wait-drawer" ? "AT-JO-02 same room"
                : fixture.scenario == "jump-wait-other" ? "AT-JO-02 other room" : "AT-JO-08 cold " + fixture.scenario
            let pass = early <= 0.5 && advances == 1 && rebounds == 0 && hasSettled
            print("\(testID) \(pass ? "PASS":"FAIL") early=\(early) moves=\(advances) rebounds=\(rebounds) drawn=\(String(describing:drawFrame)) settled=\(String(describing:settled)) failure=\(loader.failure != nil)")
        case "jump-prefetch", "jump-prefetch-error", "jump-prefetch-budget", "jump-prefetch-delay":
            view.history.onLoadViewport = nil
            loader.updateLoadingTargets([],visibleBodies:[],scope:model.isHome ? "home":model.selectionIdentity)
            try await wait("prefetch fixture idle") { !loader.busy && !model.history.refreshing }
            guard let context = model.history.context else { throw HistoryFailure.changed }
            let page = try await client.history.query(context:context,kind:"messages",scope:first.employee,
                fields:["target":["room":first.employee,"thread":first.thread]])
            try model.applyHistoryMessages(page,key:first,context:context,generation:model.history.generation)
            let original = try await client.history.query(context:context,kind:"resolve",scope:first.employee,
                fields:["target":[rows[0]],"limit":1])
            guard let root = (original["items"] as? [[String:Any]])?.first else { throw HistoryFailure.invalidResponse }
            try model.applyHistoryBody(root,expectedKey:first)
            view.drawerShownWidth = PetController.drawerWidth
            view.openFromBubble(first)
            try await settle()
            try await wait("recent reply window idle") { !loader.busy && !model.history.refreshing }
            let beforeRecent = model.historyReplyIDs(first)
            try require(rendered(rows[0]) && !beforeRecent.isEmpty && !beforeRecent.contains(rows[10]),
                        "reading fixture has a rendered root, recent replies and an older target outside the window")
            let input = fixture.threads.enumerated().map { index, thread -> [String:Any] in
                let remoteCard = index == 3 && fixture.scenario == "jump-prefetch-delay"
                return [
                    "employee":remoteCard ? "beta":first.employee,"id":String(format:"fixture-%02d",index),
                    "title":"Fixture \(index)","due":"2026-12-01",
                    "notice":["message_id":(remoteCard ? fixture.otherRoot:nil) ?? fixture.rows[thread]![index == 0 ? 10 : 0],
                              "thread":(remoteCard ? fixture.other:nil) ?? thread]
                ]
            }
            controller.deadlineSender = { _ in }
            controller.drawerFilter = .deadline
            if fixture.scenario == "jump-prefetch-error" { try await control("prefetch-error") }
            controller.todoDrawer.receive(["available":true,"items":[],"failed":[]])
            view.setDrawerState(open:true,chatExpanded:true)
            view.refresh()
            layout()
            try await settle()
            let selected = model.selected
            let unfolded = view.history.contents.filter(\.expanded).map(\.id)
            let unread = model.rooms.map { model.unread(employee:$0.id) }
            let noticeIDs = model.history.notices.map(\.id)
            let origin = view.history.contentView.bounds.minY
            let visibleIDs = view.history.visibleMessageIDs
            guard let visibleID = rows.first(where:visibleIDs.contains) else { throw HistoryFailure.invalidResponse }
            let visibleGap = y(first.thread,visibleID)
            let readingLayout = view.history.layouts.first { $0.content.id == first.thread }
            let initialPins = model.residentBudget.pins
            let offset = try await observe().requests.count
            controller.todoDrawer.receive(["available":true,"items":input,"failed":[]])
            view.refresh()
            layout()
            guard let list = view.todoDrawer.subviews.compactMap({ $0 as? NSScrollView }).first else {
                throw HistoryFailure.invalidResponse
            }
            let cards = view.todoDrawer.cardViews
            try require(cards.count == 30,"prefetch fixture has 30 cards")
            cards.first?.scrollToVisible(cards.first?.bounds ?? .zero)
            let viewport = list.contentView.bounds
            let reach = viewport.insetBy(dx:0,dy:-viewport.height)
            let nearby = cards.filter { card in
                card.convert(card.bounds,to:list.documentView).intersects(reach)
            }.compactMap { $0.card.key }
            try require(nearby.contains(first) && nearby.count < cards.count,"prefetch fixture receives the old target in a proper subset")
            try await wait("initial prefetch idle") { !loader.busy }
            try await settle()
            let ready = nearby.filter { key in
                guard let root = model.history.summaries[key]?.rootID else { return false }
                return model.messages[root] != nil && model.history.messagePages[key] != nil
            }
            let requests = Array(try await observe().requests.dropFirst(offset))
            for _ in 0..<5 { view.refresh(); layout() }
            for _ in 0..<3 {
                view.todoDrawer.cardViews.last?.scrollToVisible(view.todoDrawer.cardViews.last?.bounds ?? .zero)
                try await wait("scrolled prefetch idle") { !loader.busy }
                list.contentView.scroll(to:viewport.origin)
                list.reflectScrolledClipView(list.contentView)
                try await wait("returned prefetch idle") { !loader.busy }
            }
            let originChange = abs(view.history.contentView.bounds.minY-origin)
            let visibleChange = abs(y(first.thread,visibleID)-visibleGap)
            let stayed = model.selected == selected && view.history.contents.filter(\.expanded).map(\.id) == unfolded
                && model.rooms.map { model.unread(employee:$0.id) } == unread
                && model.history.notices.map(\.id) == noticeIDs
                && originChange <= 0.5 && visibleChange <= 1 && view.todoDrawer.cardViews.map(\.card) == cards.map(\.card)
            view.setDrawerState(open:false,chatExpanded:true)
            try await settle()
            let afterScroll = try await observe().requests.dropFirst(offset)
            let closedOffset = try await observe().requests.count
            view.refresh()
            try await settle()
            let closed = try await observe().requests.dropFirst(closedOffset).filter { $0.kind == "resolve" }.count
            if visibleChange > 1,let readingLayout,
               let finalLayout = view.history.layouts.first(where:{ $0.content.id == first.thread }) {
                let anchorCount = readingLayout.anchors.keys.filter { readingLayout.anchors[$0] != finalLayout.anchors[$0] }.count
                let heights = rows.enumerated().compactMap { index,id -> String? in
                    let left = readingLayout.anchors[id]?.height, right = finalLayout.anchors[id]?.height
                    return left == right ? nil:"\(index):\(left ?? -1)→\(right ?? -1)"
                }
                let requestKinds = Set(requests.filter { $0.thread == first.thread || $0.thread == nil }.map(\.kind)).sorted()
                print("AT-JO-11 reading row: height=\(readingLayout.height)→\(finalLayout.height) reserve=\(readingLayout.header.reserve)→\(finalLayout.header.reserve) changedAnchors=\(anchorCount) changedHeights=\(heights) requests=\(requestKinds)")
            }
            let unchanged = model.historyReplyIDs(first) == beforeRecent
            let anchored = requests.filter { $0.kind == "resolve" && $0.anchor != nil }.count
            let firstLoads = requests.filter { $0.kind == "resolve" && $0.threadTarget == true }
            let outside = firstLoads.filter { row in !nearby.contains { $0.thread == row.thread } }.count
            let allLoads = afterScroll.filter { $0.kind == "resolve" && $0.threadTarget == true }
            let duplicate = Dictionary(grouping:allLoads,by:{ $0.thread ?? "" }).values.contains { $0.count > 1 }
            let entered = allLoads.count > firstLoads.count
            let reported = ready.count == Set(nearby).count && anchored == 0 && unchanged && stayed
                && outside == 0 && !duplicate && entered && closed == 0
            print("AT-JO-11 \(reported ? "PASS":"FAIL") ready=\(ready.count)/\(nearby.count) oldTargetAnchoredRequests=\(anchored) recentUnchanged=\(unchanged) viewUnchanged=\(stayed) originChange=\(originChange) visibleChange=\(visibleChange) outside=\(outside) duplicate=\(duplicate) entered=\(entered) closed=\(closed)")
            func clickMeasured(_ card:TodoDrawerModel.Card,expectWait:Bool) async throws -> (earliest:Int?,drawn:Int?,earlyMotion:CGFloat,moves:Int,rebounds:Int) {
                view.setDrawerState(open:true,chatExpanded:true)
                try await wait("delayed click starts idle") { !loader.busy && !model.history.refreshing }
                guard let key = card.key,let message = card.messageID else { throw HistoryFailure.invalidResponse }
                scroll(bottom())
                let oldRoom = model.selectionIdentity
                let before = view.history.contentView.bounds.minY
                var earliest: Int?, drawn: Int?
                var earlyMotion: CGFloat = 0
                var samples: [CGFloat] = []
                let list = view.history
                view.history.reduceMotion = { false }
                let realClock = list.clock
                var time = realClock()
                list.clock = { time }
                defer { list.clock = realClock }
                view.selectDrawerCard(card)
                layout()
                let entryOrigin = oldRoom == key.employee ? before : view.history.contentView.bounds.minY
                samples.append(entryOrigin)
                for tick in 0..<120 {
                    if tick > 0 {
                        try await Task.sleep(nanoseconds:16_666_667)
                        time += 1.0/60
                    }
                    list.advanceScroll()
                    layout()
                    let origin = list.contentView.bounds.minY
                    samples.append(origin)
                    if rendered(message),let frame = list.frame(for:key.thread,message:message) {
                        if drawn == nil { drawn = tick }
                        let goal = max(0,min(frame.midY-list.contentView.bounds.height/2,max(0,bottom())))
                        let distance = abs(goal - origin)
                        if distance <= 1 && earliest == nil { earliest = tick }
                    } else {
                        if expectWait && drawn == nil { earlyMotion = max(earlyMotion,abs(origin-entryOrigin)) }
                    }
                }
                var moves = 0, rebounds = 0, stationary = 3
                var direction: CGFloat = 0
                for (previous,current) in zip(samples,samples.dropFirst()) {
                    let delta = current-previous
                    if abs(delta) <= 0.5 { stationary += 1; continue }
                    if stationary >= 3 { moves += 1 }
                    if direction != 0 && (delta > 0) != (direction > 0) { rebounds += 1 }
                    direction = delta
                    stationary = 0
                }
                return (earliest,drawn,earlyMotion,moves,rebounds)
            }
            let nearbyCards = cards.map(\.card).filter { card in card.key.map { nearby.contains($0) } == true }
            if fixture.scenario == "jump-prefetch-delay" {
                try await control("prefetch-link-delay")
                for isRemote in [false,true] {
                    let candidates = isRemote ? cards.map(\.card):nearbyCards
                    if let card = candidates.first(where: { card in
                        (card.employee == "beta") == isRemote && card.messageID.map { model.messages[$0] != nil } == true
                    }) {
                        let result = try await clickMeasured(card,expectWait:false)
                        let pass = result.earliest.map { isRemote ? $0 == result.drawn : $0 <= 18 && result.rebounds == 0 } ?? false
                        print("AT-JO-12 \(isRemote ? "other":"same") room \(pass ? "PASS":"FAIL") arrived=\(String(describing:result.earliest)) frameLimit=18 rebounds=\(result.rebounds)")
                    } else {
                        print("AT-JO-12 \(isRemote ? "other":"same") room FAIL no prepared target")
                    }
                }
                try await control("prefetch-clear-delay")
                view.chooseEmployee(first.employee)
                try await wait("old card room idle") { !loader.busy && !model.history.refreshing }
                try await control("prefetch-old-delay")
                guard let old = nearbyCards.first(where: { $0.messageID == rows[10] }) else { throw HistoryFailure.invalidResponse }
                let result = try await clickMeasured(old,expectWait:true)
                let pass = result.earlyMotion <= 0.5 && result.moves == 1 && result.rebounds == 0
                    && (result.earliest ?? 999) - (result.drawn ?? 0) <= 18
                print("AT-JO-12 outside recent page \(pass ? "PASS":"FAIL") settled=\(String(describing:result.earliest)) drawn=\(String(describing:result.drawn)) earlyMotion=\(result.earlyMotion) moves=\(result.moves) rebounds=\(result.rebounds)")
                try await control("prefetch-clear-delay")
            } else if fixture.scenario == "jump-prefetch-error" {
                let errorTarget = fixture.threads[5]
                let calls = try await observe().requests.dropFirst(offset).filter {
                    $0.kind == "resolve" && $0.threadTarget == true && $0.thread == errorTarget
                }
                let quiet = calls.count == 1 && loader.failure == nil && !ready.isEmpty
                print("AT-JO-13 error \(quiet ? "PASS":"FAIL") requests=\(calls.count) globalError=\(loader.failure != nil) otherPrepared=\(ready.count)")
                if let failedCard = nearbyCards.first(where: { $0.key?.thread == errorTarget }) {
                    try await control("prefetch-old-delay")
                    let result = try await clickMeasured(failedCard,expectWait:true)
                    let pass = result.earlyMotion <= 0.5 && result.moves == 1 && result.rebounds == 0
                        && (result.earliest ?? 999) - (result.drawn ?? 0) <= 18
                    print("AT-JO-13 error click \(pass ? "PASS":"FAIL") settled=\(String(describing:result.earliest)) earlyMotion=\(result.earlyMotion) moves=\(result.moves) rebounds=\(result.rebounds)")
                }
            } else if fixture.scenario == "jump-prefetch-budget" {
                let evicted = nearbyCards.filter { card in
                    card.messageID.map { model.evictedHistoryBodies[$0] != nil } == true
                }
                let addedPins = model.residentBudget.pins.subtracting(initialPins).count
                print("AT-JO-13 eviction \(!evicted.isEmpty && addedPins == 0 ? "PASS":"FAIL") evicted=\(evicted.count) addedPins=\(addedPins)")
                if let card = evicted.first {
                    try await control("prefetch-old-delay")
                    let result = try await clickMeasured(card,expectWait:true)
                    let pass = result.earlyMotion <= 0.5 && result.moves == 1 && result.rebounds == 0
                        && (result.earliest ?? 999) - (result.drawn ?? 0) <= 18
                    print("AT-JO-13 evicted click \(pass ? "PASS":"FAIL") settled=\(String(describing:result.earliest)) earlyMotion=\(result.earlyMotion) moves=\(result.moves) rebounds=\(result.rebounds)")
                }
            }
        case "jump-status":
            view.drawerShownWidth = PetController.drawerWidth
            view.setDrawerState(open:true,chatExpanded:true)
            view.refresh()
            layout()
            let card = TodoDrawerModel.Card(id:"fixture-status",kind:.alert,title:"Fixture",
                employee:first.employee,name:"Fixture",status:"",statusUrgent:false,trailing:"",
                key:first,messageID:rows[0],order:clock,urgent:false)
            let baseline = TodoDrawerModel.Snapshot(urgent:[card])
            func position(_ snapshot: TodoDrawerModel.Snapshot) throws -> CGRect {
                view.todoDrawer.show(snapshot,filter:.all,selected:nil)
                view.todoDrawer.layoutSubtreeIfNeeded()
                guard let card = view.todoDrawer.cardViews.first else { throw HistoryFailure.invalidResponse }
                return card.convert(card.bounds,to:nil)
            }
            let before = try position(baseline)
            var updating = baseline
            updating.historyUpdating = true
            let refreshPosition = try position(updating)
            let drawerRefreshLabel = HistoryJumpStatusHarness.labels(in:view.todoDrawer).contains("대화 알림을 갱신 중이에요.")
            var needsUpdate = baseline
            needsUpdate.gateStatus = .updateRequired
            var readFailed = baseline
            readFailed.failed = true
            var closeFailed = baseline
            closeFailed.closeFailed = true
            for (name,snapshot) in [("update-required",needsUpdate),("read-failure",readFailed),("close-failure",closeFailed)] {
                let shifted = try position(snapshot)
                if name == "read-failure" {
                    try HistoryJumpStatusHarness.saveScreenshot(of:view,named:"drawer-read-failure")
                }
                let restored = try position(baseline)
                let movement = max(abs(shifted.minY - before.minY),abs(restored.minY - before.minY))
                print("AT-JO-15 \(name) movement=\(movement)")
            }
            view.history.onLoadViewport = nil
            try await wait("AT-JO-14 ready idle") { !loader.busy && !model.history.refreshing }
            guard let initialContext = model.history.context else { throw HistoryFailure.changed }
            let page = try await client.history.query(context:initialContext,kind:"messages",scope:first.employee,
                fields:["target":["room":first.employee,"thread":first.thread]])
            try model.applyHistoryMessages(page,key:first,context:initialContext,generation:model.history.generation)
            view.refresh()
            layout()
            try require(rendered(rows[0]),"AT-JO-14 target prepared")
            try await control("jump-refresh-delay")
            let offset = try await observe().requests.count
            view.selectDrawerCard(card)
            try await wait("AT-JO-14 refresh begins") { loader.busy && model.history.refreshing }
            layout()
            let conversationUpdateLabel = HistoryJumpStatusHarness.labels(in:view).contains("대화를 갱신하고 있어요")
            let hasInlineUpdate = view.history.contents.contains { $0.id.contains("history-status") }
            try HistoryJumpStatusHarness.saveScreenshot(of:view,named:"refresh")
            var missingTarget = false
            var largestGap: CGFloat = 0
            var measuredAfterPlacement = false
            for _ in 0..<120 {
                if !rendered(rows[0]) {
                    missingTarget = true
                } else if let target = view.history.frame(for:first.thread,message:rows[0]) {
                    let list = view.history
                    let expected = max(0,min(target.midY-list.contentView.bounds.height/2,max(0,bottom())))
                    let gap = abs(expected-list.contentView.bounds.minY)
                    measuredAfterPlacement = measuredAfterPlacement || gap <= 1
                    if measuredAfterPlacement { largestGap = max(largestGap,gap) }
                }
                if !loader.busy && !model.history.refreshing { break }
                try await Task.sleep(nanoseconds:16_666_667)
                layout()
            }
            let refetches = try await observe().requests.dropFirst(offset).filter {
                $0.anchor == rows[0] || $0.restoreID == rows[0]
            }.count
            let cleared = !HistoryJumpStatusHarness.labels(in:view).contains("대화를 갱신하고 있어요")
            print("AT-JO-14 target missing=\(missingTarget) refetches=\(refetches) placement=\(measuredAfterPlacement) gap=\(largestGap) conversationAccessibility=\(conversationUpdateLabel) inlineUpdate=\(hasInlineUpdate) cleared=\(cleared)")
            try await wait("AT-JO-14 refresh finishes") { !loader.busy && !model.history.refreshing }
            try await control("prefetch-clear-delay")
            try await control("fail-refresh")
            loader.retry()
            try await wait("history failure") { loader.failure != nil }
            layout()
            let failureRow = view.history.contents.first { $0.id.contains("history-status") }
            try HistoryJumpStatusHarness.saveScreenshot(of:view,named:"failure")
            let beforeRetry = try await observe().requests.count
            try await control("refresh")
            // The reference has its retry button in a history list row.
            let inlineRetry = failureRow?.top.compactMap { piece -> FileChip? in
                guard case .accessory(let id,_,let make) = piece,id == "history-retry" else { return nil }
                return make() as? FileChip
            }.first
            func retryButton(in view:NSView) -> NSButton? {
                if let button = view as? NSButton,button.title == "다시 시도",{ !button.isHiddenOrHasHiddenAncestor }() { return button }
                return view.subviews.lazy.compactMap { retryButton(in:$0) }.first
            }
            if let inlineRetry { inlineRetry.invoke?() }
            else if let button = retryButton(in:view) { button.performClick(nil) }
            else { throw HistoryFailure.server("AT-JO-15 retry control missing",retryable:false) }
            try await wait("history retry succeeds") { loader.failure == nil && !loader.busy && !model.history.refreshing }
            let refreshes = try await observe().requests.dropFirst(beforeRetry).filter { $0.kind == "overview" }.count
            print("AT-JO-14 refresh drawer shift=\(abs(refreshPosition.minY - before.minY)) accessibility=\(drawerRefreshLabel)")
            print("AT-JO-15 conversation inline failure row=\(failureRow != nil) retryRefreshes=\(refreshes)")
        case "jump-stream", "jump-stream-interleave", "jump-stream-reconnect":
            let stream = try JSONDecoder().decode(LiveThread.self,from:await control("stream-open"))
            let key = ConversationKey(employee:first.employee,thread:stream.thread)
            try await wait("stream first summary") { model.history.summaries[key] != nil && !loader.busy }
            view.openFromBubble(key)
            try await settle()
            try await wait("stream refresh settled") { !loader.busy && !model.history.refreshing }
            var renderedText: [String] = []
            view.drawerShownWidth = PetController.drawerWidth
            view.setDrawerState(open:true,chatExpanded:true)
            view.refresh()
            layout()
            try await wait("drawer opened before stream") { !loader.busy && !model.history.refreshing }
            var editCount = 0
            var refreshFrames = 0
            view.reduceMotion = { true }
            func settledSummary() -> [String:Any] {
                guard let summary = model.history.summaries[key],let totals = model.history.totals[key.employee] else { return [:] }
                return [
                    "unread":totals.unread,"alerts":totals.alerts,"questions":totals.questions,
                    "title":summary.title,"preview":summary.preview,"working":summary.activity.working,
                    "bell":summary.bell.map { $0 as Any } ?? NSNull(),
                    "request":summary.assessment.requestID != nil,"pending":summary.assessment.pendingID != nil,
                    "assessmentWorking":summary.assessment.working,"settled":summary.assessment.settled,
                    "approved":summary.assessment.approved,"waiting":summary.waitingButtonCount
                ]
            }
            func presentation() throws -> Data {
                let drawer = controller.drawerSnapshot
                return try JSONSerialization.data(withJSONObject:[
                    "summary":settledSummary(),"order":model.rooms.map(\.id),
                    "cards":(drawer.urgent+drawer.rest).map { [$0.id,$0.title,$0.trailing] }
                ],options:.sortedKeys)
            }
            let initialPresentation = try presentation()
            var changedPresentations = 0
            let handleFrame = client.onHistoryFrame
            client.onHistoryFrame = { frame in
                try handleFrame?(frame)
                guard frame["type"] as? String == "edit", frame["msg_id"] as? String == stream.root else { return }
                if frame["final"] as? Bool == false {
                    editCount += 1
                    let labels = HistoryJumpStatusHarness.labels(in:view)
                    if labels.contains("대화를 갱신하고 있어요") || labels.contains("대화 알림을 갱신 중이에요.") {
                        refreshFrames += 1
                    }
                    if try presentation() != initialPresentation { changedPresentations += 1 }
                }
                let thread = view.history.contents.first { $0.id == stream.thread }
                let displayed = (thread?.top ?? []).compactMap { piece -> String? in
                    guard case .post(let post) = piece,post.id == stream.root else { return nil }
                    return post.text.string
                }.first
                let workingText = (thread?.replies ?? []).compactMap { piece -> String? in
                    guard case .accessory(let id,_,let make) = piece,id == stream.thread+":work",
                          let working = make() as? WorkingControlRow else { return nil }
                    return working.row.accessibilityLabel()
                }.first
                if let text = displayed ?? workingText,renderedText.last != text { renderedText.append(text) }
            }
            defer { client.onHistoryFrame = handleFrame }
            let offset = try await observe().requests.count
            let session = client.historySession
            try await control("stream-run")
            if fixture.scenario == "jump-stream-reconnect" {
                try await wait("stream reconnected") {
                    client.isConnected && client.historySession != session && model.history.summaries[key] != nil && !loader.busy
                }
            } else {
                try await wait("stream final applied") { model.messages[stream.root]?.finalized == true && !loader.busy }
            }
            let observation = try await observe()
            guard let end = observation.streamFinal ?? observation.streamDisconnect,let start = observation.streamTimes?.first else {
                throw HistoryFailure.invalidResponse
            }
            let aggregates = Set(["overview","threads","notices","questions"])
            let requests = observation.requests.dropFirst(offset).filter { aggregates.contains($0.kind) }
            let during = requests.filter { request in request.time.map { $0 >= start && $0 < end } ?? false }
            let after = requests.filter { request in request.time.map { $0 >= end } ?? false }
            try require(editCount == 30,"AT-JO-18 30 fragments received")
            let afterOverview = after.filter { $0.kind == "overview" }.count
            let pass: Bool
            if let interleave = observation.streamInterleave {
                let before = during.filter { ($0.time ?? 0) < interleave }
                let requestsFromNewPost = during.filter { $0.kind == "overview" && ($0.time ?? 0) >= interleave }
                pass = before.isEmpty && !requestsFromNewPost.isEmpty && renderedText.count >= 30
            } else if observation.streamDisconnect != nil {
                pass = during.isEmpty && afterOverview >= 1 && client.historySession != session
            } else {
                pass = during.isEmpty && refreshFrames == 0 && changedPresentations == 0
                    && renderedText.count >= 30 && (1...2).contains(afterOverview)
            }
            let summary = settledSummary()
            try require(!summary.isEmpty,"AT-JO-18 requires final aggregate values")
            let canonical = try JSONSerialization.data(withJSONObject:summary,options:.sortedKeys)
            print("AT-JO-18 \(fixture.scenario) \(pass ? "PASS":"FAIL") edits=\(editCount) renderedChanges=\(renderedText.count) refreshFrames=\(refreshFrames) during=\(during.count) afterOverview=\(afterOverview) presentationChanges=\(changedPresentations)")
            print("AT-JO-18 canonical " + String(decoding:canonical,as:UTF8.self))
        case "jump-ready-middle", "jump-ready-edge", "jump-reduced-motion-interior", "jump-height",
             "jump-entry-question", "jump-entry-worker", "jump-entry-bubble", "jump-entry-search", "jump-entry-notice":
            view.history.onLoadViewport = nil
            try await wait("jump_reduced_idle") { !loader.busy && model.history.context != nil }
            guard let context = model.history.context else { throw HistoryFailure.changed }
            let generation = model.history.generation
            for id in fixture.threads {
                let key = ConversationKey(employee:first.employee,thread:id)
                let page = try await client.history.query(context:context,kind:"messages",scope:key.employee,
                                                          fields:["target":["room":key.employee,"thread":key.thread]])
                try model.applyHistoryMessages(page,key:key,context:context,generation:generation)
            }
            view.refresh()
            layout()
            try await settle()
            try await wait("jump_ready_idle") { !loader.busy && !model.history.refreshing }
            let edge = fixture.scenario == "jump-ready-edge"
            let reducedMotion = fixture.scenario == "jump-reduced-motion-interior"
            let entry = fixture.scenario.hasPrefix("jump-entry-") ? String(fixture.scenario.dropFirst("jump-entry-".count)) : nil
            let cardOnly = entry == "worker" || entry == "bubble"
            let addingHeight = fixture.scenario == "jump-height"
            let testID = entry.map { "AT-JO-08 " + $0 } ?? (addingHeight ? "AT-JO-03" : edge ? "AT-JO-01b" : reducedMotion ? "AT-JO-09" : "AT-JO-01")
            let targetIndex = edge ? 0 : 5
            let targetThread = fixture.threads[targetIndex]
            guard let root = fixture.rows[targetThread]?.first else { throw HistoryFailure.invalidResponse }
            let target = ConversationKey(employee:first.employee,thread:targetThread)
            let list = view.history
            func goal() throws -> CGFloat {
                guard let index = list.contents.firstIndex(where: { $0.id == target.thread }),
                      list.layouts.indices.contains(index) else { throw HistoryFailure.invalidResponse }
                let row = list.table.rect(ofRow:index)
                let midpoint: CGFloat
                if cardOnly {
                    midpoint = row.midY
                } else {
                    guard let post = list.layouts[index].anchors[root] else {
                        throw HistoryFailure.server("target post frame missing",retryable:false)
                    }
                    midpoint = row.minY + post.midY
                }
                let viewportHeight = list.contentView.bounds.height
                return max(0,min(midpoint - viewportHeight/2,max(0,list.table.bounds.height - viewportHeight)))
            }
            let cardHeight = fixture.threads.compactMap { list.frame(for:$0)?.height }.reduce(0,+)
            try require(cardHeight >= 3 * list.contentView.bounds.height,"AT-JO-09 12 cards span at least three viewports")
            scroll(bottom())
            let initialGoal = try goal()
            guard let cardFrame = list.frame(for:target.thread) else { throw HistoryFailure.invalidResponse }
            let clipHeight = list.contentView.bounds.height
            let maximum = bottom()
            let cardGoal = max(0,min(cardFrame.midY - clipHeight/2,maximum))
            if edge {
                try require(initialGoal == 0 && cardGoal == 0,"AT-JO-01b clamped edge")
            } else {
                try require([initialGoal,cardGoal].allSatisfy { 300...maximum-300 ~= $0 }
                    && (cardOnly || abs(initialGoal - cardGoal) >= 50),"interior fixture")
            }
            let card = TodoDrawerModel.Card(id:root,kind:.alert,title:"Fixture",employee:target.employee,name:"Fixture",
                                            status:"",statusUrgent:false,trailing:"",key:target,messageID:root,
                                            order:clock,urgent:false)
            let frameInterval = 1.0/60
            var frameTime = ProcessInfo.processInfo.systemUptime
            list.reduceMotion = { reducedMotion }
            list.clock = { frameTime }
            defer { list.clock = { ProcessInfo.processInfo.systemUptime } }
            try require(!loader.busy && !model.history.refreshing,"queue idle before E1")
            let initialOrigin = list.contentView.bounds.minY
            try require(abs(initialOrigin - initialGoal) >= 300,"starts at least 300pt away")
            var samples = [(origin:initialOrigin,distance:abs(initialOrigin - initialGoal))]
            let start = ProcessInfo.processInfo.systemUptime
            switch entry {
            case "question": view.activateIsland(.question(root,target))
            case "worker": view.activateIsland(.worker(target))
            case "bubble": view.openFromBubble(target)
            case "search": view.revealHistorySearch(target,id:root)
            case "notice":
                guard let notice = model.notices(first.employee).first(where: { $0.messages.contains(root) }) else {
                    throw HistoryFailure.server("fixture notice missing",retryable:false)
                }
                view.jumpNotice(notice)
            default: view.selectDrawerCard(card)
            }
            let growingThreads = [fixture.threads[2],fixture.threads[3]]
            var changed = false
            var settledAt: Int?
            for tick in 1...(addingHeight ? 120 : 90) {
                let remaining = start + Double(tick)*frameInterval - ProcessInfo.processInfo.systemUptime
                if remaining > 0 { try await Task.sleep(nanoseconds:UInt64(remaining * 1_000_000_000)) }
                frameTime += frameInterval
                list.advanceScroll()
                layout()
                let origin = list.contentView.bounds.minY
                let distance = abs(origin - (try goal()))
                samples.append((origin,distance))
                if addingHeight {
                    if distance > 1 { settledAt = nil }
                    else if settledAt == nil { settledAt = tick }
                    if tick == 6 || (!changed && settledAt.map { tick - $0 == 18 } == true) {
                        let id = growingThreads[changed ? 1:0]
                        guard let row = list.contents.firstIndex(where: {$0.id == id}) else {
                            throw HistoryFailure.invalidResponse
                        }
                        let before = list.table.rect(ofRow:row).height
                        var cards = list.contents
                        cards[row].top.append(.accessory(id:"fixture-height-"+id,height:110,view:{ NSView() }))
                        list.show(cards,identity:model.selectionIdentity,historyMode:true)
                        layout()
                        let after = list.table.rect(ofRow:row).height
                        print("AT-JO-03 injected tick=\(tick) delta=\(after-before)")
                        if tick != 6 { changed = true }
                    }
                }
            }
            var advances = 0
            var stationaryFrames = 3
            var rebounds = 0
            for (before,after) in zip(samples,samples.dropFirst()) {
                if abs(after.origin - before.origin) > 0.5 {
                    if stationaryFrames >= 3 { advances += 1 }
                    stationaryFrames = 0
                } else {
                    stationaryFrames += 1
                }
                if stationaryFrames < 3 && after.distance - before.distance > 0.5 { rebounds += 1 }
            }
            let settled = (samples.lastIndex { $0.distance > 1 }.map { $0 + 1 }) ?? 0
            let settlesQuickly = settled <= 18
            let stableAfterSettling = settled + 60 < samples.count &&
                samples[settled...(settled+60)].allSatisfy { abs($0.origin - samples[settled].origin) <= 0.5 }
            let passed: Bool
            if addingHeight {
                passed = changed && rebounds == 0 && (samples.last?.distance ?? .infinity) <= 1
            } else {
                passed = rebounds == 0 && (edge ? advances <= 1 : advances == 1)
                    && (reducedMotion || settlesQuickly)
                    && (edge || reducedMotion || stableAfterSettling)
            }
            print("\(testID) cardHeightSum=\(cardHeight) viewport=\(clipHeight) maximum=\(maximum) cardGoal=\(cardGoal) messageGoal=\(initialGoal)")
            for (tick,sample) in samples.enumerated() {
                print("\(testID) sample=\(tick) origin=\(sample.origin) distance=\(sample.distance)")
            }
            print("\(testID) \(passed ? "PASS":"FAIL") moves=\(advances) rebounds=\(rebounds) settleFrame=\(settled) stableAfterSettling=\(stableAfterSettling)")
        case "jump-assumptions":
            guard let other = fixture.other, let otherRoot = fixture.otherRoot,
                  let context = model.history.context else { throw HistoryFailure.invalidResponse }
            let remote = ConversationKey(employee:"beta",thread:other)
            let generation = model.history.generation
            func resolve(_ key: ConversationKey, anchor: String) async throws -> [String:Any] {
                try await client.history.query(context:context,kind:"resolve",scope:key.employee,
                    fields:["target":["room":key.employee,"thread":key.thread],"anchor":anchor])
            }
            func body(_ key: ConversationKey, id: String) async throws -> [String:Any] {
                let result = try await client.history.query(context:context,kind:"resolve",scope:key.employee,
                                                          fields:["target":[id],"limit":1])
                guard let row = (result["items"] as? [[String:Any]])?.first,
                      row["missing"] as? Bool != true else { throw HistoryFailure.invalidResponse }
                return row
            }
            func hasFrame(_ key: ConversationKey, _ id: String) -> Bool {
                zip(view.history.contents,view.history.layouts).contains {
                    $0.0.id == key.thread && $0.1.anchors[id] != nil
                }
            }
            func drawerCard(_ key: ConversationKey, _ id: String) -> TodoDrawerModel.Card {
                .init(id:id,kind:.alert,title:"Fixture",employee:key.employee,name:"Fixture",
                      status:"",statusUrgent:false,trailing:"",key:key,messageID:id,
                      order:clock,urgent:false)
            }
            view.history.onLoadViewport = nil
            try await wait("jump_idle") { !loader.busy }
            let page = try await resolve(remote,anchor:otherRoot)
            try model.applyHistoryMessages(page,key:remote,context:context,generation:generation,anchor:otherRoot)
            try model.applyHistoryBody(await body(remote,id:otherRoot),expectedKey:remote)
            try require(model.history.threadPages[remote.employee] == nil,"G-1 no remote thread list")
            view.selectDrawerCard(drawerCard(remote,otherRoot))
            layout()
            let remoteDrawn = hasFrame(remote,otherRoot)
            let remoteCardCount = view.history.contents.filter { model.history.summaries[.init(employee:"beta",thread:$0.id)] != nil }.count
            print("G-1 first frame=\(remoteDrawn) cards=\(remoteCardCount) room-list=false")
            try await wait("jump_remote_idle") { !loader.busy }

            guard let localContext = model.history.context else { throw HistoryFailure.changed }
            let localTarget = ["room":first.employee,"thread":first.thread]
            let initialPage = try await client.history.query(context:localContext,kind:"messages",scope:first.employee,
                                                              fields:["target":localTarget])
            try model.applyHistoryMessages(initialPage,key:first,context:localContext,generation:model.history.generation)
            view.openFromBubble(first)
            layout()
            try await wait("jump_local_idle") { !loader.busy && model.history.context != nil }
            let target = rows[10]
            let repliesBefore = model.historyReplyIDs(first)
            let postsBefore = displayedReplies(first.thread)
            guard let contextBefore = model.history.context else { throw HistoryFailure.changed }
            let generationBefore = model.history.generation
            let latestPage = try await client.history.query(context:contextBefore,kind:"messages",scope:first.employee,
                                                             fields:["target":localTarget])
            let anchoredPage = try await client.history.query(context:contextBefore,kind:"resolve",scope:first.employee,
                                                               fields:["target":localTarget,"anchor":target])
            let read = try await client.history.query(context:contextBefore,kind:"resolve",scope:first.employee,
                                                     fields:["target":[target],"limit":1])
            guard let targetBody = (read["items"] as? [[String:Any]])?.first else {
                throw HistoryFailure.invalidResponse
            }
            try await settle()
            try require(view.history.frame(for:first.thread)?.intersects(view.history.contentView.bounds) == true
                        && !repliesBefore.contains(target) && !hasFrame(first,target) && !postsBefore.isEmpty,
                        "G-2 target outside visible thread's loaded reply window")
            try model.applyHistoryBody(targetBody,expectedKey:first)
            view.refresh()
            layout()
            let bodyOnlyReady = hasFrame(first,target)
            let preserved = displayedReplies(first.thread) == postsBefore && model.historyReplyIDs(first) == repliesBefore
            print("G-2 body-only resident=\(model.messages[target] != nil) composition-preserved=\(preserved) target-frame=\(bodyOnlyReady)")

            try model.applyHistoryMessages(anchoredPage,key:first,context:contextBefore,generation:generationBefore,anchor:target)
            view.refresh()
            layout()
            let openingChangesComposition = displayedReplies(first.thread) != postsBefore
            let openingDrawsTarget = hasFrame(first,target)
            print("G-2 anchored page changes visible composition=\(openingChangesComposition) target-frame=\(openingDrawsTarget)")

            try model.applyHistoryMessages(latestPage,key:first,context:contextBefore,generation:generationBefore)
            try model.applyHistoryBody(targetBody,expectedKey:first)
            view.refresh()
            layout()
            try require(displayedReplies(first.thread) == postsBefore && !hasFrame(first,target),
                        "G-2 restore visible window before the E1 timing trace")
            model.select(chosen,markRead:false)
            try await wait("jump_selection_baseline") { model.selected == chosen && !loader.busy }
            try await settle()
            try require(!hasFrame(first,target),"E1 target still outside the displayed reply window")
            let requestOffset = try await observe().requests.count
            let clip = view.history.contentView
            let initialOrigin = clip.bounds.minY
            if let now = ThreeTapDiagnostics.timestamp() {
                ThreeTapDiagnostics.begin(frame:now,recognized:now,main:now)
            }
            let movementObserver = NotificationCenter.default.addObserver(
                forName:NSView.boundsDidChangeNotification,object:clip,queue:.main
            ) { _ in
                if abs(clip.bounds.minY - initialOrigin) > 0.5 { ThreeTapDiagnostics.moved() }
            }
            defer { NotificationCenter.default.removeObserver(movementObserver) }
            view.selectDrawerCard(drawerCard(first,target))
            layout()
            try await wait("jump_click_idle") { !loader.busy }
            try await settle()
            let requests = Array(try await observe().requests.dropFirst(requestOffset))
            let refreshes = requests.filter { $0.kind == "overview" }.count
            let opens = requests.filter { $0.kind == "resolve" && $0.anchor == target }.count
            ThreeTapDiagnostics.waitJitter("jump_once_click",view:"fixture",fields:[
                "refreshes":refreshes, "anchor_requests":opens, "target_frame":hasFrame(first,target),
                "requests":requests.map { request in
                    var row: [String:Any] = ["kind":request.kind,"scope":request.scope]
                    row["thread"] = request.thread
                    row["anchor"] = request.anchor
                    row["time"] = request.time
                    return row
                }
            ])
            ThreeTapDiagnostics.finished()
            print("E1 refreshes=\(refreshes) anchor_requests=\(opens) target-frame=\(hasFrame(first,target))")
            print("E1 request sequence: \(requests.map(\.kind).joined(separator:" → "))")
        case "basic":
            try await wait("initial_origin") { try await observe().held }
            try await settle()
            let initial = try await observe().requests
            let unread = model.rooms.map { model.unread(employee:$0.id) }
            let origin = view.history.contentView.bounds.origin
            let expanded = view.history.contents.filter(\.expanded).map(\.id)
            try await control("release")
            try await wait("root_cards") { rootIDs.allSatisfy(rendered) && !loader.busy }
            try await settle()
            let final = try await observe().requests
            try require(noOldButtons() && visibleThreads().count == 3,"AT-ALD-01")
            try require(model.selected == chosen && view.history.contents.filter(\.expanded).map(\.id) == expanded,
                        "AT-ALD-02 selected and expanded")
            try require(model.rooms.map { model.unread(employee:$0.id) } == unread,"AT-ALD-02 unread")
            try require(origin == view.history.contentView.bounds.origin,
                        "AT-ALD-02 origin \(origin) to \(view.history.contentView.bounds.origin)")
            try require(!final.dropFirst(initial.count).contains { $0.kind == "read_plan" },"AT-ALD-02 requests")
            try require(!final.contains { $0.kind == "copy" },"AT-ALD-17 automatic copy")
            let board = NSPasteboard(name:.init("autoload-fixture-"+UUID().uuidString))
            view.clipboardBoard = board
            let card = view.history.contents.first { $0.id == first.thread }
            guard let copy = card?.actions.first(where:{$0.identifier=="copy-"+first.thread}) else {
                throw HistoryFailure.invalidResponse
            }
            copy.invoke()
            try await wait("clipboard") { !view.historyCopyInProgress && board.string(forType:.string) != nil }
            let copied = board.string(forType:.string) ?? ""
            let copyRequests = try await observe().requests.filter { $0.kind == "copy" && $0.thread == first.thread }
            let date = ISO8601DateFormatter().date(from:"2026-01-01T00:00:00Z")!
            let stamp = DateFormatter()
            stamp.dateFormat = "yyyy-MM-dd HH:mm"
            stamp.locale = Locale(identifier:"en_US_POSIX")
            let display = model.name("alpha")
            let sections = (0...2).map { "[\(stamp.string(from:date))] \(display)\nfixture card 0 reply \($0)" }
            let header = "@\(display) 스레드 · 글 3개\nhejo://thread?room=alpha&thread=\(first.thread)"
            try require(copyRequests.filter { $0.action == "finalize" }.count == 1 &&
                        copied == ([header]+sections).joined(separator:"\n\n"),"AT-ALD-17 explicit copy")
            board.releaseGlobally()
        case "repeat":
            let stride = view.history.contentView.bounds.height*0.8
            for _ in 0..<3 {
                var position = view.history.contentView.bounds.minY
                while position > 0 {
                    position = max(0,position-stride)
                    scroll(position);try await settle()
                }
                while position < bottom() {
                    position = min(bottom(),position+stride)
                    scroll(position);try await settle()
                }
            }
            try await wait("all_cards") { rootIDs.allSatisfy(rendered) && !loader.busy }
            let before = try await observe().requests
            for key in fixture.threads where key != chosen.thread {
                try require(bodyRequests(before,for:key).count == 1,"AT-ALD-07 once")
            }
            for _ in 0..<3 {
                let context = model.history.context
                try await control("live")
                try await wait("repeat_refresh") { model.history.context != context && !loader.busy }
            }
            let after = try await observe().requests
            try require(!after.dropFirst(before.count).contains { $0.kind == "resolve" && $0.scope == "alpha" },
                        "AT-ALD-07 refresh")
        case "growth":
            try await wait("growth_held") { try await observe().held }
            let id = fixture.rows[chosen.thread]![0]
            scroll(frame(chosen.thread,id).minY+2)
            let offset = y(chosen.thread,id)
            try await control("release")
            try await wait("growth_loaded") { !loader.busy }
            try await settle()
            try require(rendered(id) && abs(y(chosen.thread,id)-offset) <= 1,
                        "AT-ALD-08 y \(offset) to \(y(chosen.thread,id))")
        case "delete":
            try await wait("delete_initial") { rendered(rows[0]) }
            try await control("delete")
            try await wait("deleted") { model.history.deletedThreads[first] != nil &&
                !view.history.contents.contains { $0.id == first.thread } }
        case "priority":
            try await wait("priority_held") { try await observe().held }
            let before = try await observe().requests
            let visible = visibleThreads(), nearby = visibleThreads(view.history.contentView.bounds.height)
            try await control("release")
            try await wait("priority_done") {
                let requests = try await observe().requests.dropFirst(before.count)
                let ids = requests.filter { $0.kind=="resolve" && $0.scope=="alpha" }.compactMap(\.thread)
                return ids.contains { visible.contains($0) } && ids.contains { nearby.subtracting(visible).contains($0) } &&
                    !loader.busy
            }
            try await settle()
            let after = try await observe().requests.dropFirst(before.count).filter { $0.kind == "resolve" && $0.scope == "alpha" }
            let ids = after.compactMap(\.thread)
            let visibleOffsets = ids.indices.filter { visible.contains(ids[$0]) }
            let prefetchOffsets = ids.indices.filter { nearby.subtracting(visible).contains(ids[$0]) }
            try require(visibleOffsets.last.map { last in prefetchOffsets.first.map { last < $0 } ?? true } ?? false,
                        "AT-ALD-24 visible priority")
        case "thread-pages", "budget":
            let count = fixture.threads.count
            let firstPage = try await observe().requests
            try require(!firstPage.contains { $0.kind=="threads" && $0.cursor },"AT-ALD-29 no automatic list request")
            var previousCount = view.history.contents.count
            for _ in 0..<((count+49)/50) {
                scroll(0)
                requestOlderList()
                try await settle()
                try await wait("list_page") { !loader.busy }
                let current = view.history.contents.count
                if current == previousCount { break }
                previousCount = current
            }
            let cards = Set(view.history.contents.map(\.id))
            try require(cards.isSuperset(of:fixture.threads),"AT-ALD-29 all cards")
            if fixture.scenario == "thread-pages" {
                scroll(0)
                try await wait("oldest_body") { rendered(rootIDs[0]) }
            } else {
                for key in fixture.threads {
                    guard let rect = view.history.frame(for:key) else {throw HistoryFailure.invalidResponse}
                    scroll(rect.minY)
                    try await wait("budget_idle") { !loader.busy }
                    let resident = model.residentBudget
                    let count = resident.ids.filter { !resident.pins.contains($0) }.count
                    try require(resident.bytes-resident.pinnedBytes <= 5*1024*1024 && count <= 500,"AT-ALD-20")
                }
                scroll(bottom())
                try await wait("budget_end_body") { model.messages[rootIDs.last!] != nil && !loader.busy }
                let resident = model.residentBudget
                try require(resident.bytes-resident.pinnedBytes <= 5*1024*1024 &&
                            resident.ids.filter { !resident.pins.contains($0) }.count <= 500,"AT-ALD-20 at end")
            }
        case "evicted":
            view.chooseThread(first)
            try await wait("evicted_open") { !loader.busy && model.evictedHistoryBodies.values.contains { $0.key == first } }
            let page = model.history.messagePages[first], unread = model.unread(first)
            let publish = view.history.onLoadViewport
            var entered = [String]()
            var previousVisible = Set<String>()
            var lastViewportChange = ProcessInfo.processInfo.systemUptime
            view.history.onLoadViewport = { cards in
                if !cards.isEmpty {
                    let visible = visibleBodies().intersection(rows)
                    if visible != previousVisible {
                        entered += visible.subtracting(previousVisible).sorted().filter { model.evictedHistoryBodies[$0] != nil }
                        previousVisible = visible
                        lastViewportChange = ProcessInfo.processInfo.systemUptime
                    }
                }
                publish?(cards)
            }
            defer { view.history.onLoadViewport = publish }
            for step in 0...3 {
                let before = try await observe().requests.count
                entered.removeAll(keepingCapacity:true)
                lastViewportChange = ProcessInfo.processInfo.systemUptime
                let bounds = view.history.contentView.bounds
                scroll(step == 0 ? 0:bounds.minY+bounds.height)
                try await wait("evicted_visible step \(step)") {
                    !loader.busy && ProcessInfo.processInfo.systemUptime-lastViewportChange > 0.9
                }
                if step == 0 {
                    clock.addTimeInterval(10)
                    loader.tick()
                    try await settle()
                }
                let requests = try await observe().requests.dropFirst(before)
                let restored = requests.compactMap(\.restoreID)
                let wanted = entered.compactMap { rows.firstIndex(of:$0) }
                let actual = restored.compactMap { rows.firstIndex(of:$0) }
                try require(restored.sorted() == entered.sorted(),
                            "AT-ALD-36 step \(step) visible entries \(wanted) requests \(actual)")
                try require(visibleBodies().intersection(rows).allSatisfy { model.messages[$0] != nil },
                            "AT-ALD-36 visible bodies restored")
            }
            try require(noOldButtons() && model.history.messagePages[first]?.next == page?.next &&
                        model.history.messagePages[first]?.complete == page?.complete && model.unread(first) == unread,"AT-ALD-16")
        case "prefetch-eviction":
            try await wait("prefetch_eviction") { !loader.busy && !model.evictedHistoryBodies.isEmpty }
            let offscreen = Set(model.evictedHistoryBodies.keys).subtracting(visibleBodies())
            try require(!offscreen.isEmpty,"AT-ALD-36 prefetch fixture")
            let before = try await observe().requests.count
            clock.addTimeInterval(10);loader.tick()
            try await settle()
            let restored = try await observe().requests.dropFirst(before).compactMap(\.restoreID)
            try require(offscreen.isDisjoint(with:restored),"AT-ALD-36 offscreen")
        case "retry-outside":
            try await wait("retry_outside_first") {
                try await bodyRequests(observe().requests,for:failing.thread).count == 1 && !loader.busy
            }
            scroll(0)
            try require(visibleThreads(view.history.contentView.bounds.height).contains(failing.thread) == false,
                        "AT-ALD-33 out of range")
            clock.addTimeInterval(61);loader.tick()
            try await settle()
            let after = try await observe().requests
            try require(bodyRequests(after,for:failing.thread).count == 1,"AT-ALD-33 no delayed request")
        case "held":
            try await wait("held") { try await observe().held }
            let card = view.history.contents.first { $0.id == fixture.threads[0] }
            let loading = card?.top.contains { piece in
                if case .accessory(_,_,let make) = piece, let label = make() as? NSTextField {
                    return label.stringValue.contains("불러오는 중…") && label.stringValue.contains("fixture")
                }
                return false
            }
            try require(loading == true && noOldButtons(),"AT-ALD-03")
            try await control("release")
            try await wait("released_body") { rootIDs.allSatisfy(rendered) }
        case "missing", "retry", "retry-fails":
            try await wait("first_round") {
                let requests = try await observe().requests
                return bodyRequests(requests,for:failing.thread).count == 1 && !loader.busy &&
                    rootIDs.filter { $0 != failureRoot }.allSatisfy(rendered)
            }
            try await settle()
            let firstRequests = try await observe().requests
            let count = bodyRequests(firstRequests,for:failing.thread).count
            if fixture.scenario == "missing" {
                try require(buttons(failing.thread,"다시 시도") == 1 && loader.failure == nil &&
                            labels(failing.thread).contains { $0.contains("fixture") && $0.contains("원문을 불러오지 못했어요") } &&
                            !view.history.contents.contains {$0.id=="empty"},"AT-ALD-04")
                scroll(0)
                scroll(bottom())
                try await settle()
                let afterScroll = try await observe().requests
                try require(bodyRequests(afterScroll,for:failing.thread).count == count,"AT-ALD-04 stopped")
                try await control("fail")
                try pressRetry(failing.thread)
            } else {
                try require(buttons(failing.thread,"다시 시도") == 0 && loader.failure == nil,"AT-ALD-33 waiting")
                clock.addTimeInterval(59)
                loader.tick()
                try await settle()
                let elapsed59 = try await observe().requests
                try require(bodyRequests(elapsed59,for:failing.thread).count == count,"AT-ALD-33 order")
                clock.addTimeInterval(2)
                loader.tick()
            }
            if fixture.scenario == "retry-fails" {
                try await wait("retry_failed") { buttons(failing.thread,"다시 시도") == 1 }
                clock.addTimeInterval(120)
                loader.tick()
                try await settle()
            } else {
                try await wait("retried") { rendered(failureRoot) && !loader.busy }
            }
            let final = try await observe().requests
            try require(bodyRequests(final,for:failing.thread).count == count+1 && loader.failure == nil,"AT-ALD-04/33/34 request count")
        case "long", "long-fail":
            if fixture.scenario == "long-fail" {
                try await wait("long_failure") { buttons(first.thread,"다시 시도") == 1 }
                let firstCount = try await observe().requests.filter { $0.kind == "content" }.count
                try require(rendered(rows[0]) && rendered(rows[2]),"AT-ALD-10 neighboring bodies")
                scroll(0);scroll(bottom())
                try await settle()
                let after = try await observe().requests
                try require(after.filter { $0.kind == "content" }.count == firstCount,"AT-ALD-10 no auto retry")
                try await control("content")
                try pressRetry(first.thread)
            }
            try await wait("long_content") { model.messages[rows[1]]?.text == String(repeating:"긴 글",count:12000) && rendered(rows[1]) }
            try require(noOldButtons(),"AT-ALD-09")
        case "viewport", "leave-room", "refresh-fails":
            try await wait("held") { try await observe().held }
            let before = try await observe().requests
            if fixture.scenario == "leave-room" { view.chooseEmployee("beta");layout() }
            else if fixture.scenario == "refresh-fails" {
                try await control("fail-refresh")
                try await control("live")
            } else { scroll(0) }
            try await control("release")
            if fixture.scenario == "refresh-fails" {
                try await wait("global_failure") { loader.failure != nil }
                let failed = try await observe().requests
                try require(failed.dropFirst(before.count).filter { $0.kind == "resolve" }.isEmpty,"AT-ALD-25 paused")
                try await control("refresh")
                loader.retry()
                try await wait("resume") {
                    let requests = try await observe().requests
                    return loader.failure == nil && !loader.busy &&
                        requests.dropFirst(failed.count).contains { $0.kind == "resolve" && $0.scope == "alpha" }
                }
                let resumed = try await observe().requests
                try require(resumed.dropFirst(failed.count).contains { $0.kind == "resolve" && $0.scope == "alpha" },"AT-ALD-25 resumed")
            } else {
                try await settle()
                if fixture.scenario == "viewport" {
                    try await wait("scrolled_card") { rendered(rootIDs[0]) && !loader.busy }
                }
                let after = try await observe().requests
                let sent = after.dropFirst(before.count).filter { $0.kind == "resolve" && $0.scope == "alpha" }
                if fixture.scenario == "leave-room" {
                    try require(sent.isEmpty,"AT-ALD-06")
                } else {
                    try require(Set(after.compactMap { $0.kind == "resolve" ? $0.thread : nil }).count < fixture.threads.count,"AT-ALD-05")
                    try require(rendered(rootIDs[0]),"AT-ALD-05 scrolled")
                }
            }
        case "refresh-count":
            scroll(0)
            try await settle()
            try require(model.selected == chosen &&
                        !visibleThreads(view.history.contentView.bounds.height).contains(chosen.thread),
                        "AT-ALD-25 selected outside prefetch")
            let before = try await observe().requests.count
            for _ in 0..<3 {
                let context = model.history.context
                try await control("live")
                try await wait("refresh_once") { model.history.context != context && !loader.busy }
                try await settle()
            }
            let after = try await observe().requests.dropFirst(before).filter { $0.thread == chosen.thread }
            try require(after.count == 3 && after.allSatisfy { $0.kind=="messages" && !$0.cursor && $0.anchor==nil },
                        "AT-ALD-25 selected refresh ownership")
        case "root-only":
            try await wait("stable_root_selection") {
                model.selected == first && !loader.busy && !model.history.refreshing
            }
            try require(model.messages[rows[0]] == nil &&
                        model.historyReplyIDs(first) == Array(rows[71...120]) &&
                        view.history.contents.first { $0.id == first.thread }?.expanded == false,
                        "AT-ALD-13/26 selected collapsed thread with an unloaded root")
            let before = try await observe().requests.count
            view.history.onLoadViewport = publishLoadViewport
            scroll(frame(first.thread,rows[0]).minY)
            try await wait("selected_root") { rendered(rows[0]) && !loader.busy }
            let requests = try await observe().requests.dropFirst(before)
            let rootRequests = bodyRequests(Array(requests),for:first.thread)
            try require(model.selected == first && rootRequests.count == 1 &&
                        rootRequests.first?.responseIDs == [rows[0]] &&
                        requests.filter { $0.kind == "messages" && $0.thread == first.thread && $0.cursor }.isEmpty,
                        "AT-ALD-13/26")
            try require(!loader.failed(.root(first)), "AT-ALD-26 successful root must leave the load target satisfied")
        case "older", "cursor-context", "cursor-expired", "cursor-far", "cursor-fails", "root-edge":
            let far = fixture.scenario == "cursor-far"
            let initialStart = far ? 50:71
            let initialEnd = far ? 149:120
            if far { view.revealHistorySearch(first,id:rows[100]) } else { view.chooseThread(first) }
            try await wait("opened") {
                model.historyReplyIDs(first) == Array(rows[initialStart...initialEnd]) && !loader.busy
            }
            try await settle()
            let before = try await observe().requests
            let openingPages = before.filter { $0.thread == first.thread && $0.cursor }
            try require(openingPages.count == (far ? 1:0),"AT-ALD-11/31 opening request count")
            try require(model.selected == first &&
                        view.history.contents.contains { $0.id==first.thread && $0.expanded },"AT-ALD-19")
            let pageStart = far ? 100:71
            try require(frame(first.thread,rows[initialEnd]).maxY-frame(first.thread,rows[pageStart]).minY > height*2,
                        "pagination fixture geometry")
            if ["cursor-context","cursor-far"].contains(fixture.scenario) {
                let original = model.history.context
                try await control("live")
                try await wait("context") { model.history.context != original && !loader.busy }
            }
            let afterRefresh = try await observe().requests.count
            let edge = rows[initialStart]
            let reference = fixture.scenario == "root-edge" ? rows[0]:edge
            scroll(frame(first.thread,reference).minY+2)
            let offset = y(first.thread,reference)
            if fixture.scenario == "cursor-fails" {
                try await wait("cursor_failure") { buttons(first.thread,"다시 시도") == 1 }
                let failed = try await observe().requests.dropFirst(afterRefresh)
                try require(failed.filter { $0.thread == first.thread && $0.cursor }.count == 3 &&
                            failed.filter { $0.thread == first.thread && !$0.cursor && $0.anchor == edge }.count == 2,"AT-ALD-32")
                let beforeWait = try await observe().requests.count
                clock.addTimeInterval(10)
                loader.tick()
                scroll(bottom())
                scroll(frame(first.thread,reference).minY+2)
                try await settle()
                let afterWait = try await observe().requests.dropFirst(beforeWait)
                try require(afterWait.allSatisfy { $0.thread != first.thread || $0.kind != "messages" } &&
                            buttons(first.thread,"다시 시도") == 1,"AT-ALD-32 no requests after ten seconds and scrolling")
                try await control("cursor")
                try pressRetry(first.thread)
            }
            let start = far || fixture.scenario == "root-edge" ? 1:21
            try await wait("previous") { model.historyReplyIDs(first).first == rows[start] && !loader.busy }
            try await settle()
            try require(abs(y(first.thread,reference)-offset) <= 1,"AT-ALD-12/37")
            let final = try await observe().requests.dropFirst(afterRefresh).filter { $0.thread == first.thread }
            if ["cursor-context","cursor-expired","cursor-far"].contains(fixture.scenario) {
                try require(final.filter { $0.anchor == edge && !$0.cursor }.count == 1,"AT-ALD-30/31 reanchor")
            }
            if far {
                try require(final.count == 2 && final.last?.responseIDs == Array(rows[0...49]),"AT-ALD-31 response")
            } else if fixture.scenario == "root-edge" {
                let responses = final.filter(\.cursor).compactMap(\.responseIDs)
                try require(responses == [Array(rows[21...70]),Array(rows[0...20])] &&
                            model.historyReplyIDs(first) == Array(rows.dropFirst()),"AT-ALD-37")
            } else {
                scroll(frame(first.thread,rows[start]).minY+2)
                try await wait("all_older") { model.historyReplyIDs(first) == Array(rows.dropFirst()) }
                try require(noOldButtons(),"AT-ALD-11")
                if fixture.scenario == "older" {
                    let requests = try await observe().requests.dropFirst(afterRefresh)
                    try require(requests.filter { $0.thread == first.thread && $0.cursor }.count == 2,"AT-ALD-11 requests")
                }
            }
        case "anchored", "anchored-last", "anchored-fail", "anchored-reopen", "anchored-live", "anchored-no-progress", "anchored-send", "jump-placement":
            view.revealHistorySearch(first,id:rows[120])
            try await wait("middle_open_held") { try await observe().held && model.historyReplyIDs(first) == Array(rows[120...169]) }
            try await settle()
            try require(frame(first.thread,rows[169]).maxY-frame(first.thread,rows[120]).minY > height*2,
                        "pagination fixture geometry")
            let openingY = y(first.thread,rows[120])
            try require(view.history.contentView.bounds.intersects(frame(first.thread,rows[120])),"AT-ALD-14 anchor visible")
            try await control("release")
            try await wait("initial_previous") { model.historyReplyIDs(first) == Array(rows[70...169]) && !loader.busy }
            try await settle()
            let opening = try await observe().requests.filter { $0.thread == first.thread && $0.cursor }
            try require(opening.count == 1 && opening.first?.responseIDs == Array(rows[70...119]) &&
                        abs(y(first.thread,rows[120])-openingY) <= 1,
                        "AT-ALD-14 opening previous page: requests=\(opening.count), firstCount=\(opening.first?.responseIDs?.count ?? -1), y=\(openingY)→\(y(first.thread,rows[120]))")
            if fixture.scenario == "anchored-send" || fixture.scenario == "jump-placement" {
                try require(displayedReplies(first.thread) == Array(rows[70...169]) &&
                            model.history.messagePages[first]?.newerCount == 131,"AT-ALD-41 initial reply window")
                let text = "fixture reply sent from the anchored window"
                let latest = Array(rows[251...300])
                let beforeSend = try await observe().requests.count
                controller.setText(text,for:first)
                view.send()
                try await wait("send_held") { try await observe().sendHeld }
                try await settle()
                let posts = replyPosts(first.thread)
                guard let pending = posts.last, pending.pending, pending.mine, pending.time == "보내는 중",
                      pending.text.string.contains(text), pending.id.hasPrefix("pending:") else {
                    throw HistoryFailure.server("AT-ALD-41 pending reply piece",retryable:false)
                }
                try require(posts.map(\.id) == latest + [pending.id],"AT-ALD-41 latest reply IDs while sending")
                let requests = try await observe().requests.dropFirst(beforeSend)
                try require(requests.filter { $0.kind == "resolve" && $0.thread == first.thread &&
                            $0.anchor == nil && $0.responseIDs == latest }.count == 1,"AT-ALD-41 anchorless opening")
                let pendingFrame = frame(first.thread,pending.id)
                let before = view.history.contentView.bounds
                try require(before.minY <= pendingFrame.minY && before.maxY >= pendingFrame.maxY,"AT-ALD-41 sending reply visible")
                let pendingY = pendingFrame.minY - before.minY
                let clientID = String(pending.id.dropFirst("pending:".count))
                try await control("release-send")
                try await wait("reply_confirmed") {
                    !loader.busy && model.timeline(first).contains { $0.clientMessageID == clientID }
                }
                try await settle()
                guard let confirmed = model.timeline(first).first(where:{ $0.clientMessageID == clientID }),
                      let posted = replyPosts(first.thread).last, posted.id == confirmed.id, !posted.pending else {
                    throw HistoryFailure.server("AT-ALD-41 confirmed reply piece",retryable:false)
                }
                try require(displayedReplies(first.thread) == latest + [confirmed.id],"AT-ALD-41 confirmed reply IDs")
                let confirmedFrame = frame(first.thread,confirmed.id)
                let after = view.history.contentView.bounds
                let confirmedY = confirmedFrame.minY - after.minY
                try require(after.minY <= confirmedFrame.minY && after.maxY >= confirmedFrame.maxY &&
                            abs(confirmedY - pendingY) <= 1,
                            "AT-ALD-41 confirmed reply position \(pendingY) -> \(confirmedY), viewport \(after)")
                if fixture.scenario == "jump-placement" {
                    let sentOrigin = view.history.contentView.bounds.minY
                    try clickCard(first)
                    try await settle()
                    try clickCard(first)
                    try await wait("AT-JO-10 thread opens") { !loader.busy && !model.history.refreshing }
                    try await settle()
                    let threadOrigin = view.history.contentView.bounds.minY
                    view.chooseEmployee("beta")
                    try await wait("AT-JO-10 room opens") { model.selectionIdentity == "beta" && !loader.busy && !model.history.refreshing }
                    try await settle()
                    let roomOrigin = view.history.contentView.bounds.minY
                    let data = try JSONSerialization.data(withJSONObject:[
                        "sent":sentOrigin,"thread":threadOrigin,"entry":roomOrigin
                    ],options:.sortedKeys)
                    print("AT-JO-10 canonical "+String(decoding:data,as:UTF8.self))
                }

                break
            }
            if fixture.scenario == "anchored-reopen" {
                try require(displayedReplies(first.thread) == Array(rows[70...169]),"AT-ALD-38 initial order")
                try clickCard(first)
                try require(view.history.contents.first { $0.id == first.thread }?.expanded == false,"AT-ALD-38 collapsed")
                try clickCard(first)
                try await wait("reopen_latest") { model.historyReplyIDs(first).last == rows[300] && !loader.busy }
                try await settle()
                try require(displayedReplies(first.thread) == Array(rows[251...300]),"AT-ALD-38 latest reply order")
                try require(rows[70...169].allSatisfy { model.messages[$0] == nil },"AT-ALD-38 dropped resident bodies")
                let beforeOlder = try await observe().requests.count
                scroll(frame(first.thread,rows[251]).minY+2)
                try await wait("reopen_prior") { model.historyReplyIDs(first).first == rows[201] && !loader.busy }
                try await settle()
                let previous = try await observe().requests.dropFirst(beforeOlder).filter { $0.thread == first.thread && $0.cursor }
                try require(previous.count == 1 && previous.first?.responseIDs == Array(rows[201...250]) &&
                            displayedReplies(first.thread) == Array(rows[201...300]),"AT-ALD-38 previous reply order")
                break
            }
            var liveID: String?
            if fixture.scenario == "anchored-live" {
                let incoming = try await sendLiveMessage()
                liveID = incoming
                try await wait("live_in_middle") { model.messages[incoming] != nil && !loader.busy }
                try await settle()
                try require(displayedReplies(first.thread) == Array(rows[70...169]) && !rendered(incoming),
                            "AT-ALD-39 live reply while history has a gap")
            }
            for (tail,newTail) in [(169,218),(218,267),(267,300)] {
                if fixture.scenario == "anchored-last" && tail == 169 { scroll(bottom()) }
                else { scroll(frame(first.thread,rows[tail]).maxY-view.history.contentView.bounds.height+20) }
                let offset = y(first.thread,rows[tail])
                if fixture.scenario == "anchored-fail" && tail == 218 {
                    try await wait("next_failure") { buttons(first.thread,"다시 시도") == 1 }
                    try require(model.historyReplyIDs(first).last == rows[218],"AT-ALD-27 stopped")
                    try await control("allow-newer")
                    try pressRetry(first.thread)
                }
                if fixture.scenario == "anchored-no-progress" && tail == 169 {
                    try await wait("next_no_progress") { buttons(first.thread,"다시 시도") == 1 && !loader.busy }
                    try await settle()
                    let requests = try await observe().requests.filter { $0.thread == first.thread && $0.anchor == rows[169] }
                    try require(requests.count == 1 && requests.first?.responseIDs == Array(rows[120...169]),
                                "V-8 successful response left the same target")
                    try await control("allow-newer")
                    try pressRetry(first.thread)
                }
                let reachedEnd = newTail == 300 ? liveID : nil
                let expectedIDs = Array(rows[70...newTail]) + [reachedEnd].compactMap { $0 }
                try await wait("next_page") { model.historyReplyIDs(first).last == expectedIDs.last }
                try await settle()
                try require(model.historyReplyIDs(first) == expectedIDs,"AT-ALD-15 contiguous")
                if liveID != nil {
                    try require(displayedReplies(first.thread) == expectedIDs,"AT-ALD-39 reply order as the gap closes")
                }
                if tail == 169 { try require(abs(y(first.thread,rows[tail])-offset) <= 1,"AT-ALD-14 next page position") }
            }
            try require(noOldButtons(),"AT-ALD-14 old buttons")
            let afterNext = try await observe().requests.filter { $0.thread == first.thread && $0.kind == "messages" }
            let expected = (fixture.scenario == "anchored-no-progress" ? [rows[169]]:[]) + [rows[169],rows[218]]
                + (fixture.scenario == "anchored-fail" ? [rows[218]]:[]) + [rows[267]]
            try require(afterNext.filter { !$0.cursor }.compactMap(\.anchor) == expected &&
                        afterNext.filter(\.cursor).count == 1,"AT-ALD-15 requests")
            if fixture.scenario == "anchored" {
                for (head,newHead) in [(70,20),(20,1)] {
                    scroll(frame(first.thread,rows[head]).minY+2)
                    try await wait("prior_after_next") { model.historyReplyIDs(first).first == rows[newHead] && !loader.busy }
                }
                let previous = try await observe().requests.filter { $0.thread == first.thread && $0.kind == "messages" }.dropFirst(afterNext.count)
                try require(previous.allSatisfy(\.cursor) &&
                            previous.compactMap(\.responseIDs) == [Array(rows[20...69]),Array(rows[0...19])] &&
                            model.historyReplyIDs(first) == Array(rows.dropFirst()) &&
                            displayedReplies(first.thread) == Array(rows.dropFirst()),"AT-ALD-28")
            }
        case "live-new-thread":
            try await wait("existing_room_ready") { rootIDs.allSatisfy(rendered) && !loader.busy }
            // Establish an explicit selection in the existing room before the live events.
            try clickCard(chosen)
            try await wait("existing_thread_selected") { model.selected == chosen && !loader.busy }
            try require(model.selected == chosen,"AT-ALD-40 original selection")
            let live = try JSONDecoder().decode(LiveThread.self,from:try await control("live-root"))
            let newKey = ConversationKey(employee:"alpha",thread:live.thread)
            try await wait("live_root") { rendered(live.root) && !loader.busy }
            try require(model.selected == chosen,"AT-ALD-40 selection before the replies")
            let replies = try JSONDecoder().decode([String].self,from:try await control("live-replies"))
            try await wait("live_replies_received") { replies.allSatisfy { model.messages[$0] != nil } && !loader.busy }
            try await settle()
            try require(rendered(live.root) && displayedReplies(live.thread).last == replies.last,
                        "AT-ALD-40 new thread shows live replies before opening")
            try clickCard(newKey)
            try await wait("new_thread_expanded") {
                view.history.contents.first { $0.id == live.thread }?.expanded == true && !loader.busy
            }
            try require(displayedReplies(live.thread) == replies,"AT-ALD-40 expanded reply order")
            let pages = try await observe().requests.filter { $0.thread == live.thread && ["messages","resolve"].contains($0.kind) }
            try require(pages.count <= 1,"AT-ALD-40 at most one thread page (observed \(pages.count))")
        case "live":
            try await wait("live_initial") { rendered(rows[10]) && !loader.busy }
            try require(model.historyReplyIDs(first) == Array(rows.dropFirst()),"AT-ALD-39 complete initial history")
            scroll(bottom())
            let incoming = try await sendLiveMessage()
            try await wait("held_live_refresh") { try await observe().held }
            try await settle()
            try require(displayedReplies(first.thread).last == incoming,
                        "AT-ALD-39 live reply before the refresh response")
            try await control("release-live-refresh")
            try await wait("live_refresh_finished") { !loader.busy }
            let visible = view.history.contentView.bounds
            try require(view.history.table.bounds.maxY-visible.maxY <= 2 &&
                        visible.minY <= frame(first.thread,incoming).maxY &&
                        visible.maxY >= frame(first.thread,incoming).maxY,"AT-ALD-35")
        default: throw HistoryFailure.invalidResponse
        }

        print("AUTOLOAD PASS \(fixture.scenario)")
    }
}
#endif
