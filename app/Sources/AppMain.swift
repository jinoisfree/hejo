import AppKit

@main enum HejoMain {
    @MainActor static func main() {
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
