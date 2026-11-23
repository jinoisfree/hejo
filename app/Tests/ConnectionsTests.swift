import AppKit
import SwiftUI

@MainActor private func restartDocument()->[String:Any] {
    ["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[
        ["id":"app:synthetic","service":"synology","label":"시험 연결","group":"mac","state":"unknown","reason":"VALUES_REQUIRED","checked_at":"2026-01-01T00:00:00Z","capabilities":[],"rules":[],"actions":[["id":"app_connect","label":"이어서 하기","primary":true]]],
        ["id":"gateway","service":"gateway","label":"시험 게이트웨이","group":"channel","state":"unknown","reason":"VALUES_REQUIRED","checked_at":"2026-01-01T00:00:00Z","capabilities":[],"rules":[],"actions":[["id":"gateway_restart","label":"다시 시작","primary":true]]]
    ]]]]
}

/// Reproduces the two independent UI failures with synthetic replies and actual AppKit sheets.
@MainActor func connectionStuckReproduction() async throws {
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:dir)}
    let controller=try testConversation(client:GateClient(store:try LocalStore(directory:dir),credentials:MemoryCredentials()))
    let window=ConnectionsWindow(controller:controller),model=window.model
    let conversation=PetPanel(contentRect:CGRect(x:100,y:100,width:600,height:500),styleMask:[.borderless],backing:.buffered,defer:false)
    conversation.isReleasedWhenClosed=false;conversation.level=NSWindow.Level(rawValue:25)
    conversation.contentView=NSTextField(labelWithString:"가짜 대화 창")
    defer{model.close();window.window.close();conversation.close()}
    model.confirm={true}
    var mutations=0,queries=0
    model.send={frame in
        if frame["type"] as? String=="connections" {return ["document":restartDocument()]}
        if frame["action"] as? String=="job_status" {
            queries += 1
            let reply:[String:Any]=mutations==0 ? ["outcome":"refused","reason":"UNKNOWN_JOB"]:["outcome":"done","job":"synthetic-job","connected":1]
            return ["reply":reply]
        }
        if frame["values"] != nil {mutations += 1;await pause(0.03);throw GateFailure.notConnected}
        return ["reply":["outcome":"waiting","committed":true,"next":["kind":"gateway_restart","hint":"가짜 재시작 안내"]]]
    }
    await model.refresh();model.detail="app:synthetic";window.show();window.setPreferredLevel(NSWindow.Level(rawValue:26))
    await model.perform("app_connect");await pause(0.15)
    guard let input=window.window.attachedSheet else{throw TestFailure.assertion("CS probe input missing")}
    conversation.setFrame(window.window.frame,display:true);conversation.orderFrontRegardless()
    queries=0
    let confirmation=Task{await model.submit()};await pause(0.15)
    let alert=input.attachedSheet ?? window.window.attachedSheet
    let visible=(alert?.level.rawValue ?? -1)>conversation.level.rawValue
    print("CS REPRO confirmation: parent=\(window.window.level.rawValue), input=\(input.level.rawValue), alert=\(alert?.level.rawValue ?? -1), conversation=25, key=\(alert?.isKeyWindow == true), aboveConversation=\(visible)")
    if let alert,let parent=alert.sheetParent {parent.endSheet(alert,returnCode:.alertFirstButtonReturn)}
    await confirmation.value;await pause(0.1)
    print("CS REPRO response loss: mutations=\(mutations), queries=\(queries), busy=\(model.busy), inputError=\(model.inputError), notice=\(model.notice)")
    try check(visible && queries>0 && !model.inputError.contains("다시 해"),"CS reproduced: internal alert hidden by floating conversation and lost reply offers mutation retry without job lookup")
}

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
    try await connectionIncompleteReplyTests(document:document)
    try await connectionRestartTests(outputDirectory:outputDirectory)
}

