import AppKit
import SwiftUI

@MainActor private func connectionFixtureDocument()->[String:Any] {
    return ["schema":"hermes-connections/1","checked_at":"2026-01-01T12:00:00Z","agents":[["profile":"alpha","display_name":"직원 A","connections":[["id":"key:SYNTHETIC_KEY","service":"key","label":"시험 서비스","reason":"KEY_UNVERIFIED","checked_at":"2026-01-01T12:00:00Z","group":"account","state":"unknown","capabilities":["키 저장됨(확인 안 함)"],"rules":["동작은 서버에서 실행해요."],"actions":[["id":"secret_set","label":"키 바꾸기","primary":true]]]]]]]
}

/// Isolated access to the original private test functions; no assertions are omitted inside them.
@MainActor func connectionSupplementTests(_ part:String) async throws {
    switch part {
    case "management":try await connectionManagementTests(outputDirectory:nil)
    case "incomplete":try await connectionIncompleteReplyTests(document:connectionFixtureDocument())
    default:throw TestFailure.assertion("unknown connection supplement")
    }
}

@MainActor func connectionsTests(outputDirectory:URL?=nil) async throws {
    let document=connectionFixtureDocument()
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
    try await googleDisconnectTests()
}

/// GD-T01/T02/T05/T06/T17/T18: real AppKit model, fake gate replies only.
@MainActor func googleDisconnectTests() async throws {
    var item:[String:Any] = ["id":"team:google-personal","service":"google","label":"Google 개인","group":"account","state":"connected","reason":"GOOGLE_VERIFIED","checked_at":"2026-01-01T00:00:00Z","account":"old"+"@example.test","scope":"personal","reconnect":"personal","disconnect_mode":"forget_account","capabilities":[],"rules":[],"actions":[["id":"account_disconnect","label":"연결 해제","primary":true],["id":"account_connect","label":"연결","primary":false]]]
    var frames:[[String:Any]]=[],confirmation="",allow=true,reauth=true,cancelFails=false
    let model=ConnectionsModel(send:{frame in
        frames.append(frame)
        if frame["type"] as? String == "connections" {
            return ["document":["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"Synthetic","connections":[item]]]]]
        }
        switch frame["action"] as? String {
        case "account_disconnect":
            item.removeValue(forKey:"account");item["state"]="not_connected"
            return ["reply":["outcome":"done","reason":"DISCONNECTED"]]
        case "account_connect":return ["reply":["outcome":"pending","session_id":"synthetic-job","instruction":"서버 Mac의 브라우저에서 계정을 선택해 주세요. 다른 Mac에서는 완료할 수 없습니다."]]
        case "account_cancel":
            if cancelFails{throw GateFailure.notConnected}
            return ["reply":["outcome":"done","reason":"CANCELLED"]]
        default:return ["reply":["outcome":"pending"]]
        }
    },confirm:{reauth})
    model.confirmDisconnect={confirmation=$0;return allow}
    await model.refresh();model.selected="alpha";model.detail="team:google-personal"
    allow=false
    let before=frames.count;await model.perform("account_disconnect")
    try check(frames.count==before,"GD-T02 confirmation cancellation sends no mutation")
    allow=true;reauth=false
    await model.perform("account_disconnect")
    try check(frames.count==before,"GD-T02 rejected reauthentication sends no mutation")
    reauth=true;await model.perform("account_disconnect")
    try check(confirmation.contains("지웁니다") && confirmation.contains("인증 정보") && confirmation.contains("다른 직원"),"GD-T17 deletion confirmation describes employee credentials and other employee preservation")
    try check(!confirmation.contains("그대로 써요"),"GD-T18 deletion capability changes the confirmation meaning")
    let sent=frames.first{$0["action"] as? String == "account_disconnect"}
    try check((sent?["values"] as? [String:String])?["disconnect_mode"]=="forget_account" && sent?["reauth"] as? Bool==true,"GD-T18 deletion meaning and reauthentication both cross the wire")
    try check(model.item?.account==nil && model.item?.state == .notConnected,"GD-T01 successful deletion refreshes the email immediately")
    await model.perform("account_connect")
    try check(model.notice.contains("서버 Mac") && model.notice.contains("다른 Mac"),"GD-T17 loopback restriction stays visible during authentication")
    // Closing after changing the selected employee must cancel the originating job.
    model.selected="beta";model.close();await pause(0.05)
    let cancelled=frames.first{$0["action"] as? String == "account_cancel"}
    try check(cancelled?["profile"] as? String=="alpha" && cancelled?["connection"] as? String=="synthetic-job" && cancelled?["reauth"] as? Bool==false,"GD-T06 close cancels only the owned originating OAuth session without Touch ID")
    model.selected="alpha";await model.perform("account_connect");cancelFails=true
    model.close();await pause(0.05)
    try check(model.notice.contains("취소 확인 안 됨"),"GD-T17 failed cancellation is not presented as successful")
    model.close()
    var held:CheckedContinuation<[String:Any],Never>?
    var lateFrames:[[String:Any]]=[]
    let late=ConnectionsModel(send:{frame in
        lateFrames.append(frame)
        if frame["type"] as? String=="connections" {return ["document":["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"Synthetic","connections":[item]]]]]}
        if frame["action"] as? String=="account_connect" {return await withCheckedContinuation{held=$0}}
        return ["reply":["outcome":"done","reason":"CANCELLED"]]
    },confirm:{true})
    late.openAuthorization={_ in};await late.refresh();late.detail="team:google-personal"
    let connecting=Task{await late.perform("account_connect")};await pause(0.05);late.close()
    held?.resume(returning:["reply":["outcome":"pending","session_id":"synthetic-late-job"]])
    await connecting.value
    try check(!late.authenticating && lateFrames.contains{$0["action"] as? String=="account_cancel" && $0["connection"] as? String=="synthetic-late-job"},"GD-T06 closing before the start reply cancels the late job")
    var timedFrames:[[String:Any]]=[]
    let timed=ConnectionsModel(send:{frame in
        timedFrames.append(frame)
        if frame["type"] as? String=="connections" {return ["document":["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"Synthetic","connections":[item]]]]]}
        if frame["action"] as? String=="account_connect" {return ["reply":["outcome":"pending","session_id":"synthetic-expired-job"]]}
        if frame["action"] as? String=="account_cancel" {return ["reply":["outcome":"done","reason":"CANCELLED"]]}
        throw GateFailure.notConnected
    },confirm:{true})
    timed.pollingWait={};timed.openAuthorization={_ in};await timed.refresh();timed.detail="team:google-personal"
    await timed.perform("account_connect");try await waitFor{!timed.authenticating}
    try check(timed.notice.contains("초과") && timedFrames.contains{$0["action"] as? String=="account_cancel" && $0["connection"] as? String=="synthetic-expired-job"},"GD-T06 expired polling closes the sheet and cancels its originating job")
    print("GOOGLE DISCONNECT APP PASS")
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
    let focusOrigin=ProcessInfo.processInfo.systemUptime
    let focusEvents:[Notification.Name]=[NSApplication.didBecomeActiveNotification,NSApplication.didResignActiveNotification,NSWindow.didBecomeKeyNotification,NSWindow.didResignKeyNotification,NSWindow.didEndSheetNotification]
    let focusObservers=focusEvents.map { name in
        NotificationCenter.default.addObserver(forName:name,object:nil,queue:.main) { event in
            MainActor.assumeIsolated {
                if let eventWindow=event.object as? NSWindow,eventWindow !== window.window,eventWindow.sheetParent !== window.window {return}
                print("AT-HC-27 EVENT t=\(ProcessInfo.processInfo.systemUptime-focusOrigin) name=\(event.name.rawValue) active=\(NSApp.isActive) key=\(window.window.isKeyWindow) sheets=\(window.window.sheets.count)")
                fflush(stdout)
            }
        }
    }
    defer {focusObservers.forEach{NotificationCenter.default.removeObserver($0)}}
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
    live.inputDismissed();await pause(0.1);window.show()
    // Observe AppKit's asynchronous activation; the product remains responsible for taking focus.
    do {
        try await waitFor(5) {window.window.isVisible && window.window.isKeyWindow && live.fields.isEmpty && !live.busy}
    } catch {
        print("AT-HC-27 WAIT_TIMEOUT limit=5 active=\(NSApp.isActive) visible=\(window.window.isVisible) key=\(window.window.isKeyWindow) fields=\(live.fields.count) busy=\(live.busy) sheets=\(window.window.sheets.count) canKey=\(window.window.canBecomeKey) keyWindowPresent=\(NSApp.keyWindow != nil) frontmostIsSelf=\(NSWorkspace.shared.frontmostApplication?.processIdentifier == ProcessInfo.processInfo.processIdentifier) securityAgentFront=\(NSWorkspace.shared.frontmostApplication?.bundleIdentifier == "com.apple.SecurityAgent"))")
        fflush(stdout)
        throw TestFailure.assertion("AT-HC-27 activation/key event wait timed out (5 seconds)")
    }
    print("AT-HC-27 observation visible=\(window.window.isVisible) key=\(window.window.isKeyWindow) fields=\(live.fields.count) busy=\(live.busy) sheets=\(window.window.sheets.count)")
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
    model.values=["password":"synthetic-private-value"]
    try check(model.fields.first?.secure==true,"AT-FF-70 fixture keeps a secure input field")
    try check(connectionWindowIsShareable(window.window),"AT-FF-70 input stage shares connection window and every sheet")
    let confirmation=Task{await model.confirmRestart()};await pause(0.1)
    let alert=input.attachedSheet
    let shareableDuringAlert=connectionWindowIsShareable(window.window)
    let normalDuringAlert=window.window.level == .normal
    if let alert{input.endSheet(alert,returnCode:.alertSecondButtonReturn)}
    let accepted=await confirmation.value;await pause(0.1)
    try check(alert != nil && normalDuringAlert && !accepted && window.window.level.rawValue==26 && input.isVisible,"AT-FF-22 restart alert lowers then restores input")
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


/// GD-T17: production AppKit authentication sheet, fake server and no real OAuth.
@MainActor func googleDisconnectSheetTests() async throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer{try? FileManager.default.removeItem(at:directory)}
    let store=try LocalStore(directory:directory),controller=try testConversation(client:GateClient(store:store,credentials:MemoryCredentials()))
    let connectionWindow=ConnectionsWindow(controller:controller),model=connectionWindow.model
    defer{model.close();connectionWindow.window.close()}
    var sent:[[String:Any]]=[]
    let item:[String:Any]=["id":"team:google-personal","service":"google","label":"Google 개인","group":"account","state":"not_connected","reason":"NOT_CONNECTED","checked_at":"2026-01-01T00:00:00Z","scope":"personal","disconnect_mode":"forget_account","capabilities":[],"rules":[],"actions":[["id":"account_connect","label":"연결","primary":true]]]
    model.confirm={true};model.openAuthorization={_ in}
    model.send={frame in
        sent.append(frame)
        if frame["type"] as? String=="connections" {return ["document":["schema":"hermes-connections/1","checked_at":"2026-01-01T00:00:00Z","agents":[["profile":"alpha","display_name":"Synthetic","connections":[item]]]]]}
        if frame["action"] as? String=="account_connect" {return ["reply":["outcome":"pending","session_id":"synthetic-sheet-job"]]}
        return ["reply":["outcome":"done","reason":"CANCELLED"]]
    }
    await model.refresh();model.detail="team:google-personal";connectionWindow.show()
    await model.perform("account_connect");await pause(0.15)
    guard let sheet=connectionWindow.window.attachedSheet else{throw TestFailure.assertion("GD-T17 authentication AppKit sheet missing")}
    func descendants(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap{descendants($0)}}
    let controls=sheet.contentView.map(descendants) ?? []
    let text=controls.compactMap{($0 as? NSTextField)?.stringValue}.joined(separator:" ")
    try check(sheet is NSPanel && NSApp.modalWindow==nil && text.contains("서버 Mac") && text.contains("다른 Mac"),"GD-T17 real AppKit sheet shows loopback restriction")
    guard let cancel=controls.compactMap({$0 as? NSButton}).first(where:{$0.title=="인증 취소"}) else{throw TestFailure.assertion("GD-T17 cancel button missing")}
    if let path=ProcessInfo.processInfo.environment["HEJO_GOOGLE_CAPTURE"],let content=sheet.contentView,let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds){
        content.cacheDisplay(in:content.bounds,to:bitmap)
        if let data=bitmap.representation(using:.png,properties:[:]){try data.write(to:URL(fileURLWithPath:path+".render.png"))}
        try? FileManager.default.removeItem(atPath:path)
        let capture=Process();capture.executableURL=URL(fileURLWithPath:"/usr/sbin/screencapture")
        capture.arguments=["-x","-o","-l",String(sheet.windowNumber),path]
        try capture.run();capture.waitUntilExit()
        print("APPKIT_SCREEN_CAPTURE_EXIT \(capture.terminationStatus)")
    }
    cancel.performClick(nil);await pause(0.15)
    try check(!model.authenticating && connectionWindow.window.attachedSheet==nil,"GD-T17 cancel dismisses authentication sheet")
    try check(sent.contains{$0["action"] as? String=="account_cancel" && $0["profile"] as? String=="alpha" && $0["connection"] as? String=="synthetic-sheet-job" && $0["reauth"] as? Bool==false},"GD-T06 AppKit cancel uses owned job without Touch ID")
    print("GOOGLE DISCONNECT APPKIT SHEET PASS")
}

/// GD-T17 / IR-1: actual hosted controls, AppKit confirmation/authentication sheets and loopback gate.
/// Only reauthentication, browser opening and the existing polling clock are injected; send stays production.
@MainActor func googleDisconnectUITests(directory:URL,endpoint:String,evidence:URL,closeOnly:Bool=false) async throws {
    // Enable accessibility only inside this fixture process so SwiftUI publishes its rendered nodes.
    NSApp.accessibilitySetValue(true,forAttribute:NSAccessibility.Attribute(rawValue:"AXEnhancedUserInterface"))
    NSApp.accessibilitySetValue(true,forAttribute:NSAccessibility.Attribute(rawValue:"AXManualAccessibility"))
    let store=try LocalStore(directory:directory),client=GateClient(store:store,credentials:MemoryCredentials())
    let controller=try testConversation(client:client),connection=ConnectionsWindow(controller:controller),model=connection.model
    defer{model.close();connection.window.close();client.stop()}
    var authCount=0,releasePolling=false
    model.confirm={authCount+=1;return true};model.openAuthorization={_ in}
    model.pollingWait={
        while !releasePolling && !Task.isCancelled {await pause(0.01)}
        try Task.checkCancellation();await pause(0.001)
    }
    try client.pair(address:endpoint,code:"test_code-12",device:"synthetic-ui")
    try await waitFor{controller.canSend}
    connection.show(profile:"alpha")

    // NSHostingView exports the actual SwiftUI controls through AppKit accessibility, without AX system permission.
    func nodes(_ object:Any,depth:Int=0)->[NSObject] {
        guard depth<30,let element=object as? NSObject else{return []}
        let dynamic:AnyObject=element
        return [element]+(dynamic.accessibilityChildren?() ?? []).flatMap{nodes($0,depth:depth+1)}
    }
    func attribute(_ element:NSObject,_ name:String)->String? {
        let selector=NSSelectorFromString(name)
        guard element.responds(to:selector) else{return nil}
        return element.perform(selector)?.takeUnretainedValue() as? String
    }
    func title(_ element:NSObject)->String? {attribute(element,"accessibilityTitle")}
    func isButton(_ element:NSObject)->Bool {attribute(element,"accessibilityRole")==NSAccessibility.Role.button.rawValue}
    func click(_ element:NSObject)->Bool {
        let dynamic:AnyObject=element
        return dynamic.isAccessibilityEnabled?()==true && dynamic.accessibilityPerformPress?()==true
    }
    func texts(_ window:NSWindow)->String {
        nodes(window).flatMap{element->[String] in
            ["accessibilityLabel","accessibilityValue","accessibilityTitle"].compactMap{attribute(element,$0)}
        }.joined(separator:" | ")
    }
    func button(_ label:String)->NSObject? {
        nodes(connection.window).first{isButton($0) && (attribute($0,"accessibilityLabel")==label || title($0)==label)}
    }
    func press(_ label:String) async throws {
        try await waitFor{button(label) != nil}
        guard let control=button(label) else{throw TestFailure.assertion("GD-T17 rendered button missing: \(label)")}
        try check(click(control),"GD-T17 rendered button accepts press: \(label)")
    }
    func nativePress(_ label:String,in window:NSWindow) async throws {
        func views(_ view:NSView)->[NSView]{[view]+view.subviews.flatMap{views($0)}}
        func button()->NSButton? {window.contentView.flatMap{views($0).compactMap{$0 as? NSButton}.first{$0.title==label}}}
        try await waitFor{button()?.isEnabled==true}
        guard let control=button() else{throw TestFailure.assertion("GD-T17 native button missing: \(label)")}
        try check(control.isEnabled,"GD-T17 native button is enabled: \(label)")
        control.performClick(nil)
    }
    func capture(_ name:String,_ window:NSWindow) throws {
        guard let content=window.contentView else{throw TestFailure.assertion("GD-T17 missing content view")}
        content.layoutSubtreeIfNeeded();content.displayIfNeeded()
        guard let bitmap=content.bitmapImageRepForCachingDisplay(in:content.bounds) else{throw TestFailure.assertion("GD-T17 missing rendered bitmap")}
        content.cacheDisplay(in:content.bounds,to:bitmap)
        guard let png=bitmap.representation(using:.png,properties:[:]) else{throw TestFailure.assertion("GD-T17 missing PNG")}
        try png.write(to:evidence.appendingPathComponent(name+".png"))
        try texts(window).write(to:evidence.appendingPathComponent(name+".txt"),atomically:true,encoding:.utf8)
        print("GD-T17 VIEW \(name)")
    }
    defer {try? texts(connection.window).write(to:evidence.appendingPathComponent("last-view.txt"),atomically:true,encoding:.utf8)}
    if closeOnly {
        let connect="Synthetic, Google 개인, 연결"
        func begin() async throws {
            releasePolling=false
            try await press(connect)
            try await waitFor{connection.window.attachedSheet?.title=="Google 연결"}
            guard let sheet=connection.window.attachedSheet else{throw TestFailure.assertion("GD-T17 close sheet missing")}
            print("GD-T17 STANDARD_CLOSE_BUTTON \(sheet.standardWindowButton(.closeButton)?.isEnabled as Any)")
        }
        func closeFromControl(_ name:String) async throws {
            guard let sheet=connection.window.attachedSheet else{throw TestFailure.assertion("GD-T17 close control sheet missing")}
            try capture(name,sheet)
            try await nativePress("창 닫기",in:sheet)
            try await waitFor{!connection.window.isVisible && connection.window.attachedSheet==nil && !model.authenticating}
        }
        func reopen(_ wording:String,_ name:String) async throws {
            connection.show(profile:"alpha")
            try await waitFor{connection.window.isVisible && texts(connection.window).contains(wording) && button(connect) != nil}
            try check(!texts(connection.window).contains("연결을 확인했어요."),"GD-T17 closed authentication cannot become successful")
            try capture(name,connection.window)
        }
        try await waitFor{button(connect) != nil}
        try await begin();try await closeFromControl("close-01-success-control")
        try await waitFor{model.notice=="인증을 취소했어요." && !model.loading}
        try await reopen("인증을 취소했어요.","close-02-success-reopened")

        // Break only the fixture connection before clicking the real control: request cannot be sent.
        if button("‹ Synthetic") != nil {try await press("‹ Synthetic")}
        try await begin()
        try Data().write(to:evidence.appendingPathComponent("disconnect-requested"))
        try await waitFor{!client.isConnected}
        try await closeFromControl("close-03-offline-control")
        try await waitFor{model.notice.contains("취소 확인 안 됨")}
        try await reopen("취소 확인 안 됨","close-04-offline-reopened")
        try check(!texts(connection.window).contains("인증을 취소했어요."),"GD-T17 failed close cancellation never claims success")
        try Data().write(to:evidence.appendingPathComponent("allow-reconnect"))
        try await waitFor{controller.canSend}
        try await waitFor{!model.loading}
        try check(texts(connection.window).contains("취소 확인 안 됨"),"GD-T17 failure guidance survives reconnect and refresh")

        // Existing cancel stays a separate action and keeps the connection window open.
        if button("‹ Synthetic") != nil {try await press("‹ Synthetic")}
        try await begin()
        try await nativePress("인증 취소",in:connection.window.attachedSheet!)
        try await waitFor{connection.window.attachedSheet==nil && texts(connection.window).contains("인증을 취소했어요.")}
        try check(connection.window.isVisible,"GD-T17 cancel button still leaves parent open")
        try capture("close-05-cancel-regression",connection.window)

        // Hold an actual poll reply until after close. The existing cancelled task must ignore it.
        if button("‹ Synthetic") != nil {try await press("‹ Synthetic")}
        try await begin();releasePolling=true
        try await waitFor{FileManager.default.fileExists(atPath:evidence.appendingPathComponent("late-poll-ready").path)}
        try await closeFromControl("close-06-late-control")
        try await waitFor{model.notice=="인증을 취소했어요."}
        try await reopen("인증을 취소했어요.","close-07-late-reopened")
        try await waitFor{FileManager.default.fileExists(atPath:evidence.appendingPathComponent("late-response-sent").path)}
        try await press("새로 확인")
        try await waitFor{FileManager.default.fileExists(atPath:evidence.appendingPathComponent("late-refresh-sent").path) && !model.loading}
        try check(texts(connection.window).contains("인증을 취소했어요.") && connection.window.attachedSheet==nil && !texts(connection.window).contains("연결을 확인했어요."),"GD-T17 late poll cannot overwrite closed/reopened guidance")
        try capture("close-08-late-stable",connection.window)
        print("GD-T17 USER CLOSE APPKIT PASS")
        return
    }
    let old="old"+"@example.test",new="new"+"@example.test"
    let disconnect="Synthetic, Google 개인, 연결 해제",connect="Synthetic, Google 개인, 연결"
    try await waitFor{texts(connection.window).contains(old) && button(disconnect) != nil}
    try capture("01-connected-list",connection.window)

    func deletion(accept:Bool) async throws {
        let before=authCount
        try await press(disconnect)
        try await waitFor{connection.window.attachedSheet != nil}
        guard let alert=connection.window.attachedSheet else{throw TestFailure.assertion("GD-T17 deletion alert missing")}
        let wording=texts(alert)
        try check(wording.contains("연결을 해제할까요?") && wording.contains("계정 연결·이메일·전용 인증 정보를 지웁니다") && wording.contains("다른 직원과 회사 연결은 유지") && wording.contains("다음 연결에서 Google 계정을 선택"),"GD-T17 actual deletion confirmation explains exact effects")
        try check(!wording.contains("넣어 둔 값은 남아") && authCount==before,"GD-T17 deletion confirmation precedes reauthentication")
        try capture(accept ? "03-confirm-delete":"02-decline-delete",alert)
        try await nativePress(accept ? "해제":"취소",in:alert)
        try await waitFor{connection.window.attachedSheet==nil && !model.busy}
        try check(authCount==before+(accept ? 1:0),"GD-T17 deletion accepts or declines before authenticating")
    }
    try await deletion(accept:false)
    // Declining may select detail, so return through the actual back control before inspecting the list.
    if button("‹ Synthetic") != nil {try await press("‹ Synthetic")}
    try await waitFor{texts(connection.window).contains(old)}
    try check(button(disconnect) != nil,"GD-T17 decline preserves actual connected row")
    try await deletion(accept:true)
    try await waitFor{!texts(connection.window).contains(old) && button(connect) != nil}
    try capture("04-disconnected-detail",connection.window)
    try await press("‹ Synthetic")
    try await waitFor{button(connect) != nil && !texts(connection.window).contains(old)}
    try capture("05-disconnected-list",connection.window)
    try await press("새로 확인")
    try await waitFor{!model.loading && button(connect) != nil}
    try check(!texts(connection.window).contains(old),"GD-T17 actual list refresh cannot restore forgotten email")

    func begin() async throws {
        releasePolling=false
        try await press(connect)
        try await waitFor{connection.window.attachedSheet?.title=="Google 연결"}
        guard let sheet=connection.window.attachedSheet else{throw TestFailure.assertion("GD-T17 authentication sheet missing")}
        let text=texts(sheet)
        try check(sheet is NSPanel && text.contains("서버 Mac") && text.contains("다른 Mac") && NSApp.modalWindow==nil,"GD-T17 real authentication sheet keeps loopback guidance")
    }
    try await begin();try capture("06-reconnecting",connection.window.attachedSheet!)
    releasePolling=true
    try await waitFor{connection.window.attachedSheet==nil && texts(connection.window).contains("연결을 확인했어요.")}
    try await press("‹ Synthetic")
    try await waitFor{texts(connection.window).contains(new) && !texts(connection.window).contains(old) && button(disconnect) != nil}
    try capture("07-new-account-list",connection.window)
    try await press("새로 확인");try await waitFor{!model.loading && texts(connection.window).contains(new)}
    try check(!texts(connection.window).contains(old),"GD-T17 actual refreshed list displays only the new account")
    // Return to disconnected state using the same production alert and transport, then test failure paths.
    try await deletion(accept:true)
    try await press("‹ Synthetic")
    try await waitFor{button(connect) != nil && !texts(connection.window).contains(new)}

    try await begin()
    try await nativePress("인증 취소",in:connection.window.attachedSheet!)
    try await waitFor{connection.window.attachedSheet==nil && texts(connection.window).contains("취소 확인 안 됨")}
    try check(!texts(connection.window).contains("인증을 취소했어요."),"GD-T17 actual unconfirmed cancellation never shows success")
    try capture("08-cancel-unconfirmed",connection.window)
    try await press("‹ Synthetic")
    try await begin();try capture("09-expiring",connection.window.attachedSheet!)
    releasePolling=true
    try await waitFor(12){connection.window.attachedSheet==nil && texts(connection.window).contains("동의 시간이 초과됐어요.")}
    try check(!texts(connection.window).contains(old) && !texts(connection.window).contains(new),"GD-T17 actual expiry leaves email absent")
    try capture("10-expired",connection.window)
    try await press("‹ Synthetic")

    try await begin();try capture("11-before-close",connection.window.attachedSheet!)
    // AppKit disables performClose while this sheet is attached (the sheet has no close button).
    // Exercise the actual parent NSWindow closing notification, not ConnectionsModel.close(), as on teardown.
    connection.window.close()
    try await waitFor{!connection.window.isVisible && connection.window.attachedSheet==nil && !model.authenticating}
    // Server acknowledgment/refresh must settle before reopening; this is not a model assignment.
    try await waitFor{model.notice=="인증을 취소했어요." && !model.loading}
    connection.show(profile:"alpha")
    try await waitFor{connection.window.isVisible && connection.window.attachedSheet==nil && !model.loading && button(connect) != nil}
    try check(!texts(connection.window).contains(old) && !texts(connection.window).contains(new),"GD-T17 reopening closed window refreshes a disconnected account")
    try capture("12-reopened",connection.window)
    if button("‹ Synthetic") != nil {try await press("‹ Synthetic")}
    try await begin()
    try await nativePress("인증 취소",in:connection.window.attachedSheet!)
    try await waitFor{connection.window.attachedSheet==nil && texts(connection.window).contains("인증을 취소했어요.")}
    try capture("13-cancel-confirmed",connection.window)
    print("GD-T17 ACTUAL APPKIT ROUNDTRIP PASS")
}
