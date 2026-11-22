import AppKit

/// One level rule for auxiliary windows. The pet itself and system confirmation
/// sheets keep their own lifecycles; ConnectionsWindow retains its .normal exception.
@MainActor enum OptionWindows {
    private static let windows=NSHashTable<NSWindow>.weakObjects()
    static var petLevel: () -> NSWindow.Level = { .floating }
    static var activate: () -> Void = { NSApp.activate(ignoringOtherApps:true) }
    static func level(active: Bool) -> NSWindow.Level {
        active ? NSWindow.Level(rawValue:petLevel().rawValue+1) : .normal
    }
    static func prepare(_ window:NSWindow) {
        windows.add(window)
        activate()
        window.level=level(active:true)
    }
    static func updateLevels(active:Bool) {
        for window in windows.allObjects where window.isVisible {
            window.level=level(active:active)
        }
    }
    static func show(_ window:NSWindow) {
        prepare(window);window.makeKeyAndOrderFront(nil)
    }
    static var alertResponse: (NSAlert)->NSApplication.ModalResponse = { $0.runModal() }
    @discardableResult static func runModal(_ alert:NSAlert)->NSApplication.ModalResponse {
        prepare(alert.window);return alertResponse(alert)
    }
    static func runModal(_ panel:NSSavePanel)->NSApplication.ModalResponse {
        prepare(panel);return panel.runModal()
    }
}