/// TASK-13: replies without a check must not turn unfinished actions into completion notices.
@MainActor private func connectionIncompleteReplyTests(document:[String:Any]) async throws {
    var reply:[String:Any]=[:]
    let model=ConnectionsModel(send:{frame in
        if frame["type"] as? String=="connections" {return ["document":document]}
        if frame["action"] as? String=="secret_guide" {return ["reply":["outcome":"done","reason":"OK","fields":[["id":"value","label":"시험 키","secure":true]]]]}
        return ["reply":reply]
    },confirm:{true})
    await model.refresh();model.selected="alpha";model.detail="key:SYNTHETIC_KEY"
    for (outcome,reason) in [("waiting","UNDO_CONFLICT"),("waiting","UNKNOWN_REASON"),("failed","command_failed"),("refused","UNKNOWN_REASON"),("partial","UNKNOWN_REASON"),("pending","JOB_PENDING")] {
        await model.perform("secret_set");model.values=["value":"synthetic-private-value"]
        reply=["outcome":outcome,"reason":reason,"raw_error":"synthetic-private-value"]
        await model.submit()
        try check(model.showingInput && model.inputError==model.notice && !model.notice.isEmpty && model.notice != "마쳤어요.","TASK-13 unfinished \(outcome) response has no completion notice")
        try check(!model.notice.contains("synthetic-private-value") && !model.notice.contains(reason),"TASK-13 raw errors and reason codes remain hidden")
        if reason=="UNDO_CONFLICT" {try check(model.notice=="서버의 연결 설정이 바뀌어 저장하지 못했어요. 기존 설정을 확인한 뒤 다시 연결해 주세요.","TASK-13 conflict explains why saving stopped")}
        if outcome=="pending" {try check(model.notice=="아직 처리 중이에요. 잠시 기다려 주세요.","TASK-13 pending response stays pending")}
        model.closeInput()
    }
    await model.perform("secret_set");model.values=["value":"synthetic-private-value"]
    reply=["outcome":"done","reason":"OK"];await model.submit()
    try check(model.notice=="마쳤어요." && !model.showingInput && model.values.isEmpty,"TASK-13 completed reply still closes and clears input")
    print("TASK-13 INCOMPLETE REPLY PASS")
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
    try await waitFor{window.window.attachedSheet?.isVisible==true && window.window.attachedSheet?.isKeyWindow==true}
    let alert=window.window.attachedSheet
    try check(alert != nil && NSApp.modalWindow==nil && window.window.level.rawValue==26 && alert?.level.rawValue==26 && alert?.isVisible==true && alert?.isKeyWindow==true,"AT-HC-26 restart confirmation is visible and key at the preferred level without app modality")
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
    model.values=["password":"synthetic-private-value"]
    try check(model.fields.first?.secure==true,"AT-FF-70 fixture keeps a secure input field")
    try check(connectionWindowIsShareable(window.window),"AT-FF-70 input stage shares connection window and every sheet")
    let confirmation=Task{await model.confirmRestart()};await pause(0.1)
    let alert=input.attachedSheet
    let shareableDuringAlert=connectionWindowIsShareable(window.window)
    let visibleDuringAlert=(alert?.level.rawValue ?? 0)>conversation.level.rawValue
    if let alert{input.endSheet(alert,returnCode:.alertSecondButtonReturn)}
    let accepted=await confirmation.value;await pause(0.1)
    try check(alert != nil && visibleDuringAlert && !accepted && window.window.level.rawValue==26 && input.isVisible,"AT-FF-22 internal restart alert stays above the floating conversation")
    try check(shareableDuringAlert,"AT-FF-70 confirmation stage shares connection window and every sheet")
    for accepted in [false,true] {
        var normalDuringAuth=false
        model.confirm={normalDuringAuth=window.window.level == .normal;return accepted}
        await model.perform("app_connect");await pause(0.1)
        try check(normalDuringAuth && window.window.level.rawValue==26 && window.window.attachedSheet?.isVisible==true,"AT-FF-22 authentication success/cancellation restores input")
    }
    model.closeInput();await pause(0.1)
    try check(window.window.sheets.isEmpty && model.values.isEmpty && connectionWindowIsShareable(window.window),"AT-FF-70 closing input clears values and keeps connection window shareable")
    print("AT-FF-70 CONNECTION SHARING PASS; AT-FF-71 regression in full suite")
    window.setPreferredLevel(.normal)
    await model.perform("app_connect");await pause(0.1)
    try check(window.window.level == .normal && window.window.attachedSheet?.isVisible==true,"AT-FF-23 inactive preference stays normal with input")
    print("AT-FF-20~23 APP PASS")
}

