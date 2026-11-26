import AppKit
import CoreGraphics

private struct WaitJitterFailure: Error { let message: String }
private struct Geometry {
    var extra: CGFloat = 0
    var typing = false
    var streaming = false
}
private struct Update {
    let interval: Double
    let geometry: Geometry
    let event: Bool
    var typing: Bool { geometry.typing }
}

private func waiting(close: Bool = false) -> [Update] {
    let intervals = [0.0, 0.03, 0.06, 0.2, 0.45]
    var typing = false
    return (1...30).map { index in
        let event = [5, 12, 20, 27].contains(index)
        if event { typing.toggle() }
        let interval = close && index == 6 ? 0.03 : intervals[(index - 1) % intervals.count]
        return Update(interval: interval, geometry: Geometry(typing: typing), event: event)
    }
}

private func streaming() -> [Update] {
    var updates: [Update] = []
    for step in 1...12 {
        let geometry = Geometry(extra: CGFloat(step * 40), typing: true, streaming: true)
        updates.append(Update(interval: 1.0 / 30, geometry: geometry, event: true))
        for _ in 0..<2 { updates.append(Update(interval: 1.0 / 30, geometry: geometry, event: false)) }
    }
    updates.append(Update(interval: 1.0 / 30, geometry: Geometry(extra: 480), event: true))
    return updates
}

private let frameTime = 1.0 / 60
@MainActor private func wait(_ duration: Double) async {
    try? await Task.sleep(nanoseconds: UInt64(duration * 1_000_000_000))
}

private final class ArrowTarget: NSView {
    var moveReader: (() -> Void)?
    override var acceptsFirstResponder: Bool { true }
    override func keyDown(with event: NSEvent) {
        if event.keyCode == 125 { moveReader?() } else { super.keyDown(with: event) }
    }
}

@MainActor private final class ListFixture {
    let list = NativeThreadList(frame: CGRect(x: 0, y: 0, width: 460, height: 300))
    let window: NSWindow
    let history: Bool
    var now = 10.0

    init(history: Bool, gap: CGFloat, initial: Geometry, reducedMotion: Bool) {
        self.history = history
        window = NSWindow(contentRect: list.frame, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = list
        window.makeKeyAndOrderFront(nil)
        list.automaticallyTicks = false
        list.reduceMotion = { reducedMotion }
        list.clock = { [weak self] in self?.now ?? 0 }
        show(initial)
        list.readerInput(wheel: false)
        scroll(to: maximum - gap)
    }

    var maximum: CGFloat { list.table.bounds.maxY - list.contentView.bounds.height }
    var y: CGFloat { list.contentView.bounds.minY }

    func scroll(to y: CGFloat) {
        list.contentView.scroll(to: NSPoint(x: 0, y: y))
        list.reflectScrolledClipView(list.contentView)
    }

    func show(_ geometry: Geometry) {
        let contents: [NativeThreadCard.Content] = (0..<18).map { index in
            let last = index == 17
            let post = NativeThreadCard.Post(
                id: "post-\(index)", mine: false, text: NSAttributedString(string: "Fixture text \(index)"),
                speaker: "Fixture", time: "", avatar: ProfileAvatar(), nameColor: .labelColor,
                streaming: last && geometry.streaming, openLink: { _ in }
            )
            var pieces: [NativeThreadCard.Piece] = [
                .post(post), .accessory(id: "space-\(index)", height: 70 + (last ? geometry.extra : 0), view: { NSView() })
            ]
            if last && geometry.typing {
                pieces.append(.accessory(id: "typing", height: 34, view: { NSView() }))
            }
            return .init(id: "card-\(index)", top: pieces, replies: nil, rail: nil, actions: [],
                         deleting: nil, style: .init(inset: 12, fill: 0, stroke: nil, lineWidth: 1),
                         bell: nil, onBell: {}, clickCard: {}, bubbleWidth: 300,
                         quiet: .secondaryLabelColor, expanded: false)
        }
        list.show(contents, identity: "fixture-room", historyMode: history)
        list.layoutSubtreeIfNeeded()
    }

    func tick() {
        now += frameTime
        list.advanceFollow()
        list.layoutSubtreeIfNeeded()
    }

    func finish() {
        list.readerInput(wheel: false)
        window.orderOut(nil)
    }
}

private struct Sample {
    let seconds: Double
    let origin: CGFloat
    let maximum: CGFloat
}
private struct Section {
    let target: CGFloat
    var samples: [Sample]
    var rebounds: Int {
        var minimum = CGFloat.infinity
        var count = 0
        for sample in samples {
            let distance = abs(sample.origin - target)
            if distance > minimum + 0.5 { count += 1 }
            minimum = min(minimum, distance)
        }
        return count
    }

