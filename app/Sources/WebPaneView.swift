import AppKit

/// Native controls for the same ephemeral tab model; WebKit keeps each page alive when its tab is hidden.
final class WebPaneView: NSView, NSTextFieldDelegate {
    static let barHeight: CGFloat = 40
    let web: WebPaneModel
    let address = NSTextField()
    let blank = WebTabBlankView()
    let surface = WebPictureSurface()
    private let tabsScroll = NSScrollView(), tabsRow = NSView()
    private let back = WebControl("chevron.left", "뒤로", "뒤로 (⌘[)"), forward = WebControl("chevron.right", "앞으로", "앞으로 (⌘])")
    private let reload = WebControl("arrow.clockwise", "새로고침", "새로고침 (⌘R)")
    private let outside = WebControl("arrow.up.forward.square", "밖에서 열고 칸 닫기", "밖에서 열고 칸 닫기")
    let newTab = WebControl("plus", "새 탭", "새 탭 (⌘T)"), close = WebControl("sidebar.right", "웹 칸 닫기", "웹 칸 닫기")
    private let notice = NSTextField(wrappingLabelWithString: "")
    private let leadingRule = WebLeadingRule()
    private var chips: [UUID: WebChip] = [:]
    private var seenFocus = 0
    private var shownTab: UUID?
    override var isFlipped: Bool { true }
    init(web: WebPaneModel) {
        self.web = web; super.init(frame: .zero)
        wantsLayer = true; setAccessibilityIdentifier("web-pane")
        tabsScroll.documentView = tabsRow; tabsScroll.drawsBackground = false; tabsScroll.hasHorizontalScroller = false
        address.cell = WebAddressCell();address.isEditable = true;address.isSelectable = true;address.usesSingleLineMode = true
        address.placeholderString = "주소 또는 검색어"; address.font = .systemFont(ofSize: ChatMetrics.auxiliaryFont + 1)
        address.drawsBackground = false; address.isBordered = false; address.focusRingType = .none; address.delegate = self; address.target = self; address.action = #selector(submit)
        address.wantsLayer = true; address.layer?.cornerRadius = 9; address.setAccessibilityLabel("주소"); address.setAccessibilityIdentifier("web-address")
        outside.setAccessibilityIdentifier("web-open-outside"); newTab.setAccessibilityIdentifier("web-new-tab"); close.setAccessibilityIdentifier("web-close")
        notice.font = .systemFont(ofSize: ChatMetrics.auxiliaryFont); notice.setAccessibilityIdentifier("web-notice")
        [tabsScroll, newTab, close, back, forward, reload, address, outside, notice, surface, blank, leadingRule].forEach(addSubview)
        blank.web = web; web.addressField = address
        back.invoke = { [weak web] in web?.current?.view.goBack() }; forward.invoke = { [weak web] in web?.current?.view.goForward() }
        reload.invoke = { [weak web] in guard let tab = web?.current else { return }; if tab.loading { tab.view.stopLoading() } else { tab.view.reload() } }
        newTab.invoke = { [weak web] in web?.newTab() }; close.invoke = { [weak web] in web?.close() }; outside.invoke = { [weak web] in web?.openOutside() }
        web.onChange = { [weak self] in self?.refresh() }
        refresh()
    }
    required init?(coder: NSCoder) { fatalError() }
    func refresh() {
        for (id, chip) in chips where !web.tabs.contains(where: { $0.id == id }) { chip.removeFromSuperview(); chips[id] = nil }
        for tab in web.tabs {
            let chip = chips[tab.id] ?? WebChip(tab: tab, web: web)
            if chip.superview == nil { tabsRow.addSubview(chip); chips[tab.id] = chip }
            chip.refresh(chosen: tab.id == web.selected)
        }
        back.isEnabled = web.current?.canGoBack == true; forward.isEnabled = web.current?.canGoForward == true
        let loading = web.current?.loading == true
        reload.symbol(loading ? "xmark" : "arrow.clockwise"); reload.toolTip = loading ? "멈추기" : "새로고침 (⌘R)"; reload.setAccessibilityLabel(loading ? "멈추기" : "새로고침")
        outside.isEnabled = web.current.map { $0.file != nil || $0.url.map(WebAddress.isWeb) == true } ?? false
        if !web.addressFocused { address.stringValue = web.current?.address ?? "" }
        notice.stringValue = web.notice.map { "ⓘ " + $0 } ?? ""; notice.isHidden = web.notice == nil
        if web.ready, let tab = web.current { surface.install(tab) } else { surface.clear() }; surface.isHidden = !web.ready || web.current == nil
        let changedTab = shownTab != web.selected; shownTab = web.selected
        if (seenFocus != web.addressFocus || changedTab && web.current?.url == nil), window != nil {
            seenFocus = web.addressFocus; window?.makeFirstResponder(address)
        }
        needsLayout = true; needsDisplay = true
        if changedTab, let id = web.selected {
            DispatchQueue.main.async { [weak self] in
                guard let self, self.web.selected == id, let chip = self.chips[id] else { return }
                self.layoutSubtreeIfNeeded()
                let clip = self.tabsScroll.contentView, visible = clip.bounds
                let x = chip.frame.minX < visible.minX ? chip.frame.minX : chip.frame.maxX > visible.maxX ? chip.frame.maxX-visible.width : visible.minX
                NSAnimationContext.runAnimationGroup { context in context.duration = 0.15; context.timingFunction = CAMediaTimingFunction(name:.easeInEaseOut); clip.animator().setBoundsOrigin(CGPoint(x:max(0,x),y:0)) }
                self.tabsScroll.reflectScrolledClipView(clip)
            }
        }
    }
    override func viewDidChangeEffectiveAppearance() { super.viewDidChangeEffectiveAppearance(); refresh() }
    override func layout() {
        super.layout();leadingRule.frame = CGRect(x:0,y:0,width:1,height:bounds.height)
        let width = bounds.width
        tabsScroll.frame = CGRect(x: 8, y: 7, width: max(0, width - 74), height: 26)
        var x: CGFloat = 0
        for tab in web.tabs { guard let chip = chips[tab.id] else { continue }; let size = chip.fittingWidth; chip.frame = CGRect(x: x, y: 0, width: size, height: 26); x += size + 4 }
        tabsRow.frame = CGRect(x: 0, y: 0, width: max(x, tabsScroll.contentSize.width), height: 26)
        newTab.frame = CGRect(x: width - 60, y: 9, width: 20, height: 22); close.frame = CGRect(x: width - 34, y: 9, width: 20, height: 22)
        blank.frame = CGRect(x: 0, y: 0, width: width, height: 40)
        blank.occupied = web.tabs.compactMap { chips[$0.id].map { blank.convert($0.bounds, from: $0) } } + [newTab.frame, close.frame]
        back.frame = CGRect(x: 12, y: 52, width: 10, height: 14); forward.frame = CGRect(x: 30, y: 52, width: 10, height: 14)
        reload.frame = CGRect(x: 48, y: 51, width: 14, height: 16)
        address.frame = CGRect(x: 68, y: 47, width: max(1, width - 104), height: 25)
        outside.frame = CGRect(x: width - 30, y: 52, width: 16, height: 14)
        let noticeHeight = web.notice == nil ? 0 : max(36, notice.sizeThatFits(NSSize(width: max(1,width-20), height: 200)).height + 20)
        notice.frame = CGRect(x: 10, y: 88, width: max(1,width-20), height: max(0,noticeHeight-20))
        surface.frame = CGRect(x: 0, y: 78 + noticeHeight, width: max(0,width), height: max(0,bounds.height-78-noticeHeight))
        effectiveAppearance.performAsCurrentDrawingAppearance { address.layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(0.07).cgColor }
    }
    override func draw(_ dirtyRect: NSRect) {
        if web.notice != nil {NSColor.labelColor.withAlphaComponent(0.06).setFill();NSRect(x:0,y:78,width:bounds.width,height:max(0,surface.frame.minY-78)).fill()}
        NSColor.separatorColor.setFill(); NSRect(x:0,y:40,width:bounds.width,height:1).fill(); NSRect(x:0,y:77,width:bounds.width,height:1).fill()
    }
    @objc private func submit() { web.go(address.stringValue) }
    func controlTextDidBeginEditing(_ obj: Notification) { web.addressFocused = true; web.current?.editing = true }
    func controlTextDidChange(_ obj: Notification) { web.current?.address = address.stringValue }
    func controlTextDidEndEditing(_ obj: Notification) { web.addressFocused = false; web.current?.editing = false; address.stringValue = web.current?.shownAddress ?? "" }
}