// AT-FF-70 includes nested confirmation sheets, not just the immediate input sheet.
@MainActor private func connectionWindowIsShareable(_ window:NSWindow)->Bool {
    window.sharingType != .none && window.sheets.allSatisfy(connectionWindowIsShareable)
}

/// AT-CS-01~04: literal acceptance expectations, fake gate and real AppKit event dispatch.
@MainActor func connectionRestartTests(outputDirectory:URL?=nil) async throws {
    setbuf(stdout,nil)
    try await restartModelTests()
    try await restartTransportTests()
    try await restartWindowTests(outputDirectory:outputDirectory)
    print("AT-CS-01~04 PASS (fake gate; real AppKit sheets and mouse events; no operational restart)")
}

@MainActor private func restartModelTests() async throws {
    let document=restartDocument()
    var frames:[[String:Any]]=[]
    var original:CheckedContinuation<[String:Any],Error>?
    var queries=0
    let model=ConnectionsModel(send:{frame in
        frames.append(frame)
        if frame["type"] as? String=="connections" {return ["document":document]}
        if frame["action"] as? String=="job_status" {
            queries += 1
            return ["reply":["outcome":queries==1 ? "pending":"done","job":"synthetic-job","connected":1]]
        }
        if frame["values"] != nil {return try await withCheckedThrowingContinuation{original=$0}}
        return ["reply":["outcome":"waiting","committed":true,"next":["kind":"gateway_restart"]]]
    },confirm:{true})
    model.confirmRestart={true};model.pollingInterval=1_000_000
    await model.refresh();model.detail="app:synthetic";await model.perform("app_connect")
    try check(ConnectionInputView(model:model).primaryTitle=="다시 시작" && ConnectionInputView(model:model).storageHint.isEmpty,"AT-CS-01 restart label has no storage instruction")
    let submitted=Task{await model.submit()};try await waitFor{original != nil}
    try check(model.busy && model.restartInFlight && model.notice.contains("응답을 기다리고"),"AT-CS-03a response delay is visible before a reply exists")
    model.selected="beta" // Queries must retain the request profile even if the selection changes.
    original?.resume(returning:["reply":["outcome":"pending","job":"synthetic-job"]]);original=nil
    await submitted.value;try await waitFor{model.notice.contains("완료됐고")}
    try check(!model.trackingRestart && !model.showingInput,"AT-CS-03a acknowledged completion releases the old restart step for a new connection")
    let resumes=frames.filter{($0["values"] as? [String:String])?["resume"]=="gateway_restart"}
    try check(resumes.count==1 && resumes[0]["values"] as? [String:String]==["resume":"gateway_restart"],"AT-CS-03a resume request is sent exactly once without saved inputs")
    let lookups=frames.filter{$0["action"] as? String=="job_status"}
    try check(lookups.count==2 && lookups.allSatisfy{$0["connection"] as? String=="synthetic-job" && $0["profile"] as? String=="alpha" && $0["reauth"] as? Bool==false},"AT-CS-03a known job/profile stay fixed through pending and done")
    model.close()

    for (outcome,reason,expected) in [("failed","RESTART_FAILED","작업에 실패"),("refused","RESTART_FAILED","작업이 거절"),("partial","OK","일부 채널"),("unknown","OK","실행 여부를 확인할 수 없"),("timeout","OK","확인 기한"),("refused","UNKNOWN_JOB","확인할 기록이 없")] {
        var mutations=0,reads=0
        let m=ConnectionsModel(send:{frame in
            if frame["type"] as? String=="connections" {return ["document":document]}
            if frame["action"] as? String=="job_status" {reads += 1;return ["reply":["outcome":outcome,"reason":reason]]}
            mutations += 1;return ["reply":["outcome":"pending","job":"synthetic-job"]]
        },confirm:{true})
        m.confirmRestart={true};m.pollingInterval=1_000_000
        await m.refresh();m.detail="gateway";await m.perform("gateway_restart")
        try await waitFor{m.notice.contains(expected)}
        await m.perform("gateway_restart");try await waitFor{reads==2}
        try check(mutations==1 && !m.notice.contains("동의") && !m.notice.contains("다시 연결을"),"AT-CS-03c \(outcome)/\(reason) permits only read-only rechecking")
        m.close()
    }
    for exhaustedByFailure in [false,true] {
        var mutations=0,reads=0
        let m=ConnectionsModel(send:{frame in
            if frame["type"] as? String=="connections" {return ["document":document]}
            if frame["action"] as? String=="job_status" {
                reads += 1
                if exhaustedByFailure {throw GateFailure.notConnected}
                return ["reply":["outcome":"pending","job":"synthetic-job"]]
            }
            mutations += 1;return ["reply":["outcome":"pending","job":"synthetic-job"]]
        },confirm:{true})
        m.confirmRestart={true};m.pollingInterval=1_000_000;m.pollingAttempts=2
        await m.refresh();m.detail="gateway";await m.perform("gateway_restart")
        try await waitFor{m.notice.contains("읽기 전용")}
        try check(reads==2 && mutations==1 && !m.busy && !m.notice.contains("동의"),"AT-CS-03c bounded polling exhaustion: failure=\(exhaustedByFailure)")
        m.close()
    }
    var mutations=0
    let busy=ConnectionsModel(send:{frame in
        if frame["type"] as? String=="connections" {return ["document":document]}
        if frame["values"] != nil {mutations += 1;return ["reply":["outcome":"refused","reason":"BUSY"]]}
        return ["reply":["outcome":"waiting","committed":true,"next":["kind":"gateway_restart"]]]
    },confirm:{true})
    busy.confirmRestart={true};await busy.refresh();busy.detail="app:synthetic";await busy.perform("app_connect");await busy.submit()
    try check(mutations==1 && !busy.busy && !busy.trackingRestart && busy.showingInput && busy.inputError.contains("시작하지 않았"),"AT-CS-03c explicit BUSY restores editable input and explains nonexecution")
    busy.close()

    var authentication:CheckedContinuation<Bool,Never>?
    let auth=ConnectionsModel(send:{frame in
        if frame["type"] as? String=="connections" {return ["document":document]}
        throw TestFailure.assertion("AT-CS-04 closed authentication must not send")
    },confirm:{await withCheckedContinuation{authentication=$0}})
    await auth.refresh();auth.detail="gateway"
    let task=Task{await auth.perform("gateway_restart")};try await waitFor{authentication != nil}
    print("AT-CS-04 authentication entered; busy=\(auth.busy), confirming=\(auth.confirming)")
    auth.close();authentication?.resume(returning:true);await task.value
    try check(!auth.busy && !auth.confirming && !auth.showingInput,"AT-CS-04 late authentication cannot submit after close")

    // Ordinary stages retain their label and storage help independently of the restart stage.
    try check(ConnectionInputView(model:busy).primaryTitle=="확인하고 저장" && ConnectionInputView(model:busy).storageHint.contains("저장"),"AT-CS-01 ordinary input keeps saving language")
    print("AT-CS MODEL PASS: delayed send, known-job polling, terminal outcomes, bounded failures, BUSY, authentication dismissal")
}

