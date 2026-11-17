import AppKit

/// AppKit supplies the original pasteboard, including Finder file URLs and screenshot image data.
final class AttachmentDropView: NSView {
    var canAttach: () -> Bool = { false }
    var onPaste: ((NSPasteboard) -> Bool)?
    var onTarget: ((Bool) -> Void)?
    private(set) var targeted = false
    override init(frame: NSRect) {
        super.init(frame: frame)
        registerForDraggedTypes([.fileURL, .png, .tiff])
    }
    required init?(coder: NSCoder) { fatalError() }
    override func hitTest(_ point: NSPoint) -> NSView? { nil }
    override var isFlipped: Bool { true }
    func setTargeted(_ value: Bool) {
        guard targeted != value else { return }
        targeted = value;needsDisplay=true;onTarget?(value)
    }
    func updateDrag(from board: NSPasteboard, at point: NSPoint, operation: NSDragOperation = .copy) -> NSDragOperation {
        let accepts = canAttach() && window != nil && !isHiddenOrHasHiddenAncestor && bounds.contains(convert(point, from: nil))
            && operation.contains(.copy) && ClipboardAttachments.containsAttachments(board)
        setTargeted(accepts)
        return accepts ? .copy : []
    }
    func drop(from board: NSPasteboard, at point: NSPoint, operation: NSDragOperation = .copy) -> Bool {
        let accepts = updateDrag(from: board, at: point, operation: operation) == .copy
        setTargeted(false)
        guard accepts, onPaste?(board) == true else { return false }
        return true
    }
    override func draw(_ dirtyRect:NSRect) {
        guard targeted else{return}
        NSColor.controlAccentColor.setStroke();let path=NSBezierPath(roundedRect:bounds.insetBy(dx:6,dy:6),xRadius:16,yRadius:16);path.lineWidth=2;path.stroke()
        let text="여기에 놓아 첨부" as NSString,a:[NSAttributedString.Key:Any]=[.font:NSFont.systemFont(ofSize:11,weight:.semibold),.foregroundColor:NSColor.labelColor],size=text.size(withAttributes:a)
        let area=CGRect(x:bounds.midX-(size.width+43)/2,y:14,width:size.width+43,height:29)
        NSColor.windowBackgroundColor.setFill();NSBezierPath(roundedRect:area,xRadius:area.height/2,yRadius:area.height/2).fill()
        FileTile.symbol("paperclip",point:11,at:CGPoint(x:area.minX+17,y:area.midY),color:.labelColor)
        text.draw(at:CGPoint(x:area.minX+29,y:area.midY-size.height/2),withAttributes:a)
    }
    override func draggingEntered(_ sender: NSDraggingInfo) -> NSDragOperation {
        updateDrag(from: sender.draggingPasteboard, at: sender.draggingLocation, operation: sender.draggingSourceOperationMask)
    }
    override func draggingUpdated(_ sender: NSDraggingInfo) -> NSDragOperation { draggingEntered(sender) }
    override func draggingExited(_ sender: NSDraggingInfo?) { setTargeted(false) }
    override func prepareForDragOperation(_ sender: NSDraggingInfo) -> Bool { draggingEntered(sender) == .copy }
    override func performDragOperation(_ sender: NSDraggingInfo) -> Bool {
        drop(from: sender.draggingPasteboard, at: sender.draggingLocation, operation: sender.draggingSourceOperationMask)
    }
    override func concludeDragOperation(_ sender: NSDraggingInfo?) { setTargeted(false) }
    override func draggingEnded(_ sender: NSDraggingInfo) { setTargeted(false) }
}
