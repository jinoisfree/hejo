import AppKit

/// CalendarSource is the external boundary: every calendar test uses this synthetic, read-only source.
final class FixtureCalendarSource: CalendarSource {
    var access: CalendarAccess = .allowed
    var values: [CalendarEntry] = []
    var requests = 0
    var intervals: [(Date,Date)] = []
    func requestAccess(_ completion: @escaping () -> Void) { requests += 1;completion() }
    func events(from:Date,to:Date)->[CalendarEntry] {intervals.append((from,to));return values.filter{$0.start < to && $0.end > from}}
}

@MainActor func calendarTests(outputDirectory:URL? = nil) async throws {
    try webToolbarTests()
    var clock = Calendar(identifier:.gregorian);clock.timeZone = TimeZone.current
    let reference = clock.date(from:DateComponents(year:2030,month:11,day:18))!
    func event(_ id:String,_ title:String,_ offset:Int = 0,location:String = "",calendarID:String = "fixture")->CalendarEntry {
        let start = reference.addingTimeInterval(Double(offset)*86400+15*3600)
        return CalendarEntry(identifier:id,calendarID:calendarID,title:title,start:start,end:start.addingTimeInterval(3600),calendar:"시험 일정",location:location,notes:"합성 메모")
    }
    let meeting = event("meeting","3시 회의",1),dental = event("dental","치과",2),review = event("review","분기 계획 검토",8)
    let values = [meeting,dental,review]
    func matches(_ text:String)->[CalendarEntry] {CalendarMatch.related(to:text,at:reference,events:values,calendar:clock)}
    try check(matches("내일 3시 회의") == [meeting],"AT97 tomorrow uses received message date, not wall clock")
    try check(matches("다음주 화요일 분기 계획 검토") == [review],"AT97 next week Tuesday starts from Monday")
    try check(matches("11월 20일 치과") == [dental],"AT97 month/day inherits message year")
    try check(matches("오늘 치과대학 설명").isEmpty && matches("다음 주").isEmpty,"AT97 short title word boundary; bare week cannot invent an appointment")
    try check(CalendarMatch.related(to:"내일 회의",at:reference,events:[event("generic","회의",1)],calendar:clock).isEmpty,"AT97 generic meeting title alone cannot identify an event")
    try check(CalendarMatch.days(in:"2월 30일",relativeTo:reference,calendar:clock).isEmpty,"AT97 invalid calendar date")
    try check(matches("November 20, 2030 치과") == [dental],"AT97 English dates")
    let located = event("located","설계 검토",1,location:"시험 회의실")
    try check(CalendarMatch.related(to:"내일 시험 회의실 주차",at:reference,events:[located],calendar:clock) == [located],"AT97 explicit day and specific location")
    try check(CalendarMatch.related(to:"시험 회의실 운영 시간",at:reference,events:[located],calendar:clock).isEmpty,"AT97 location alone does not match")
    let other = event("meeting","3시 회의",1,calendarID:"other")
    try check(CalendarMatch.related(to:"내일 3시 회의",at:reference,events:[meeting,meeting,other],calendar:clock).count == 2,"AT97 identities distinguish calendars and remove exact duplicates")
    try check(BubbleReveal.Action.content("내일 3시 회의",events:[meeting],at:reference).map(\.title) == ["일정 보기"],"AT97 one real event button")
    let actions = BubbleReveal.Action.bubble("https://example.invalid 내일 3시 회의",events:[meeting,other],at:reference)
    try check(actions.map(\.title) == ["링크 열기","관련 일정 2개","나중에 알려줘"],"AT97 two content actions omit open-chat; maximum three")
    try check(BubbleReveal.Action.bubble("내일 3시 회의",at:reference).map(\.title) == ["대화 열기","나중에 알려줘"],"AT97 no fabricated event without calendar snapshots")
    let source = FixtureCalendarSource(),model = MacCalendar(source:source,observe:false)
    let now = Date(),start = Calendar.current.startOfDay(for:now).addingTimeInterval(9*3600)
    let current = CalendarEntry(identifier:"series",calendarID:"fixture",title:"일정 연결 점검",start:start,end:start.addingTimeInterval(3600),calendar:"시험 일정",location:"시험 회의실",notes:"합성 메모")
    source.values = [current]
    var delivered:[CalendarEntry] = [];model.onChange = {delivered = $0}
    let view = MacCalendarView(model:model)
    let window = NSWindow(contentRect:NSRect(x:0,y:0,width:760,height:540),styleMask:[.borderless],backing:.buffered,defer:false)
    window.isReleasedWhenClosed = false;window.contentView = view;window.orderFrontRegardless()
    defer {window.orderOut(nil)}
    model.browse();try await waitFor{!model.loading}
    try check(model.events == [current] && delivered == [current] && model.visibleEvents == [current],"AT97 real browser receives source snapshots")
    try check(source.requests == 0,"AT97 allowed access never requests permission")
    view.layoutSubtreeIfNeeded()
    try check(view.month.frame.minY == 62,"AT97 original month label vertical placement, 65pt rendered ink top")
    try check(view.eventButtons.count == 1 && view.explanation.isHidden,"AT97 allowed native event list")
    view.eventButtons[0].performClick(nil);try await waitFor{model.selected != nil}
    try check(model.selected == current && view.detailLabels.map(\.stringValue).contains("합성 메모"),"AT97 actual native row opens re-read event details")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        for (name,appearance) in [("light",NSAppearance.Name.aqua),("dark",.darkAqua)] {
            window.appearance = NSAppearance(named:appearance);view.layoutSubtreeIfNeeded();window.display();await pause(0.1)
            try captureCalendar(view,to:outputDirectory.appendingPathComponent("task46-hejo-"+name+".png"))
        }
    }
    var longEvent = current;longEvent.identifier = "long";longEvent.title = String(repeating:"아주 긴 합성 일정 제목 ",count:6)
    let longButton = CalendarEventButton(event:longEvent,selected:false),shortButton = CalendarEventButton(event:current,selected:false)
    try check(shortButton.fittingHeight(width:360) == 73 && longButton.fittingHeight(width:360) == 105,"AT97 unmodified calendar label fitting: normal 73pt and wrapping 105pt")
    source.values = [longEvent,current];model.refresh(force:true);try await waitFor{!model.loading}
    view.layoutSubtreeIfNeeded()
    let orderedButtons = view.eventButtons
    try check(orderedButtons.count == 2 && orderedButtons[1].frame.minY == orderedButtons[0].frame.maxY+6,"AT97 event rows use measured heights and 6pt spacing")
    source.values = [current];model.refresh(force:true);try await waitFor{!model.loading}
    view.search.stringValue = "회의실";view.controlTextDidChange(Notification(name:NSText.didChangeNotification))
    try check(model.visibleEvents == [current],"AT97 location search")
    view.search.stringValue = "없는 일정";view.controlTextDidChange(Notification(name:NSText.didChangeNotification))
    try check(model.visibleEvents.isEmpty && view.eventButtons.isEmpty,"AT97 native query updates empty list")
    model.query = "";let oldMonth = model.month
    model.refresh(force:true)
    view.next.invoke?() // No nested AppKit click animation while the pending-query condition is observed.
    let nextMonth = Calendar.current.date(byAdding:.month,value:1,to:oldMonth)!
    try check(model.loading && view.month.stringValue == nextMonth.formatted(.dateTime.year().month(.wide)),"AT97 month label updates immediately while an earlier query is pending")
    try await waitFor{!model.loading}
    try check(Calendar.current.dateComponents([.month],from:oldMonth,to:model.month).month == 1,"AT97 next month button")
    view.previous.performClick(nil);try await waitFor{!model.loading}
    try check(model.month == oldMonth,"AT97 previous month button")
    model.moveMonth(12);try await waitFor{!model.loading}
    try check(source.intervals.contains{$0.0 == model.month},"AT97 distant month read added outside related-event horizon")
    model.moveMonth(-12);try await waitFor{!model.loading}
    // Same recurring identifier but moved start must never open another occurrence.
    var moved = current;moved.start = start.addingTimeInterval(1800)
    source.values = [moved];model.select(current)
    try await waitFor{model.notice == "이 일정이 삭제되거나 변경됐어요. 새로고침해 주세요."}
    try check(model.selected == nil && model.events.isEmpty && delivered.isEmpty,"AT97 exact occurrence re-read removes stale buttons")
    source.values = [current];model.refresh(force:true);try await waitFor{!model.loading}
    var second = current;second.identifier = "second";source.values = [current,second]
    model.showRelated([current,second]);try await waitFor{!model.loading}
    try check(model.selected == nil && model.visibleEvents.count == 2 && view.title.stringValue == "대화와 관련된 일정","AT97 ambiguous events show list rather than choosing")
    model.showRelated([current]);try await waitFor{model.selected?.id == current.id}
    try check(model.relatedIDs == [current.id],"AT97 one related event selects exact identity")
    var allDay = current;allDay.identifier = "all-day";allDay.allDay = true
    allDay.start = Calendar.current.startOfDay(for:now);allDay.end = allDay.start.addingTimeInterval(86400)
    source.values = [allDay];model.select(allDay);try await waitFor{model.selected?.id == allDay.id}
    try check(view.detailLabels.map(\.stringValue).contains("종일") && view.detailLabels.map(\.stringValue).contains("~ " + allDay.end.addingTimeInterval(-1).formatted(date:.complete,time:.omitted)),"AT97 all-day exclusive end displayed as last included day")
    source.access = .denied;model.refresh(force:true);try await waitFor{!model.loading}
    try check(model.events.isEmpty && model.selected == nil && delivered.isEmpty && !view.explanation.isHidden && view.split.isHidden,"AT97 denied access removes event list and cached actions")
    try check(view.explanation.stringValue == "Mac 캘린더의 일정을 조회하고 대화와 관련된 일정을 열려면 캘린더 전체 접근을 허용해 주세요." && view.allow.title == "캘린더 접근 허용" && view.settings.title == "권한 설정 열기","AT97 official permission wording")
    view.allow.performClick(nil);try await waitFor{!model.loading}
    try check(source.requests == 0,"AT97 denied access uses settings; no repeated permission requests")
    source.access = .unknown;view.allow.performClick(nil);try await waitFor{!model.loading}
    try check(source.requests == 1 && model.events.isEmpty,"AT97 only fake unknown permission handler called")
    source.access = .allowed;model.refresh(force:true);try await waitFor{!model.loading}
    // Real ConversationView accessories and folded reply use the same event identities and message time.
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:root)}
    let store = try LocalStore(directory:root),client = GateClient(store:store,credentials:MemoryCredentials()),controller = try testConversation(client:client)
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    let text = "내일 3시 회의",stamp = "2030-11-18T00:00:00Z"
    controller.receive(["type":"message","seq":1,"msg_id":"calendar-reply","employee":"alpha","thread":"calendar-thread","role":"employee","text":text,"ts":stamp])
    var localMeeting = meeting
    localMeeting.start = Calendar.current.startOfDay(for:reference).addingTimeInterval(86400+15*3600);localMeeting.end = localMeeting.start.addingTimeInterval(3600)
    controller.calendarEvents = [localMeeting]
    let message = controller.model.messages["calendar-reply"]!
    var streamingMessage = message;streamingMessage.streaming = true
    try check(controller.calendarActions(for:streamingMessage).map(\.title) == ["일정 보기"],"AT97 native calendar accessory follows PetActionMemo during streaming")
    streamingMessage.pending = true
    try check(controller.calendarActions(for:streamingMessage).isEmpty,"AT97 unconfirmed pending post has no content action")
    let conversation = ConversationView(controller:controller),thread = ConversationThread(key:message.key,title:"",preview:"",latestSeq:1)
    conversation.frame = NSRect(x:0,y:0,width:850,height:800)
    let content = conversation.threadContent(thread)
    let pieces = content.top + (content.replies ?? [])
    var clicked:[CalendarEntry] = [];conversation.onCalendar = {clicked = $0}
    var found = false
    for piece in pieces {
        if case .accessory(let id,let height,let make) = piece,id == "calendar-reply:calendar" {
            let row = make();let buttons = homeDescendants(row,FileChip.self)
            try check(buttons.map(\.title) == ["일정 보기"],"AT97 native card calendar accessory title")
            let accessory = row as! MessageAccessory
            accessory.frame = NSRect(x:0,y:0,width:500,height:height);accessory.layoutSubtreeIfNeeded()
            try check(height == 22 && accessory.content.frame.minX == 43 && accessory.content.frame.minY == 2 && accessory.content.frame.height == 20 && buttons[0].intrinsicContentSize == NSSize(width:62,height:20),"AT97 original calendar button intrinsic size and 2pt top inset")
            buttons.first?.invoke?();found = true
        }
    }
    try check(found && clicked == [localMeeting],"AT97 card button carries read identities to calendar owner")
    controller.calendarEvents = []
    try check(controller.calendarActions(for:message).isEmpty,"AT97 permission revocation clears card action")
    var notice = BubbleReveal.Notice(kind:.reply,headline:"",detail:"",key:message.key,id:message.id,body:text,date:reference,calendarEvents:[localMeeting])
    try check(notice.actions.contains(.calendar([localMeeting])),"AT97 folded reply matches relative to received timestamp")
    notice.calendarEvents = [];try check(!notice.actions.contains(where:\.isCalendar),"AT97 folded reply drops denied calendar snapshot")
    let delegate = AppDelegate(),menu = delegate.makeStatusMenu(),item = menu.items.first{$0.title == "내 캘린더"}
    try check(item?.action == #selector(AppDelegate.showCalendar) && item?.isEnabled == true,"AT97 live menu points to native calendar browser")
    print("AT-HF-97 APP PASS · fake CalendarSource only; no system calendar permission or write API")
}

@MainActor private func captureCalendar(_ view:NSView,to url:URL) throws {
    guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else {throw TestFailure.assertion("AT97 bitmap unavailable")}
    view.cacheDisplay(in:view.bounds,to:bitmap)
    guard let png = bitmap.representation(using:.png,properties:[:]) else {throw TestFailure.assertion("AT97 PNG unavailable")}
    try png.write(to:url)
}