/// Uses the production request continuation/timer; only the transport and timeout duration are injected.
@MainActor private func restartTransportTests() async throws {
    for direct in [false,true] {
        for disconnect in [false,true] {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:dir)}
            let controller=try testConversation(client:GateClient(store:try LocalStore(directory:dir),credentials:MemoryCredentials()))
            var frames:[[String:Any]]=[],mutations=0,queries=0,originalRef:String?
            let window=ConnectionsWindow(controller:controller,requestTimeout:30_000_000,transmit:{frame in
                frames.append(frame)
                let ref=frame["id"] as! String
                var reply:[String:Any]
                if frame["type"] as? String=="connections" {controller.receive(["v":1,"type":"connections_status","ref":ref,"document":restartDocument()]);return}
                if frame["action"] as? String=="job_status" {
                    if mutations==0 {reply=["outcome":"refused","reason":"UNKNOWN_JOB"]}
                    else {
                        queries += 1
                        if queries==1 {throw GateFailure.notConnected}
                        reply=["outcome":queries==2 ? "pending":"done","job":"synthetic-job","connected":1]
                    }
                } else if frame["action"] as? String=="gateway_restart" || (frame["values"] as? [String:String])?["resume"]=="gateway_restart" {
                    mutations += 1;originalRef=ref
                    if disconnect {throw GateFailure.notConnected}
                    return // The actual production request timer must expire.
                } else {reply=["outcome":"waiting","committed":true,"next":["kind":"gateway_restart"]]}
                controller.receive(["v":1,"type":"connection_result","ref":ref,"reply":reply])
            })
            let m=window.model
            defer{m.close();window.window.close()}
            m.confirm={true};m.confirmRestart={true};m.pollingInterval=1_000_000
            await m.refresh();m.detail=direct ? "gateway":"app:synthetic"
            if !direct {await m.perform("app_connect")}
            let operation=Task{if direct {await m.perform("gateway_restart")}else{await m.submit()}}
            try await waitFor{mutations==1}
            await operation.value;try await waitFor{m.notice.contains("완료됐고")}
            try check(mutations==1 && queries==3 && !m.busy && m.notice.hasPrefix("최근 재시작 결과:"),"AT-CS-03b direct=\(direct), disconnect=\(disconnect): one mutation, latest recovery, honest recent result")
            let mutation=frames.first{$0["action"] as? String=="gateway_restart" || ($0["values"] as? [String:String])?["resume"]=="gateway_restart"}!
            try check(direct ? mutation["values"]==nil:mutation["values"] as? [String:String]==["resume":"gateway_restart"],"AT-CS-03b direct and resume retain distinct frame contracts")
            let reads=frames.filter{$0["action"] as? String=="job_status"}
            try check(reads.prefix(2).allSatisfy{$0["connection"] as? String=="latest"} && reads.last?["connection"] as? String=="synthetic-job","AT-CS-03b latest lookup switches to the returned job")
            let before=m.notice
            if let ref=originalRef {controller.receive(["v":1,"type":"connection_result","ref":ref,"reply":["outcome":"pending","job":"late-job"]])}
            await pause(0.02)
            try check(m.notice==before && mutations==1,"AT-CS-03d expired original reply cannot start a second recovery path")
            let previousQueries=queries
            if direct {await m.perform("gateway_restart")}else{await m.submit()}
            try await waitFor{queries==previousQueries+1}
            let recheck=frames.last{$0["type"] as? String=="connection_action"}
            try check(mutations==1 && recheck?["action"] as? String=="job_status" && recheck?["reauth"] as? Bool==false,"AT-CS-03b a recent result after response loss still permits only read-only rechecking")
            if direct {try check(!m.showingInput && !m.notice.isEmpty,"AT-CS-03b direct restart result is visible in connection notice without input")}
            print("AT-CS-03b transport direct=\(direct), disconnect=\(disconnect), mutations=\(mutations), queries=\(queries), result=\(m.notice)")
        }
    }
    try await restartReopenTests()
}

