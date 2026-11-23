import AppKit

/// AT-HT-01/04: reuse the performance workload and measure real editor actions,
/// counting synchronous full refreshes separately from explicitly injected receives.
@MainActor func hejoTypingSample(view: ConversationView, controller: ConversationController,
    run: Int, mode: String, sequence: Int, message: String, output: URL) async throws -> [String: Any] {
    let baseline = ProcessInfo.processInfo.environment["HEJO_TYPING_BASELINE"] == "1"
    var rows = [[String: Any]](), refreshes = 0
    view.onUnread = { _ in refreshes += 1 }
    defer { view.onUnread = nil }
    let editor = view.editor.editor
    let operations = ["insert", "insert-korean", "replace", "delete", "multiline", "clear"]
    var failures = [String]()
    for (index, action) in operations.enumerated() {
        let submitted = ProcessInfo.processInfo.systemUptime
        print("HEJO_PERF_STAGE time=\(submitted) run=\(run) frame=\(index) name=input-submit-\(action)"); fflush(stdout)
        await withCheckedContinuation { (continuation: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                if mode.hasSuffix("-receive") {
                    controller.receive(["v": 1, "type": "edit", "seq": sequence + index + 1,
                        "msg_id": message, "text": "수신 \(index)", "final": true])
                }
                continuation.resume()
            }
        }
        let began = ProcessInfo.processInfo.systemUptime
        print("HEJO_PERF_STAGE time=\(began) run=\(run) frame=\(index) name=input-start-\(action)"); fflush(stdout)
        let before = refreshes
        switch action {
        case "insert": editor.insertText("a", replacementRange: NSRange(location: NSNotFound, length: 0))
        case "insert-korean": editor.insertText("한", replacementRange: NSRange(location: NSNotFound, length: 0))
        case "replace": editor.insertText("b", replacementRange: NSRange(location: 0, length: 1))
        case "delete": editor.deleteBackward(nil)
        case "multiline": editor.insertText("line\nnext", replacementRange: NSRange(location: NSNotFound, length: 0))
        default: editor.insertText("", replacementRange: NSRange(location: 0, length: (editor.string as NSString).length))
        }
        let ended = ProcessInfo.processInfo.systemUptime
        let count = refreshes - before
        if count != (baseline && mode.contains("home") ? 1 : 0) { failures.append("\(action): full refresh count \(count)") }
        if controller.draft.text != MessageFormat.serialize(editor.attributedString(), baseSize: ChatMetrics.bodyFont) { failures.append("\(action): draft mismatch") }
        let row: [String: Any] = ["action": action, "queue_seconds": began - submitted,
            "handler_seconds": ended - began, "total_seconds": ended - submitted, "full_refreshes": count]
        rows.append(row)
        let data = try JSONSerialization.data(withJSONObject: ["run": run, "warm_up": run == 0, "events": rows, "failures": failures], options: [.prettyPrinted, .sortedKeys])
        try data.write(to: output.appendingPathComponent("typing-run-\(run).json"), options: .atomic)
        print("HEJO_PERF_STAGE time=\(ended) run=\(run) frame=\(index) name=input-complete-\(action)"); fflush(stdout)
    }
    try check(failures.isEmpty, "AT-HT-01: \(failures.joined(separator: "; "))")
    if !baseline && run > 0 {
        for key in ["queue_seconds", "handler_seconds", "total_seconds"] {
            let values = rows.map { $0[key] as! Double }.sorted()
            let median = (values[2] + values[3]) / 2
            try check(median <= 0.25 && values.last! <= 0.5, "AT-HT-04 \(key) budget")
        }
    }
    if !baseline && run == 0 { try hejoTypingEditorChecks(view:view,controller:controller) }
    return ["run": run, "warm_up": run == 0, "events": rows, "mode": mode]
}