final class WebControl: NSButton {
    var invoke: (() -> Void)?
    init(_ icon: String, _ name: String, _ help: String) {
        super.init(frame: .zero); isBordered = false; target = self; action = #selector(pressed); symbol(icon); toolTip = help; setAccessibilityLabel(name)
    }
    required init?(coder: NSCoder) { fatalError() }
    func symbol(_ name: String) { image = NSImage(systemSymbolName: name, accessibilityDescription: nil) }
    @objc private func pressed() { invoke?() }
}
private final class WebChip: NSView {
    let tab: WebTab
    private let spinner = WebSpinner()
    let select = WebControl("globe", "", ""), close = WebControl("xmark", "", "탭 닫기 (⌘W)")
    var fittingWidth: CGFloat { min(150, max(32, (tab.label as NSString).size(withAttributes:[.font:NSFont.systemFont(ofSize: ChatMetrics.auxiliaryFont)]).width)) + 50 }
    init(tab: WebTab, web: WebPaneModel) {
        self.tab = tab; super.init(frame: .zero); wantsLayer = true; layer?.cornerRadius = 8
        select.imagePosition = .imageLeading; select.alignment = .left; select.lineBreakMode = .byTruncatingTail
        select.invoke = { [weak web] in web?.selected = tab.id }; close.invoke = { [weak web] in web?.closeTab(tab.id) }
        spinner.style = .spinning; spinner.controlSize = .mini; spinner.isDisplayedWhenStopped = false
        addSubview(select); addSubview(close); addSubview(spinner)
        close.image = close.image?.withSymbolConfiguration(.init(pointSize:8,weight:.bold))
    }
    required init?(coder: NSCoder) { fatalError() }
    func refresh(chosen: Bool) {
        select.title = tab.label; select.toolTip = tab.label; select.setAccessibilityLabel(tab.label + (chosen ? ", 선택됨" : ""))
        select.font = .systemFont(ofSize: ChatMetrics.auxiliaryFont, weight: chosen ? .semibold : .regular)
        select.symbol(tab.file == nil ? "globe" : "doc")
        select.image = tab.loading ? NSImage(size:NSSize(width:12,height:12)) : select.image?.withSymbolConfiguration(.init(pointSize:10,weight:.regular))
        if tab.loading {spinner.startAnimation(nil)} else {spinner.stopAnimation(nil)}
        close.setAccessibilityLabel(tab.label + " 탭 닫기"); close.alphaValue = 0.7
        effectiveAppearance.performAsCurrentDrawingAppearance { layer?.backgroundColor = NSColor.labelColor.withAlphaComponent(chosen ? 0.14 : 0.05).cgColor }
    }
    override func layout() { super.layout(); select.frame = NSRect(x:8,y:2,width:max(0,bounds.width-30),height:22); close.frame = NSRect(x:bounds.width-20,y:5,width:12,height:16);spinner.frame=NSRect(x:8,y:7,width:12,height:12) }
}

private final class WebSpinner: NSProgressIndicator {override func hitTest(_ point:NSPoint)->NSView? {nil}}

/// A padded line of text centered in the original 25pt address background, including field-editor placement.
final class WebAddressCell: NSTextFieldCell {
    override func drawingRect(forBounds rect:NSRect)->NSRect {
        let height:CGFloat = 15
        return NSRect(x:rect.minX+10,y:rect.midY-height/2,width:max(0,rect.width-20),height:height)
    }
}
private final class WebLeadingRule:NSView {
    override func hitTest(_ point:NSPoint)->NSView? {nil}
    override func draw(_ rect:NSRect) {NSColor.labelColor.withAlphaComponent(0.14).setFill();bounds.fill()}
}
