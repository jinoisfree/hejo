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
    var reduceMotion:()->Bool={NSWorkspace.shared.accessibilityDisplayShouldReduceMotion}
    var followsAnswer:Bool {contents.isEmpty || documentVisibleRect.maxY>=table.bounds.height-120}
    private var streamingRows=Set<String>()
    private var rowHeights:[CGFloat]=[],shrinking:[String:(shown:CGFloat,at:Double)]=[:]
    private var layingOut = false
    private var measuredWidth: CGFloat = 0
    private var identity = ""
    private var appearanceRevision=ChatAppearance.revision
    private var scrollRevision = 0
    private var userScrolls = 0
    var clock:()->Double={ProcessInfo.processInfo.systemUptime}
    var automaticallyTicks=true
    private var inputMonitor:Any?,observers:[NSObjectProtocol]=[]
    private var followTimer:Timer?,deferredWork:DispatchWorkItem?
    private var deferred:([NativeThreadCard.Content],String,String?,Double)?
    private var wheelAt = -Double.infinity
    private struct Place {var bottom:CGFloat;var input:Int;var revision:Int}
    private var follow:Place?,settleUntil:Double=0,glidedAt:Double=0,idle=0
    private var resizing:(id:String?,offset:CGFloat,bottom:Bool,input:Int,revision:Int)?
    private var entryID:String?
    private var entryActive=false
    var isFollowing:Bool {follow != nil}
    var hasDeferredUpdate:Bool {deferred != nil}
    private var scrollMotion:(ease:WorkspaceEase,revision:Int,input:Int)?
    private var scrollTimer:Timer?
    override class var isCompatibleWithResponsiveScrolling:Bool {false}
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
    deinit {scrollTimer?.invalidate();followTimer?.invalidate();deferredWork?.cancel();if let inputMonitor {NSEvent.removeMonitor(inputMonitor)};for observer in observers {NotificationCenter.default.removeObserver(observer)}}
    override func viewDidMoveToWindow(){super.viewDidMoveToWindow();installInputMonitoring()}
    private func installInputMonitoring(){
        guard inputMonitor==nil else{return}
        observers.append(NotificationCenter.default.addObserver(forName:NSScrollView.willStartLiveScrollNotification,object:self,queue:.main){[weak self] _ in self?.readerInput(wheel:false)})
        inputMonitor=NSEvent.addLocalMonitorForEvents(matching:[.scrollWheel,.leftMouseDown,.keyDown]){[weak self] event in
            self?.observeInput(event);return event
        }
    }
    func observeInput(_ event:NSEvent){
        guard !isHiddenOrHasHiddenAncestor,let window,event.window===window else{return}
        let point=convert(event.locationInWindow,from:nil)
        var reading=(event.type == .scrollWheel || event.type == .leftMouseDown) && bounds.contains(point)
        if event.type == .keyDown,[49,115,116,119,121,123,124,125,126].contains(event.keyCode),let responder=window.firstResponder as? NSView {reading=responder===self || responder.isDescendant(of:self)}
        if reading {readerInput(wheel:event.type == .scrollWheel)}
    }
    func readerInput(wheel:Bool){
        userScrolls+=1;entryActive=false;follow=nil;followTimer?.invalidate();followTimer=nil
        scrollMotion=nil;scrollTimer?.invalidate();scrollTimer=nil
        if wheel {wheelAt=clock()}
    }
    override func scrollWheel(with event:NSEvent){readerInput(wheel:true);super.scrollWheel(with:event)}
    func show(_ contents:[NativeThreadCard.Content],identity:String,entry:String?=nil){
        if appearanceRevision != ChatAppearance.revision {
            appearanceRevision=ChatAppearance.revision;deferredWork?.cancel();deferredWork=nil;deferred=nil
            apply(contents,identity:identity,entry:entry);return
        }
        if identity==self.identity,clock()-wheelAt<0.25 {
            let start=deferred?.3 ?? clock()
            if clock()-start<2 {
                deferred=(contents,identity,entry,start);deferredWork?.cancel()
                let work=DispatchWorkItem{[weak self] in self?.flushDeferred()};deferredWork=work
                DispatchQueue.main.asyncAfter(deadline:.now()+0.25,execute:work);return
            }
        }
        deferredWork?.cancel();deferredWork=nil;deferred=nil
        apply(contents,identity:identity,entry:entry)
    }
    func flushDeferred(){
        guard let (contents,identity,entry,start)=deferred else{return}
        if clock()-wheelAt<0.25,clock()-start<2 {
            let work=DispatchWorkItem{[weak self] in self?.flushDeferred()};deferredWork=work
            DispatchQueue.main.asyncAfter(deadline:.now()+0.25,execute:work);return
        }
        deferred=nil;deferredWork=nil;apply(contents,identity:identity,entry:entry)
    }
    private func apply(_ contents:[NativeThreadCard.Content],identity:String,entry:String?){
        let changed=self.identity != identity,old=place(),oldStreaming = !streamingRows.isEmpty
        if changed {scrollRevision+=1;follow=nil;entryActive=true;entryID=entry}
        func streaming(_ content:NativeThreadCard.Content)->Bool {(content.top+(content.replies ?? [])).contains{if case .post(let post)=$0{return post.streaming};return false}}
        let streamingNow=Set(contents.filter(streaming).map(\.id))
        streamingRows=Set(self.contents.filter(streaming).map(\.id)).union(streamingNow)
        if !changed,follow==nil,!streamingNow.isEmpty,old.bottom<=120,resizing==nil {follow=Place(bottom:0,input:userScrolls,revision:scrollRevision);glidedAt=clock();idle=0}
        self.identity=identity;self.contents=contents;remeasure(force:true)
        if entryActive {entryID=entry;placeEntry()}
        else if let follow {
            if oldStreaming && streamingNow.isEmpty {settleUntil=clock()+1.2}
            if reduceMotion(){restore(follow)}else{startFollowing()}
        } else if !changed,resizing==nil {keep(old)}
        streamingRows=streamingNow
    }
    private func place()->Place {Place(bottom:max(0,table.bounds.maxY-contentView.bounds.maxY),input:userScrolls,revision:scrollRevision)}
    private func move(to y:CGFloat){contentView.scroll(to:CGPoint(x:contentView.bounds.minX,y:min(max(0,y),max(0,table.bounds.height-contentView.bounds.height))));reflectScrolledClipView(contentView)}
    private func restore(_ place:Place){guard place.input==userScrolls,place.revision==scrollRevision else{return};move(to:table.bounds.maxY-place.bottom-contentView.bounds.height)}
    private func keep(_ place:Place){for delay in [0.0,0.06,0.2,0.4] {DispatchQueue.main.asyncAfter(deadline:.now()+delay){[weak self] in guard let self,self.follow==nil,self.resizing==nil,!self.entryActive else{return};self.restore(place)}}}
    private func startFollowing(){guard automaticallyTicks,followTimer==nil else{return};let timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.advanceFollow()};followTimer=timer;RunLoop.main.add(timer,forMode:.common)}
    /// Source glideStep: growth eases by elapsed frames, shrink settles immediately.
    func advanceFollow(){
        guard let follow,follow.input==userScrolls,follow.revision==scrollRevision else{self.follow=nil;followTimer?.invalidate();followTimer=nil;return}
        let now=clock(),wanted=min(max(0,table.bounds.maxY-follow.bottom-contentView.bounds.height),max(0,table.bounds.maxY-contentView.bounds.height)),gap=wanted-contentView.bounds.minY
        if abs(gap)<=0.5 {
            idle+=1
            if idle>=24,now>=settleUntil,streamingRows.isEmpty {self.follow=nil;followTimer?.invalidate();followTimer=nil};return
        }
        idle=0;let frames=CGFloat(min(6,max(1,(now-glidedAt)*60)));glidedAt=now
        let next:CGFloat
        if gap<0 || reduceMotion(){next=wanted}
        else {let share=abs(gap)*(1-pow(0.8,frames));next=gap<=2 ? wanted:contentView.bounds.minY+min(abs(gap),36*frames,max(2,share))}
        move(to:next)
    }
    func frame(for id:String,message:String?=nil)->CGRect? {
        guard let index=contents.firstIndex(where:{$0.id==id}),layouts.indices.contains(index) else{return nil}
        let row=table.rect(ofRow:index)
        return message.flatMap{layouts[index].anchors[$0]}.map{$0.offsetBy(dx:row.minX,dy:row.minY)} ?? row
    }
    func scrollTo(_ id:String,message:String?=nil,bottom:Bool=false){
        entryActive=false;scrollRevision+=1;follow=nil
        let revision=scrollRevision,input=userScrolls
        for delay in [0.0,0.15,0.45] {DispatchQueue.main.asyncAfter(deadline:.now()+delay){[weak self] in
            guard let self,self.scrollRevision==revision,self.userScrolls==input,let rect=self.frame(for:id,message:message) else{return}
            let bounds=self.contentView.bounds,wanted=bottom ? rect.maxY-bounds.height:rect.midY-bounds.height/2
            let y=min(max(0,wanted),max(0,self.table.bounds.height-bounds.height))
            if self.reduceMotion(){self.move(to:y)}else{
                #if HEJO_PERF_TESTING
                HejoSmoothProbe.scrollStarts += 1
                #endif
                self.scrollMotion=(WorkspaceEase(from:bounds.minY,to:y,start:self.clock()),revision,input)
                if self.scrollTimer==nil {let timer=Timer(timeInterval:1.0/60,repeats:true){[weak self] _ in self?.advanceScroll()};self.scrollTimer=timer;RunLoop.main.add(timer,forMode:.common)}}
            self.reflectScrolledClipView(self.contentView)
        }}
    }
    func advanceScroll(){guard let motion=scrollMotion,motion.revision==scrollRevision,motion.input==userScrolls else{scrollMotion=nil;scrollTimer?.invalidate();scrollTimer=nil;return};move(to:motion.ease.value(clock()));if !motion.ease.pending(clock()) {scrollMotion=nil;scrollTimer?.invalidate();scrollTimer=nil}}
    func enter(_ id:String?,bottom:Bool=false){scrollRevision+=1;follow=nil;entryActive=true;entryID=id;placeEntry(bottom:bottom)}
    private func placeEntry(bottom:Bool=false){
        guard entryActive else{return}
        if let id=entryID,let rect=frame(for:id) {move(to:bottom ? rect.maxY-contentView.bounds.height:rect.midY-contentView.bounds.height/2)}
        else {move(to:table.bounds.height-contentView.bounds.height)}
        if !contents.isEmpty {entryActive=false}
    }
    func beginReadingResize(){guard resizing==nil else{return};let visible=contentView.bounds,id=contents.first{frame(for:$0.id)?.intersects(visible)==true}?.id
        resizing=(id,id.flatMap{frame(for:$0)}.map{$0.minY-visible.minY} ?? 0,table.bounds.maxY-visible.maxY<=2,userScrolls,scrollRevision)
    }
    func endReadingResize(){defer{resizing=nil};restoreResize()}
    private func restoreResize(){guard let held=resizing,held.input==userScrolls,held.revision==scrollRevision else{return}
        if held.bottom {move(to:table.bounds.height-contentView.bounds.height)}else if let id=held.id,let rect=frame(for:id){move(to:rect.minY-held.offset)}
    }
    override func viewWillStartLiveResize(){beginReadingResize();super.viewWillStartLiveResize()}
    override func viewDidEndLiveResize(){super.viewDidEndLiveResize();endReadingResize()}
    override func layout() { super.layout(); remeasure() }
    private func remeasure(force: Bool = false) {
        let width = max(1, contentSize.width)
        guard !layingOut, force || abs(width - measuredWidth) > 0.5 else { return }
        layingOut = true; defer { layingOut = false }
        let resized=abs(width-measuredWidth)>0.5
        let ownsResize=resized && resizing==nil
        if ownsResize {beginReadingResize()}
        measuredWidth = width
        let follows=followsAnswer,previousHeights=Dictionary(uniqueKeysWithValues:zip(layouts.map{$0.content.id},rowHeights))
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
        table.tableColumns.first?.width = width
        table.frame.size.width = width
        if previousIDs == contents.map(\.id), table.numberOfRows == layouts.count {
            for index in layouts.indices {
                (table.view(atColumn: 0, row: index, makeIfNecessary: false) as? NativeThreadCard)?.configure(layouts[index])
            }
            table.noteHeightOfRows(withIndexesChanged: IndexSet(integersIn: layouts.indices))
        } else { table.reloadData() }
        let height = rowHeights.reduce(CGFloat(0)) { $0 + $1 + table.intercellSpacing.height }
        let oldHeight = table.frame.height
        table.frame.size.height = max(contentSize.height, height)
        if resizing != nil {restoreResize();if ownsResize && !inLiveResize {resizing=nil}}
        if entryActive {placeEntry()}
        if abs(oldHeight - table.frame.height) > 0.5 { DispatchQueue.main.async { [weak self] in self?.onMeasured?() } }
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
