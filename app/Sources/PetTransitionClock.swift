import AppKit
import CoreVideo
import QuartzCore

/// Drives one genie transition. Its owner replaces the clock on reversal or completion.
final class PetTransitionClock {
    private let tick: (PetTransitionClock) -> Void
    private var invalidateDisplayLink: (() -> Void)?
    private var legacyLink: CVDisplayLink?
    private var screenObserver: NSObjectProtocol?
    private var fallback: Timer?
    private var active = false
    private var displayGeneration = 0
    private(set) var route = ""

    init(tick: @escaping (PetTransitionClock) -> Void) {
        self.tick = tick
    }

    deinit { stop() }

    func start(for panel: NSWindow) {
        guard !active else { return }
        active = true
        if let screen = panel.screen {
            if #available(macOS 14.0, *) {
                startModern(on: screen)
            } else if startLegacy(on: screen) {
                record("cv_display_link")
            } else {
                startFallback()
            }
        } else {
            startFallback()
        }
        screenObserver = NotificationCenter.default.addObserver(forName: NSWindow.didChangeScreenNotification,
                                                                object: panel, queue: .main) { [weak self, weak panel] _ in
            guard let self, let panel, self.active, self.fallback == nil else { return }
            guard let screen = panel.screen else { self.startFallback(); return }
            if #available(macOS 14.0, *) {
                self.stopDisplay()
                self.startModern(on: screen)
            } else if let link = self.legacyLink, !Self.selectDisplay(for: link, screen: screen) {
                self.startFallback()
            }
        }
    }

    func fire() {
        guard active else { return }
        tick(self)
    }

    func stop() {
        active = false
        stopDisplay()
        fallback?.invalidate()
        fallback = nil
        if let screenObserver { NotificationCenter.default.removeObserver(screenObserver) }
        screenObserver = nil
    }

    private func stopDisplay() {
        displayGeneration &+= 1
        invalidateDisplayLink?()
        invalidateDisplayLink = nil
        if let legacyLink { CVDisplayLinkStop(legacyLink) }
        legacyLink = nil
    }

    private func record(_ route: String) {
        self.route = route
        ThreeTapDiagnostics.transitionDriver(route)
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.transitionPath = route
        #endif
    }

    private func startFallback() {
        stopDisplay()
        record("timer_fallback")
        let timer = Timer(timeInterval: 1.0 / 60, repeats: true) { [weak self] _ in self?.fire() }
        fallback = timer
        RunLoop.main.add(timer, forMode: .common)
    }

    private static func selectDisplay(for link: CVDisplayLink, screen: NSScreen) -> Bool {
        guard let number = screen.deviceDescription[NSDeviceDescriptionKey("NSScreenNumber")] as? NSNumber else { return false }
        return CVDisplayLinkSetCurrentCGDisplay(link, number.uint32Value) == kCVReturnSuccess
    }

    private func startLegacy(on screen: NSScreen) -> Bool {
        var created: CVDisplayLink?
        guard CVDisplayLinkCreateWithActiveCGDisplays(&created) == kCVReturnSuccess,
              let link = created, Self.selectDisplay(for: link, screen: screen) else { return false }
        let pending = PendingTick(self)
        // CoreVideo owns the handler and its box. The box never retains the clock.
        guard CVDisplayLinkSetOutputHandler(link, { _, _, _, _, _ in
            pending.enqueue()
            return kCVReturnSuccess
        }) == kCVReturnSuccess, CVDisplayLinkStart(link) == kCVReturnSuccess else { return false }
        legacyLink = link
        return true
    }

    @available(macOS 14.0, *)
    private func startModern(on screen: NSScreen) {
        // The screen keeps supplying ticks while the pet panel is temporarily hidden.
        let target = DisplayTarget(self, generation: displayGeneration)
        let link = screen.displayLink(target: target, selector: #selector(DisplayTarget.update(_:)))
        invalidateDisplayLink = { link.invalidate() }
        record("screen_display_link")
        link.add(to: .main, forMode: .common)
    }

    @available(macOS 14.0, *)
    private final class DisplayTarget: NSObject {
        weak var clock: PetTransitionClock?
        let generation: Int
        init(_ clock: PetTransitionClock, generation: Int) {
            self.clock = clock
            self.generation = generation
        }
        @objc func update(_ link: CADisplayLink) {
            guard let clock, clock.displayGeneration == generation, clock.route == "screen_display_link" else { return }
            clock.fire()
        }
    }

    private final class PendingTick {
        weak var clock: PetTransitionClock?
        private let lock = NSLock()
        private var queued = false

        init(_ clock: PetTransitionClock) { self.clock = clock }

        func enqueue() {
            lock.lock()
            guard !queued else { lock.unlock(); return }
            queued = true
            lock.unlock()
            DispatchQueue.main.async { [self] in
                defer {
                    lock.lock()
                    queued = false
                    lock.unlock()
                }
                guard clock?.route == "cv_display_link" else { return }
                clock?.fire()
            }
        }
    }
}
