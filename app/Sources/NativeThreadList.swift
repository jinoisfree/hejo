import AppKit

/// Native card reuse, measured row heights and reader-owned scrolling; no platform model lives here.
final class NativeThreadList: NSScrollView, NSTableViewDataSource, NSTableViewDelegate {
    final class Table: NSTableView {
        var resized: (() -> Void)?
        var blank: (() -> Void)?
        override func mouseDown(with event: NSEvent) {
            if row(at: convert(event.locationInWindow, from: nil)) < 0 { blank?() } else { super.mouseDown(with: event) }
        }
        override func layout() { super.layout(); resized?() }
    }
    var onBlank: (() -> Void)?
    var onMeasured: (() -> Void)?
    let table = Table()
    private(set) var contents: [NativeThreadCard.Content] = []
    private(set) var layouts: [NativeThreadCard.Layout] = []
    private var layingOut = false
    private var measuredWidth: CGFloat = 0
    private var identity = ""
    private var scrollRevision = 0
    private var userScrolls = 0
    override init(frame: NSRect) {
        super.init(frame: frame)
        drawsBackground = false; hasVerticalScroller = true; autohidesScrollers = true
        table.style = .plain; table.headerView = nil; table.backgroundColor = .clear; table.selectionHighlightStyle = .none
        table.focusRingType = .none; table.intercellSpacing = CGSize(width: 0, height: 18)
        table.usesAutomaticRowHeights = false; table.columnAutoresizingStyle = .lastColumnOnlyAutoresizingStyle
        let column = NSTableColumn(identifier: .init("messages")); column.minWidth = 1; column.resizingMask = .autoresizingMask
        table.addTableColumn(column); table.dataSource = self; table.delegate = self; documentView = table
        NativeThreadCard.settle = { [weak self] _ in self?.remeasure(force: true) }
        table.blank = { [weak self] in self?.onBlank?() }
        contentInsets = NSEdgeInsets(top: 14, left: 0, bottom: 14, right: 0)
        table.resized = { [weak self] in self?.remeasure() }
    }
    required init?(coder: NSCoder) { fatalError() }
    func show(_ contents: [NativeThreadCard.Content], identity: String) {
        let changed = self.identity != identity
        let follows = changed || documentVisibleRect.maxY >= table.bounds.height - 30
        self.identity = identity; self.contents = contents
        remeasure(force: true)
        if follows, !contents.isEmpty { table.scrollRowToVisible(contents.count - 1) }
    }
    override func scrollWheel(with event: NSEvent) { userScrolls += 1; super.scrollWheel(with: event) }
    func scrollTo(_ id: String,message:String?=nil) {
        scrollRevision += 1
        let revision=scrollRevision, input=userScrolls
        for delay in [0.0, 0.15, 0.45] {
            DispatchQueue.main.asyncAfter(deadline:.now()+delay) { [weak self] in
                guard let self, self.scrollRevision == revision, self.userScrolls == input,
                      let index=self.contents.firstIndex(where:{$0.id == id}) else { return }
                var rect=self.table.rect(ofRow:index)
                if let message,let anchor=self.layouts[index].anchors[message] {rect=anchor.offsetBy(dx:rect.minX,dy:rect.minY)}
                let bounds=self.contentView.bounds
                let wanted=min(max(0,rect.maxY-bounds.height),max(0,self.table.bounds.height-bounds.height))
                if NSWorkspace.shared.accessibilityDisplayShouldReduceMotion { self.contentView.scroll(to:CGPoint(x:bounds.minX,y:wanted)) }
                else { NSAnimationContext.runAnimationGroup { context in context.duration=0.24; self.contentView.animator().setBoundsOrigin(CGPoint(x:bounds.minX,y:wanted)) } }
                self.reflectScrolledClipView(self.contentView)
            }
        }
    }
    override func layout() { super.layout(); remeasure() }
    private func remeasure(force: Bool = false) {
        let width = max(1, contentSize.width)
        guard !layingOut, force || abs(width - measuredWidth) > 0.5 else { return }
        layingOut = true; defer { layingOut = false }
        measuredWidth = width
        let previousIDs = layouts.map { $0.content.id }
        layouts = contents.map { NativeThreadCard.layout($0, width: max(1, width - 2 * ChatMetrics.horizontalInset)) }
        table.tableColumns.first?.width = width
        table.frame.size.width = width
        if previousIDs == contents.map(\.id), table.numberOfRows == layouts.count {
            for index in layouts.indices {
                (table.view(atColumn: 0, row: index, makeIfNecessary: false) as? NativeThreadCard)?.configure(layouts[index])
            }
            table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: layouts.indices))
        } else { table.reloadData() }
        let height = layouts.reduce(CGFloat(0)) { $0 + $1.height + table.intercellSpacing.height }
        let oldHeight = table.frame.height
        table.frame.size.height = max(contentSize.height, height)
        if abs(oldHeight - table.frame.height) > 0.5 { DispatchQueue.main.async { [weak self] in self?.onMeasured?() } }
    }
    func numberOfRows(in tableView: NSTableView) -> Int { layouts.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { layouts[row].height }
    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("native-card")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NativeThreadCard ?? NativeThreadCard(frame: .zero)
        cell.identifier = id; cell.configure(layouts[row]); return cell
    }
}
