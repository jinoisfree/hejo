#if HEJO_PERF_TESTING && !HEJO_RECONNECT_BASELINE
import AppKit

/// HR-02/03: observe public notifications, cursor and actual View after each boundary.
@MainActor func hejoReconnectBoundaries() async throws {
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:directory)}
    let jsonBoolean = (try JSONSerialization.jsonObject(with:Data("[true]".utf8)) as! [Any])[0]
    for (index, invalid) in ([nil, "invalid", 1.5, jsonBoolean] as [Any?]).enumerated() {
        let client=GateClient(store:try LocalStore(directory:directory.appendingPathComponent("invalid-\(index)")),credentials:MemoryCredentials())
        let controller=try testConversation(client:client);controller.stop()
        defer {controller.stop();client.stop()}
        try await client.receive(hrWelcome(999));client.stop()
        var welcome=hrWelcome(999);welcome["head_seq"]=invalid
        try await client.receive(welcome)
        try check(!client.hasPendingHistory,"HR-02 absent/non-integer welcome head never defers, including JSON boolean")
        var done=hrDone(0);done["head_seq"]=invalid
        try await client.receive(done)
        try check(!client.hasPendingHistory,"HR-02 non-integer sync head is ignored")
        var count=0,applied = -1
        controller.onChange={count+=1;applied=controller.model.applied}
        try await client.receive(hrPost(1,80000+index,0,1,"정수 head 없음"))
        try check(count==1 && applied==1,"HR-02 unknown head keeps first record synchronous")
    }
    for variant in 0..<4 {
        let rig=try HRRig(hrStore(directory.appendingPathComponent("case-\(variant)")))
        defer {rig.dispose()}
        let c=rig.controller,client=rig.client
        try await client.receive(hrWelcome(810));rig.count=0
        try await client.receive(hrPost(801,40001,0,1,"기록 경계"))
        try check(rig.count==0 && c.model.applied==801 && client.hasPendingHistory,"HR-02 record applied without rendering")
        if variant==0 {
            c.pollUpdates();try check(rig.count==1 && rig.shownApplied==801,"HR-02 stalled receive flushes on one tick")
            c.pollUpdates();try check(rig.count==1,"HR-02 clean tick emits nothing")
            try await client.receive(hrPost(802,40002,0,1,"사용자 동작 전"));try check(rig.count==1,"HR-02 new history deferred")
            var actionApplied = -1
            rig.view.onUnread={_ in actionApplied=c.model.applied}
            rig.view.chooseEmployee("fixture-1")
            try check(c.model.selected?.employee=="fixture-1" && actionApplied==802,"HR-02 actual room refresh sees applied history immediately")
            rig.view.editor.editor.insertText("x",replacementRange:NSRange(location:0,length:0))
            try check(c.draft.text.contains("x"),"HR-02 text action works while history remains")
            c.notice="즉시 알림"
            let before=rig.count;c.pollUpdates();try check(rig.count==before,"HR-02 immediate notification clears pending flush")
            c.performUpdates {c.performUpdates {c.notice="inner"};c.notice="outer"}
            try check(rig.count==before+1,"HR-02 explicit nested transaction stays synchronous")
        } else if variant==1 {
            client.stop();c.notifyChange()
            try check(!client.hasPendingHistory && rig.shownApplied==801,"HR-02 disconnect clears head and flushes presentation")
            for absent in [true,false] {
                try await client.receive(hrWelcome(999))
                client.stop()
                var welcome=hrWelcome(999)
                welcome["head_seq"]=absent ? nil : "invalid"
                try await client.receive(welcome)
                let before=rig.count,seq=client.store.settings.applied+1
                try await client.receive(hrPost(seq,40000+seq,0,1,"head 없음"))
                try check(!client.hasPendingHistory && rig.count==before+1 && rig.shownApplied==seq,"HR-02 absent/invalid head has immediate delivery after prior connection")
                c.pollUpdates();try check(rig.count==before+1,"HR-02 absent head leaves no pending change")
            }
            try await client.receive(hrWelcome(client.store.settings.applied))
            let before=rig.count,seq=client.store.settings.applied+1
            try await client.receive(hrPost(seq,50000+seq,0,1,"평상시"))
            try check(rig.count==before+1 && rig.shownApplied==seq,"HR-02 no backlog delivers synchronously")
        } else if variant==2 {
            try await client.receive(hrWelcome(802));rig.count=0
            try await client.receive(hrPost(802,40002,0,1,"head 도달"))
            try check(rig.count==1 && rig.shownApplied==802 && !client.hasPendingHistory,"HR-02 reaching head flushes before sync_done")
            c.pollUpdates();try check(rig.count==1,"HR-02 head flush clears pending flag")
            try await client.receive(hrDone(802,head:804));rig.count=0
            try await client.receive(hrPost(803,40003,0,1,"sync head 갱신"))
            try check(rig.count==0 && client.hasPendingHistory,"HR-02 sync_done can announce a newer head")
            try await client.receive(hrPost(804,40004,0,1,"갱신 head 도달"))
            try check(rig.count==1 && !client.hasPendingHistory,"HR-02 new sync head flushes on arrival")
        } else {
            try await client.receive(["v":1,"type":"error","code":"too_large"])
            try check(client.status == .tooLarge && rig.shownApplied==801 && c.transferFailure != nil,"HR-02 error is visible during pending history")
        }
    }
    for count in [1,50] {
        let rig=try HRRig(hrStore(directory.appendingPathComponent("pause-\(count)")))
        defer {rig.dispose()}
        try await rig.client.receive(hrWelcome(800+count))
        rig.controller.setPaused(true);rig.count=0
        for i in 1...count {try await rig.client.receive(hrPost(800+i,60000+i,0,1,"정지 중 \(i)"))}
        try check(rig.count==0 && rig.controller.model.applied==800,"HR-03 pause keeps presentation unchanged")
        rig.controller.setPaused(false)
        try check(rig.count==1 && rig.shownApplied==800+count,"HR-03 unpause delivers one synchronous transaction")
        let expected=(1...count).map{hrID(60000+$0)}
        try check(Array(rig.controller.model.timeline(.init(employee:"fixture-0",thread:hrID(1))).suffix(count)).map(\.id)==expected,"HR-03 unpause retains all records in order")
    }
    print("AT-HR-02_SYNTHETIC_AND_03_PASS")
}

