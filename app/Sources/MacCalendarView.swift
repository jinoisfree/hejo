import AppKit

/// AppKit browser of transient CalendarSource values; EventKit remains the sole calendar authority.
final class MacCalendarView: NSView, NSTextFieldDelegate, NSSplitViewDelegate {
    let model: MacCalendar
    let title = NSTextField(labelWithString: ""), month = NSTextField(labelWithString: "")
    let search = NSTextField(), progress = NSProgressIndicator()
    let explanation = NSTextField(wrappingLabelWithString: "Mac 캘린더의 일정을 조회하고 대화와 관련된 일정을 열려면 캘린더 전체 접근을 허용해 주세요.")
    let refreshButton = CalendarButton("새로고침"), previous = CalendarButton("이전 달"), next = CalendarButton("다음 달")
    let browse = CalendarButton("전체 캘린더 보기"), allow = CalendarButton("캘린더 접근 허용"), settings = CalendarButton("권한 설정 열기")
    let split = NSSplitView(), list = NSScrollView(), detail = NSScrollView()
    private let rows = CalendarCanvas(), details = CalendarCanvas()
    private(set) var eventButtons: [CalendarEventButton] = []
    private(set) var detailLabels: [NSTextField] = []
    override var isFlipped: Bool { true }
    init(model: MacCalendar) {
        self.model = model;super.init(frame:.zero)
        title.font = .systemFont(ofSize:17,weight:.bold);month.alignment = .center;month.font = .systemFont(ofSize:13)
        progress.style = .spinning;progress.controlSize = .small;progress.isDisplayedWhenStopped = false
        search.bezelStyle = .roundedBezel;search.isBezeled = true;search.font = .systemFont(ofSize:13)
        search.placeholderString = "제목 또는 장소 검색";search.delegate = self;search.setAccessibilityLabel("제목 또는 장소 검색")
        explanation.font = .systemFont(ofSize:13)
        split.isVertical = true;split.dividerStyle = .thin;split.delegate = self
        for scroll in [list,detail] {scroll.drawsBackground = false;scroll.hasVerticalScroller = true;scroll.autohidesScrollers = true;scroll.scrollerStyle = .overlay;split.addArrangedSubview(scroll)}
        list.documentView = rows;detail.documentView = details
        [title,month,search,progress,explanation,refreshButton,previous,next,browse,allow,settings,split].forEach(addSubview)
        refreshButton.invoke = { [weak model] in model?.refresh(force:true,requestAccess:true) }
        previous.invoke = { [weak model] in model?.moveMonth(-1) };next.invoke = { [weak model] in model?.moveMonth(1) }
        browse.invoke = { [weak model] in model?.browse() };allow.invoke = { [weak model] in model?.refresh(force:true,requestAccess:true) }
        settings.invoke = { [weak model] in model?.openSettings() }
        model.onPresentation = { [weak self] in self?.refresh() }
        refresh()
    }
    required init?(coder:NSCoder) { fatalError() }
    func refresh() {
        title.stringValue = model.relatedIDs == nil ? "내 캘린더":"대화와 관련된 일정"
        month.stringValue = model.month.formatted(.dateTime.year().month(.wide))
        if model.loading {progress.startAnimation(nil)} else {progress.stopAnimation(nil)}
        let allowed = model.access == .allowed
        [explanation,allow,settings].forEach { $0.isHidden = allowed }
        [search,split].forEach { $0.isHidden = !allowed }
        [previous,next,month].forEach { $0.isHidden = !allowed || model.relatedIDs != nil }
        browse.isHidden = !allowed || model.relatedIDs == nil
        if search.stringValue != model.query {search.stringValue = model.query}
        rows.subviews.forEach { $0.removeFromSuperview() };eventButtons = []
        for event in model.visibleEvents {
            let button = CalendarEventButton(event:event,selected:model.selected?.id == event.id)
            button.invoke = { [weak model] in model?.select(event) };rows.addSubview(button);eventButtons.append(button)
        }
        if eventButtons.isEmpty {
            let empty = NSTextField(labelWithString:model.loading ? "조회 중…":"표시할 일정이 없어요.")
            empty.textColor = .secondaryLabelColor;empty.frame = NSRect(x:16,y:16,width:220,height:20);rows.addSubview(empty)
        }
        details.subviews.forEach { $0.removeFromSuperview() };detailLabels = []
        func line(_ text:String,_ font:NSFont = .systemFont(ofSize:13),_ color:NSColor = .labelColor) {
            let field = NSTextField(wrappingLabelWithString:text);field.font = font;field.textColor = color;field.isSelectable = true;details.addSubview(field);detailLabels.append(field)
        }
        if let event = model.selected {
            line(event.title,.systemFont(ofSize:17,weight:.bold));line(event.calendar,.systemFont(ofSize:13),.secondaryLabelColor)
            line(event.allDay ? "종일":"시간",.boldSystemFont(ofSize:13))
            line(event.start.formatted(date:.complete,time:event.allDay ? .omitted:.shortened))
            line("~ " + (event.allDay ? event.end.addingTimeInterval(-1):event.end).formatted(date:.complete,time:event.allDay ? .omitted:.shortened))
            if !event.location.isEmpty {line("장소",.boldSystemFont(ofSize:13));line(event.location)}
            if !event.notes.isEmpty {line("메모",.boldSystemFont(ofSize:13));line(event.notes)}
        } else {line(model.notice ?? "일정을 선택하면 상세 내용을 볼 수 있어요.",.systemFont(ofSize:13),.secondaryLabelColor)}
        needsLayout = true;needsDisplay = true
    }
    override func layout() {
        super.layout();let width = max(620,bounds.width),height = max(430,bounds.height)
        title.frame = NSRect(x:20,y:24,width:width-180,height:20)
        refreshButton.frame = NSRect(origin:NSPoint(x:width-20-refreshButton.intrinsicContentSize.width,y:20),size:refreshButton.intrinsicContentSize);progress.frame = NSRect(x:width-128,y:23,width:16,height:16)
        let explanationHeight = explanation.sizeThatFits(NSSize(width:width-40,height:10000)).height
        explanation.frame = NSRect(x:20,y:58,width:width-40,height:explanationHeight)
        allow.frame = NSRect(origin:NSPoint(x:20,y:58+explanationHeight+14),size:allow.intrinsicContentSize)
        settings.frame = NSRect(origin:NSPoint(x:allow.frame.maxX+8,y:allow.frame.minY),size:settings.intrinsicContentSize)
        previous.frame = NSRect(x:20,y:58,width:62,height:24);next.frame = NSRect(x:width-90,y:58,width:70,height:24)
        month.frame = NSRect(x:100,y:62,width:width-200,height:20);browse.frame = NSRect(origin:NSPoint(x:20,y:58),size:browse.intrinsicContentSize)
        search.frame = NSRect(x:20,y:96,width:width-40,height:24)
        split.frame = NSRect(x:20,y:134,width:width-40,height:height-154)
        if list.frame.width < 230 || detail.frame.width < 250 {split.setPosition((width-40)/2,ofDividerAt:0)}
        split.adjustSubviews();layoutDocuments()
    }
    private func layoutDocuments() {
        let width = list.contentSize.width
        var rowY:CGFloat = 0
        for button in eventButtons {let height = button.fittingHeight(width:width);button.frame = NSRect(x:0,y:rowY,width:width,height:height);rowY += height+6}
        rows.frame = NSRect(x:0,y:0,width:width,height:max(list.contentSize.height,max(0,rowY-6)))
        var y:CGFloat = 16
        for field in detailLabels {
            let size = field.sizeThatFits(NSSize(width:max(1,detail.contentSize.width-32),height:10000))
            field.frame = NSRect(x:16,y:y,width:max(1,detail.contentSize.width-32),height:size.height);y += size.height+12
        }
        details.frame = NSRect(x:0,y:0,width:detail.contentSize.width,height:max(detail.contentSize.height,y+4))
    }
    func splitViewDidResizeSubviews(_ notification:Notification) {layoutDocuments()}
    func splitView(_ splitView:NSSplitView,constrainMinCoordinate proposedMinimumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {230}
    func splitView(_ splitView:NSSplitView,constrainMaxCoordinate proposedMaximumPosition:CGFloat,ofSubviewAt dividerIndex:Int)->CGFloat {splitView.bounds.width-250}
    func controlTextDidChange(_ notification:Notification) {model.query = search.stringValue}
    override func draw(_ rect:NSRect) {NSColor.windowBackgroundColor.setFill();bounds.fill()}
}
final class CalendarCanvas: NSView {override var isFlipped:Bool {true}}
final class CalendarButton: NSButton {
    var invoke:(()->Void)?
    init(_ title:String) {super.init(frame:.zero);self.title = title;bezelStyle = .rounded;target = self;action = #selector(press)}
    required init?(coder:NSCoder) {fatalError()}
    @objc private func press() {invoke?()}
}
final class CalendarEventButton: NSButton {
    let event:CalendarEntry
    let chosen:Bool
    var invoke:(()->Void)?
    override var isFlipped:Bool {true}
    init(event:CalendarEntry,selected:Bool) {
        self.event = event;chosen = selected;super.init(frame:.zero);isBordered = false;title = event.title;target = self;action = #selector(press)
        setAccessibilityIdentifier("calendar-event-"+event.id);setAccessibilityLabel(event.title)
    }
    required init?(coder:NSCoder) {fatalError()}
    @objc private func press() {invoke?()}
    private func lines(width:CGFloat)->[(NSAttributedString,NSRect)] {
        var y:CGFloat = 10
        return [(event.title,NSFont.boldSystemFont(ofSize:13),NSColor.labelColor),(event.start.formatted(date:.abbreviated,time:event.allDay ? .omitted:.shortened),.systemFont(ofSize:13),.labelColor),(event.calendar,.systemFont(ofSize:10),.secondaryLabelColor)].map { text,font,color in
            let paragraph = NSMutableParagraphStyle();paragraph.lineBreakMode = .byWordWrapping
            paragraph.minimumLineHeight = ("Ag" as NSString).size(withAttributes:[.font:font]).height;paragraph.maximumLineHeight = paragraph.minimumLineHeight
            let value = NSAttributedString(string:text,attributes:[.font:font,.foregroundColor:color,.paragraphStyle:paragraph])
            let height = ceil(value.boundingRect(with:NSSize(width:max(1,width-20),height:10000),options:[.usesLineFragmentOrigin,.usesFontLeading]).height)
            let frame = NSRect(x:10,y:y,width:max(1,width-20),height:height);y += height+4
            return (value,frame)
        }
    }
    func fittingHeight(width:CGFloat)->CGFloat {(lines(width:width).last?.1.maxY ?? 10)+10}
    override func draw(_ rect:NSRect) {
        if chosen {NSColor.controlAccentColor.withAlphaComponent(0.16).setFill();NSBezierPath(roundedRect:bounds,xRadius:8,yRadius:8).fill()}
        for (text,frame) in lines(width:bounds.width) {text.draw(in:frame)}
    }
}
