import AppKit
import SwiftUI

@MainActor func connectionsTests(outputDirectory:URL?=nil) async throws {
    let document:[String:Any] = ["schema":"hermes-connections/1","checked_at":"2026-01-01T12:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[["id":"key:SYNTHETIC_KEY","service":"key","label":"시험 서비스","reason":"KEY_UNVERIFIED","checked_at":"2026-01-01T12:00:00Z","group":"account","state":"unknown","capabilities":["키 저장됨(확인 안 함)"],"rules":["동작은 서버에서 실행해요."],"actions":[["id":"secret_set","label":"키 바꾸기","primary":true]]]]]]]
    var frames:[[String:Any]]=[],confirmed=false,privacy=false
    let model=ConnectionsModel(send:{frame in
        frames.append(frame)
        if frame["type"] as? String=="connections" {return ["document":document]}
        if frame["action"] as? String=="secret_guide" {return ["reply":["outcome":"done","reason":"OK","fields":[["id":"value","label":"시험 키","secure":true]],"guide":[["n":1,"text":"공식 서비스에서 키를 발급받아 붙여넣으세요."]]]]}
        return ["reply":["outcome":"done","reason":"OK","instruction":"키 저장됨(확인 안 함)"]]
    },confirm:{confirmed})
    model.privacy={privacy=$0};await model.refresh();model.selected="alpha";model.detail="key:SYNTHETIC_KEY"
    try check(model.agent?.summary=="확인 안 됨" && model.item?.primaryAction?.id=="secret_set","AT83 no inferred connected status or actions")
    model.values=["value":"synthetic-private-value"]
    await model.perform("secret_set",submitted:true)
    try check(frames.count==1,"AT83 authentication cancellation sends nothing")
    await model.perform("secret_set")
    try check(model.showingInput && privacy && model.fields.first?.secure==true,"AT83 server fields and private input")
    confirmed=true;await model.submit()
    try check(frames.contains{$0["action"] as? String=="secret_set" && $0["reauth"] as? Bool==true},"AT83 authenticated action")
    try check(model.values.isEmpty && !model.showingInput && !privacy && model.notice=="키 저장됨(확인 안 함)","AT83 success wipes input without false connected")
    model.values=["value":"synthetic-private-value"];model.closeInput()
    try check(model.values.isEmpty,"AT83 close wipes input")
    model.people={ [AgentConnectionProfile(profile:"alpha",display_name:"직원 A",connections:[]),AgentConnectionProfile(profile:"beta",display_name:"직원 B",connections:[])] }
    await model.refresh()
    try check(frames.last?["profile"] as? String=="alpha" && model.roster.count==2,"AT83 profile-scoped document preserves roster without oversized all-profile frame")
    let beforeRestart=frames.count;model.confirmRestart={false};model.values=["resume":"gateway_restart"]
    await model.perform("app_connect",submitted:true)
    try check(frames.count==beforeRestart,"AT83 resumed app restart requires confirmation")
    let before=frames.count;model.close()
    try check(frames.count==before,"AT83 closing never submits")
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:dir)}
    let store=try LocalStore(directory:dir),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    var received=false;controller.onConnectionsFrame={_ in received=true}
    controller.receive(["v":1,"type":"connection_result","ref":"request","reply":["outcome":"done"]])
    try check(received && controller.model.messages.isEmpty && !FileManager.default.fileExists(atPath:store.cacheURL.path),"AT83 management response bypasses message cache")
    if let outputDirectory {
        try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)
        model.detail=nil
        let host=NSHostingView(rootView:ConnectionsView(model:model));host.frame=CGRect(x:0,y:0,width:860,height:590)
        let window=NSWindow(contentRect:host.frame,styleMask:[.borderless],backing:.buffered,defer:false);window.isReleasedWhenClosed=false;window.contentView=host;window.orderFrontRegardless();await pause(0.5)
        host.layoutSubtreeIfNeeded();let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds)!;host.cacheDisplay(in:host.bounds,to:bitmap)
        try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("task32-hejo.png"));window.orderOut(nil)
    }
    print("AT-HF-83 APP PASS")
    try await connectionFilteringTests(outputDirectory:outputDirectory)
    try await connectionsScreenTests()
}