    var reversals: Int {
        var extreme = samples[0].origin
        var direction: CGFloat = 0
        var count = 0
        for sample in samples.dropFirst() {
            let step = sample.origin - extreme
            if abs(step) <= 0.5 { continue }
            let sign: CGFloat = step > 0 ? 1 : -1
            if direction != 0 && sign != direction { count += 1 }
            direction = sign
            extreme = sample.origin
        }
        return count
    }
}

@MainActor private final class Runner {
    let evidence: URL
    var failed = false
    let reference: Reference
    let traceSubset: Bool

    struct Reference: Decodable {
        let origin_offsets: [String: [CGFloat]]
    }

    init(evidence: URL, targets: URL, traceSubset: Bool) throws {
        self.evidence = evidence
        self.reference = try JSONDecoder().decode(Reference.self, from: Data(contentsOf:targets))
        self.traceSubset = traceSubset
    }

    private func report(_ id: String, _ good: Bool, _ details: String) {
        print("\(id) \(good ? "PASS" : "FAIL") \(details)")
        if !good { failed = true }
    }

    private func write(_ name: String, _ text: String) throws {
        try Data((text + "\n").utf8).write(to: evidence.appendingPathComponent(name))
    }

    func conversation(_ id: String, history: Bool, gap: CGFloat, updates: [Update],
                      initial: Geometry = Geometry(), motion: Bool = false) async throws {
        let fixture = ListFixture(history: history, gap: gap, initial: initial, reducedMotion: !motion)
        defer { fixture.finish() }
        await wait(0.05)
        fixture.scroll(to: fixture.maximum - gap)
        let start = fixture.y
        guard abs(fixture.maximum - start - gap) <= 0.5 else {
            throw WaitJitterFailure(message: "\(id) initial gap \(fixture.maximum - start), expected \(gap)")
        }
        var observed: [[Sample]] = [[Sample(seconds: 0, origin: start, maximum: fixture.maximum)]]
        let began = ProcessInfo.processInfo.systemUptime
        var elapsed = 0.0
        var next = 0
        var deadline = updates[0].interval
        let finish = updates.reduce(0) { $0 + $1.interval } + 0.5
        var sampleIndex = 0
        while elapsed <= finish + 0.00001 {
            let nominal = began + elapsed
            await wait(max(0, nominal - ProcessInfo.processInfo.systemUptime))
            while next < updates.count && deadline <= elapsed + 0.00001 {
                let update = updates[next]
                let yBefore = fixture.y
                if update.event {
                    observed.append([Sample(seconds: deadline, origin: yBefore, maximum: fixture.maximum)])
                }
                fixture.show(update.geometry)
                next += 1
                if next < updates.count { deadline += updates[next].interval }
            }
            fixture.tick()
            observed[observed.count - 1].append(Sample(seconds: elapsed, origin: fixture.y, maximum: fixture.maximum))
            sampleIndex += 1
            elapsed = Double(sampleIndex) * frameTime
        }
        guard let offsets = reference.origin_offsets[id], offsets.count == observed.count else {
            throw WaitJitterFailure(message:"missing baseline targets for \(id)")
        }
        let targets = offsets.map { start + $0 }
        try write("samples-\(id).log", "section\ttime\torigin\tmaximum\n" + observed.enumerated().flatMap { section, samples in
            samples.map { "\(section)\t\($0.seconds)\t\($0.origin)\t\($0.maximum)" }
        }.joined(separator: "\n"))
        let sections = zip(targets, observed).map(Section.init)
        let rebounds = sections.map(\.rebounds)
        let reversals = sections.map(\.reversals)
        let endErrors = sections.map { abs($0.samples.last!.origin - $0.target) }
        let still = observed[0].map { abs($0.origin - start) }.max() ?? 0
        let flat = observed.flatMap { $0 }
        let frameDelta = zip(flat, flat.dropFirst()).map { abs($0.origin - $1.origin) }.max() ?? 0
        let endGap = flat.last!.maximum - flat.last!.origin
        let correct = motion ? frameDelta <= 36.0001 && endGap <= 1 : endErrors.allSatisfy { $0 <= 1 } && still <= 0.5
        report(id, correct && rebounds.allSatisfy { $0 == 0 } && reversals.allSatisfy { $0 == 0 },
               "rebounds=\(rebounds) reversals=\(reversals) endpointErrors=\(endErrors) still=\(still) maxStep=\(frameDelta) endGap=\(endGap)")
    }

