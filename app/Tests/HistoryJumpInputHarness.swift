#if HEJO_HISTORY_TRANSPORT_TEST
import AppKit

@MainActor enum HistoryJumpInputHarness {
    enum ReadInput: String {
        case wheel
        case click
        case key
    }

    private final class EventTestDelegate:NSObject,NSApplicationDelegate {
        let work: @MainActor () async throws -> Void
        var result: Result<Void,Error>?

        init(work:@escaping @MainActor () async throws -> Void) { self.work = work }

        func applicationDidFinishLaunching(_ notification:Notification) {
            Task { @MainActor in
                do { try await work();result = .success(()) }
                catch { result = .failure(error) }
                NSApp.stop(nil)
                if let wake = NSEvent.otherEvent(with:.applicationDefined,location:.zero,
                    modifierFlags:[],timestamp:0,windowNumber:0,context:nil,subtype:0,data1:0,data2:0) {
                    NSApp.postEvent(wake,atStart:false)
                }
            }
        }
    }

    static func runApplication(_ work:@escaping @MainActor () async throws -> Void) throws {
        let app = NSApplication.shared
        app.setActivationPolicy(.accessory)
        let delegate = EventTestDelegate(work:work)
        app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
        guard let result = delegate.result else {
            throw HistoryFailure.server("AT-JO-04 event loop stopped before the test",retryable:false)
        }
        try result.get()
    }

    private final class ArrowResponder: NSView {
        override var acceptsFirstResponder: Bool { true }
        override func mouseDown(with event: NSEvent) { }
        override func keyDown(with event: NSEvent) { }
    }

    static func deliver(_ kind: ReadInput, in window: NSWindow, to list: NativeThreadList) async throws {
        let center = list.convert(CGPoint(x:list.bounds.midX,y:list.bounds.midY),to:nil)
        switch kind {
        case .wheel:
            guard CGPreflightPostEventAccess(),
                  let event = CGEvent(scrollWheelEvent2Source:nil,units:.pixel,wheelCount:1,wheel1:-80,wheel2:0,wheel3:0),
                  let screenTop = NSScreen.screens.first?.frame.maxY else {
                throw HistoryFailure.server("AT-JO-04 wheel delivery unavailable",retryable:false)
            }
            let initialPolicy = NSApp.activationPolicy()
            let originalApp = NSWorkspace.shared.frontmostApplication
            let originalLevel = window.level
            let initialCursor = CGEvent(source:nil)?.location
            defer {
                if let initialCursor { CGWarpMouseCursorPosition(initialCursor) }
                window.level = originalLevel
                NSApp.setActivationPolicy(initialPolicy)
                originalApp?.activate(options:[])
            }
            NSApp.setActivationPolicy(.regular)
            NSApp.activate(ignoringOtherApps:true)
            window.level = .popUpMenu
            window.makeKeyAndOrderFront(nil)
            for _ in 0..<20 where !window.isKeyWindow || !NSApp.isActive {
                try await Task.sleep(nanoseconds:10_000_000)
            }
            let screen = window.convertPoint(toScreen:center)
            let cursor = CGPoint(x:screen.x,y:screenTop-screen.y)
            guard window.isKeyWindow && NSApp.isActive,CGWarpMouseCursorPosition(cursor) == .success else {
                throw HistoryFailure.server("AT-JO-04 wheel target unavailable",retryable:false)
            }
            event.location = cursor
            try await observe(eventType:.scrollWheel,in:window) { event.post(tap:.cghidEventTap) }
        case .click:
            let point = CGPoint(x:list.frame.maxX - 12,y:center.y)
            let local = list.table.convert(point,from:nil)
            let surface = ArrowResponder(frame:CGRect(x:local.x-4,y:local.y-4,width:8,height:8))
            list.table.addSubview(surface)
            defer { surface.removeFromSuperview() }
            guard let down = NSEvent.mouseEvent(with:.leftMouseDown,location:point,modifierFlags:[],
                timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,
                eventNumber:1,clickCount:1,pressure:1),
                  let up = NSEvent.mouseEvent(with:.leftMouseUp,location:point,modifierFlags:[],
                timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,
                eventNumber:2,clickCount:1,pressure:0) else { throw HistoryFailure.invalidResponse }
            try await observe(eventType:.leftMouseDown,in:window) {
                NSApp.postEvent(down,atStart:false)
                NSApp.postEvent(up,atStart:false)
            }
        case .key:
            let responder = ArrowResponder(frame:.zero)
            list.table.addSubview(responder)
            defer { responder.removeFromSuperview() }
            guard window.makeFirstResponder(responder),
                  let event = NSEvent.keyEvent(with:.keyDown,location:center,modifierFlags:[],
                timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,
                characters:"\u{F701}",charactersIgnoringModifiers:"\u{F701}",isARepeat:false,keyCode:125)
            else { throw HistoryFailure.invalidResponse }
            try await observe(eventType:.keyDown,in:window) { NSApp.postEvent(event,atStart:false) }
        }
    }

    private static func observe(eventType: NSEvent.EventType, in window: NSWindow, post: () -> Void) async throws {
        let mask = NSEvent.EventTypeMask(rawValue:1 << eventType.rawValue)
        var reachedWindow = false
        let monitor = NSEvent.addLocalMonitorForEvents(matching:mask) {
            if $0.window === window { reachedWindow = true }
            return $0
        }
        defer { if let monitor { NSEvent.removeMonitor(monitor) } }
        post()
        for _ in 0..<30 where !reachedWindow { try await Task.sleep(nanoseconds:5_000_000) }
        guard reachedWindow else { throw HistoryFailure.server("AT-JO-04 input not delivered",retryable:false) }
    }
}
#endif