/// AT-HT-02: real NSTextView marked text, selection, undo and recipient presentation.
/// This synthetic marked-text test does not stand in for an OS Korean input-method observation.
@MainActor func hejoTypingEditorChecks(view: ConversationView, controller: ConversationController) throws {
    let editor=view.editor.editor
    view.window?.makeFirstResponder(editor)
    func replace(_ text:String) {editor.insertText(text,replacementRange:NSRange(location:0,length:(editor.string as NSString).length))}
    replace("abc")
    editor.setSelectedRange(NSRange(location:1,length:1))
    editor.insertText("Z",replacementRange:editor.selectedRange())
    try check(editor.string=="aZc" && editor.selectedRange()==NSRange(location:2,length:0),"AT-HT-02 selection replacement and cursor")
    editor.breakUndoCoalescing();editor.undoManager?.removeAllActions()
    editor.insertText("q",replacementRange:NSRange(location:2,length:0));editor.breakUndoCoalescing()
    try check(editor.undoManager?.canUndo==true,"AT-HT-02 edit retains undo")
    editor.undoManager?.undo()
    try check(editor.string=="aZc","AT-HT-02 undo restores text")
    editor.undoManager?.redo()
    try check(editor.string=="aZqc","AT-HT-02 redo restores text")
    replace("")
    editor.setMarkedText("ㅎ",selectedRange:NSRange(location:1,length:0),replacementRange:NSRange(location:NSNotFound,length:0))
    try check(editor.hasMarkedText(),"AT-HT-02 initial marked text survives input updates")
    editor.setMarkedText("한",selectedRange:NSRange(location:1,length:0),replacementRange:NSRange(location:NSNotFound,length:0))
    try check(editor.hasMarkedText() && editor.string=="한","AT-HT-02 updated composition remains marked")
    editor.insertText("한",replacementRange:NSRange(location:NSNotFound,length:0))
    try check(!editor.hasMarkedText() && editor.string=="한","AT-HT-02 composition commits once")
    replace("")
    let formatted=MessageFormat.editor("<b>bold</b>",bodySize:ChatMetrics.bodyFont)
    editor.insertText(formatted,replacementRange:NSRange(location:0,length:0))
    try check(controller.draft.text.contains("<b>"),"AT-HT-02 attributed paste keeps formatting")
    replace("")
    if controller.model.isHome {
        view.createThread()
        replace("@직원 1 요청")
        let faces=try homeRequire(homeDescendants(view,ComposerFaces.self).first,"AT-HT-02 recipient faces")
        try check(faces.lit==1,"AT-HT-02 typed mention immediately lights recipient")
        controller.pickHome("fixture-0")
        try check(faces.lit==0 && faces.explicitlyPicked,"AT-HT-02 explicit recipient takes priority")
        controller.pickHome("fixture-0")
        try check(faces.lit==1 && !faces.explicitlyPicked,"AT-HT-02 clearing pick restores typed recipient")
        replace("")
    }
    print("AT-HT-02 EDITOR PASS");fflush(stdout)
}

/// AT-HT-02: use the existing local WebSocket fixture for the connected button matrix.
@MainActor func hejoTypingConnectedChecks(view:ConversationView,controller:ConversationController) throws {
    try check(controller.canSend,"AT-HT-02 connected fixture prerequisite")
    let editor=view.editor.editor
    let send=try homeRequire(homeDescendants(view,ComposerButton.self).first{$0.title=="보내기"},"AT-HT-02 send button")
    let attachment=controller.client.store.directory.appendingPathComponent("typing-fixture.txt")
    try Data("fixture".utf8).write(to:attachment)
    defer {try? FileManager.default.removeItem(at:attachment)}
    for attached in [false,true] {
        if attached {controller.addAttachments([attachment])}
        for text in ["", " ", "\n", "body"] {
            editor.insertText(text,replacementRange:NSRange(location:0,length:(editor.string as NSString).length))
            let expected=attached || text=="body"
            try check(send.isEnabled==expected,"AT-HT-02 connected button after edit, attachment=\(attached)")
            view.refresh()
            try check(send.isEnabled==expected,"AT-HT-02 connected button agrees after full refresh")
        }
        if attached {controller.removeAttachment(attachment)}
    }
    controller.setText("");view.refresh()
    print("AT-HT-02 CONNECTED BUTTONS PASS");fflush(stdout)
}


