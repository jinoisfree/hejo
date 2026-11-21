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
    try await finderConnectionsLevelTests()
    try await connectionsScreenTests()
    try await connectionManagementTests(outputDirectory:outputDirectory)
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
    let before=frames.count;model.confirmUndo={_ in false};await model.perform("app_undo")
    try check(frames.count==before,"AT-HC-28 declined reset sends nothing")
    model.confirmUndo={_ in true};await model.perform("app_undo")
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
    // V-3: perform the action from both row states and inspect the actual AppKit alert.
    func descendants(_ view:NSView)->[NSView] {[view]+view.subviews.flatMap{descendants($0)}}
    for (state,label,title) in [("unknown","처음부터 다시","이 연결을 처음부터 다시 할까요?"),("connected","되돌리기","마지막 연결 변경을 되돌릴까요?")] {
        live.send={_ in ["document":["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[row("app:synthetic",state:state,actions:[["id":"app_undo","label":label,"primary":false]])]]]] ]}
        await live.refresh();live.detail="app:synthetic"
        let undo=Task{await live.perform("app_undo")};await pause(0.1)
        let sheet=window.window.attachedSheet
        let views=sheet?.contentView.map{descendants($0)} ?? []
        let labels=views.compactMap{($0 as? NSTextField)?.stringValue}
        let buttons=views.compactMap{($0 as? NSButton)?.title}
        let correct=sheet != nil && labels.contains(title) && buttons.contains(label)
        if let sheet {window.window.endSheet(sheet,returnCode:.alertSecondButtonReturn)}
        await undo.value
        try check(correct,"V-3 \(state) undo confirmation matches the row action")
    }
    live.close();window.window.close();print("AT-HC-20~29 APP PASS")
}

/// AT-CM-30~38: fake server frames with the real model, SwiftUI view and AppKit windows.
@MainActor private func connectionManagementTests(outputDirectory:URL?) async throws {
    let settings:[[String:Any]] = [["step":"address","label":"주소","value":"nas.example.invalid"],["step":"login","label":"로그인","value":"저장됨"],["step":"sync_root","label":"동기화 폴더","value":"synthetic-folder"]]
    func document(_ settings:[[String:Any]],action:String="app_disconnect",identifier:String="app:synthetic")->[String:Any] {
        ["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[["id":identifier,"service":"synology","label":"시험 앱","group":"mac","state":"connected","reason":"CONFIG_ONLY","checked_at":"2026-01-01T00:00:00Z","capabilities":[],"rules":[],"settings":settings,"actions":[["id":"app_connect","label":"설정 바꾸기","primary":true],["id":action,"label":"해제","primary":false],["id":"app_undo","label":"되돌리기","primary":false]]]]]]]
    }
    var frames:[[String:Any]]=[],order:[String]=[],allow=false,focusCount=0,activeSettings=settings,disconnectText=""
    var reply:[String:Any] = ["outcome":"done"]
    let model=ConnectionsModel(send:{frame in
        frames.append(frame)
        return frame["type"] as? String=="connections" ? ["document":document(activeSettings)]:["reply":reply]
    },confirm:{order.append("auth");return true})
    model.restoreFocus={focusCount += 1}
    model.confirmDisconnect={text in
        disconnectText=text
        order.append("ask");return allow
    }
    await model.refresh();model.detail="app:synthetic"
    try check(model.item?.otherActions.map(\.label)==["해제","되돌리기"],"AT-CM-30 secondary menu labels use supplied actions")
    if let outputDirectory {
        let host=NSHostingView(rootView:ConnectionsView(model:model));host.frame=CGRect(x:0,y:0,width:880,height:640)
        let preview=NSWindow(contentRect:host.frame,styleMask:[.borderless],backing:.buffered,defer:false)
        preview.isReleasedWhenClosed=false;preview.contentView=host;preview.orderFrontRegardless()
        for (detail,name) in [(String?.none,"conn-manage-list.png"),(String?.some("app:synthetic"),"conn-manage-settings.png")] {
            model.detail=detail;await pause(0.2);host.layoutSubtreeIfNeeded()
            let bitmap=host.bitmapImageRepForCachingDisplay(in:host.bounds)!;host.cacheDisplay(in:host.bounds,to:bitmap)
            try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent(name))
        }
        preview.orderOut(nil)
    }

    let before=frames.count
    await model.perform("app_disconnect")
    try check(frames.count==before && order==["ask"] && disconnectText.contains("넣어 둔 값은 남아"),"AT-CM-31 declined disconnect sends nothing and skips reauthentication")
    allow=true;order=[];await model.perform("app_disconnect")
    try check(order==["ask","auth"] && frames.filter{$0["action"] as? String=="app_disconnect"}.count==1 && frames.first{$0["action"] as? String=="app_disconnect"}?["reauth"] as? Bool==true,"AT-CM-31 confirm then authenticate then disconnect")
    let accountDocument=try AgentConnectionDocument.decode(JSONSerialization.data(withJSONObject:document(settings,action:"account_disconnect",identifier:"team:x")))
    model.known["alpha"]=accountDocument.agents[0];model.detail="team:x";order=[]
    reply=["outcome":"waiting","next":["kind":"gateway_restart"]]
    await model.perform("account_disconnect")
    try check(order==["ask","auth"] && frames.last?["connection"] as? String=="team:x" && frames.last?["action"] as? String=="account_disconnect","AT-CM-31 account disconnect frame follows confirmation")
    order=[];model.confirmRestart={true};reply=["outcome":"done"];await model.submit()
    try check(order==["auth"],"AT-CM-31 saved disconnect resumes without confirming the same mutation again")
    model.detail="app:synthetic"
    try check(model.item?.settings?.map(\.label)==["주소","로그인","동기화 폴더"],"AT-CM-32 current settings decode")
    model.detail=nil;let count=frames.count
    await model.perform("app_connect",item:model.agent!.connections[0])
    try check(model.detail=="app:synthetic" && frames.count==count,"AT-CM-33 multiple settings opens detail without a request")
    reply=["outcome":"waiting","next":["kind":"choose_sync_root","options":[["id":"one","label":"첫 폴더"]],"selected":["one"]]]
    await model.change("sync_root")
    try check(frames.last?["values"] as? [String:String]==["change":"sync_root"] && model.choices==["one"],"AT-CM-33 selected step frame")
    model.closeInput()
    activeSettings=[settings[2]];await model.refresh();model.detail="app:synthetic"
    await model.perform("app_connect")
    try check(frames.last?["values"] as? [String:String]==["change":"sync_root"],"AT-CM-33 single setting starts directly")
    model.closeInput();activeSettings=settings;await model.refresh();model.detail="app:synthetic"
    reply=["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"api_base","label":"주소","secure":false]]]]
    await model.change("address")
    reply=["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"password","label":"비밀번호","secure":true]]]]
    model.values=["api_base":"https://nas.example.invalid"];await model.submit()
    reply=["outcome":"waiting","next":["kind":"choose_scope","options":[["id":"a","label":"A"],["id":"b","label":"B"],["id":"c","label":"C"]],"selected":["a","c"]]]
    model.values=["password":"synthetic-password"];await model.submit()
    try check(model.choices==["a","c"],"AT-CM-34 selected option ids")
    let accumulated=frames.last?["values"] as? [String:String]
    try check(accumulated==["change":"address","api_base":"https://nas.example.invalid","password":"synthetic-password"],"AT-CM-38 every request carries all prior inputs")
    reply=["outcome":"waiting","committed":true,"next":["kind":"gateway_restart"]]
    await model.submit()
    try check(model.changeValues.isEmpty && model.values.isEmpty,"AT-CM-38 committed immediately drops password and change")
    model.confirmRestart={true};reply=["outcome":"done"];await model.submit()
    let resume=frames.last{$0["type"] as? String=="connection_action"}?["values"] as? [String:String]
    try check(resume==["resume":"gateway_restart"],"AT-CM-38 post-commit resume has no old inputs")
    reply=["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"password","label":"비밀번호","secure":true]]]]
    await model.change("login");model.values=["password":"synthetic-abandoned-password"];model.closeInput()
    try check(model.changeValues.isEmpty && model.values.isEmpty,"AT-CM-38 close wipes all inputs")
    await model.change("login")
    try check(frames.last?["values"] as? [String:String]==["change":"login"],"AT-CM-38 new session contains only change")
    model.closeInput()
    for accepted in [true,false] {
        focusCount=0;model.confirm={accepted};reply=["outcome":"done"]
        await model.perform("account_connect")
        try check(focusCount==1,"AT-CM-35 reauthentication success and cancellation restore focus once")
    }
    model.close()

    // Inject the inactive state at the confirmation boundary and exercise real AppKit key windows.
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:dir)}
    let store=try LocalStore(directory:dir),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let window=ConnectionsWindow(controller:controller),live=window.model
    live.send={frame in frame["type"] as? String=="connections" ? ["document":document(settings)]:["reply":["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"password","label":"비밀번호","secure":true]]]]]}
    await live.refresh();live.detail="app:synthetic";window.show();await pause(0.1)
    window.setPreferredLevel(NSWindow.Level(rawValue:26))
    for withInput in [false,true] {
        for accepted in [true,false] {
            if withInput {live.confirm={true};await live.change("login");await pause(0.1)}
            var simulatedActive=true,wasInactive=false,normalDuringConfirm=false
            live.confirm={normalDuringConfirm=window.window.level == .normal;simulatedActive=false;wasInactive = !simulatedActive;return accepted}
            var restores=0
            live.restoreFocus={restores += 1;simulatedActive=true;window.restoreFocus()}
            await live.perform("account_connect")
            try await waitFor{let foremost=window.window.attachedSheet ?? window.window;return NSApp.isActive && foremost.isVisible && foremost.isKeyWindow}
            try check(restores==1 && wasInactive && simulatedActive && normalDuringConfirm,"AT-CM-35 focus restored for sheet=\(withInput), accepted=\(accepted)")
            live.closeInput();await pause(0.1)
        }
    }
    live.close();window.window.close()
    print("AT-CM-30~38 APP PASS")
}


/// AT-FF-20~23: fake gate, real input/alert sheets alongside the floating conversation panel.
@MainActor private func finderConnectionsLevelTests() async throws {
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:dir)}
    let store=try LocalStore(directory:dir),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let conversation=PetPanel(contentRect:CGRect(x:100,y:100,width:600,height:500),styleMask:[.borderless],backing:.buffered,defer:false)
    conversation.isReleasedWhenClosed=false;conversation.hidesOnDeactivate=false
    conversation.level=NSWindow.Level(rawValue:25)
    conversation.contentView=NSTextField(labelWithString:"시험 대화 창")
    conversation.orderFrontRegardless()
    let window=ConnectionsWindow(controller:controller),model=window.model
    defer{model.close();window.window.close();conversation.close()}
    let document:[String:Any] = ["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[["id":"app:synthetic","service":"synology","label":"시험 연결","group":"mac","state":"unknown","reason":"VALUES_REQUIRED","checked_at":"2026-01-01T00:00:00Z","capabilities":[],"rules":[],"actions":[["id":"app_connect","label":"이어서 하기","primary":true]]]]]]]
    model.send={frame in
        frame["type"] as? String=="connections" ? ["document":document]:["reply":["outcome":"waiting","next":["kind":"secret_set","fields":[["id":"password","label":"비밀번호","secure":true]]]]]
    }
    model.confirm={true}
    await model.refresh();model.detail="app:synthetic"
    try check(model.item != nil,"AT-FF fixture loads connection")
    window.setPreferredLevel(NSWindow.Level(rawValue:26));window.show()
    await model.perform("app_connect");await pause(0.15)
    print("AT-FF-20 observation: conversation=\(conversation.level.rawValue), connections=\(window.window.level.rawValue), inputVisible=\(window.window.attachedSheet?.isVisible == true)")
    try check(conversation.isVisible && window.window.attachedSheet?.isVisible==true && window.window.level.rawValue==26,"AT-FF-20 input keeps connections above conversation")
    window.window.orderBack(nil)
    window.window.level = .normal // A stale level must be recomputed when reopened.
    window.show();await pause(0.1)
    try check(window.window.level.rawValue==26 && window.window.isVisible && window.window.attachedSheet?.isVisible==true,"AT-FF-21 show recalculates level and brings input forward")
    guard let input=window.window.attachedSheet else{throw TestFailure.assertion("AT-FF-22 missing input")}
    let confirmation=Task{await model.confirmRestart()};await pause(0.1)
    let alert=input.attachedSheet
    let normalDuringAlert=window.window.level == .normal
    if let alert{input.endSheet(alert,returnCode:.alertSecondButtonReturn)}
    let accepted=await confirmation.value;await pause(0.1)
    try check(alert != nil && normalDuringAlert && !accepted && window.window.level.rawValue==26 && input.isVisible,"AT-FF-22 restart alert lowers then restores input")
    for accepted in [false,true] {
        var normalDuringAuth=false
        model.confirm={normalDuringAuth=window.window.level == .normal;return accepted}
        await model.perform("app_connect");await pause(0.1)
        try check(normalDuringAuth && window.window.level.rawValue==26 && window.window.attachedSheet?.isVisible==true,"AT-FF-22 authentication success/cancellation restores input")
    }
    model.closeInput();await pause(0.1)
    window.setPreferredLevel(.normal)
    await model.perform("app_connect");await pause(0.1)
    try check(window.window.level == .normal && window.window.attachedSheet?.isVisible==true,"AT-FF-23 inactive preference stays normal with input")
    print("AT-FF-20~23 APP PASS")
}
