#if HEJO_PERF_TESTING
import AppKit

/// A nil screen exercises the real timer fallback without replacing CoreVideo or AppKit.
private final class OffscreenTransitionWindow: NSWindow {
    override var screen: NSScreen? { nil }
}

@MainActor func hejoTransitionClockTests(resources: URL) async throws {
    let window = OffscreenTransitionWindow(contentRect:.zero, styleMask:.borderless, backing:.buffered,defer:false)
    var fallbackTicks = 0
    let driver = PetTransitionClock { _ in fallbackTicks += 1 }
    driver.start(for:window)
    try check(driver.route == "timer_fallback","S3 missing screen must select fallback")
    try await waitFor(1) { fallbackTicks > 0 }
    driver.stop()
    let stopped = fallbackTicks
    driver.fire()
    await pause(0.06)
    try check(fallbackTicks == stopped,"S3 late stopped callback must be ignored")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    let store = try LocalStore(directory:directory)
    let pet = PetController(store:store, atlas:try SpriteAtlas(resourceDirectory:resources))
    defer { pet.panel.orderOut(nil) }
    pet.show()
    try check(pet.panel.screen != nil,"S3 controller requires an attached window")
    var now = 100.0
    var reduce = false
    pet.clock = { now }
    pet.reducedMotion = { reduce }
    pet.showChat()
    let openingClock = HejoSmoothProbe.transitionPath
    try check(["screen_display_link","cv_display_link"].contains(openingClock),"S3 opening must use the display")
    try await waitFor(1) { pet.transitionSteps >= 1 }
    now += ChatMorph.genieDuration * 0.4
    pet.stepTransition()
    let openProgress = pet.transitionProgress
    try check(openProgress > 0 && openProgress < 1,"S3 opening progress")
    pet.collapseChat()
    try check(pet.transitionProgress == openProgress,"S3 reversal must retain the current pose")
    now += ChatMorph.genieDuration * 0.4
    pet.stepTransition()
    try check(pet.transitionProgress < openProgress && pet.transitionProgress > 0,"S3 reversed motion must close")
    pet.panel.orderOut(nil)
    now += ChatMorph.genieDuration
    try await waitFor(1) { pet.transitionProgress == 0 }
    try check(pet.transitionProgress == 0 && !pet.chatExpanded && pet.pet.genie.isHidden,"S3 completed close")
    let completed = pet.transitionSteps
    await pause(0.06)
    try check(pet.transitionSteps == completed,"S3 completion must stop callbacks")

    reduce = true
    HejoSmoothProbe.transitionPath = ""
    pet.showChat()
    try check(pet.transitionProgress == 1 && pet.chatExpanded && pet.pet.genie.isHidden &&
              pet.transitionSteps == 0 && HejoSmoothProbe.transitionPath.isEmpty,"S3 reduce motion must open synchronously")
    pet.collapseChat()
    try check(pet.transitionProgress == 0 && !pet.chatExpanded && pet.pet.genie.isHidden &&
              pet.transitionSteps == 0,"S3 reduce motion must close synchronously")
    print("HEJO_S3_DRIVER_PASS \(openingClock)")
}
#endif