/// Exercises input boundaries with no transport and no production account.
@MainActor func hejoTypingBoundaryTests(manual: Bool = false) async throws {
    guard let home=ProcessInfo.processInfo.environment["HERMES_HOME"],
          FileManager.default.fileExists(atPath:home+"/hejo-perf-isolated") else {
        throw TestFailure.assertion("Typing checks require an isolated home")
    }
    let directory=URL(fileURLWithPath:home).appendingPathComponent(UUID().uuidString)
    defer {try? FileManager.default.removeItem(at:directory)}
    let client=GateClient(store:try LocalStore(directory:directory),credentials:MemoryCredentials())
    let controller=try testConversation(client:client)
    controller.stop()
    defer {controller.stop();client.stop()}
    controller.receive(["type":"welcome","employees":[["id":"alpha","name":"직원 A","aliases":[]]],"head_seq":0])
    for index in 1...12 {
        controller.receive(["v":1,"type":"message","seq":index,"msg_id":"fixture-message-\(index)","employee":"alpha","thread":"fixture-thread-\(index)","role":"employee","text":"입력 시험용 대화 \(index)","ts":"2026-11-15T00:00:00Z","files":[],"buttons":[]])
    }
    let view=ConversationView(controller:controller)
    view.frame=CGRect(x:0,y:0,width:840,height:760)
    view.reduceMotion={true}
    let window=NSWindow(contentRect:view.frame,styleMask:[.titled,.closable,.resizable],backing:.buffered,defer:false)
    window.isReleasedWhenClosed=false
    window.contentView=view
    view.chooseHome();view.createThread();view.layoutSubtreeIfNeeded()
    let editor=view.editor.editor
    let send=try homeRequire(homeDescendants(view,ComposerButton.self).first{$0.title=="보내기"},"boundary send button")
    func replace(_ text:String) {editor.insertText(text,replacementRange:NSRange(location:0,length:(editor.string as NSString).length))}
    replace("a");view.layoutSubtreeIfNeeded();view.needsLayout=false
    replace("b")
    try check(!view.needsLayout,"AT-HT-01 same-height input does not invalidate whole layout")
    let board=NSPasteboard.withUniqueName()
    defer {board.releaseGlobally()}
    board.setString("붙여넣기\n둘째 줄",forType:.string)
    replace("");editor.pastePlain(from:board)
    try check(editor.string=="붙여넣기\n둘째 줄" && controller.draft.text==editor.string,"AT-HT-02 real plain paste path updates draft")
    replace("@직원")
    var selection=0
    let range=editor.rangeForUserCompletion
    let matches=editor.completions(forPartialWordRange:range,indexOfSelectedItem:&selection) ?? []
    try check(matches.contains("@직원 A"),"AT-HT-02 mention completion candidates")
    editor.insertCompletion("@직원 A",forPartialWordRange:range,movement:NSReturnTextMovement,isFinal:true)
    try check(editor.string=="@직원 A" && controller.draft.text==editor.string,"AT-HT-02 completion updates draft")
    replace("작성 중")
    controller.receive(["type":"typing","employee":"alpha","thread":"fixture-thread-1","on":true,"ttl_seconds":10])
    try check(controller.model.typing[.init(employee:"alpha",thread:"fixture-thread-1")] != nil && editor.string=="작성 중","AT-HT-03 typing update keeps draft")
    controller.receive(["v":1,"type":"delete","seq":13,"scope":"thread","room":"alpha","thread":"fixture-thread-1","msg_id":"fixture-message-1"])
    try check(controller.model.timeline(.init(employee:"alpha",thread:"fixture-thread-1")).isEmpty && editor.string=="작성 중","AT-HT-03 deletion updates model without losing draft")
    let file=directory.appendingPathComponent("attachment.txt")
    try Data("fixture".utf8).write(to:file)
    for attached in [false,true] {
        if attached {controller.addAttachments([file])}
        for text in [""," ","\n","body"] {
            replace(text)
            try check(!send.isEnabled,"AT-HT-02 disconnected button after editing")
            view.refresh();try check(!send.isEnabled,"AT-HT-02 disconnected button after refresh")
        }
        if attached {controller.removeAttachment(file)}
    }
    controller.model.resetReplica()
    for text in [""," ","\n","body"] {
        replace(text);view.refresh()
        try check(controller.model.selected==nil && !send.isEnabled,"AT-HT-02 no selection stays disabled")
    }
    print("AT-HT-01/02/03 BOUNDARIES PASS");fflush(stdout)
    if manual {
        controller.receive(["type":"welcome","employees":[["id":"alpha","name":"직원 A","aliases":[]]],"head_seq":13])
        for index in 1...12 {
            controller.receive(["v":1,"type":"message","seq":13+index,"msg_id":"manual-message-\(index)","employee":"alpha","thread":"manual-thread-\(index)","role":"employee","text":"입력 시험용 대화 \(index)","ts":"2026-11-15T00:00:00Z","files":[],"buttons":[]])
        }
        controller.model.selectHome();view.createThread();replace("")
        window.title="hejo 한글 입력 시험 · 서버 연결 없음 · 닫으면 종료"
        NSApp.setActivationPolicy(.regular)
        window.center();window.makeKeyAndOrderFront(nil);NSApp.activate(ignoringOtherApps:true)
        window.makeFirstResponder(editor)
        print("MANUAL_TYPING_READY timeout=300");fflush(stdout)
        let deadline=Date().addingTimeInterval(300)
        while window.isVisible && Date()<deadline {await pause(0.2)}
        print("MANUAL_TYPING_CLOSED · user observation required; no automatic pass");fflush(stdout)
    }
    window.close()
}