/// AT-101: the visible groups follow AC-05 without changing the full document or sending filter requests.
@MainActor private func connectionFilteringTests(outputDirectory:URL?) async throws {
    func connection(_ id:String,_ label:String,_ service:String,_ group:String,_ state:String,account:String?=nil)->[String:Any] {
        var row:[String:Any] = ["id":id,"label":label,"service":service,"group":group,"state":state,"reason":"NO_TOKEN","checked_at":"2026-01-01T12:00:00Z","capabilities":[],"rules":[],"actions":[]]
        if let account{row["account"]=account}
        return row
    }
    let document:[String:Any] = ["schema":"hermes-connections/1","checked_at":"2026-01-01T12:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[
        connection("b","xAI","xai","account","connected"),
        connection("q-idonly","Perplexity","pplx","account","not_connected"),
        connection("c","Google AI Studio","gemini","account","connected"),
        connection("r","Mistral","svc-only-token","account","needs_reconnect"),
        connection("a","Google AI Studio","gemini","account","unknown"),
        connection("d","NOUS_BASE_URL","key","account","unknown",account:"시험 계정"),
        connection("e","anthropic","anthropic","account","unknown"),
        connection("t2","웹 검색","web","tool","connected"),
        connection("t1","브라우저","browser","tool","off"),
        connection("ch","hejo","hejo","channel","connected")
    ]]]]
    var frames:[[String:Any]]=[]
    let model=ConnectionsModel(send:{frame in frames.append(frame);return ["document":document]},confirm:{false})
    await model.refresh()
    let all=[["e","a","c","r","d","q-idonly","b"],["t1","t2"],["ch"]]
    func expectGroups(_ ids:[[String]],_ message:String) throws {
        try check(model.visibleGroups.map{$0.items.map(\.id)}==ids,"AT-101 \(message)")
        let items=model.agent?.connections ?? []
        try check(items.filter{$0.state == .connected}.count==4 && items.filter{$0.state == .needsReconnect || $0.state == .notConnected}.count==2 && items.filter{$0.state == .unknown}.count==3 && model.agent?.summary=="다시 연결 필요","AT-101 filters preserve full summary 4/2/3 and roster dot")
    }
    try expectGroups(all,"case-insensitive natural label order and equal-label id order")
    try check(model.visibleGroups.map(\.id)==["account","tool","channel"] && model.visibleGroups.map(\.title)==["계정과 서비스","도구","대화 채널"],"AT-101 group order and empty Mac group hidden")
    for (query,ids) in [("GOOGLE",[["a","c"]]),("시험 계정",[["d"]]),("idonly",[["q-idonly"]]),("svc-only",[["r"]]),("  xai  ",[["b"]]),("  ",all),("저장된",[])] {
        model.searchText=query
        try expectGroups(ids,"search \(query)")
    }
    model.searchText="";model.connectedOnly=true
    try expectGroups([["c","b"],["t2"],["ch"]],"connected only excludes all four other states")
    model.searchText="google"
    try expectGroups([["c"]],"connected only and search intersect")
    model.searchText="idonly"
    try expectGroups([],"not-connected id match stays hidden")
    model.known["beta"]=AgentConnectionProfile(profile:"beta",display_name:"직원 B",connections:[])
    model.selected="beta"
    try check(model.visibleGroups.isEmpty && model.searchText=="idonly" && model.connectedOnly,"AT-101 switching employee keeps filter values")
    model.selected="alpha"
    try expectGroups([],"returning employee keeps active filters")
    try check(model.searchText=="idonly" && model.connectedOnly && frames.count==1,"AT-101 filters and model selection send no requests")
    if let outputDirectory {
        model.searchText="google";model.connectedOnly=false;model.detail=nil
        let host=NSHostingView(rootView:ConnectionsView(model:model).background(Color(nsColor:.windowBackgroundColor)));host.frame=CGRect(x:0,y:0,width:760,height:560)
        let window=NSWindow(contentRect:host.frame,styleMask:[.borderless],backing:.buffered,defer:false)
        window.isReleasedWhenClosed=false;window.contentView=host;window.orderFrontRegardless()
        defer{window.orderOut(nil);model.close()}
        func capture(_ name:String) throws {
            host.layoutSubtreeIfNeeded()
            let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds)!
            host.cacheDisplay(in:host.bounds,to:bitmap)
            try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent(name))
        }
        await pause(0.5);try capture("task54-hejo.png")
        model.detail="c"
        await pause(0.5);try capture("task54-detail.png")
    }
    print("AT-101 APP PASS")
}