/// Socket cases make sync requests and transport/storage failures cross the real loop.
@MainActor func hejoReconnectBoundarySocket(_ args:[String]) async throws {
    let directory=URL(fileURLWithPath:ProcessInfo.processInfo.environment["HERMES_HOME"]!).appendingPathComponent("boundary-socket")
    for mode in ["pages","gap","protocol","storage"] {
        let store=try hrStore(directory.appendingPathComponent(mode))
        let address=args[4]+"/" // endpoint normalizes trailing slash to /v1/ws
        try store.select(address:address,device:mode)
        let rig=try HRRig(store);defer {rig.dispose()}
        let c=rig.controller,client=rig.client
        var steps=[Int](), statuses=[ConnectionStatus]()
        client.onStatus={status in statuses.append(status);c.notifyChange()}
        let forward=client.onFrame
        client.onFrame={frame in
            forward?(frame)
            if frame["type"] as? String=="sync_done" {
                if (frame["through"] as? Int ?? 0) > 800 {steps.append(rig.shownApplied)}
            }
        }
        try await client.adopt(address:address,device:mode,token:"fixture-credential")
        if ["pages","gap"].contains(mode) {
            try await waitFor {client.replayComplete && c.model.applied==804}
            try check(steps==[802,804],"HR-02 socket pages flush each sync_done and fill gap")
            try check(!client.hasPendingHistory && rig.shownApplied==804,"HR-02 socket final head flushed")
        } else {
            // Fake server waits for this frame after sending exactly one deferred record.
            try await waitFor {c.model.applied==801}
            if mode=="storage" {
                try FileManager.default.removeItem(at:store.cacheURL)
                try FileManager.default.createDirectory(at:store.cacheURL,withIntermediateDirectories:false)
            }
            try await client.send(["v":1,"type":"fixture_continue"])
            if mode=="storage" {try await waitFor {client.status == .storageError}}
            else {try await waitFor {statuses.contains {if case .disconnected=$0{return true};return false}}}
            try check(c.model.applied==801 && store.settings.applied==801 && rig.shownApplied==801,"HR-02 failed record preserves last success and displays it")
            try check(!client.hasPendingHistory,"HR-02 failed connection drops stale head")
        }
        print("AT-HR-02_SOCKET_\(mode.uppercased())_PASS")
    }
}

#endif
