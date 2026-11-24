import AppKit

/// AT-TD-01~06 exercise journal projection, notices, bells and the actual card status.
@MainActor func threadDoneTests() throws {
    let home=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:home)}
    let store=try LocalStore(directory:home),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials())),model=controller.model
    defer {controller.client.stop()}
    let now=Date(timeIntervalSince1970:1794000000);controller.clock={now}
    controller.receive(["type":"roster","employees":[["id":"alpha","name":"직원 A","aliases":[]]]])
    var seq=0
    @discardableResult func post(_ text:String,thread:String=UUID().uuidString.lowercased(),role:String="employee",asked:Bool=false,target:String?=nil,streaming:Bool=false) throws ->ConversationMessage {
        seq+=1;let id=UUID().uuidString.lowercased()
        var row:[String:Any]=["v":1,"type":"message","seq":seq,"msg_id":id,"employee":"alpha","thread":thread,"role":role,"text":text,"files":[],"buttons":asked ? [["id":UUID().uuidString.lowercased(),"label":"승인","kind":"reply","style":"default"]]:[],"reply_state":asked ? "asked":NSNull(),"ts":ISO8601DateFormatter().string(from:now)]
        if let target {row["answer_to"]=target}
        try store.append(row);controller.receive(row)
        if streaming {
            seq+=1
            let edit:[String:Any]=["v":1,"type":"edit","seq":seq,"msg_id":id,"text":text,"final":false]
            try store.append(edit);controller.receive(edit)
        }
        return try homeRequire(model.messages[id],"AT-TD fixture decoded")
    }
    let view=ConversationView(controller:controller,islandModel:IslandModel(clock:{now}));view.frame=CGRect(x:0,y:0,width:840,height:760)
    view.chooseEmployee("alpha")
    func status(_ key:ConversationKey) throws ->NSColor? {
        view.refresh()
        return try homeRequire(view.history.contents.first{$0.id==key.thread},"AT-TD actual card exists").style.status
    }
    func typing(_ key:ConversationKey) throws {
        try model.apply(["v":1,"type":"typing","employee":key.employee,"thread":key.thread,"on":true,"ttl_seconds":60],now:now)
        try check(controller.working(key),"AT-TD fixture working")
    }

    // AT-TD-01: a free-text answer covers both earlier requests; a finished staff post settles it.
    let done=try post("🔴 검토 요청",asked:true)
    try post("추가 검토 요청",thread:done.key.thread,asked:true)
    try post("두 번째 항목을 고쳐 주세요",thread:done.key.thread,role:"owner")
    try post("수정 내용을 반영했어요",thread:done.key.thread)
    let state=model.assessment(done.key)
    try check(state.settled && state.color=="#2EB67D","AT-TD-01 free-text answer then finished staff post settles green")
    try check(model.bell(done.key)==nil,"AT-TD-01 settled thread has no bell")
    let ids=Set(model.timeline(done.key).map(\.id))
    try check(model.notices(HomeRoom.id).flatMap(\.messages).allSatisfy{!ids.contains($0)},"AT-TD-01 settled thread excluded from notices and questions")
    try check(try status(done.key)==MessageFormat.color("#2EB67D"),"AT-TD-01 actual card green despite red title")

    // AT-TD-02: a later request reopens the same thread.
    let reopened=try post("다음 항목 요청",thread:done.key.thread,asked:true)
    try check(model.assessment(done.key).pending?.id==reopened.id,"AT-TD-02 latest unanswered request pending")
    try check(try status(done.key)==AttentionRail.color,"AT-TD-02 reopened card red")

    // AT-TD-03(a)(b): unfinished streaming and thinking posts cannot complete a request.
    for (suffix,text,streaming) in [("a","수정 내용을 작성하고 있어요",true),("b","생각 중…",false)] {
        let request=try post("🔴 검토 요청",asked:true)
        try post("두 번째 항목을 고쳐 주세요",thread:request.key.thread,role:"owner")
        let draft=try post(text,thread:request.key.thread,streaming:streaming)
        try check(streaming ? draft.streaming:ThreadTools.thinking(draft.text),"AT-TD-03"+suffix+" unfinished fixture")
        try check(!model.assessment(request.key).settled,"AT-TD-03"+suffix+" unfinished staff post does not settle")
        try check(try status(request.key)==MessageFormat.color("#ECB22E"),"AT-TD-03"+suffix+" working card yellow despite red title")
    }

    // AT-TD-04: a targeted answer to A does not answer B, even with a later staff post.
    let itemA=try post("🔴 요청 A",asked:true)
    let itemB=try post("요청 B",thread:itemA.key.thread,asked:true)
    try post("첫 번째 항목을 고쳐 주세요",thread:itemA.key.thread,role:"owner",target:itemA.id)
    try post("첫 번째 항목을 반영했어요",thread:itemA.key.thread)
    try check(model.assessment(itemA.key).pending?.id==itemB.id && !model.assessment(itemA.key).settled,"AT-TD-04 targeted answer leaves B pending")
    try check(try status(itemA.key)==AttentionRail.color,"AT-TD-04 unanswered B keeps card red")

    // AT-TD-05: an answered request never falls back to its report title color.
    let waiting=try post("🔴 검토 요청",asked:true)
    try post("두 번째 항목을 고쳐 주세요",thread:waiting.key.thread,role:"owner")
    try check(!controller.working(waiting.key) && model.assessment(waiting.key).color==nil,"AT-TD-05 answered request has no derived color yet")
    try check(try status(waiting.key)==nil,"AT-TD-05 idle answered request has no card status color")
    try typing(waiting.key)
    try check(try status(waiting.key)==MessageFormat.color("#ECB22E"),"AT-TD-05 working answered request yellow")

    // AT-TD-06: ordinary reports retain title colors, with working yellow taking priority.
    for (title,hex) in [("🔴 보고","#E01E5A"),("✅ 보고","#2EB67D")] {
        let report=try post(title)
        try check(model.assessment(report.key).request==nil,"AT-TD-06 report has no request")
        try check(try status(report.key)==MessageFormat.color(hex),"AT-TD-06 report preserves title color")
    }
    let active=try post("🔴 작성 중인 보고")
    try typing(active.key)
    try check(try status(active.key)==MessageFormat.color("#ECB22E"),"AT-TD-06 working report yellow overrides red title")
    print("AT_TD_01_06_PASS")
}