/// AT-HC-20~28 use fake management frames and real AppKit sheet ownership.
@MainActor private func connectionsScreenTests() async throws {
    func row(_ id:String,hidden:Bool=false,state:String="unknown",actions:[[String:Any]]=[])->[String:Any] {
        var item:[String:Any] = ["id":id,"service":"app","label":"시험 연결","group":"mac","state":state,"reason":"CONFIG_ONLY","checked_at":"2026-01-01T00:00:00Z","capabilities":[],"rules":[],"actions":actions]
        if hidden {item["hidden_by_default"]=true};return item
    }
    let actions:[[String:Any]] = [["id":"app_connect","label":"이어서 하기","primary":true],["id":"app_undo","label":"처음부터 다시","primary":false]]
    func document(unread:Bool=true)->[String:Any] {
        var agent:[String:Any] = ["profile":"alpha","display_name":"직원 A","connections":[row("app:synthetic",actions:actions),row("hidden1",hidden:true,state:"not_connected"),row("hidden2",hidden:true),row("hidden3",hidden:true)]]
        if unread {agent["unread"]=[["part":"toolset_config","reason":"admin_failed"]]}
        return ["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[agent]]
    }
    var failure:String?,disconnected=false,frames:[[String:Any]]=[]
    var stage=0
    let model=ConnectionsModel(send:{frame in
        frames.append(frame)
        if disconnected {throw GateFailure.notConnected}
        if frame["type"] as? String=="connections" {
            if let failure {return ["reply":["outcome":"failed","reason":failure]]}
            return ["document":document()]
        }
        stage += 1
        let fields:[[String:Any]] = stage==1 ? [["id":"api_base","label":"서버 주소","secure":false],["id":"link_host","label":"파일 주소","secure":false]] : [["id":"user","label":"아이디","secure":false,"value":"synthetic-user"],["id":"password","label":"비밀번호","secure":true,"value":"must-not-prefill"]]
        return ["reply":["outcome":"waiting","next":["kind":"secret_set","fields":fields,"guide":[["n":1,"text":"비밀번호를 넣어 주세요."]]]]]
    },confirm:{true})
    await model.refresh();model.detail="app:synthetic"
    try check(model.readNotice=="일부 항목을 읽지 못했어요(도구 설정)" && model.agent?.connections.count==4,"AT-HC-20 unread preserves rows with a separate notice")
    failure="admin_failed";await model.refresh()
    try check(model.agent?.connections.count==4 && model.readNotice.contains("마지막으로 확인한 내용이에요") && model.readNotice.contains("연결 상태를 읽지 못했어요. 서버 기록에 이유를 남겼어요"),"AT-HC-21 last known rows survive failure")
    for (reason,text) in [("admin_unavailable","서버의 관리 기능에 닿지 못했어요"),("too_large","연결 상태를 읽지 못했어요. 서버 기록에 이유를 남겼어요"),("timeout","서버에 연결되지 않았어요")] {
        failure=reason;await model.refresh();try check(model.readNotice.contains(text),"AT-HC-22 reason \(reason)")
    }
    disconnected=true;await model.refresh();try check(model.readNotice.contains("서버에 연결되지 않았어요"),"AT-HC-22 disconnected")
    disconnected=false;failure=nil;await model.refresh()
    try check(model.visibleGroups.flatMap(\.items).map(\.id)==["app:synthetic"] && model.listed(model.agent!).count==1 && model.agent?.summary=="확인 안 됨","AT-HC-24 default rows, count source and summary omit hidden entries")
    model.includingHidden=true
    try check(model.visibleGroups.flatMap(\.items).count==4 && model.listed(model.agent!).count==4 && model.agent?.summary(includingHidden:true)=="다시 연결 필요","AT-HC-24 toggle includes hidden rows and summary")
    await model.perform("app_connect")
    try check(model.showingInput && model.fields.map(\.id)==["api_base","link_host"],"AT-HC-25 address form")
    failure="admin_failed";await model.refresh()
    try check(model.inputError.isEmpty && model.showingInput,"AT-HC-23 refresh notice never becomes a red input error")
    model.values=["api_base":"https://nas.example.invalid","link_host":"nas.example.invalid"];await model.submit()
    try check(model.showingInput && model.fields.map(\.id)==["user","password"] && !model.busy,"AT-HC-25 waiting opens login stage")
    try check(model.values==["user":"synthetic-user"] && model.fields.last?.secure==true,"AT-HC-25 only nonsecret defaults survive the stage transition")
    try check(model.item?.primaryAction?.label=="이어서 하기" && frames.contains{$0["action"] as? String=="app_connect"},"AT-HC-28 supplied label and resume frame")
    let before=frames.count;model.confirmUndo={false};await model.perform("app_undo")
    try check(frames.count==before,"AT-HC-28 declined reset sends nothing")
    model.confirmUndo={true};await model.perform("app_undo")
    try check(frames.last?["action"] as? String=="app_undo","AT-HC-28 confirmed reset sends app_undo")
    model.close()

    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:dir)}
    let store=try LocalStore(directory:dir),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let window=ConnectionsWindow(controller:controller),live=window.model
    var held:CheckedContinuation<[String:Any],Never>?
    var actionCount=0
    live.confirm={true}
    live.send={frame in
        if frame["type"] as? String=="connections" {return ["document":document(unread:false)]}
        if frame["action"] as? String=="job_status" {return ["reply":["outcome":"done"]]}
        actionCount += 1
        if actionCount==2 {return await withCheckedContinuation{held=$0}}
        return ["reply":["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"api_base","label":"주소","secure":false]]]]]
    }
    await live.refresh();live.detail="app:synthetic";window.show();await live.perform("app_connect");await pause(0.1)
    try check(window.window.attachedSheet != nil && NSApp.modalWindow==nil,"AT-HC-26 input is an attached AppKit sheet")
    let request=Task{await live.submit()};await pause(0.05)
    if let sheet=window.window.attachedSheet {window.window.endSheet(sheet)}
    await pause(0.1)
    held?.resume(returning:["reply":["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"user","label":"아이디","secure":false],["id":"password","label":"비밀번호","secure":true]]]]])
    await request.value;await pause(0.15)
    try check(live.showingInput && live.fields.map(\.id)==["user","password"] && window.window.attachedSheet?.isVisible==true && !live.busy,"AT-HC-25 dismissal during a request still opens the next stage")
    live.inputDismissed();await pause(0.1);window.show();await pause(0.1)
    try check(window.window.isVisible && window.window.isKeyWindow && live.fields.isEmpty && !live.busy,"AT-HC-27 show after onDismiss clears input and remains usable")
    // The production confirmation uses beginSheetModal; resolve the real alert via its parent sheet.
    window.setPreferredLevel(NSWindow.Level(rawValue:26))
    let confirmation=Task{await live.confirmRestart()};await pause(0.1)
    let alert=window.window.attachedSheet
    try check(alert != nil && NSApp.modalWindow==nil && window.window.level == .normal,"AT-HC-26 restart confirmation is a sheet at a visible level")
    if let alert {window.window.endSheet(alert,returnCode:.alertSecondButtonReturn)}
    let accepted=await confirmation.value
    try check(accepted==false,"AT-HC-26 cancellation resolves asynchronously")
    live.close();window.window.close();print("AT-HC-20~29 APP PASS")
}
