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
        targeted = value; onTarget?(value)
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
