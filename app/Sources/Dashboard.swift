import AppKit

/// A view of the local read-only monitor. No session or transcript is persisted by the dashboard.
@MainActor final class DashboardModel {
    var name = "hejo" { didSet { onChange?() } }
    var tasks: [WorkItem] = []
    var connections: [ConnectionInfo] = []
    var paused = false
    var warning: String?
    var lastScan: Date?
    var selectedID: String?
    var filter = "전체"
    var onChange: (() -> Void)?
    var onSelect: ((String?) -> Void)?
    var onRefresh: (() -> Void)?
    var onPause: (() -> Void)?
    var onPreview: (() -> Void)?
    var onHooks: (() -> Void)?
    var filtered: [WorkItem] { tasks.filter { filter == "전체" || $0.provider.name == filter } }
    func apply(_ snapshot: Snapshot) {
        tasks = snapshot.tasks; connections = snapshot.connections
        warning = snapshot.warning; lastScan = snapshot.observedAt; onChange?()
    }
}

@MainActor final class Dashboard: NSView {
    let model: DashboardModel
    let filter = NSSegmentedControl(labels: ["전체", "Codex", "Claude Code"], trackingMode: .selectOne, target: nil, action: nil)
    let pauseButton = CalendarButton("잠시 쉬기")
    let refreshButton = CalendarButton("새로고침")
    let previewButton = CalendarButton("동작 미리보기")
    let hooksButton = CalendarButton("승인 알림 연결 안내")
    let scroll = NSScrollView()
    private let rows = DashboardCanvas()
    private(set) var taskButtons: [DashboardTaskButton] = []
    override var isFlipped: Bool { true }
    init(model: DashboardModel) {
        self.model = model; super.init(frame: CGRect(x: 0, y: 0, width: 710, height: 610))
        appearance = NSAppearance(named: .aqua)
        filter.target = self; filter.action = #selector(filterChanged); filter.selectedSegment = 0
        filter.setAccessibilityLabel("서비스")
        for button in [pauseButton, refreshButton, previewButton, hooksButton] { button.bezelStyle = .rounded; addSubview(button) }
        pauseButton.invoke = { [weak model] in model?.onPause?() }
        refreshButton.invoke = { [weak model] in model?.onRefresh?() }
        previewButton.invoke = { [weak model] in model?.onPreview?() }
        hooksButton.invoke = { [weak model] in model?.onHooks?() }
        addSubview(filter); scroll.documentView = rows; scroll.hasVerticalScroller = true; scroll.drawsBackground = false; addSubview(scroll)
        model.onChange = { [weak self] in self?.refresh() }; refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func filterChanged() { model.filter = ["전체", "Codex", "Claude Code"][max(0, filter.selectedSegment)]; refresh() }
    func refresh() {
        pauseButton.title = model.paused ? "다시 살펴보기" : "잠시 쉬기"
        let previous=Dictionary(uniqueKeysWithValues:taskButtons.map{($0.item.id,$0)})
        let liveIDs=Set(model.filtered.map(\.id))
        taskButtons.filter{!liveIDs.contains($0.item.id)}.forEach{$0.removeFromSuperview()}
        taskButtons = model.filtered.map { item in
            let button=previous[item.id] ?? DashboardTaskButton(item:item,pinned:model.selectedID == item.id)
            button.update(item:item,pinned:model.selectedID == item.id)
            button.invoke = { [weak model] in model?.onSelect?(model?.selectedID == item.id ? nil : item.id) }
            if button.superview == nil {rows.addSubview(button)}
            return button
        }
        rows.empty = taskButtons.isEmpty
        rows.paused = model.paused
        setAccessibilityElement(true);setAccessibilityRole(.group);setAccessibilityLabel("작업 목록 · "+model.tasks.map{$0.provider.name+" · "+$0.state.label}.joined(separator:", "))
        needsDisplay = true; needsLayout = true
    }
    override func layout() {
        super.layout()
        pauseButton.sizeToFit(); pauseButton.frame.origin = CGPoint(x: bounds.width-26-pauseButton.frame.width, y: 26)
        filter.frame = CGRect(x: bounds.width-286, y: 209, width: 260, height: 24)
        let footer: CGFloat = 134
        scroll.frame = CGRect(x: 26, y: model.warning == nil ? 243 : 267, width: bounds.width-52, height: max(50, bounds.height-footer-(model.warning == nil ? 243 : 267)))
        rows.frame = CGRect(x: 0, y: 0, width: scroll.contentSize.width, height: max(scroll.contentSize.height, CGFloat(taskButtons.count)*74))
        for (i, button) in taskButtons.enumerated() { button.frame = CGRect(x: 0, y: CGFloat(i)*74, width: rows.bounds.width, height: 66) }
        refreshButton.font = .systemFont(ofSize: 10); refreshButton.sizeToFit(); refreshButton.frame.origin = CGPoint(x: bounds.width-26-refreshButton.frame.width, y: bounds.height-81)
        previewButton.font = .systemFont(ofSize: 10); previewButton.sizeToFit(); previewButton.frame.origin = CGPoint(x: 26, y: bounds.height-50)
        hooksButton.font = .systemFont(ofSize: 10); hooksButton.sizeToFit(); hooksButton.frame.origin = CGPoint(x: previewButton.frame.maxX+8, y: bounds.height-50)
    }
    override func draw(_ dirtyRect: NSRect) {
        NSColor(srgbRed: 0.95, green: 0.96, blue: 0.93, alpha: 1).setFill(); bounds.fill()
        DashboardInk.text("hejo", at: CGPoint(x: 26, y: 26), size: 29, weight: .bold, rounded: true)
        DashboardInk.text("AI가 일하는 동안, \(PetIdentity.subject(model.name)) 살펴볼게요.", at: CGPoint(x: 26, y: 67), size: 13, color: .secondaryLabelColor)
        let width = (bounds.width-76)/3
        for (i, value) in [("작업 중", WorkState.running, NSColor.systemTeal), ("확인 필요", .waiting, .systemOrange), ("최근 응답", .responded, .systemBlue)].enumerated() {
            let rect = CGRect(x: 26+CGFloat(i)*(width+12), y: 105, width: width, height: 84)
            NSColor.white.withAlphaComponent(0.7).setFill(); NSBezierPath(roundedRect: rect, xRadius: 14, yRadius: 14).fill()
            DashboardInk.text(value.0, at: CGPoint(x: rect.minX+15, y: rect.minY+15), size: 11, color: .secondaryLabelColor)
            DashboardInk.text(String(model.tasks.filter{$0.state == value.1}.count), at: CGPoint(x: rect.minX+15, y: rect.minY+37), size: 27, weight: .semibold, color: value.2, rounded: true)
        }
        DashboardInk.text("작업 목록", at: CGPoint(x: 26, y: 213), size: 16, weight: .semibold)
        if let warning = model.warning { DashboardInk.text(warning, at: CGPoint(x: 26, y: 243), size: 10, color: .systemOrange) }
        var y = scroll.frame.maxY+15
        for connection in model.connections {
            let dot = CGRect(x: 26, y: y+4, width: 5, height: 5)
            (connection.available ? NSColor.systemTeal : .systemGray).setFill(); NSBezierPath(ovalIn: dot).fill()
            DashboardInk.text(connection.provider.name, at: CGPoint(x: 37, y: y), size: 10, weight: .medium)
            DashboardInk.text((connection.available ? "" : "연결 안 됨 · ")+connection.detail, at: CGPoint(x: connection.provider == .codex ? 74 : 103, y: y), size: 10, color: .secondaryLabelColor)
            y += 20
        }
        DashboardInk.text("이 Mac의 최근 기록 · 응답 종료는 작업 성공을 뜻하지 않습니다.", at: CGPoint(x: 26, y: bounds.height-75), size: 10, color: .secondaryLabelColor)
        if let date = model.lastScan {
            DashboardInk.text(DashboardInk.time(date), at: CGPoint(x: bounds.width-100, y: bounds.height-43), size: 10, color: .secondaryLabelColor)
        }
    }
}

private enum DashboardInk {
    static func time(_ date: Date) -> String { let f = DateFormatter(); f.timeStyle = .short; return f.string(from: date) }
    static func color(_ state: WorkState) -> NSColor {
        switch state { case .running: return .systemTeal; case .waiting: return .systemOrange; case .failed: return .systemRed; case .responded: return .systemBlue; default: return .secondaryLabelColor }
    }
    static func text(_ text: String, at point: CGPoint, size: CGFloat, weight: NSFont.Weight = .regular, color: NSColor = NSColor(srgbRed: 0.08, green: 0.13, blue: 0.15, alpha: 1), rounded: Bool = false, mono: Bool = false, width: CGFloat = 1000) {
        var font = mono ? NSFont.monospacedSystemFont(ofSize: size, weight: weight) : .systemFont(ofSize: size, weight: weight)
        if rounded, let descriptor = font.fontDescriptor.withDesign(.rounded) { font = NSFont(descriptor: descriptor, size: size) ?? font }
        let paragraph = NSMutableParagraphStyle(); paragraph.lineBreakMode = .byTruncatingTail
        (text as NSString).draw(in: CGRect(x: point.x, y: point.y, width: width, height: ceil(size*1.5)), withAttributes: [.font: font, .foregroundColor: color, .paragraphStyle: paragraph])
    }
}
final class DashboardTaskButton: NSButton {
    private(set) var item: WorkItem, pinned: Bool
    var invoke: (() -> Void)?
    override var isFlipped: Bool { true }
    init(item: WorkItem, pinned: Bool) {
        self.item = item; self.pinned = pinned; super.init(frame: .zero)
        isBordered = false;target = self; action = #selector(pressed);update(item:item,pinned:pinned)
    }
    func update(item:WorkItem,pinned:Bool) {
        self.item=item;self.pinned=pinned
        title = item.provider.name+" · "+item.project+" · "+item.state.label+" · "+item.shortID+" · "+item.source
        setAccessibilityLabel(title);needsDisplay=true
    }
    required init?(coder: NSCoder) { fatalError() }
    @objc private func pressed() { invoke?() }
    var pinFrame: CGRect {
        let provider=(item.provider.name as NSString).size(withAttributes:[.font:NSFont.boldSystemFont(ofSize:12)]).width
        let project=(item.project.isEmpty ? "작업 공간":item.project) as NSString
        let width=min(max(0,bounds.width-provider-180),project.size(withAttributes:[.font:NSFont.systemFont(ofSize:12)]).width)
        return CGRect(x:36+provider+width+8,y:15,width:10,height:12)
    }
    override func draw(_ dirtyRect: NSRect) {
        let edge = bounds.insetBy(dx: 0.5, dy: 0.5), path = NSBezierPath(roundedRect: edge, xRadius: 12, yRadius: 12)
        NSColor.white.withAlphaComponent(0.85).setFill(); path.fill()
        (pinned ? NSColor.systemTeal.withAlphaComponent(0.6) : NSColor.black.withAlphaComponent(0.04)).setStroke(); path.stroke()
        DashboardInk.color(item.state).setFill(); NSBezierPath(roundedRect: CGRect(x: 12, y: 12, width: 4, height: 42), xRadius: 3, yRadius: 3).fill()
        DashboardInk.text(item.provider.name, at: CGPoint(x: 28, y: 15), size: 12, weight: .bold)
        let nameWidth = (item.provider.name as NSString).size(withAttributes: [.font: NSFont.boldSystemFont(ofSize: 12)]).width
        DashboardInk.text(item.project.isEmpty ? "작업 공간" : item.project, at: CGPoint(x: 36+nameWidth, y: 15), size: 12, color: .secondaryLabelColor, width: max(0,bounds.width-nameWidth-180))
        DashboardInk.text(item.shortID+" · "+item.source, at: CGPoint(x: 28, y: 35), size: 10, color: .secondaryLabelColor, mono: true, width: bounds.width-155)
        DashboardInk.text(item.state.label, at: CGPoint(x: bounds.width-12-(item.state.label as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.medium)]).width, y: 15), size: 12, weight: .medium, color: DashboardInk.color(item.state))
        DashboardInk.text(DashboardInk.time(item.updatedAt), at: CGPoint(x: bounds.width-12-(DashboardInk.time(item.updatedAt) as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:10)]).width, y: 35), size: 10, color: .secondaryLabelColor)
        if pinned { NSImage(systemSymbolName: "pin.fill", accessibilityDescription: "고정")?.withSymbolConfiguration(.init(pointSize:10,weight:.regular).applying(.init(paletteColors:[.systemTeal])))?.draw(in:pinFrame) }
    }
}
private final class DashboardCanvas: NSView {
    var empty = false, paused = false
    override var isFlipped: Bool { true }
    override func draw(_ dirtyRect: NSRect) {
        guard empty else { return }
        NSImage(systemSymbolName: "cup.and.saucer", accessibilityDescription: nil)?.withSymbolConfiguration(.init(pointSize:30,weight:.regular).applying(.init(paletteColors:[.systemTeal])))?.draw(in: CGRect(x: bounds.midX-23.5, y: 32, width: 47, height: 35))
        let heading=paused ? "지금은 쉬고 있어요" : "아직 표시할 작업이 없어요"
        let detail="Codex나 Claude Code에서 작업을 시작하면 여기에 나타납니다."
        DashboardInk.text(heading, at: CGPoint(x: bounds.midX-(heading as NSString).size(withAttributes:[.font:NSFont.boldSystemFont(ofSize:13)]).width/2, y: 77), size: 13, weight: .bold)
        DashboardInk.text(detail, at: CGPoint(x: bounds.midX-(detail as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize:10)]).width/2, y: 105), size: 10, color: .secondaryLabelColor)
    }
}