    func input(_ id: String, kind: String) async throws {
        let fixture = ListFixture(history: false, gap: 300, initial: Geometry(), reducedMotion: true)
        defer { fixture.finish() }
        let originalPolicy = NSApp.activationPolicy()
        let oldFrontApp = NSWorkspace.shared.frontmostApplication
        let originalLevel = fixture.window.level
        if kind == "wheel" {
            guard CGPreflightPostEventAccess() else { throw WaitJitterFailure(message:"wheel delivery requires event posting") }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps:true)
            fixture.window.level = .popUpMenu
            fixture.window.makeKeyAndOrderFront(nil)
            for _ in 0..<30 {
                if NSApp.isActive && fixture.window.isKeyWindow { break }
                await wait(0.025)
            }
            guard NSApp.isActive, fixture.window.isKeyWindow else {
                throw WaitJitterFailure(message:"scroll test window did not become active")
            }
        }
        defer {
            if kind == "wheel" {
                fixture.window.level = originalLevel
                NSApp.setActivationPolicy(originalPolicy)
                oldFrontApp?.activate(options:[])
            }
        }
        await wait(0.05)
        for update in waiting().prefix(10) {
            await wait(update.interval)
            fixture.show(update.geometry)
        }
        let list = fixture.list
        let window = fixture.window
        let point = list.convert(CGPoint(x: list.bounds.midX, y: list.bounds.midY), to: nil)
        let before = fixture.y
        switch kind {
        case "wheel":
            guard let wheel = CGEvent(scrollWheelEvent2Source: nil, units: .pixel, wheelCount: 1,
                                      wheel1: -30, wheel2: 0, wheel3: 0)
            else { throw WaitJitterFailure(message: "wheel event") }
            guard let desktopTop = NSScreen.screens.first?.frame.maxY,
                  NSApp.isActive, window.isKeyWindow else {
                throw WaitJitterFailure(message:"wheel target window is unavailable")
            }
            let screen = window.convertPoint(toScreen: point)
            let cursor = CGPoint(x:screen.x,y:desktopTop-screen.y)
            let previousCursor = CGEvent(source:nil)?.location
            defer { if let previousCursor { CGWarpMouseCursorPosition(previousCursor) } }
            var delivered = false
            let monitor = NSEvent.addLocalMonitorForEvents(matching:.scrollWheel) {
                if $0.window === window { delivered = true }
                return $0
            }
            defer { if let monitor { NSEvent.removeMonitor(monitor) } }
            wheel.location = cursor
            guard CGWarpMouseCursorPosition(cursor) == .success else {
                throw WaitJitterFailure(message:"could not position wheel over test window")
            }
            wheel.post(tap:.cghidEventTap)
            await wait(0.075)
            guard delivered else { throw WaitJitterFailure(message:"the wheel event did not reach the test window") }
        case "click":
            for type in [NSEvent.EventType.leftMouseDown, .leftMouseUp] {
                guard let event = NSEvent.mouseEvent(with: type, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, eventNumber: 1, clickCount: 1, pressure: type == .leftMouseDown ? 1 : 0)
                else { throw WaitJitterFailure(message: "click event") }
                NSApp.postEvent(event, atStart: false)
            }
            await wait(0.02)
            fixture.scroll(to: fixture.y + 30)
        default:
            let target = ArrowTarget(frame: .zero)
            list.table.addSubview(target)
            target.moveReader = { [weak fixture] in
                guard let fixture else { return }
                fixture.scroll(to: fixture.y + 30)
            }
            guard window.makeFirstResponder(target),
                  let event = NSEvent.keyEvent(with: .keyDown, location: point, modifierFlags: [],
                    timestamp: ProcessInfo.processInfo.systemUptime, windowNumber: window.windowNumber,
                    context: nil, characters: "\u{F701}", charactersIgnoringModifiers: "\u{F701}",
                    isARepeat: false, keyCode: 125) else { throw WaitJitterFailure(message: "key event") }
            NSApp.postEvent(event, atStart: false)
            await wait(0.02)
        }
        let after = fixture.y
        var values = [after]
        for _ in 0..<30 {
            await wait(frameTime)
            fixture.tick()
            values.append(fixture.y)
        }
        try write("samples-\(id).log", "before=\(before) after=\(after)\n" + values.map { String(describing: $0) }.joined(separator: "\n"))
        let drift = values.map { abs($0 - after) }.max() ?? 0
        report(id, abs(after - before) > 0.5 && drift <= 0.5, "inputMovement=\(after - before) maxDrift=\(drift)")
    }