@MainActor private func restartReopenTests() async throws {
    let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:dir)}
    let controller=try testConversation(client:GateClient(store:try LocalStore(directory:dir),credentials:MemoryCredentials()))
    var mutations=0,queries=0,originalRef:String?,staleQuery:String?,profiles:[String]=[]
    let window=ConnectionsWindow(controller:controller,requestTimeout:60_000_000,transmit:{frame in
        let ref=frame["id"] as! String
        if frame["type"] as? String=="connections" {controller.receive(["v":1,"type":"connections_status","ref":ref,"document":restartDocument()]);return}
        var reply:[String:Any]
        if frame["action"] as? String=="job_status" {
            if mutations==0 {reply=["outcome":"refused","reason":"UNKNOWN_JOB"]}
            else {
                profiles.append(frame["profile"] as! String);queries += 1
                if queries==1 {staleQuery=ref;return}
                reply=["outcome":queries==2 ? "pending":"done","job":"synthetic-job","connected":1]
            }
        } else if frame["values"] != nil {mutations += 1;originalRef=ref;return}
        else {reply=["outcome":"waiting","committed":true,"next":["kind":"gateway_restart"]]}
        controller.receive(["v":1,"type":"connection_result","ref":ref,"reply":reply])
    })
    let m=window.model
    defer{m.close();window.window.close()}
    m.confirm={true};m.confirmRestart={true};m.pollingInterval=1_000_000
    window.show();try await waitFor{m.agent != nil};m.detail="app:synthetic";await m.perform("app_connect");await pause(0.1)
    let task=Task{await m.submit()};try await waitFor{mutations==1}
    m.closeInput() // Close during the initial response wait.
    await task.value;try await waitFor{staleQuery != nil}
    window.window.close();m.selected="beta"
    m.known["beta"]=AgentConnectionProfile(profile:"beta",display_name:"직원 B",connections:[])
    window.show(profile:"beta")
    try await waitFor{m.notice.contains("완료됐고")}
    for ref in [originalRef,staleQuery].compactMap({$0}) {controller.receive(["v":1,"type":"connection_result","ref":ref,"reply":["outcome":"pending","job":"late-job"]])}
    await pause(0.04)
    try check(mutations==1 && profiles.allSatisfy{$0=="alpha"} && queries==3 && !m.showingInput && window.window.sheets.isEmpty && m.notice.hasPrefix("최근 재시작 결과:"),"AT-CS-03d/04 close, selection change, reopen and late replies preserve one request and its original profile")
    print("AT-CS-03d/04 reopen: mutations=\(mutations), queries=\(queries), profiles=\(profiles), input=false")
}

