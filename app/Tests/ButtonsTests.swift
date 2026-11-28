import AppKit

@MainActor func buttonsTests(_ args:[String]) async throws {
    func waitAt(_ seconds:Double=8,line:Int = #line,_ condition:()->Bool) async throws {
        do {try await waitFor(seconds,condition)} catch {throw TestFailure.assertion("button fixture timeout at line "+String(line))}
    }
    let address=args[3],store=try LocalStore(directory:URL(fileURLWithPath:args[2]),historyMode:true)
    let client=GateClient(store:store,credentials:MemoryCredentials()),controller=try testConversation(client:client)
    defer {controller.stop();client.stop()}
    func observe(_ behavior:String?=nil) async throws -> [String:Any] {
        var req=URLRequest(url:URL(string:"http://\(address)/fixture")!);req.httpMethod="POST"
        req.httpBody=try JSONSerialization.data(withJSONObject:behavior.map{["behavior":$0]} ?? [:])
        let (data,_)=try await URLSession.shared.data(for:req)
        return try JSONSerialization.jsonObject(with:data) as! [String:Any]
    }
    let seed=try await observe(),key=ConversationKey(employee:"fixture",thread:seed["thread"] as! String)
    let posts=seed["posts"] as! [[String:Any]]
    let rows=try JSONDecoder().decode([QuestionRow].self,from:JSONSerialization.data(withJSONObject:posts))
    func descendants(_ root:NSView)->[NSView] {[root]+root.subviews.flatMap(descendants)}
    let row=rows[0]
    try client.pair(address:address,code:"fixture_rd12",device:"Button fixture")
    try await waitAt {controller.canSend && controller.model.history.context != nil && !controller.historyLoading.busy}
    func answer()->QuestionAnswer? {controller.currentAnswer(row.messageID,history:nil,revision:0)}
    func click(_ i:Int,text:String?=nil) async {
        await controller.click(row.buttons[i],messageID:row.messageID,key:key,buttons:row.buttons,text:text)
    }
    func retract(_ id:String) async {await controller.requestReply("retract",question:row.messageID,key:key,answerID:id)}
    func commands() async throws -> [[String:Any]] {try await observe()["commands"] as! [[String:Any]]}
    func rendered(_ input:QuestionRow, circles:Bool=false)->QuestionControls {
        var question=input
        question.answer=controller.currentAnswer(input.messageID,history:nil,revision:0)
        return QuestionControls(question,key:key,controller:controller,circles:circles,onEdit:{_ in},choose:{button,text in
            Task {await controller.click(button,messageID:question.messageID,key:key,buttons:question.buttons,text:text)}
        })
    }
    func resultButton(_ question:QuestionRow) throws ->HejoButton {
        try homeRequire(rendered(question).line.arrangedSubviews.compactMap{$0 as? HejoButton}.first{$0.result},"missing result")
    }
    let window=NSWindow(contentRect:NSRect(x:0,y:0,width:310,height:60),styleMask:.borderless,backing:.buffered,defer:false)
    let canvas=NSView(frame:window.frame);window.contentView=canvas
    defer {window.orderOut(nil)}
    let snap=URL(fileURLWithPath:ProcessInfo.processInfo.environment["HEJO_BUTTON_SNAP"] ?? "../.build/buttons/snap")
    try FileManager.default.createDirectory(at:snap,withIntermediateDirectories:true)
    for theme in [NSAppearance.Name.aqua,.darkAqua] {
        let appearance=NSAppearance(named:theme)!;window.appearance=appearance;canvas.appearance=appearance
        window.isOpaque=true;canvas.wantsLayer=true
        window.backgroundColor=NSColor(white:theme == .darkAqua ? 0.14:0.97,alpha:1)
        canvas.layer?.backgroundColor=window.backgroundColor.cgColor
        for circle in [false,true] {
            let controls=QuestionControls(row,key:key,controller:controller,circles:circle,onEdit:{_ in},choose:{_,_ in})
            canvas.addSubview(controls);controls.frame=CGRect(origin:CGPoint(x:8,y:8),size:controls.fittingSize);controls.layoutSubtreeIfNeeded()
            let buttons=controls.line.arrangedSubviews.compactMap{$0 as? HejoButton}
            try check(buttons.count==4 && buttons[0].tone == .blue && buttons[1].tone == .neutral,"AT-HB-31 initial")
            func capture(_ name:String)throws->Data {
                let rep=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!
                appearance.performAsCurrentDrawingAppearance {canvas.cacheDisplay(in:canvas.bounds,to:rep)}
                // Inspect the two-point ring outside the actual controls. Diffuse shadows
                // are allowed, a high-opacity blue or green stroke is not.
                let frames=buttons.map{$0.convert($0.bounds,to:canvas)}
                let scale=CGFloat(rep.pixelsWide)/canvas.bounds.width
                var borderPixels=0,iconPixels=0
                for y in 0..<rep.pixelsHigh {for x in 0..<rep.pixelsWide {
                    let pt=CGPoint(x:(CGFloat(x)+0.5)/scale,y:canvas.bounds.height-(CGFloat(y)+0.5)/scale)
                    let first=frames[0]
                    if name=="reject",first.contains(pt),let c=rep.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB),
                       c.blueComponent-c.redComponent>0.3 && c.blueComponent-c.greenComponent>0.14 {
                        if !first.insetBy(dx:1.5,dy:1.5).contains(pt) {borderPixels+=1}
                        if abs(pt.y-first.midY)<6 && pt.x>first.minX+3 && pt.x<first.minX+(circle ? first.width-3:23) {iconPixels+=1}
                    }
                    if frames.contains(where:{$0.insetBy(dx:-2,dy:-2).contains(pt)}) && !frames.contains(where:{$0.contains(pt)}),
                       let color=rep.colorAt(x:x,y:y)?.usingColorSpace(.deviceRGB),color.alphaComponent>=0.5 {
                        try check(max(color.blueComponent,color.greenComponent)-color.redComponent<0.3,"AT-HB-38 exterior ring")
                    }
                }}
                if name=="reject" {try check(borderPixels>=4 && iconPixels>=2,"AT-HB-38 primary blue border and icon pixels \(borderPixels), \(iconPixels)")}
                let png=rep.representation(using:.png,properties:[:])!
                try png.write(to:snap.appendingPathComponent("\(theme.rawValue)-\(circle ? "circle":"pill")-\(name).png"));return png
            }
            let idle=try capture("idle")
            let event=NSEvent.enterExitEvent(with:.mouseEntered,location:.zero,modifierFlags:[],timestamp:0,windowNumber:window.windowNumber,context:nil,eventNumber:1,trackingNumber:0,userData:nil)!
            buttons[1].mouseEntered(with:event)
            try check(buttons.map(\.tone)==[.outline,.blue,.neutral,.neutral] && (try capture("reject")) != idle,"AT-HB-38 blue moves")
            buttons[1].mouseExited(with:event);try check(try capture("leave-reject")==idle,"AT-HB-38 pixels restored")
            buttons[0].mouseEntered(with:event);try check(buttons[0].tone == .green && (try capture("approve")) != idle,"AT-HB-38 approval")
            buttons[0].mouseExited(with:event);try check(try capture("leave-approve")==idle,"AT-HB-38 primary restored")
            controls.removeFromSuperview()
            var memo=row;memo.buttons[0].label="메모";memo.buttons[0].accent="blue"
            let memoRow=QuestionControls(memo,key:key,controller:controller,circles:circle,onEdit:{_ in},choose:{_,_ in})
            let first=memoRow.line.arrangedSubviews.first as! HejoButton
            first.mouseEntered(with:event);try check(first.tone == .blue,"AT-HB-38 memo remains blue")
        }
    }
    for index in [1,5,0] {
        let q=rows[index], controls=rendered(q)
        let buttons=controls.line.arrangedSubviews.compactMap{$0 as? HejoButton}
        try check(buttons.map(\.tone)==[.blue,.neutral,.neutral,.neutral],"AT-HB-31 issued, legacy and default")
        if index==1 {try check(q.buttons.allSatisfy{$0.primary==nil && $0.icon==nil},"AT-HB-31 legacy")}
        if index==5 {try check(q.buttons[0].id=="std:approve","AT-HB-31 default")}
        let before=try await commands().count
        if index==0 {_=try await observe("long_window")}
        buttons[0].performClick(nil)
        try await waitAt{controller.currentAnswer(q.messageID,history:nil,revision:0)?.result=="승인함"}
        let frames=try await commands()
        try check(frames.count==before+1 && frames.last?["button_id"] as? String==q.buttons[0].id && frames.last?["msg_id"] as? String==q.messageID,"AT-HB-31 actual click")
    }
    let accepted=try resultButton(row)
    try check(accepted.title=="승인함" && accepted.tone == .green && (accepted.remaining?() ?? 0)>0.8,"AT-HB-33 green approval ignores server clock skew")
    controller.clock={Date().addingTimeInterval(4)}
    try check((0.30...0.55).contains(accepted.remaining?() ?? 0),"AT-HB-33 ack duration of eight seconds")
    for (theme,name) in [(NSAppearance.Name.darkAqua,"dark"),(.aqua,"light")] {
        window.appearance=NSAppearance(named:theme);canvas.appearance=window.appearance
        let background=NSColor(white:name=="dark" ? 0.14:0.97,alpha:1)
        canvas.layer?.backgroundColor=background.cgColor;window.backgroundColor=background
        let result=rendered(row);canvas.addSubview(result)
        result.frame=CGRect(origin:CGPoint(x:8,y:8),size:result.fittingSize);result.layoutSubtreeIfNeeded()
        let b=result.line.arrangedSubviews.first as! HejoButton
        let rep=b.bitmapImageRepForCachingDisplay(in:b.bounds)!
        b.cacheDisplay(in:b.bounds,to:rep)
        func green(_ x:CGFloat)->CGFloat {
            let c=rep.colorAt(x:Int(CGFloat(rep.pixelsWide)*x),y:Int(CGFloat(rep.pixelsHigh)*0.20))!.usingColorSpace(.deviceRGB)!
            return c.greenComponent-c.redComponent
        }
        try check(green(0.18)>green(0.81)+0.1,"AT-HB-33 half pill extends across its left side")
        let shot=canvas.bitmapImageRepForCachingDisplay(in:canvas.bounds)!;canvas.cacheDisplay(in:canvas.bounds,to:shot)
        try shot.representation(using:.png,properties:[:])!.write(to:snap.appendingPathComponent("result-half-"+name+".png"))
        result.removeFromSuperview()
    }
    controller.clock=Date.init
    let a=answer()!.answerID
    for failure in ["retract_expired","journal_write_failed","invalid_frame"] {
        _=try await observe(failure);await retract(a);try await waitAt{controller.replyRequests.isEmpty}
        try check(answer()?.answerID==a && controller.notice=="지금은 취소할 수 없어요","AT-HB-33b failed retract")
    }
    accepted.performClick(nil);try await waitAt{controller.replyRequests.isEmpty && answer()==nil}
    let restored=rendered(row).line.arrangedSubviews.compactMap{$0 as? HejoButton}
    try check(restored.map(\.tone)==[.blue,.neutral,.neutral,.neutral] && restored.map(\.title)==row.buttons.map(\.label),"AT-HB-33 controls restored")
    let memo=rows[3]
    await controller.click(memo.buttons[0],messageID:memo.messageID,key:key,buttons:memo.buttons)
    try await waitAt{controller.currentAnswer(memo.messageID,history:nil,revision:0)?.result=="메모"}
    let memoResult=try resultButton(memo)
    try check(memoResult.tone == .blue && memoResult.title=="메모","AT-HB-33 blue memo")
    memoResult.performClick(nil);try await waitAt{controller.currentAnswer(memo.messageID,history:nil,revision:0)==nil}
    try check(controller.notice=="취소했어요 · 직원이 이미 처리했다면 되돌려지지 않아요","AT-HB-33")
    await click(2,text:"내용");try await waitAt{answer()?.role=="comment"}
    let observed=try await commands()
    try check(observed.last?["text"] as? String=="내용" && observed.last?["button_id"] as? String==row.buttons[2].id,"AT-HB-32 inline opinion")
    for scenario in ["drop_before","drop_after","replace"] {
        if answer()==nil {await click(0);try await waitAt{answer() != nil}}
        let old=answer()!.answerID, count=try await commands().count
        _=try await observe(scenario)
        let undo=try resultButton(row);undo.performClick(nil)
        try await waitAt{!controller.replyRequests.isEmpty}
        try check(descendants(rendered(row)).contains{($0 as? NSTextField)?.stringValue=="확인 중"},"AT-HB-33b pending while ack missing")
        try await waitAt(15){controller.replyRequests.isEmpty}
        let actual=try await commands()
        try check(actual.count==count+1 && actual.last?["answer_id"] as? String==old,"AT-HB-33b no retry")
        if scenario=="drop_before" {
            let pending=try resultButton(row)
            let left=controller.undoEnd(answer()!).timeIntervalSince(controller.clock())
            try check((1.6...2.2).contains(left) && (0.30...0.45).contains(pending.remaining?() ?? 0),"AT-HB-33b remaining pie after reconnect \(left)")
            try check(answer()?.answerID==old && controller.notice=="취소되지 않았어요","retract lost before processing")}
        else {try check(answer()?.answerID != old && controller.notice=="취소했어요","retract processed before disconnect")}
        if scenario=="replace" {
            let left=controller.undoEnd(answer()!).timeIntervalSince(controller.clock())
            try check(answer()?.result=="거절함" && (2.6...3.2).contains(left),"replacement B and its three remaining seconds")
        }
    }
    if let id=answer()?.answerID {await retract(id);try await waitAt{answer()==nil}}
    _=try await observe("drop_after");await click(0);try await waitAt(15){answer()?.result=="승인함" && controller.replyRequests.isEmpty}
    let final=try await observe();try check(final["sends"] as? Int==0,"button actions never send ordinary text")
    if let id=answer()?.answerID {await retract(id);try await waitAt{answer()==nil}}
    _=try await observe("no_ack")
    let legacy=rows[1]
    await controller.click(legacy.buttons[0],messageID:legacy.messageID,key:key,buttons:legacy.buttons)
    try check(!controller.replyRequests.isEmpty,"legacy click awaiting ack")
    controller.clock={Date().addingTimeInterval(11)};controller.pollUpdates()
    try check(controller.replyRequests.isEmpty,"legacy gate releases pending at ten seconds")
    controller.clock=Date.init
    let oldCount=try await commands().count
    await controller.click(legacy.buttons[0],messageID:legacy.messageID,key:key,buttons:legacy.buttons)
    try await waitAt{controller.replyRequests.isEmpty}
    let repeated=try await commands()
    try check(repeated.count==oldCount+1,"legacy button accepts next press")
    let view=ConversationView(controller:controller)
    let chat=PetPanel(contentRect:NSRect(x:0,y:0,width:1000,height:700),styleMask:.titled,backing:.buffered,defer:false)
    chat.chatExpanded=true;chat.onCancelComposerBranch={view.cancelComposerBranch()}
    chat.isOpaque=true
    chat.contentView=view;chat.orderFrontRegardless();defer{chat.orderOut(nil)}
    view.chooseThread(key)
    try await waitAt{controller.model.messages[row.messageID] != nil}
    func hint(_ question:QuestionRow)->HejoButton? {
        descendants(view).compactMap{$0 as? HejoButton}.first{!$0.isHidden && $0.title=="↳ "+String((question.text.components(separatedBy:.newlines).first ?? "").prefix(30))+" 갈래에 쓰기  ✕"}
    }
    controller.selectBranch(row,key:key);view.refresh()
    try homeRequire(hint(row),"branch close control").performClick(nil)
    try check(controller.branchTarget==nil,"branch close button")
    controller.selectBranch(row,key:key);view.refresh();chat.makeFirstResponder(view.editor.editor)
    let escape=NSEvent.keyEvent(with:.keyDown,location:.zero,modifierFlags:[],timestamp:0,windowNumber:chat.windowNumber,context:nil,characters:"\u{1b}",charactersIgnoringModifiers:"\u{1b}",isARepeat:false,keyCode:53)!
    chat.sendEvent(escape);try check(controller.branchTarget==nil && chat.isVisible,"composer escape precedes collapse")
    try check(controller.model.messages[rows[4].messageID]?.checklist?.items==["자료 검토"],"AT-HB-32 checklist question from history")
    for question in [row,rows[2],rows[3],rows[4]] {
        controller.selectBranch(question,key:key)
        view.refresh()
        try check(hint(question) != nil,"AT-HB-32 branch composer prompt")
        if question.messageID != row.messageID {
            let labels=rendered(question).line.arrangedSubviews.compactMap{($0 as? HejoButton)?.title}
            try check(!labels.contains("의견") && labels==question.buttons.map(\.label),"AT-HB-32 no inserted opinion")
        }
        let text=question.messageID==row.messageID ? "내용2":"내용4"
        controller.setText(text,for:key)
        await controller.sendCurrent(for:key)
        try await waitAt{controller.replyRequests.isEmpty}
        let sent=try await commands().last
        try check(sent?["button_id"] as? String=="std:comment" && sent?["msg_id"] as? String==question.messageID && sent?["text"] as? String==text,"AT-HB-32 composer branch")
    }
    controller.clearBranch()
    controller.setText("내용3",for:key)
    await controller.sendCurrent(for:key)
    let plain=try await observe()
    try check(plain["sends"] as? Int==1,"AT-HB-32 branch cleared")
    var unknown=rows[4];unknown.answer=QuestionAnswer(answerID:"fake-answer",label:"확인",role:"confirm",result:"확인함",text:nil,at:nil,undoUntil:nil,delivery:"unknown")
    let before=try await commands().count
    for delivery in [nil,"sent","unknown"] as [String?] {
        unknown.answer?.delivery=delivery
        let controls=QuestionControls(unknown,key:key,controller:controller,circles:false,onEdit:{_ in},choose:{_,_ in})
        canvas.addSubview(controls);controls.frame=CGRect(origin:.zero,size:controls.fittingSize)
        let resend=controls.arrangedSubviews.compactMap{$0 as? HejoButton}.first{$0.title=="다시 보내기"}
        try check((resend != nil)==(delivery=="unknown"),"AT-HB-33c unknown only")
        if let resend {
            window.orderFrontRegardless();resend.performClick(nil)
            try await waitAt{window.attachedSheet != nil}
            let actual=try await commands().count
            try check(actual==before,"AT-HB-33c confirmation before transmission")
            window.endSheet(window.attachedSheet!,returnCode:.alertFirstButtonReturn)
            await pause(0.15)
            let cancelled=try await commands().count;try check(cancelled==before,"AT-HB-33c cancel")
            _=try await observe("button_expired")
            resend.performClick(nil);try await waitAt{window.attachedSheet != nil}
            window.endSheet(window.attachedSheet!,returnCode:.alertSecondButtonReturn)
            await pause(0.2)
            let last=try await commands().last
            try check(last?["type"] as? String=="redeliver" && last?["answer_id"] as? String=="fake-answer","AT-HB-33c confirmed")
        }
        controls.removeFromSuperview()
    }
    // Read the expanded thread using the same sidebar projection and controls as the drawer.
    _=try await observe("reset");controller.historyLoading.liveChanged()
    view.drawerShownWidth=290;view.setDrawerState(open:true,chatExpanded:true)
    func button(_ title:String)->HejoButton? {descendants(view.todoDrawer).compactMap{$0 as? HejoButton}.first{$0.title==title}}
    try await waitAt{button("질문 2개 더") != nil}
    _=try await observe("cursor_expired")
    button("질문 2개 더")?.performClick(nil)
    try await waitAt{descendants(view.todoDrawer).compactMap{$0 as? QuestionControls}.count>=2 && button("질문 2개 더")==nil}
    await pause(0.2)
    let queries=try await observe()["queries"] as! [String]
    try check(queries.filter{$0=="asks"}.count==2,"AT-HB-35 one cursor retry")
    button("모아서 보내기")?.performClick(nil)
    func controls()->[QuestionControls] {descendants(view.todoDrawer).compactMap{$0 as? QuestionControls}}
    func option(_ i:Int,_ j:Int) throws -> FileChip {
        let rows=controls();guard rows.indices.contains(i) else{throw TestFailure.assertion("drawer row")}
        let buttons=rows[i].line.arrangedSubviews.compactMap{$0 as? FileChip}
        guard buttons.indices.contains(j) else{throw TestFailure.assertion("drawer button")}
        return buttons[j]
    }
    try await waitAt{controls().count==5}
    try check(try option(0,0).intrinsicContentSize==NSSize(width:22,height:22),"AT-HB-35 circle size")
    view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded()
    let ends=try (0..<5).map {index -> CGFloat in let last=try option(index,rows[index].buttons.count-1);return last.convert(last.bounds,to:view.todoDrawer).maxX}
    try check(ends.allSatisfy{abs($0-ends[0])<=1 && $0>260 && $0<=290},"AT-HB-35 five rows align on the right")
    for (theme,name) in [(NSAppearance.Name.darkAqua,"dark"),(.aqua,"light")] {
        chat.backgroundColor=NSColor(white:name=="dark" ? 0.14:0.97,alpha:1);chat.appearance=NSAppearance(named:theme);view.layoutSubtreeIfNeeded();chat.displayIfNeeded()
        let rep=view.bitmapImageRepForCachingDisplay(in:view.bounds)!
        view.cacheDisplay(in:view.bounds,to:rep)
        let image=NSImage(size:view.bounds.size)
        image.lockFocus()
        NSColor(white:name=="dark" ? 0.14:0.97,alpha:1).setFill();view.bounds.fill()
        let capture=NSImage(size:view.bounds.size);capture.addRepresentation(rep)
        capture.draw(in:view.bounds,from:.zero,operation:.sourceOver,fraction:1)
        image.unlockFocus()
        let opaque=NSBitmapImageRep(data:image.tiffRepresentation!)!
        try opaque.representation(using:.png,properties:[:])!.write(to:snap.appendingPathComponent("workspace-"+name+".png"))
    }
    let sample=try HistoryHTTP.message(posts[0].merging(["revision":1,"branch":rows[4].messageID]){$1})
    let parent=NativeThreadCard.Post(id:rows[4].messageID,mine:false,text:NSAttributedString(string:"갈래 질문"),speaker:"직원",time:"",avatar:ProfileAvatar(),nameColor:.labelColor,openLink:{_ in})
    var child=parent;child.id=sample.id;child.mine=true;child.branch=sample.branch
    let content=NativeThreadCard.Content(id:"thread",top:[.post(parent)],replies:[.post(child)],rail:nil,actions:[.init(title:"복사",symbol:"doc.on.doc",label:"복사",identifier:"copy",invoke:{})],deleting:nil,
        style:.init(inset:8,fill:0,stroke:nil,lineWidth:0),bell:nil,onBell:{},clickCard:{},quiet:.labelColor,expanded:true)
    let cardView=NativeThreadCard(frame:.zero)
    let layout=NativeThreadCard.layout(content,width:400)
    cardView.frame=CGRect(x:0,y:0,width:420,height:layout.height);cardView.configure(layout);cardView.layoutSubtreeIfNeeded()
    let group=descendants(cardView).first{$0.accessibilityIdentifier()=="question-branch-"+parent.id}
    try check(group?.superview?.accessibilityIdentifier()=="question-"+parent.id && group?.subviews.contains{$0 is NSTextView}==true,"AT-HB-34 nested text")
    try check(layout.anchors[child.id]!.minX > layout.anchors[parent.id]!.minX,"AT-HB-34 indentation")
    let visibleText=descendants(cardView).compactMap{($0 as? NSTextView)?.string ?? ($0 as? NSTextField)?.stringValue ?? ($0 as? NSButton)?.title}
    try check(visibleText.allSatisfy{$0.range(of:#"(^|\s)\d+\s*(번|\.)"#,options:.regularExpression)==nil},"AT-HB-34 no question numbering")
    let foot=try homeRequire(descendants(cardView).compactMap{$0 as? NSButton}.first{$0.accessibilityIdentifier()=="copy"},"card foot")
    try check(foot.isKind(of:HejoButton.self) && foot.accessibilityLabel()=="복사","AT-HB-37 card footer")
    let checklist=ReplyChecklistView(.init(items:["항목"],selected:[],canSkip:true)){_ in}
    try check(descendants(checklist).compactMap{$0 as? NSButton}.allSatisfy{$0 is HejoButton},"AT-HB-37 checklist")
    let bubble=BubbleActionButton(title:"링크 열기")
    try check(bubble.accessibilityLabel()=="링크 열기","AT-HB-37 accessible action")
    let notice=NoticePill(RoomNotice(id:"news",title:"알림",questions:false,messages:[row.messageID]))
    var noticePressed=false;notice.invoke={noticePressed=true};notice.performClick(nil)
    try check(notice.isKind(of:HejoButton.self) && noticePressed,"AT-HB-37 notice opens")
    let folded=FoldedBubbleView(frame:CGRect(x:0,y:0,width:108,height:100))
    folded.actions=[.openChat,.remindLater];folded.layoutSubtreeIfNeeded()
    var chosen:BubbleReveal.Action?;folded.onAction={chosen=$0}
    let petButton=folded.buttons[1];petButton.performClick(nil)
    try check(chosen == .remindLater && petButton.isKind(of:HejoButton.self) && petButton.truncatesTitle && petButton.accessibilityLabel()==petButton.title,"AT-HB-37 pet action and full accessible name")
    let petRep=folded.bitmapImageRepForCachingDisplay(in:folded.bounds)!
    folded.cacheDisplay(in:folded.bounds,to:petRep)
    try petRep.representation(using:.png,properties:[:])!.write(to:snap.appendingPathComponent("pet-short-actions.png"))
    func rail(_ index:Int,_ color:NSColor) ->Bool {
        let lines=controls()
        guard lines.indices.contains(index),let bar=lines[index].superview?.subviews.first(where:{$0.frame.width==3}),
              let cg=bar.layer?.backgroundColor,let actual=NSColor(cgColor:cg)?.usingColorSpace(.sRGB),
              let expected=color.usingColorSpace(.sRGB) else{return false}
        return abs(actual.redComponent-expected.redComponent)+abs(actual.greenComponent-expected.greenComponent)+abs(actual.blueComponent-expected.blueComponent)<0.08
    }
    try check(rail(0,.systemGray) && button("▸ 답한 질문 1개") != nil,"AT-HB-35 waiting rail, folded answers")
    let island=IslandView(frame:NSRect(x:0,y:0,width:110,height:30))
    island.reduceMotion={true};island.layoutSubtreeIfNeeded()
    let islandRep=island.bitmapImageRepForCachingDisplay(in:island.bounds)!
    island.cacheDisplay(in:island.bounds,to:islandRep)
    let center=islandRep.colorAt(x:islandRep.pixelsWide/2,y:islandRep.pixelsHigh/2)!.alphaComponent
    let corner=islandRep.colorAt(x:0,y:0)!.alphaComponent
    try check(center>corner,"AT-HB-37 island paints a rounded capsule")
    let beforeBatch=try await commands().count
    try option(0,0).performClick(nil);try option(1,1).performClick(nil);try option(2,0).performClick(nil)
    try option(1,1).performClick(nil);try option(1,2).performClick(nil)
    guard let field=descendants(controls()[1]).compactMap({$0 as? NSTextField}).first(where:{$0.isEditable}) else {throw TestFailure.assertion("drawer opinion editor")}
    field.stringValue="x"
    _=field.sendAction(field.action,to:field.target)
    view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded()
    try check(rail(0,.systemBlue),"AT-HB-35 selected rail")
    let held=try await commands().count
    try check(held==beforeBatch && view.todoDrawer.selectionSummary=="3개 정함 · 승인 1 · 확인 1 · 의견 1","AT-HB-36 hold, unselect and replace")
    button("한 번에 보내기")?.performClick(nil)
    try await waitAt{controller.replyRequests.isEmpty && button("취소") != nil}
    await pause(0.2)
    view.layoutSubtreeIfNeeded();view.todoDrawer.layoutSubtreeIfNeeded();try check(rail(0,.systemGreen),"AT-HB-35 answered rail")
    let sent=try await commands()
    try check(sent.suffix(3).compactMap{$0["msg_id"] as? String}==[rows[0],rows[2],rows[1]].map(\.messageID),"AT-HB-36 ordered clicks")
    button("취소")?.performClick(nil);await pause(0.3)
    let batch=try await commands()
    try check(batch.suffix(3).allSatisfy{$0["type"] as? String=="retract"} && Set(batch.suffix(3).compactMap{$0["answer_id"] as? String}).count==3,"AT-HB-36 acknowledged batch undo")
    let after=try await observe()["queries"] as! [String]
    try check(after.filter{$0=="asks"}.count==2,"AT-HB-35 no full reload for ack")
    try option(1,1).performClick(nil);try option(2,0).performClick(nil)
    _=try await observe("button_expired")
    button("한 번에 보내기")?.performClick(nil)
    try await waitAt{controller.replyRequests.isEmpty && controller.currentAnswer(rows[2].messageID,history:nil,revision:0)?.result=="확인함" && controller.currentAnswer(rows[1].messageID,history:nil,revision:0)==nil}
    try await waitAt{descendants(view.todoDrawer).contains{($0 as? NSTextField)?.stringValue=="이미 처리된 질문이에요."}}
    let failedRows=controls().enumerated().compactMap{index,line in
        descendants(line).contains{($0 as? NSTextField)?.stringValue=="이미 처리된 질문이에요."} ? index:nil
    }
    try check(failedRows==[1] && controller.currentAnswer(rows[1].messageID,history:nil,revision:0)==nil && controller.currentAnswer(rows[2].messageID,history:nil,revision:0)?.result=="확인함","AT-HB-36 error stays beside only failed row")
    _=try await observe("revision")
    try await waitAt{controller.model.history.notices.first?.revision==rows.count+2 && !controller.historyLoading.busy}
    await pause(0.2)
    let changed=try await observe()["queries"] as! [String]
    try check(changed.filter{$0=="asks"}.count==3,"AT-HB-35 revision reload")
    // The earlier batch can still be cancelled. Start a fresh batch on the last visible question.
    button("모아서 보내기")?.performClick(nil)
    try option(0,0).performClick(nil)
    try await waitAt{controller.currentAnswer(row.messageID,history:nil,revision:0) != nil}
    button("모아서 보내기")?.performClick(nil)
    _=try await observe("finish_all")
    try await waitAt{controller.model.history.notices.isEmpty && view.todoDrawer.cardViews.isEmpty}
    try check(descendants(view.todoDrawer).contains{($0 as? NSTextField)?.stringValue.hasPrefix("✓ ")==true},"AT-HB-35 finished green summary")
    try await waitAt{!descendants(view.todoDrawer).contains{($0 as? NSTextField)?.stringValue.hasPrefix("✓ ")==true}}
    let beforeOld=try await observe()["queries"] as! [String]
    _=try await observe("reset_old");controller.historyLoading.liveChanged()
    try await waitAt{controller.model.history.notices.first?.asksPreview==nil && !controller.historyLoading.busy}
    try await waitAt{button("모아서 보내기")?.state == .on && !view.todoDrawer.cardViews.isEmpty}
    let old=try await observe()["queries"] as! [String]
    try check(controls().isEmpty && old.filter{$0=="asks"}.count==beforeOld.filter{$0=="asks"}.count && view.todoDrawer.cardViews.count==1 && controller.drawerSnapshot.warning==nil,"AT-HB-35 old gate")
    print("AT-HB-31/32/33/33b/33c/34/35/36/37/38 PASS")
}
