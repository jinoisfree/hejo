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
    }

    private struct LiveThread: Decodable {
        let thread: String
        let root: String
    }

    private struct Request: Decodable {
        let kind: String
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
        let controller = try ConversationController(client:client,downloads:home.appendingPathComponent("downloads"),
                                                    residentBudget:budget)
        defer { controller.stop() }
        let model = controller.model
        let loader = controller.historyLoading
        let viewportCase = ["viewport","leave-room","refresh-fails","refresh-count","priority","retry-outside","evicted","prefetch-eviction"].contains(fixture.scenario)
        let height: CGFloat = fixture.scenario == "basic" ? 950:(viewportCase ? 540:700)
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

        func layout() {
            view.layoutSubtreeIfNeeded()
            view.history.layoutSubtreeIfNeeded()
        }
        func rendered(_ id: String) -> Bool {
            view.history.contents.contains { card in
                (card.top + (card.replies ?? [])).contains { if case .post(let post) = $0 { return post.id == id }; return false }
            }
        }
        func displayedReplies(_ id: String) -> [String] {
            view.history.contents.first { $0.id == id }?.replies?.compactMap { piece in
                if case .post(let post) = piece { return post.id }
                return nil
            } ?? []
        }
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
            scroll(frame(first.thread,rows[0]).minY)
            try await wait("selected_root") { rendered(rows[0]) && !loader.busy }
            let final = try await observe().requests
            try require(bodyRequests(final,for:first.thread).count == 1 &&
                        final.filter { $0.kind == "messages" && $0.thread == first.thread && $0.cursor }.isEmpty,"AT-ALD-13/26")
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
        case "anchored", "anchored-last", "anchored-fail", "anchored-reopen", "anchored-live", "anchored-no-progress":
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
                        abs(y(first.thread,rows[120])-openingY) <= 1,"AT-ALD-14 opening previous page")
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