@MainActor private func restartWindowTests(outputDirectory:URL?) async throws {
    if let outputDirectory {try FileManager.default.createDirectory(at:outputDirectory,withIntermediateDirectories:true)}
    for level in [0,26] {
        for disposition in ["cancel","accept","close-input","close-window"] {
            let dir=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
            defer{try? FileManager.default.removeItem(at:dir)}
            let controller=try testConversation(client:GateClient(store:try LocalStore(directory:dir),credentials:MemoryCredentials()))
            let window=ConnectionsWindow(controller:controller),m=window.model
            let conversation=PetPanel(contentRect:CGRect(x:100,y:100,width:600,height:500),styleMask:[.borderless],backing:.buffered,defer:false)
            conversation.isReleasedWhenClosed=false;conversation.level=NSWindow.Level(rawValue:25);conversation.hidesOnDeactivate=false
            conversation.contentView=NSTextField(labelWithString:"가짜 대화 창")
            defer{m.close();window.window.close();conversation.close()}
            var mutations=0
            m.send={frame in
                if frame["type"] as? String=="connections" {return ["document":restartDocument()]}
                if frame["action"] as? String=="job_status" {return ["reply":["outcome":"refused","reason":"UNKNOWN_JOB"]]}
                if frame["values"] != nil {mutations += 1;return ["reply":["outcome":"done","connected":1]]}
                return ["reply":["outcome":"waiting","committed":true,"next":["kind":"gateway_restart","hint":"가짜 재시작 안내"]]]
            }
            m.confirm={true};await m.refresh();m.detail="app:synthetic";window.setPreferredLevel(NSWindow.Level(rawValue:level));window.show()
            await m.perform("app_connect");try await waitFor{window.window.attachedSheet != nil}
            let input=window.window.attachedSheet!
            var completed=false
            let operation=Task{await m.submit();completed=true}
            try await waitFor{input.attachedSheet != nil}
            let alert=input.attachedSheet!
            if level>0 {conversation.setFrame(alert.frame,display:true);conversation.orderFrontRegardless();alert.makeKeyAndOrderFront(nil)}
            await pause(0.05)
            let cancel=try restartButton(alert,title:"취소"),accept=try restartButton(alert,title:"다시 시작")
            let buttonFrame=alert.convertToScreen(cancel.convert(cancel.bounds,to:nil))
            let screen=alert.screen?.visibleFrame ?? .zero
            let ordered=((CGWindowListCopyWindowInfo(.optionOnScreenOnly,kCGNullWindowID) as? [[String:Any]]) ?? []).compactMap{$0[kCGWindowNumber as String] as? Int}
            // Newer AppKit can composite a nested sheet into its parent's WindowServer surface.
            var surface=alert
            while !ordered.contains(surface.windowNumber),let parent=surface.sheetParent {surface=parent}
            print("AT-CS-02 surface: alert=\(alert.windowNumber), host=\(surface.windowNumber), hostFrame=\(surface.frame), level=\(surface.level.rawValue), visible=\(surface.isVisible)")
            try check(screen.contains(buttonFrame) && alert.isVisible && alert.isKeyWindow,"AT-CS-02 confirmation button lies on screen and receives key input: \(level)/\(disposition)")
            if level>0 {
                let surfaceIndex=ordered.firstIndex(of:surface.windowNumber) ?? Int.max,conversationIndex=ordered.firstIndex(of:conversation.windowNumber) ?? -1
                try check(alert.frame.intersects(conversation.frame) && alert.level.rawValue>25 && surface.level.rawValue>25 && surface.frame.contains(buttonFrame) && surfaceIndex<conversationIndex,"AT-CS-02 overlapped floating conversation cannot cover confirmation")
            }
            print("AT-CS-02 GUI \(level)/\(disposition): levels=\(window.window.level.rawValue),\(input.level.rawValue),\(alert.level.rawValue); windows=\(ordered.filter{[window.window.windowNumber,input.windowNumber,alert.windowNumber,conversation.windowNumber].contains($0)}); button=\(buttonFrame); alert=\(alert.frame); conversation=\(conversation.frame); key=\(alert.isKeyWindow)")
            if let outputDirectory,disposition=="cancel" {
                // Capture only these synthetic views; z-order/occlusion is independently checked above.
                for (name,view) in [("confirm",alert.contentView),("input",input.contentView)] {
                    guard let view,let bitmap=view.bitmapImageRepForCachingDisplay(in:view.bounds) else{throw TestFailure.assertion("AT-CS-02 AppKit capture unavailable")}
                    view.cacheDisplay(in:view.bounds,to:bitmap)
                    try bitmap.representation(using:.png,properties:[:])!.write(to:outputDirectory.appendingPathComponent("cs-\(name)-\(level).png"))
                }
                print("AT-CS-02 capture: actual AppKit view rendering; visibility evidence is window order, frame overlap and mouse events")
            }
            switch disposition {
            case "cancel":try restartClick(cancel,in:alert)
            case "accept":try restartClick(accept,in:alert)
            // AppKit disables performClose on a parent while a modal sheet is attached.
            // Exercise the real close notification (also used when the owner tears down a window).
            case "close-input":input.close()
            default:window.window.close()
            }
            try await waitFor{completed};await operation.value;await pause(0.04)
            try check(!m.busy && input.attachedSheet==nil && mutations==(disposition=="accept" ? 1:0),"AT-CS-02/04 confirmation completes once and cancelled/closed confirmation never resumes")
            if disposition=="cancel" {try check(m.showingInput && input.isVisible,"AT-CS-02 cancellation restores input")}
            if disposition.hasPrefix("close") {
                window.show();await pause(0.05)
                try check(!m.showingInput && window.window.sheets.isEmpty,"AT-CS-04 reopen leaves no hidden confirmation or reopened input")
            }
        }
    }
}