    func sidebar(_ id: String, updatePreview: Bool) async throws {
        let home = evidence.appendingPathComponent("sidebar-\(id)-\(UUID())", isDirectory: true)
        let store = try LocalStore(directory: home, historyMode: false)
        let client = GateClient(store: store, credentials: MemoryCredentials())
        let controller = try ConversationController(client: client, downloads: home.appendingPathComponent("Downloads"))
        defer {
            client.stop()
            try? FileManager.default.removeItem(at:home)
        }
        controller.receive(["v":1, "type":"roster", "employees":[
            ["id":"fixture-a", "name":"Fixture A", "aliases":[]],
            ["id":"fixture-b", "name":"Fixture B", "aliases":[]]
        ]])
        let rooms = (1...12).map { String(format: "00000000-0000-4000-8000-%012d", $0) }
        let thread = "00000000-0000-4000-8000-000000000100"
        for (index, room) in rooms.enumerated() {
            controller.receive(["v":1, "type":"room", "seq":index + 1, "room":[
                "id":room, "title":"Fixture room \(index)", "members":["fixture-a","fixture-b"], "lead":"fixture-a"
            ]])
        }
        let selected = rooms[0]
        controller.model.toggleSection("1")
        func post(room: String, seq: Int, role: String) {
            let message = String(format: "00000000-0000-4000-8000-%012d", seq + 200)
            controller.receive(["v":1,"type":"message","seq":seq,"msg_id":message,"employee":"fixture-a",
                "room":room,"role":role,"speaker":"fixture-a","thread":thread,"text":"Fixture preview \(seq)",
                "files":[],"buttons":[],"ts":String(format: "2026-01-01T00:00:%02dZ", rooms.firstIndex(of:room) ?? 0)])

        }
        for (index, room) in rooms.enumerated() {
            post(room: room, seq: index + 13, role: room == selected ? "owner" : "employee")
        }
        var previewSequence = 25
        let clock = Date(timeIntervalSince1970: 1_794_000_000)
        controller.clock = { clock }
        let ui = ConversationView(controller: controller, islandModel: IslandModel(clock: { clock }))
        let size = CGRect(x: 0, y: 0, width: 740, height: 380)
        ui.reduceMotion = { false }
        ui.frame = size
        let window = NSWindow(contentRect: size, styleMask: [.titled], backing: .buffered, defer: false)
        window.isReleasedWhenClosed = false
        window.contentView = ui
        window.makeKeyAndOrderFront(nil)
        defer { window.orderOut(nil) }
        ui.setSidebarWidth(212)
        ui.chooseEmployee(selected)
        ui.chooseThread(ConversationKey(employee: selected, thread: thread))
        ui.refresh()
        ui.layoutSubtreeIfNeeded()
        await wait(0.55)
        let table = ui.employeeTable
        guard let scroll = table.enclosingScrollView else { throw WaitJitterFailure(message: "sidebar scroll") }
        let maximum = table.bounds.height - scroll.contentView.bounds.height
        guard maximum > 40, table.numberOfRows >= 12 else {
            throw WaitJitterFailure(message: "sidebar fixture has insufficient rows: \(table.numberOfRows), extent \(maximum)")
        }
        scroll.contentView.scroll(to: CGPoint(x: 0, y: maximum / 2))
        scroll.reflectScrolledClipView(scroll.contentView)
        ui.layoutSubtreeIfNeeded()
        func visible() -> [String: CGFloat] {
            let rows = table.rows(in: scroll.contentView.bounds)
            guard rows.location != NSNotFound, rows.length > 0 else { return [:] }
            return Dictionary(uniqueKeysWithValues: (rows.location..<NSMaxRange(rows)).map { row in
                let identifier = ui.sidebarRows.indices.contains(row) ? ui.sidebarRows[row].stableID : "add"
                let modelFrame = table.rect(ofRow:row)
                let rowView = table.rowView(atRow:row,makeIfNecessary:false)
                let frame = rowView?.layer?.presentation()?.frame ?? rowView?.frame ?? modelFrame
                return (identifier, table.convert(CGPoint(x:frame.minX,y:frame.minY),to:nil).y)
            })
        }
        let stableIDs = ui.sidebarRows.map(\.stableID)
        let rowsBefore = visible()
        guard !rowsBefore.isEmpty else { throw WaitJitterFailure(message: "sidebar fixture has no visible rows") }
        let origin = scroll.contentView.bounds.minY
        var shift: CGFloat = 0
        var scrollShift: CGFloat = 0
        var changedVisible = 0
        var samples: [String] = []
        func sample() {
            let rows = visible()
            let y = scroll.contentView.bounds.minY
            if Set(rows.keys) != Set(rowsBefore.keys) { changedVisible += 1 }
            shift = max(shift, rows.compactMap { id, y in rowsBefore[id].map { abs($0 - y) } }.max() ?? 0)
            scrollShift = max(scrollShift, abs(y - origin))
            samples.append("\(y)\t" + rows.sorted { $0.key < $1.key }.map { "\($0.key)=\($0.value)" }.joined(separator: " "))
        }
        sample()
        let updates = waiting()
        var next = 0
        var deadline = updates[0].interval
        let start = ProcessInfo.processInfo.systemUptime
        let finish = updates.reduce(0) { $0 + $1.interval } + 0.5
        for frame in 0...Int(ceil(finish / frameTime)) {
            let elapsed = Double(frame) * frameTime
            await wait(max(0, start + elapsed - ProcessInfo.processInfo.systemUptime))
            while next < updates.count && deadline <= elapsed + 0.00001 {
                if updates[next].event {
                    controller.receive(["v":1,"type":"typing","room":selected,"employee":"fixture-a",
                                        "thread":thread,"on":updates[next].typing,"ttl_seconds":60])
                    guard (controller.model.typing[ConversationKey(employee: selected, thread: thread)] != nil) == updates[next].typing
                    else { throw WaitJitterFailure(message: "typing frame did not affect selected room") }
                }
                if updatePreview, [7, 15, 23].contains(next) {
                    post(room: rooms[6], seq: previewSequence, role: "employee")
                    previewSequence += 1
                }
                ui.refresh()
                guard stableIDs == ui.sidebarRows.map(\.stableID) else {
                    throw WaitJitterFailure(message: "sidebar fixture changed row order")
                }
                next += 1
                if next < updates.count { deadline += updates[next].interval }
            }
            ui.layoutSubtreeIfNeeded()
            sample()
        }
        try write("samples-\(id).log", samples.joined(separator: "\n"))
        report(id, shift <= 0.5 && scrollShift <= 0.5 && changedVisible == 0,
               "rowShift=\(shift) originShift=\(scrollShift) differentVisibleSamples=\(changedVisible)")
    }

