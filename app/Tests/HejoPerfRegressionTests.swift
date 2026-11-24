import AppKit

#if HEJO_PERF_TESTING
/// HP-01/02/03: observe final notifications and actual AppKit card/sidebar/drawer consumers.
@MainActor func hejoPerfRegressionTests() async throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:directory)}
    let store=try LocalStore(directory:directory)
    let controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    controller.stop();defer {controller.stop();controller.client.stop()}
    let model=controller.model
    let start=ThreadTools.date("2026-01-01T01:00:00Z")
    var now=start
    controller.clock={now}
    let first=ConversationKey(employee:"alpha",thread:"11111111-1111-4111-8111-111111111111")
    let second=ConversationKey(employee:"beta",thread:"22222222-2222-4222-8222-222222222222")
    let message="33333333-3333-4333-8333-333333333333", other="44444444-4444-4444-8444-444444444444"
    let file="55555555-5555-4555-8555-555555555555"
    let roster:[[String:Any]]=[["id":"alpha","name":"직원 A","aliases":[]],["id":"beta","name":"직원 B","aliases":[]]]
    var count=0, observedApplied = -1
    controller.onChange={count+=1;observedApplied=model.applied}
    func receive(_ frame:[String:Any], expected:Int=1) throws {
        count=0;controller.receive(frame)
        try check(count==expected,"HP-01 receive delivers the final state synchronously: \(frame["type"] ?? "")")
        if expected>0 {try check(observedApplied==model.applied,"HP-01 final applied cursor is visible before receive returns")}
    }
    try receive(["type":"welcome","employees":roster,"head_seq":0])
    try receive(["type":"roster","employees":roster])
    func post(_ seq:Int,_ id:String,_ key:ConversationKey,_ text:String,_ timestamp:String="2026-01-01T00:00:00Z",extras:Bool=false)->[String:Any] {
        ["v":1,"type":"message","seq":seq,"msg_id":id,"employee":key.employee,"thread":key.thread,"role":"employee","text":text,
         "ts":timestamp,"reply_state":extras ? "asked":NSNull(),
         "files":extras ? [["file_id":file,"name":"fixture.txt","mime":"text/plain","size":12]]:[],
         "buttons":extras ? [["id":"66666666-6666-4666-8666-666666666666","label":"승인","kind":"reply","style":"primary"],
                              ["id":"77777777-7777-4777-8777-777777777777","label":"거절","kind":"reply","style":"default"]]:[]]
    }
    try receive(post(1,message,first,"승인해줘",extras:true))
    try receive(post(2,other,second,"새 알림","2026-01-01T00:10:00Z"))
    try receive(["type":"typing","employee":"alpha","thread":first.thread,"on":true])
    try receive(["type":"typing","employee":"alpha","thread":first.thread,"on":false])
    try receive(["type":"sync_done","more":false,"through":2])
    try receive(["type":"error","code":"unknown_file"])
    try receive(["type":"connections_status"],expected:0)
    try receive(["type":"deadlines_status","ref":"unknown"],expected:0)
    try receive(["type":"deadline_close_status","ref":"unknown"],expected:0)
    try receive(["type":"message","seq":4])
    try check(model.applied==2 && !controller.notice.isEmpty,"HP-01 malformed/gap frame preserves cursor and error")
    count=0
    controller.performUpdates {controller.performUpdates {controller.notice="inner"};controller.notice="outer"}
    try check(count==1 && controller.notice=="outer","HP-01 nested updates flush once")
    controller.notice="outside"
    try check(count==2,"HP-01 outside notice remains synchronous")

    var requested: String?
    controller.deadlineSender={frame in requested=frame["id"] as? String}
    controller.setDrawerState(open:true,chatExpanded:true)
    try await waitFor {requested != nil}
    try receive(["type":"deadlines_status","ref":requested!,"available":true,"items":[],"failed":[]])
    requested=nil;controller.requestDeadlines(force:true)
    try await waitFor {requested != nil}
    try receive(["type":"error","ref":requested!,"code":"command_failed"])
    model.select(first)
    let view=ConversationView(controller:controller,clipboardArea:directory.appendingPathComponent("clipboard"),islandModel:IslandModel(clock:{now}))
    view.frame=CGRect(x:0,y:0,width:840,height:760);view.reduceMotion={true}
    let redraw=controller.onChange
    controller.onChange={redraw?();count+=1;observedApplied=model.applied}
    defer {controller.onChange=nil;controller.onRevealThread=nil;model.onDerive=nil}
    view.chooseEmployee("alpha")
    var derivations=[String:[String:Int]]()
    model.onDerive={kind,key in derivations[kind,default:[:]][key,default:0]+=1}
    view.refresh()
    try check(derivations["grouping"]?["messages"]==1,"HP-02 one message grouping per actual refresh")
    try check(derivations["notices"]?.values.allSatisfy{$0==1}==true,"HP-02 sidebar/cards/drawer share each room's notices")
    try check(derivations["assessment"]?.values.allSatisfy{$0<=1} ?? true,"HP-02 assessments share grouped timelines")
    try check(derivations["home_sort"]==nil,"HP-02 direct reply condition does not sort home")
    let reply=homeDescendants(view,ComposerButton.self).first{$0.title=="답글"}
    try check(reply?.isEnabled==false,"HP-03 automatic employee reply retains selected reply button state")
    view.createThread()
    try check(reply?.isEnabled==true,"HP-03 direct room can switch from new post to existing reply")
    view.writeReply()
    func card(_ id:String) throws ->NativeThreadCard.Content {
        guard let value=view.history.contents.first(where:{$0.id==id}) else {throw TestFailure.assertion("HP card missing")}
        return value
    }
    func pieces(_ card:NativeThreadCard.Content)->[NativeThreadCard.Piece] {card.top+(card.replies ?? [])}
    let initial=try card(first.thread)
    try check(initial.bell==true,"HP-03 actual initial question card rings")
    let accessories=pieces(initial).compactMap { piece -> NSView? in if case .accessory(_,_,let make)=piece {return make()};return nil }
    try check(accessories.flatMap{homeDescendants($0,FileTile.self)}.count==1,"HP-03 actual attachment tile retained")
    let labels=accessories.flatMap{homeDescendants($0,FileChip.self)}.map(\.title)
    try check(labels.contains("승인") && labels.contains("거절"),"HP-03 actual server button labels retained")
    var changedDuringRender=false
    view.onUnread={_ in
        if !changedDuringRender {changedDuringRender=true;model.markNoticeRead(first)}
    }
    view.refresh();view.onUnread=nil
    try check(changedDuringRender && (try card(first.thread)).bell==false,"HP-03 a mutation during actual render is visible before refresh returns")
    model.withRenderValues {
        view.refresh()
        model.confirm(model.messages[message]!)
        view.refresh()
    }
    try check(try card(first.thread).bell==nil && controller.drawerSnapshot.counts[.question]==0,"HP-03 confirm invalidates actual card/drawer within a nested render scope")
    derivations=[:]
    try model.withRenderValues {
        _=model.timeline(first)
        try receive(["v":1,"type":"edit","seq":3,"msg_id":message,"text":"고친 본문","final":false])
        view.refresh()
    }
    try check(derivations["assessment"]==[first.readKey:1],"HP-02 only the changed thread is assessed once")
    let edited=pieces(try card(first.thread)).compactMap{piece ->NativeThreadCard.Post? in if case .post(let post)=piece{return post};return nil}
    try check(edited.first?.text.string=="고친 본문" && edited.first?.streaming==true,"HP-03 actual streaming post invalidates cached timeline")
    try receive(["v":1,"type":"edit","seq":4,"msg_id":message,"text":"최종 본문","final":true])
    try receive(["v":1,"type":"state","seq":5,"msg_id":message,"reply_state":"closed"])
    try check(try card(first.thread).bell==nil,"HP-03 final/state update retains settled bell")
    try model.withRenderValues {
        try check(model.homeThreads.map(\.id)==[first.thread,second.thread],"HP-03 home uses latest date order")
    }
    view.chooseHome();derivations=[:];view.refresh()
    try check(derivations["home_sort"]?["home"]==1,"HP-02 home sort keys are shared in a real home render")
    try check(derivations["grouping"]?["messages"]==1,"HP-02 home groups messages once")
    view.chooseEmployee("beta")
    try model.withRenderValues {
        try check(model.notices("beta").count==1,"HP-03 alert starts live")
        try check(model.notices("beta",now:start.addingTimeInterval(86400)).isEmpty,"HP-03 explicit now is isolated from default now")
        try check(model.notices("beta").count==1,"HP-03 explicit now never poisons default lookup")
    }
    now=ThreadTools.date("2026-01-02T00:10:00Z")
    view.refresh()
    try check(try card(second.thread).bell==nil,"HP-03 next actual render expires a 24-hour alert")
    now=start
    model.withRenderValues {
        _=model.notices("beta")
        model.markNoticeRead(second)
        view.refresh()
    }
    try check(try card(second.thread).bell==false && model.unread(second)==0,"HP-03 reading invalidates card/bell synchronously")
    try model.withRenderValues {
        _=model.homeThreads
        controller.receive(["type":"roster","employees":[roster[0]]])
        view.refresh()
        try check(model.homeScope==["alpha"],"HP-03 roster invalidates home scope")
    }
    try receive(["v":1,"type":"delete","seq":6,"msg_id":other])
    view.refresh()
    try check(!view.history.contents.contains{$0.id==second.thread},"HP-03 deleted timeline does not survive in View")
    let separate=try ConversationModel(store:LocalStore(directory:directory.appendingPathComponent("separate")))
    try model.withRenderValues {try separate.withRenderValues {try check(separate.timeline(first).isEmpty,"HP-03 models never share projection values")}}
    for value in ["2026-01-01T00:00:00Z","2026-01-01T00:00:00.123Z","2026-01-01T00:00:00.123456Z",
                  "2026-01-01T00:00:00+09:00","2026-01-01T24:00:00Z","2026-12-31T23:59:60Z",
                  "2026-02-30T00:00:00Z","0001-01-01T00:00:00Z","1582-10-10T00:00:00Z","invalid"] {
        try model.withRenderValues {try check(model.date(value)==ThreadTools.date(value),"HP-03 scoped parser preserves date meaning")}
    }
    try model.withRenderValues {
        for year in [1,4,100,400,1582,1600,1900,1970,2000,2024,2026,2100,2400,9999] {
            for month in 1...12 {for day in [1,28,29,30,31] {
                let value=String(format:"%04d-%02d-%02dT23:59:59Z",year,month,day)
                try check(model.date(value)==ThreadTools.date(value),"HP-03 canonical parser preserves calendar/normalization boundaries")
            }}
        }
    }
    try model.withRenderValues {
        _=model.timeline(first)
        controller.receive(["v":1,"type":"message","seq":7])
        view.refresh()
        try check(model.applied==6 && !controller.notice.isEmpty,"HP-03 View survives model error within a query scope")
        controller.receive(post(7,other,second,"오류 뒤 정상 글"))
        view.refresh()
        try check(model.messages[other]?.text=="오류 뒤 정상 글","HP-03 normal input after error is not hidden by cached data")
    }
    controller.receive(["type":"roster","employees":roster])
    let group="fixture-group",groupThread="88888888-8888-4888-8888-888888888888"
    controller.receive(["v":1,"type":"room","seq":8,"room":["id":group,"title":"가짜 방","members":["alpha","beta"],"lead":"alpha"]])
    var groupPost=post(9,"99999999-9999-4999-8999-999999999999",.init(employee:"alpha",thread:groupThread),"단체 알림")
    groupPost["room"]=group;controller.receive(groupPost)
    view.chooseHome()
    try model.withRenderValues {
        _=model.homeThreads
        model.configureHome{$0.channel=group}
        view.refresh()
        try check(view.history.contents.contains{$0.id==groupThread} && !view.history.contents.contains{$0.id==first.thread},"HP-03 actual View follows a changed home channel within a scope")
        model.configureHome{$0.channel=nil}
        view.refresh()
        try check(!view.history.contents.contains{$0.id==groupThread},"HP-03 restored home scope discards channel projection")
    }
    // Equal-date home order uses thread ID, independent of receive order and model instance.
    try separate.apply(["type":"roster","employees":roster])
    try separate.apply(post(1,other,second,"같은 시각 B"))
    try separate.apply(post(2,message,first,"같은 시각 A"))
    try separate.withRenderValues {
        try check(separate.homeThreads.map(\.id)==[first.thread,second.thread],"HP-03 home date ties retain ID order")
        try check(separate.timeline(first).first?.text != model.timeline(first).first?.text,"HP-03 populated models never share a projection")
    }
    print("AT-HP-01_02_03_VIEW_REGRESSION_PASS")
}
#endif