@MainActor private func restartButton(_ window:NSWindow,title:String) throws ->NSButton {
    func find(_ view:NSView)->NSButton? {
        if let button=view as? NSButton,button.title==title {return button}
        return view.subviews.lazy.compactMap(find).first
    }
    guard let content=window.contentView,let button=find(content) else{throw TestFailure.assertion("CS missing AppKit button: "+title)}
    return button
}

/// Dispatches mouse down/up through the application event queue, never an alert callback or performClick.
@MainActor private func restartClick(_ button:NSButton,in window:NSWindow) throws {
    let point=button.convert(CGPoint(x:button.bounds.midX,y:button.bounds.midY),to:nil)
    print("AT-CS-02 post mouse down/up: \(button.title), window=\(window.windowNumber), point=\(point), enabled=\(button.isEnabled)")
    for type in [NSEvent.EventType.leftMouseDown,.leftMouseUp] {
        guard let event=NSEvent.mouseEvent(with:type,location:point,modifierFlags:[],timestamp:ProcessInfo.processInfo.systemUptime,windowNumber:window.windowNumber,context:nil,eventNumber:1,clickCount:1,pressure:type == .leftMouseDown ? 1:0) else{throw TestFailure.assertion("CS mouse event unavailable")}
        NSApp.postEvent(event,atStart:false)
    }
}