/// Last check in the connected fixture; resetting the replica is deliberately terminal.
@MainActor func hejoTypingNoSelectionChecks(view:ConversationView,controller:ConversationController) throws {
    try check(controller.canSend,"AT-HT-02 no-selection connected prerequisite")
    let key=controller.composeKey!,editor=view.editor.editor
    let send=try homeRequire(homeDescendants(view,ComposerButton.self).first{$0.title=="보내기"},"no-selection send button")
    let file=controller.client.store.directory.appendingPathComponent("no-selection.txt")
    try Data("fixture".utf8).write(to:file)
    defer {try? FileManager.default.removeItem(at:file)}
    for attached in [false,true] {
        controller.model.select(key);controller.composeKey=key
        if attached {controller.addAttachments([file])}
        controller.model.resetReplica();controller.composeKey=key
        for text in [""," ","\n","body"] {
            controller.setText(text,for:key)
            view.textDidChange(Notification(name:NSText.didChangeNotification,object:editor))
            try check(!send.isEnabled,"AT-HT-02 connected with no target disables send")
            view.refresh();try check(!send.isEnabled,"AT-HT-02 target absence agrees after refresh")
            controller.composeKey=key
        }
        if attached {controller.removeAttachment(file)}
    }
    do {
        controller.model.select(key);controller.composeKey=key;controller.setText("disconnect draft");view.refresh()
        controller.client.stop();view.refresh()
        try check(!controller.canSend && !send.isEnabled && controller.draft.text=="disconnect draft","AT-HT-03 disconnect preserves draft and disables send")
    }
    print("AT-HT-02 NO TARGET / DISCONNECT PASS")
}
