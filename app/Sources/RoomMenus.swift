import AppKit

/// Action closures stay with their menu items until AppKit dispatches the chosen command.
final class RoomActionItem: NSMenuItem {
    private let invokeAction: () -> Void
    init(_ title: String, action: @escaping () -> Void) {
        invokeAction = action
        super.init(title: title, action: nil, keyEquivalent: "")
        target = self; self.action = #selector(invoke)
    }
    required init(coder: NSCoder) { fatalError() }
    func trigger() { invokeAction() }
    @objc private func invoke() { invokeAction() }
}

final class EmployeeMenuTable: NSTableView {
    var makeMenu: ((Int) -> NSMenu?)?
    var onBlankDoubleClick:(()->Void)?
    override func mouseDown(with event:NSEvent) {if event.clickCount==2,row(at:convert(event.locationInWindow,from:nil))<0 {onBlankDoubleClick?();return};super.mouseDown(with:event)}
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        return makeMenu?(row(at: point))
    }
}

final class EmployeeMenuScroll: NSScrollView {
    var makeBlankMenu: (() -> NSMenu?)?
    var onBlankDoubleClick:(()->Void)?
    override func mouseDown(with event:NSEvent) {if event.clickCount==2 {onBlankDoubleClick?();return};super.mouseDown(with:event)}
    override func menu(for event: NSEvent) -> NSMenu? { makeBlankMenu?() }
}
