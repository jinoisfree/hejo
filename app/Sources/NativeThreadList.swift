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
    private final class ReadingClipView: NSClipView {
        var originDuringLayout: CGFloat?
        var documentHeightDuringLayout: CGFloat?

        private func heldOrigin(_ proposed: NSPoint, height: CGFloat) -> NSPoint {
            guard let originDuringLayout, let documentView else { return proposed }
            let documentHeight = documentHeightDuringLayout ?? documentView.bounds.maxY
            return NSPoint(x: proposed.x, y: min(originDuringLayout, max(0, documentHeight - height)))
        }

        override func constrainBoundsRect(_ proposedBounds: NSRect) -> NSRect {
            var constrained = super.constrainBoundsRect(proposedBounds)
            constrained.origin = heldOrigin(constrained.origin, height: constrained.height)
            return constrained
        }

        override func setBoundsOrigin(_ newOrigin: NSPoint) {
            super.setBoundsOrigin(heldOrigin(newOrigin, height: bounds.height))
        }

        override func scroll(to newOrigin: NSPoint) {
            super.scroll(to: heldOrigin(newOrigin, height: bounds.height))
        }
    }
    var onBlank: (() -> Void)?
    var onMeasured: (() -> Void)?
    var onOlder: (() -> Void)?
    struct LoadCard {
        let id: String
        let visible: Bool
        let pieces: Set<String>
        let visiblePieces: Set<String>
    }
    var onLoadViewport: (([LoadCard]) -> Void)?
    private var loadViewportPending = false
    private var loadViewportAfterPosition: DispatchWorkItem?
    private func prepareLoadViewport(after delay: Double) {
        guard historyMode else { return }
        loadViewportAfterPosition?.cancel()
        if loadViewportAfterPosition == nil { onLoadViewport?([]) }
        let work = DispatchWorkItem { [weak self] in
            guard let self else { return }
            if let placement = self.replyPlacement, placement.confirmed {
                self.restore(placement.anchor)
                self.replyPlacement = nil
            }
            self.loadViewportAfterPosition = nil
            self.reportLoadViewport()
        }
        loadViewportAfterPosition = work
        DispatchQueue.main.asyncAfter(deadline:.now()+delay,execute:work)
    }
    private func reportLoadViewport() {
        guard historyMode, !loadViewportPending, loadViewportAfterPosition == nil, scrollMotion == nil, onLoadViewport != nil else { return }
        loadViewportPending = true
        DispatchQueue.main.async { [weak self] in
            guard let self else { return }
            self.loadViewportPending = false
            guard self.loadViewportAfterPosition == nil, self.scrollMotion == nil else { return }
            let visible = self.contentView.bounds
            let nearby = visible.insetBy(dx: 0, dy: -visible.height)
            let cards = self.layouts.enumerated().compactMap { index, layout -> LoadCard? in
                let row = self.table.rect(ofRow: index)
                guard row.intersects(nearby) else { return nil }
                var pieces = Set<String>(), visiblePieces = Set<String>()
                for (id, local) in layout.anchors {
                    let frame = local.offsetBy(dx:row.minX,dy:row.minY)
                    if frame.intersects(nearby) { pieces.insert(id) }
                    if frame.intersects(visible) { visiblePieces.insert(id) }
                }
                return LoadCard(id:layout.content.id,visible:row.intersects(visible),
                                pieces:pieces,visiblePieces:visiblePieces)
            }
            let displayed = self.isHiddenOrHasHiddenAncestor ? []:cards
            self.onViewport?(Set(displayed.flatMap(\.visiblePieces)))
            self.onLoadViewport?(displayed)
        }
    }
    var onViewport: ((Set<String>) -> Void)?
    var visibleMessageIDs: Set<String> {
        let visible=contentView.bounds
        return Set(layouts.flatMap { layout -> [String] in
            guard let card=frame(for:layout.content.id),card.intersects(visible) else {return []}
            return layout.anchors.filter {$0.value.offsetBy(dx:card.minX,dy:card.minY).intersects(visible)}.map(\.key)
        })
    }
    private var olderRequestedAt = -Double.infinity
    let table = Table()
    private(set) var contents: [NativeThreadCard.Content] = []
    private(set) var layouts: [NativeThreadCard.Layout] = []
    var reduceMotion:()->Bool={NSWorkspace.shared.accessibilityDisplayShouldReduceMotion}
    var followsAnswer:Bool {contents.isEmpty || documentVisibleRect.maxY>=table.bounds.height-120}
    private var streamingRows=Set<String>()
    private var rowHeights:[CGFloat]=[],shrinking:[String:(shown:CGFloat,at:Double)]=[:]
    private var layingOut = false
    private var measuredWidth: CGFloat = 0
    private var identity = ""
    private var appearanceRevision=ChatAppearance.revision
    private var historyMode=false
    private var scrollRevision = 0
    private var keepGeneration = 0
    private enum ReadingPosition {
        case end(Place)
        case anchor(ReaderAnchor)
    }
    private var userScrolls = 0
    var clock:()->Double={ProcessInfo.processInfo.systemUptime}
    var automaticallyTicks=true
    private var inputMonitor:Any?,observers:[NSObjectProtocol]=[]
    private var followTimer:Timer?,deferredWork:DispatchWorkItem?
    private var deferred:([NativeThreadCard.Content],String,String?,Double,Bool,String?)?
    private var wheelAt = -Double.infinity
    private struct Place {var bottom:CGFloat;var input:Int;var revision:Int}
    private var follow:Place?,settleUntil:Double=0,glidedAt:Double=0,idle=0
    private var resizing:(id:String?,offset:CGFloat,bottom:Bool,input:Int,revision:Int)?
    private var entryID:String?
    private var entryActive=false
    var isFollowing:Bool {follow != nil}
    var hasDeferredUpdate:Bool {deferred != nil}
    /// UTF-16 payload only: attributes, glyphs, images and allocator overhead are separate.
    /// Two bytes per code unit, with a budget of twice the ordinary 5 MiB resident body budget.
    var textPayloadBudgetBytes = 10 * 1024 * 1024
    private func textPayloadBytes(_ groups:[[NativeThreadCard.Content]]) -> Int {
        var strings:[ObjectIdentifier:NSAttributedString]=[:]
        func add(_ text:NSAttributedString) {strings[ObjectIdentifier(text)]=text}
        for cards in groups {for card in cards {for piece in card.top+(card.replies ?? []) {
            switch piece {
            case .post(let post): add(post.text);for mark in post.marks {add(mark.text)}
            case .note(let mark,_): add(mark.text)
            case .stack,.accessory: break
            }
        }}}
        return strings.values.reduce(0) {$0+$1.length*2}
    }
    var renderedTextPayloadBytes:Int {
        textPayloadBytes([contents,layouts.map(\.content),deferred?.0 ?? []])
    }
    var textKitPayloadBytes:Int {
        var bytes=0
        table.enumerateAvailableRowViews { row,_ in
            guard let card=row.view(atColumn:0) as? NativeThreadCard else {return}
            bytes += card.subviews.compactMap {$0 as? NSTextView}.reduce(0) {$0+($1.textStorage?.length ?? 0)*2}
        }
        return bytes
    }
    var textPayloadExcessBytes:Int {max(0,renderedTextPayloadBytes+textKitPayloadBytes-textPayloadBudgetBytes)}
    private struct ScrollTarget {
        let card: String
        let message: String?
        let bottom: Bool
        let keepCentered: Bool
    }
    private var scrollMotion: (target:ScrollTarget,ease:WorkspaceEase,revision:Int,input:Int)?
    private var scrollTimer: Timer?
    private var waitingForTarget = false
    private var waitingOrigin: CGFloat?
    private var measuredDocumentHeight: CGFloat = 0
    private var heldTarget: (target:ScrollTarget,offset:CGFloat?)?
    var onReaderInput: (() -> Void)?
    private var isScrollingToTarget: Bool { waitingForTarget || scrollMotion != nil }

    func beginTargetPositioning() {
        stopTargetPositioning()
        keepGeneration += 1
        entryActive = false
        follow = nil
        waitingForTarget = true
        waitingOrigin = contentView.bounds.minY
    }

    func stopTargetPositioning() {
        waitingForTarget = false
        waitingOrigin = nil
        heldTarget = nil
        scrollMotion = nil
        scrollTimer?.invalidate()
        scrollTimer = nil
    }
    private struct TracedMove {
        let reason: String
        let generation: Int
        let event: Int
    }
    private lazy var traceID = UUID().uuidString
    private var tracedOrigin: CGFloat?
    private var tracedMove: TracedMove?
    private var tracedEvent = 0
    private var tracedLayoutOperation: String?

    private func traceBoundsChange() {
        guard ThreeTapDiagnostics.output != nil else { return }
        let origin = contentView.bounds.minY
        defer { tracedOrigin = origin }
        guard let previous = tracedOrigin, previous != origin else { return }
        let move = tracedMove ?? .init(reason: "appkit", generation: keepGeneration, event: tracedEvent)
        var fields: [String: Any] = [
            "reason": move.reason, "generation": move.generation, "reserved_event": move.event,
            "event": tracedEvent, "before": previous, "after": origin
        ]
        fields["layout_operation"] = tracedLayoutOperation
        ThreeTapDiagnostics.waitJitter("thread_move", view: traceID, fields: fields)
    }

    private func traceInput(_ kind: String) {
        guard ThreeTapDiagnostics.output != nil else { return }
        ThreeTapDiagnostics.waitJitter("input", view: traceID, fields: ["input": kind])
    }

    private struct TracedLayout {
        let ids: [String]
        let heights: [CGFloat]
        let frames: [CGRect]
        let viewport: CGRect
        let documentHeight: CGFloat
    }

    private func traceLayoutBefore() -> TracedLayout? {
        guard ThreeTapDiagnostics.output != nil else { return nil }
        let ids = layouts.map { $0.content.id }
        let bounds = contentView.bounds
        return .init(ids: ids, heights: rowHeights,
                     frames: ids.indices.map { table.rect(ofRow: $0) },
                     viewport: bounds, documentHeight: table.bounds.maxY)
    }

    private func traceLayoutChanges(_ previous: TracedLayout) -> (changed: Bool, rows: [[String: Any]], above: CGFloat) {
        let ids = layouts.map { $0.content.id }
        let changed = ids != previous.ids || rowHeights != previous.heights
        guard changed else { return (false, [], 0) }
        let old = Dictionary(uniqueKeysWithValues: previous.ids.enumerated().map { ($1, $0) })
        let new = Dictionary(uniqueKeysWithValues: ids.enumerated().map { ($1, $0) })
        var rows: [[String: Any]] = []
        var above: CGFloat = 0
        for id in previous.ids + ids.filter({ old[$0] == nil }) {
            let oldIndex = old[id], newIndex = new[id]
            let oldFrame = oldIndex.map { previous.frames[$0] }
            let oldHeight = oldIndex.map { previous.heights[$0] } ?? 0
            let newHeight = newIndex.map { rowHeights[$0] } ?? 0
            guard oldHeight != newHeight || oldIndex != newIndex else { continue }
            let insertionY = newIndex.flatMap { index in
                ids[index...].compactMap { old[$0] }.first.map { previous.frames[$0].minY }
            } ?? previous.documentHeight
            let delta = newHeight - oldHeight + (oldIndex == nil ? table.intercellSpacing.height : 0)
                - (newIndex == nil ? table.intercellSpacing.height : 0)
            let y = oldFrame?.minY ?? insertionY
            let top = previous.viewport.minY
            if (oldFrame?.maxY ?? insertionY) <= top { above += delta }
            rows.append(["id": id.hashValue, "ordinal": newIndex ?? oldIndex ?? 0,
                         "before_y": y, "before_height": oldHeight, "delta": delta,
                         "crosses_top": y < top && (oldFrame?.maxY ?? y) > top])
        }
        return (true, rows, above)
    }

    private func traceLayoutAfter(_ previous: TracedLayout, changed: Bool, rows: [[String: Any]], above: CGFloat) {
        let origin = previous.viewport.minY
        let height = table.bounds.maxY
        let viewport = contentView.bounds.height
        var fields: [String: Any] = [
            "event": tracedEvent, "signature_changed": changed, "cards": rows,
            "height_before": previous.documentHeight, "height_after": height,
            "origin_before": origin, "origin_after": contentView.bounds.minY,
            "viewport_before": previous.viewport.height, "viewport_after": viewport,
            "end_gap": max(0, previous.documentHeight - previous.viewport.maxY), "above_delta": above
        ]
        if let follow {
            fields["follow_gap"] = follow.bottom
            let maximum = max(0, height - viewport)
            fields["follow_distance"] = min(maximum, max(0, maximum - follow.bottom)) - origin
        }
        ThreeTapDiagnostics.waitJitter("thread_layout", view: traceID, fields: fields)
    }

    override class var isCompatibleWithResponsiveScrolling:Bool {false}
    override init(frame: NSRect) {
        super.init(frame: frame)
        contentView = ReadingClipView(frame: contentView.frame)
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
        if ThreeTapDiagnostics.output != nil { tracedOrigin = contentView.bounds.minY }
        contentView.postsBoundsChangedNotifications = true
        observers.append(NotificationCenter.default.addObserver(forName:NSView.boundsDidChangeNotification,object:contentView,queue:.main) { [weak self] _ in
            guard let self else { return }
            self.traceBoundsChange()
            self.reportLoadViewport()
        })
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit {scrollTimer?.invalidate();followTimer?.invalidate();deferredWork?.cancel();if let inputMonitor {NSEvent.removeMonitor(inputMonitor)};for observer in observers {NotificationCenter.default.removeObserver(observer)}}
    override func viewDidMoveToWindow(){super.viewDidMoveToWindow();installInputMonitoring()}
    private func installInputMonitoring(){
        guard inputMonitor==nil else{return}
        observers.append(NotificationCenter.default.addObserver(forName:NSScrollView.willStartLiveScrollNotification,object:self,queue:.main){[weak self] _ in self?.traceInput("live_scroll");self?.readerInput(wheel:false)})
        inputMonitor=NSEvent.addLocalMonitorForEvents(matching:[.scrollWheel,.leftMouseDown,.keyDown]){[weak self] event in
            self?.observeInput(event);return event
        }
    }
    func observeInput(_ event:NSEvent){
        guard !isHiddenOrHasHiddenAncestor,let window,event.window===window else{return}
        let point=convert(event.locationInWindow,from:nil)
        var reading=(event.type == .scrollWheel || event.type == .leftMouseDown) && bounds.contains(point)
        if event.type == .keyDown,[49,115,116,119,121,123,124,125,126].contains(event.keyCode),let responder=window.firstResponder as? NSView {reading=responder===self || responder.isDescendant(of:self)}
        if reading {
            if event.type != .scrollWheel { traceInput(event.type == .keyDown ? "key" : "click") }
            readerInput(wheel:event.type == .scrollWheel)
            if event.type == .scrollWheel { requestHistoryEdges(delta:event.scrollingDeltaY) }
        }
    }
    func readerInput(wheel:Bool){
        keepGeneration += 1
        userScrolls+=1;entryActive=false;follow=nil;followTimer?.invalidate();followTimer=nil
        replyPlacement=nil
        stopTargetPositioning()
        if table.frame.height > measuredDocumentHeight { remeasure(force:true) }
        onReaderInput?()
        if wheel {wheelAt=clock()}
        loadViewportAfterPosition?.cancel()
        loadViewportAfterPosition = nil
        reportLoadViewport()
    }
    private func requestHistoryEdges(delta: CGFloat) {
        guard clock()-olderRequestedAt > 0.35 else {return}
        if delta>0,contentView.bounds.minY<=100 {
            olderRequestedAt=clock();onOlder?()
        }
    }
    override func scrollWheel(with event:NSEvent){
        traceInput("wheel")
        readerInput(wheel:true)
        if ThreeTapDiagnostics.output != nil {
            tracedMove = .init(reason: "reader", generation: keepGeneration, event: tracedEvent)
        }
        super.scrollWheel(with:event)
        tracedMove = nil
        requestHistoryEdges(delta:event.scrollingDeltaY)
    }
    private struct ReaderAnchor { let card: String; let message: String?; let offset: CGFloat; let input: Int; let revision: Int }
    private var replyPlacement: (anchor: ReaderAnchor, confirmed: Bool)?

    private func outgoingReplyAnchor(in contents: [NativeThreadCard.Content]) -> ReaderAnchor? {
        guard let placement = replyPlacement, let pendingID = placement.anchor.message,
              placement.anchor.input == userScrolls, placement.anchor.revision == scrollRevision,
              let card = contents.first(where: { $0.id == placement.anchor.card }) else { return nil }
        let pieces = card.top + (card.replies ?? [])
        let clientID = String(pendingID.dropFirst("pending:".count))
        let confirmed = pieces.contains { piece in
            if case .post(let post) = piece { return !post.pending && post.clientMessageID == clientID }
            return false
        }
        guard confirmed else {
            let pending = pieces.contains { piece in
                if case .post(let post) = piece { return post.pending && post.id == pendingID }
                return false
            }
            return pending ? placement.anchor : nil
        }
        if placement.confirmed { return placement.anchor }
        // Drop corrections captured against the provisional layout. Keep the
        // outgoing reply anchored through the same viewport settling period.
        scrollRevision += 1
        follow = nil
        let anchor = ReaderAnchor(card:placement.anchor.card,message:pendingID,offset:placement.anchor.offset,
                                  input:userScrolls,revision:scrollRevision)
        replyPlacement = (anchor, true)
        return anchor
    }
    private func readerAnchor(allowAtEnd: Bool, preferredMessage: String?) -> ReaderAnchor? {
        let visible = contentView.bounds
        if let preferredMessage, let layout = layouts.first(where:{$0.anchors[preferredMessage] != nil}),
           let rect = frame(for:layout.content.id,message:preferredMessage), rect.intersects(visible) {
            return .init(card:layout.content.id,message:preferredMessage,offset:rect.minY-visible.minY,
                         input:userScrolls,revision:scrollRevision)
        }
        guard allowAtEnd || table.bounds.maxY-visible.maxY > 2 else { return nil }
        for layout in layouts {
            guard let card = frame(for:layout.content.id), card.intersects(visible) else { continue }
            let message = layout.anchors.sorted { $0.value.minY < $1.value.minY }.first {
                $0.value.offsetBy(dx:card.minX,dy:card.minY).intersects(visible)
            }?.key
            let rect = frame(for:layout.content.id,message:message) ?? card
            return .init(card:layout.content.id,message:message,offset:rect.minY-visible.minY,input:userScrolls,revision:scrollRevision)
        }
        return nil
    }
    private func restore(_ anchor: ReaderAnchor, reservedEvent: Int? = nil) {
        guard userScrolls == anchor.input, scrollRevision == anchor.revision,
              follow == nil, resizing == nil, !entryActive,
              let rect = frame(for:anchor.card,message:anchor.message) else { return }
        move(to:rect.minY-anchor.offset, reason:"anchor", reservedEvent:reservedEvent)
    }
    func show(_ contents:[NativeThreadCard.Content],identity:String,entry:String?=nil,historyMode:Bool=false, autoloadAppended:Bool=false, prependAnchor:String?=nil){
        self.historyMode=historyMode
        func bodyIDs(_ cards:[NativeThreadCard.Content])->Set<String> {
            Set(cards.flatMap{($0.top+($0.replies ?? [])).compactMap{piece -> String? in
                if case .post(let post)=piece {return post.id};return nil
            }})
        }
        let removed=historyMode && !bodyIDs(self.contents).subtracting(bodyIDs(contents)).isEmpty
        if appearanceRevision != ChatAppearance.revision {
            appearanceRevision=ChatAppearance.revision;deferredWork?.cancel();deferredWork=nil;deferred=nil
            apply(contents,identity:identity,entry:entry,autoloadAppended:autoloadAppended,prependAnchor:prependAnchor);return
        }
        // Do not retain an extra generation of text while over budget. Required visible/
        // pinned content remains displayed; its excess is observable instead of truncated.
        let canDefer = !historyMode || textPayloadBytes([self.contents,self.layouts.map(\.content),contents])+textKitPayloadBytes <= textPayloadBudgetBytes
        if !removed,canDefer,identity==self.identity,clock()-wheelAt<0.25 {
            let start=deferred?.3 ?? clock()
            if clock()-start<2 {
                deferred=(contents,identity,entry,start,autoloadAppended || deferred?.4 == true,prependAnchor ?? deferred?.5);deferredWork?.cancel()
                let work=DispatchWorkItem{[weak self] in self?.flushDeferred()};deferredWork=work
                DispatchQueue.main.asyncAfter(deadline:.now()+0.25,execute:work)
                if let before = traceLayoutBefore() {
                    traceLayoutAfter(before, changed:false, rows:[], above:0)
                }
                return
            }
        }
        let appended = autoloadAppended || (identity == self.identity && deferred?.4 == true)
        let preferred = prependAnchor ?? (identity == self.identity ? deferred?.5:nil)
        deferredWork?.cancel();deferredWork=nil;deferred=nil
        apply(contents,identity:identity,entry:entry,autoloadAppended:appended,prependAnchor:preferred)
    }
    func flushDeferred(){
        guard let (contents,identity,entry,start,autoloadAppended,prependAnchor)=deferred else{return}
        if clock()-wheelAt<0.25,clock()-start<2 {
            let work=DispatchWorkItem{[weak self] in self?.flushDeferred()};deferredWork=work
            DispatchQueue.main.asyncAfter(deadline:.now()+0.25,execute:work);return
        }
        deferred=nil;deferredWork=nil;apply(contents,identity:identity,entry:entry,autoloadAppended:autoloadAppended,prependAnchor:prependAnchor)
        onMeasured?()
    }
    private func apply(_ contents:[NativeThreadCard.Content],identity:String,entry:String?,autoloadAppended:Bool,prependAnchor:String?){
        let outgoingReply = historyMode ? outgoingReplyAnchor(in:contents):nil
        let anchor = historyMode && outgoingReply == nil
            ? readerAnchor(allowAtEnd:autoloadAppended,preferredMessage:prependAnchor) : nil
        keepGeneration += 1
        let oldHeights = rowHeights
        let oldIDs = self.contents.map(\.id)
        let oldAnchors = historyMode ? layouts.map(\.anchors):[]
        let changed=self.identity != identity,old=place(),oldStreaming = !streamingRows.isEmpty
        if changed {
            traceInput("selection");scrollRevision+=1;follow=nil
            let waiting = waitingForTarget
            stopTargetPositioning()
            waitingForTarget = waiting
            entryActive = true;entryID=entry
        }
        func streaming(_ content:NativeThreadCard.Content)->Bool {(content.top+(content.replies ?? [])).contains{if case .post(let post)=$0{return post.streaming};return false}}
        let streamingNow=Set(contents.filter(streaming).map(\.id))
        streamingRows=Set(self.contents.filter(streaming).map(\.id)).union(streamingNow)
        if outgoingReply==nil,!changed,follow==nil,!isScrollingToTarget,!streamingNow.isEmpty,old.bottom<=120,resizing==nil {follow=Place(bottom:0,input:userScrolls,revision:scrollRevision);glidedAt=clock();idle=0}
        self.identity=identity;self.contents=contents;remeasure(force:true)
        if entryActive {
            entryID=entry
            placeEntry()
            if waitingForTarget { waitingOrigin = contentView.bounds.minY }
        } else if waitingForTarget, let origin = waitingOrigin {
            move(to:origin,reason:"keep")
        } else if let follow {
            if oldStreaming && streamingNow.isEmpty {settleUntil=clock()+1.2}
            if reduceMotion(){restore(follow, reason:"follow")}else{startFollowing()}
        } else if !changed,resizing==nil,!isScrollingToTarget {
            let geometryChanged = oldHeights != rowHeights || oldIDs != contents.map(\.id)
                || (historyMode && oldAnchors != layouts.map(\.anchors))
            if geometryChanged {
                if prependAnchor != nil, let anchor {
                    keep(.anchor(anchor))
                } else if let heldTarget, let rect=targetFrame(heldTarget.target) {
                    let origin = heldTarget.offset.map { rect.minY - $0 }
                        ?? scrollOrigin(for:rect,bottom:heldTarget.target.bottom)
                    move(to:origin,reason:"anchor")
                } else if let outgoingReply {
                    // While pending, scrollTo owns positioning and animation.
                    // Only the confirmation replaces that placement.
                    if replyPlacement?.confirmed == true {
                        keep(.anchor(outgoingReply))
                    }
                } else {
                    keep(anchor.map(ReadingPosition.anchor) ?? .end(old))
                }
                prepareLoadViewport(after:0.4)
            }
        }
        streamingRows=streamingNow
        reportLoadViewport()
    }
    private func place()->Place {Place(bottom:max(0,table.bounds.maxY-contentView.bounds.maxY),input:userScrolls,revision:scrollRevision)}
    private func move(to y:CGFloat, reason:String, reservedEvent:Int?=nil){
        if ThreeTapDiagnostics.output != nil {
            tracedMove = .init(reason:reason, generation:keepGeneration, event:reservedEvent ?? tracedEvent)
        }
        defer { tracedMove = nil }
        contentView.scroll(to:CGPoint(x:contentView.bounds.minX,y:min(max(0,y),max(0,table.bounds.height-contentView.bounds.height))))
        reflectScrolledClipView(contentView)
    }
    private func restore(_ place:Place, reason:String, reservedEvent:Int?=nil){
        guard place.input==userScrolls,place.revision==scrollRevision else{return}
        move(to:table.bounds.maxY-place.bottom-contentView.bounds.height, reason:reason, reservedEvent:reservedEvent)
    }
    private func keep(_ position: ReadingPosition) {
        let generation = keepGeneration
        let reservedEvent = tracedEvent
        let correct: () -> Void = { [weak self] in
            guard let self, self.keepGeneration == generation, self.follow == nil,
                  self.resizing == nil, !self.entryActive, !self.isScrollingToTarget else { return }
            switch position {
            case .end(let place): self.restore(place, reason:"keep", reservedEvent:reservedEvent)
            case .anchor(let anchor): self.restore(anchor, reservedEvent:reservedEvent)
            }
        }
        // Restore during this layout pass, before another snapshot can read the old origin.
        correct()
        for delay in [0.06, 0.2, 0.4] {
            DispatchQueue.main.asyncAfter(deadline:.now()+delay, execute:correct)
        }
    }
    private func startFollowing(){guard automaticallyTicks,followTimer==nil else{return};let timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.advanceFollow()};followTimer=timer;RunLoop.main.add(timer,forMode:.common)}
    /// Source glideStep: growth eases by elapsed frames, shrink settles immediately.
    func advanceFollow(){
        guard let follow,follow.input==userScrolls,follow.revision==scrollRevision else{self.follow=nil;followTimer?.invalidate();followTimer=nil;return}
        let now = clock()
        let viewportHeight = contentView.bounds.height
        let current = contentView.bounds.minY
        let displayedEnd = max(0, table.bounds.maxY - viewportHeight - follow.bottom)
        var wanted = displayedEnd
        if !shrinking.isEmpty {
            let settledHeight = layouts.reduce(CGFloat(0)) {
                $0 + $1.height + table.intercellSpacing.height
            }
            let settledEnd = max(0, settledHeight - viewportHeight - follow.bottom)
            // Avoid following the part of the document that is about to disappear.
            wanted = min(displayedEnd, max(current, settledEnd))
        }
        let gap = wanted - current
        if abs(gap)<=0.5 {
            idle+=1
            if idle>=24,now>=settleUntil,streamingRows.isEmpty {self.follow=nil;followTimer?.invalidate();followTimer=nil};return
        }
        idle=0;let frames=CGFloat(min(6,max(1,(now-glidedAt)*60)));glidedAt=now
        let next:CGFloat
        if gap<0 || reduceMotion(){next=wanted}
        else {let share=abs(gap)*(1-pow(0.8,frames));next=gap<=2 ? wanted:contentView.bounds.minY+min(abs(gap),36*frames,max(2,share))}
        move(to:next, reason:"follow")
    }
    func frame(for id:String,message:String?=nil,requiresMessage:Bool=false)->CGRect? {
        guard let index=contents.firstIndex(where:{$0.id==id}),layouts.indices.contains(index) else{return nil}
        let row=table.rect(ofRow:index)
        guard let message else { return row }
        let layout = layouts[index]
        if let rect = layout.anchors[message] { return rect.offsetBy(dx:row.minX,dy:row.minY) }
        // An in-flight scroll can outlive the pending piece. Its server-confirmed
        // replacement still identifies the same outgoing reply.
        if message.hasPrefix("pending:") {
            let clientID = String(message.dropFirst("pending:".count))
            for item in layout.placed {
                if case .post(let post) = item.piece, post.clientMessageID == clientID,
                   let rect = layout.anchors[post.id] {
                    return rect.offsetBy(dx:row.minX,dy:row.minY)
                }
            }
        }
        return requiresMessage ? nil : row
    }
    private func targetFrame(_ target:ScrollTarget)->CGRect? {
        frame(for:target.card,message:target.message,requiresMessage:target.message != nil)
    }
    private func scrollOrigin(for rect: CGRect, bottom: Bool) -> CGFloat {
        let bounds = contentView.bounds
        let wanted = bottom ? rect.maxY-bounds.height : rect.midY-bounds.height/2
        return min(max(0,wanted),max(0,measuredDocumentHeight-bounds.height))
    }
    func scrollTo(_ id:String,message:String?=nil,bottom:Bool=false,immediate:Bool=false,keepCentered:Bool=false) {
        traceInput("scroll_to")
        stopTargetPositioning()
        keepGeneration += 1
        scrollRevision += 1
        entryActive = false
        follow = nil
        replyPlacement = nil
        let target = ScrollTarget(card:id,message:message,bottom:bottom,keepCentered:immediate || keepCentered)
        guard let rect = targetFrame(target) else { return }
        let goal = scrollOrigin(for:rect,bottom:bottom)
        let pending = historyMode && message?.hasPrefix("pending:") == true
        if pending,let message {
            let anchor = ReaderAnchor(card:id,message:message,offset:rect.minY-goal,input:userScrolls,revision:scrollRevision)
            replyPlacement = (anchor,false)
        }
        if immediate || reduceMotion() {
            move(to:goal,reason:"scroll_to")
            if table.frame.height > measuredDocumentHeight { remeasure(force:true) }
            if !pending { heldTarget = (target,target.keepCentered ? nil:rect.minY-goal) }
            reportLoadViewport()
            return
        }
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.scrollStarts += 1
        #endif
        scrollMotion = (target,.init(from:contentView.bounds.minY,to:goal,start:clock()),scrollRevision,userScrolls)
        prepareLoadViewport(after:SidebarMotion.duration)
        let timer = Timer(timeInterval:1.0/60,repeats:true) { [weak self] _ in self?.advanceScroll() }
        scrollTimer = timer
        RunLoop.main.add(timer,forMode:.common)
    }

    func advanceScroll() {
        guard var motion = scrollMotion,motion.revision == scrollRevision,motion.input == userScrolls,
              let frame = targetFrame(motion.target) else {
            if scrollMotion != nil { stopTargetPositioning();remeasure(force:true) }
            return
        }
        motion.ease.to = scrollOrigin(for:frame,bottom:motion.target.bottom)
        let time = clock()
        move(to:motion.ease.value(time),reason:"scroll_to")
        if motion.ease.pending(time) {
            scrollMotion = motion
        } else {
            stopTargetPositioning()
            if table.frame.height > measuredDocumentHeight { remeasure(force:true) }
            if replyPlacement == nil {
                heldTarget = (motion.target,motion.target.keepCentered ? nil:frame.minY-motion.ease.to)
            }
            reportLoadViewport()
        }
    }

    func enter(_ id:String?,bottom:Bool=false) {
        traceInput("entry");keepGeneration+=1;scrollRevision+=1;follow=nil
        heldTarget = nil
        entryActive=true;entryID=id;placeEntry(bottom:bottom)
        if waitingForTarget { waitingOrigin = contentView.bounds.minY }
    }
    private func placeEntry(bottom:Bool=false){
        guard entryActive else{return}
        if let id=entryID,let rect=frame(for:id) {move(to:bottom ? rect.maxY-contentView.bounds.height:rect.midY-contentView.bounds.height/2, reason:"entry")}
        else {move(to:table.bounds.height-contentView.bounds.height, reason:"entry")}
        if !contents.isEmpty {entryActive=false}
    }
    func beginReadingResize(){guard resizing==nil else{return};let visible=contentView.bounds,id=contents.first{frame(for:$0.id)?.intersects(visible)==true}?.id
        resizing=(id,id.flatMap{frame(for:$0)}.map{$0.minY-visible.minY} ?? 0,table.bounds.maxY-visible.maxY<=2,userScrolls,scrollRevision)
    }
    func endReadingResize(){defer{resizing=nil};restoreResize()}
    private func restoreResize(){guard let held=resizing,held.input==userScrolls,held.revision==scrollRevision else{return}
        if held.bottom {move(to:table.bounds.height-contentView.bounds.height, reason:"resize")}else if let id=held.id,let rect=frame(for:id){move(to:rect.minY-held.offset, reason:"resize")}
    }
    override func viewWillStartLiveResize(){beginReadingResize();super.viewWillStartLiveResize()}
    override func viewDidEndLiveResize(){super.viewDidEndLiveResize();endReadingResize()}
    override func layout() {
        super.layout()
        remeasure()
        if !inLiveResize,let heldTarget,heldTarget.offset == nil,
           let frame = targetFrame(heldTarget.target) {
            let origin = scrollOrigin(for:frame,bottom:heldTarget.target.bottom)
            if abs(origin-contentView.bounds.minY) > 0.5 { move(to:origin,reason:"anchor") }
        }
    }
    private func remeasure(force: Bool = false) {
        let width = max(1, contentSize.width)
        guard !layingOut, force || abs(width - measuredWidth) > 0.5 else { return }
        layingOut = true; defer { layingOut = false }
        let traceBefore = traceLayoutBefore()
        let resized=abs(width-measuredWidth)>0.5
        let ownsResize=resized && resizing==nil
        if ownsResize {beginReadingResize()}
        measuredWidth = width
        let oldHeights = rowHeights
        let follows=followsAnswer,previousHeights=Dictionary(uniqueKeysWithValues:zip(layouts.map{$0.content.id},oldHeights))
        let previousIDs = layouts.map { $0.content.id }
        layouts = contents.map { NativeThreadCard.layout($0, width: max(1, width - 2 * ChatMetrics.horizontalInset)) }
        rowHeights=layouts.map { layout in
            let now=ProcessInfo.processInfo.systemUptime,height=layout.height,previous=shrinking[layout.content.id]?.shown ?? previousHeights[layout.content.id]
            guard follows,(streamingRows.contains(layout.content.id) || shrinking[layout.content.id] != nil),!reduceMotion(),let previous,height<previous-0.5,previous-height<160 else {shrinking[layout.content.id]=nil;return height}
            let last=shrinking[layout.content.id]?.at ?? 0,shown=now-last<1.0/90 ? previous:max(height,previous-6)
            shrinking[layout.content.id]=(shown,shown==previous ? last:now)
            if shown>height {DispatchQueue.main.asyncAfter(deadline:.now()+1.0/60){[weak self] in self?.remeasure(force:true)}}else{shrinking[layout.content.id]=nil}
            return shown
        }
        let changes = traceBefore.map { traceLayoutChanges($0) }
        if changes?.changed == true { tracedEvent += 1 }
        defer {
            if let traceBefore, let changes {
                traceLayoutAfter(traceBefore, changed:changes.changed, rows:changes.rows, above:changes.above)
            }
        }
        let clip = contentView as? ReadingClipView
        let height = rowHeights.reduce(CGFloat(0)) { $0 + $1 + table.intercellSpacing.height }
        measuredDocumentHeight = max(contentSize.height,height)
        // Keep the starting viewport scrollable while switching from an expanded card
        // to a shorter document. The movement settles against the measured rows.
        let targetOrigin = waitingOrigin ?? scrollMotion?.ease.from
        let documentHeight = targetOrigin.map { max(measuredDocumentHeight,$0+contentView.bounds.height) } ?? measuredDocumentHeight
        if !resized && resizing == nil && !entryActive {
            clip?.originDuringLayout = contentView.bounds.minY
            if targetOrigin != nil { clip?.documentHeightDuringLayout = documentHeight }
        }
        tracedLayoutOperation = traceBefore == nil ? nil : "configure"
        if table.tableColumns.first?.width != width { table.tableColumns.first?.width = width }
        if table.frame.width != width { table.frame.size.width = width }
        if previousIDs == contents.map(\.id), table.numberOfRows == layouts.count {
            for index in layouts.indices {
                (table.view(atColumn: 0, row: index, makeIfNecessary: false) as? NativeThreadCard)?.configure(layouts[index])
            }
            let changedRows = IndexSet(layouts.indices.filter { oldHeights[$0] != rowHeights[$0] })
            if !changedRows.isEmpty {
                tracedLayoutOperation = traceBefore == nil ? nil : "row_heights"
                table.noteHeightOfRows(withIndexesChanged: changedRows)
            }
        } else { table.reloadData() }
        let oldHeight = table.frame.height
        tracedLayoutOperation = traceBefore == nil ? nil : "document_frame"
        if table.frame.height != documentHeight { table.frame.size.height = documentHeight }
        clip?.originDuringLayout = nil
        clip?.documentHeightDuringLayout = nil
        tracedLayoutOperation = nil
        if resizing != nil {restoreResize();if ownsResize && !inLiveResize {resizing=nil}}
        if entryActive {placeEntry()}
        reportLoadViewport()
        if abs(oldHeight - table.frame.height) > 0.5 { DispatchQueue.main.async { [weak self] in self?.onMeasured?() } }
    }
    func tableView(_ tableView:NSTableView,didRemove rowView:NSTableRowView,forRow row:Int) {
        (rowView.view(atColumn:0) as? NativeThreadCard)?.releaseContent()
    }
    func numberOfRows(in tableView: NSTableView) -> Int { layouts.count }
    func tableView(_ tableView: NSTableView, shouldSelectRow row: Int) -> Bool { false }
    func tableView(_ tableView: NSTableView, heightOfRow row: Int) -> CGFloat { rowHeights[row] }
    func tableView(_ tableView: NSTableView, viewFor column: NSTableColumn?, row: Int) -> NSView? {
        let id = NSUserInterfaceItemIdentifier("native-card")
        let cell = tableView.makeView(withIdentifier: id, owner: nil) as? NativeThreadCard ?? NativeThreadCard(frame: .zero)
        cell.identifier = id; cell.configure(layouts[row]); return cell
    }
}