    func run() async throws {
        try await conversation("AT-WJ-01", history:false, gap:300, updates:waiting())
        if !traceSubset {
            for history in [false, true] {
                for gap in [CGFloat(0), 1.5, 2.5, 100] {
                    let mode = history ? "history" : "ordinary"
                    try await conversation("AT-WJ-02-\(mode)-\(gap)", history:history, gap:gap, updates:waiting())
                }
            }
            try await conversation("AT-WJ-03", history:false, gap:300, updates:waiting(close:true))
        }
        try await conversation("AT-WJ-04", history:false, gap:0, updates:streaming(),
                               initial:Geometry(typing:true), motion:true)
        try await input("AT-WJ-05a", kind:"wheel")
        if !traceSubset {
            try await input("AT-WJ-05b", kind:"click")
            try await input("AT-WJ-05c", kind:"key")
        }
        try await sidebar("AT-WJ-06", updatePreview:false)
        try await sidebar("AT-WJ-07", updatePreview:true)
    }
}

@MainActor func waitJitterTests(output:URL, targets:URL, traceSubset:Bool) async throws {
    try FileManager.default.createDirectory(at:output,withIntermediateDirectories:true)
    let runner = try Runner(evidence:output, targets:targets, traceSubset:traceSubset)
    try await runner.run()
    try check(!runner.failed, "AT-WJ native window results")
}
