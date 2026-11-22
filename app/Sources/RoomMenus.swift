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
    /// AppKit stores the final row frames while Core Animation displays the transition.
    /// Find the visible row first, then forward the event at that row's model position.
    func presentedRow(at point:NSPoint)->Int {
        var rows:[(Int,NSTableRowView)]=[];enumerateAvailableRowViews{view,index in rows.append((index,view))}
        guard rows.contains(where:{$0.1.layer?.animationKeys()?.isEmpty==false}) else{return row(at:point)}
        return rows.reversed().first {index,view in
            let layer=view.layer?.presentation() ?? view.layer
            return (layer?.opacity ?? 1)>0.01 && (layer?.frame ?? view.frame).contains(point)
        }?.0 ?? -1
    }
    override func mouseDown(with event:NSEvent) {
        let point=convert(event.locationInWindow,from:nil),row=presentedRow(at:point)
        if event.clickCount==2,row<0 {onBlankDoubleClick?();return}
        if row>=0,row != self.row(at:point),let forwarded=NSEvent.mouseEvent(with:event.type,location:convert(NSPoint(x:point.x,y:rect(ofRow:row).midY),to:nil),modifierFlags:event.modifierFlags,timestamp:event.timestamp,windowNumber:event.windowNumber,context:nil,eventNumber:event.eventNumber,clickCount:event.clickCount,pressure:event.pressure) {super.mouseDown(with:forwarded)}else{super.mouseDown(with:event)}
    }
    override func menu(for event: NSEvent) -> NSMenu? {
        let point = convert(event.locationInWindow, from: nil)
        return makeMenu?(presentedRow(at:point))
    }
}

final class EmployeeMenuScroll: NSScrollView {
    var makeBlankMenu: (() -> NSMenu?)?
    var onBlankDoubleClick:(()->Void)?
    override func mouseDown(with event:NSEvent) {if event.clickCount==2 {onBlankDoubleClick?();return};super.mouseDown(with:event)}
    override func menu(for event: NSEvent) -> NSMenu? { makeBlankMenu?() }
}
