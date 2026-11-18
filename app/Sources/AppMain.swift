import AppKit

@main enum HejoMain {
    @MainActor static func main() {
        if let index = CommandLine.arguments.firstIndex(of: "--hook") {
            if CommandLine.arguments.count > index+1, let provider = Provider(rawValue: CommandLine.arguments[index+1]) {
                var destination: URL?
                if let i = CommandLine.arguments.firstIndex(of: "--event-root"), CommandLine.arguments.count > i+1 { destination = URL(fileURLWithPath: CommandLine.arguments[i+1]) }
                HookBridge.run(provider: provider, destination: destination)
            }
            return
        }
        let app = NSApplication.shared; app.setActivationPolicy(.accessory)
        let delegate = AppDelegate(); app.delegate = delegate
        withExtendedLifetime(delegate) { app.run() }
    }
}
