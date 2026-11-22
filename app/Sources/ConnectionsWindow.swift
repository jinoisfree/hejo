import AppKit
import SwiftUI
import LocalAuthentication
import Combine

@MainActor final class ConnectionsModel:ObservableObject {
    @Published var document:AgentConnectionDocument?
    @Published var known:[String:AgentConnectionProfile]=[:]
    var people:()->[AgentConnectionProfile]={[]}
    private var refreshAgain=false
    @Published var selected:String?
    @Published var detail:String?
    @Published var searchText=""
    @Published var connectedOnly=false
    @Published var includingHidden=false
    @Published var confirming=false
    @Published var inputError=""
    @Published private var readFailures:[String:String]=[:]
    @Published var loading=false
    @Published var notice=""
    @Published var fields:[AgentActionReply.Field]=[]
    @Published var guide:AgentActionReply.Guide?
    @Published var values:[String:String]=[:]
    @Published var showingInput=false
    @Published var busy=false
    @Published var choices=Set<String>()
    @Published var defaultChoice=""
    @Published var next:ConnectionNext?
    @Published var code=""
    @Published var loginURL:URL?
    var send:([String:Any]) async throws->[String:Any]
    var confirm:() async ->Bool
    var confirmRestart:() async ->Bool = {false}
    var confirmUndo:(String) async ->Bool = {_ in false}
    var confirmDisconnect:(String) async ->Bool = {_ in false}
    var restoreFocus:()->Void={}
    private(set) var changeValues:[String:String]=[:]
    private var changeSession:UUID?
    private func clearChange(){changeValues=[:];changeSession=nil}
    func change(_ step:String,item:AgentConnectionItem?=nil) async {
        guard !busy,let target=item ?? self.item,target.settings?.contains(where:{$0.step==step})==true else{return}
        closeInput();detail=target.id;changeSession=UUID();changeValues=["change":step]
        await perform("app_connect",item:target,submitted:true)
    }
    var privacy:(Bool)->Void={_ in}
    var avatar:(String)->ProfileAvatar={_ in ProfileAvatar()}
    private var pendingAction:String?
    private var polling:Task<Void,Never>?
    init(send:@escaping([String:Any]) async throws->[String:Any],confirm:@escaping() async->Bool){self.send=send;self.confirm=confirm}
    var roster:[AgentConnectionProfile] {let current=people();return (current.isEmpty ? document?.agents ?? []:current).map{known[$0.profile] ?? $0}}
    var agent:AgentConnectionProfile? {selected.flatMap{known[$0]} ?? (selected==nil ? document?.agents.first:nil)}
    var item:AgentConnectionItem? {agent?.connections.first{$0.id==detail}}
    func listed(_ agent:AgentConnectionProfile)->[AgentConnectionItem] {agent.connections.filter{includingHidden || $0.hidden_by_default != true}}
    var readNotice:String {
        var parts:[String]=[]
        let key=selected ?? agent?.profile ?? "*"
        if let failure=readFailures[key] {
            if agent != nil {parts.append("마지막으로 확인한 내용이에요")}
            parts.append(failure)
        } else if let instruction=document?.instruction {parts.append(instruction)}
        if let unread=agent?.unread,!unread.isEmpty {
            let labels=["toolsets":"도구 목록","toolset_config":"도구 설정","env":"키","mcp":"MCP","oauth":"로그인 연결","catalog":"추가할 수 있는 MCP","team_status":"연결 상태","apps":"앱 목록","runtime":"대화 채널"]
            parts.append("일부 항목을 읽지 못했어요("+unread.map{labels[$0.part] ?? $0.part}.joined(separator:", ")+")")
        }
        return parts.joined(separator:". ")
    }
    static func readFailure(_ reason:String)->String {
        switch reason {
        case "admin_unavailable":return "서버의 관리 기능에 닿지 못했어요"
        case "not_connected","timeout":return "서버에 연결되지 않았어요"
        default:return "연결 상태를 읽지 못했어요. 서버 기록에 이유를 남겼어요"
        }
    }
    var visibleGroups:[(id:String,title:String,items:[AgentConnectionItem])] {
        let query=searchText.trimmingCharacters(in:.whitespacesAndNewlines)
        let items=(agent.map{listed($0)} ?? []).filter { item in
            (!connectedOnly || item.state == .connected) &&
            (query.isEmpty || [item.label,item.id,item.service,item.account ?? ""].contains{$0.localizedStandardContains(query)})
        }.sorted { lhs,rhs in
            let order=lhs.label.localizedStandardCompare(rhs.label)
            return order == .orderedSame ? lhs.id < rhs.id:order == .orderedAscending
        }
        return [("account","계정과 서비스"),("tool","도구"),("mac","Mac 권한 (서버)"),("channel","대화 채널")].compactMap { id,title in
            let rows=items.filter{$0.group.rawValue==id}
            return rows.isEmpty ? nil:(id:id,title:title,items:rows)
        }
    }
    func refresh() async {
        guard !loading else{refreshAgain=true;return};loading=true
        defer{loading=false;if refreshAgain{refreshAgain=false;Task{await self.refresh()}}}
        var request:[String:Any]=["v":1,"type":"connections"]
        if let profile=selected ?? people().first?.profile{request["profile"]=profile}
        let key=request["profile"] as? String ?? "*"
        do {
            let reply=try await send(request)
            if let failure=reply["reply"] as? [String:Any],failure["outcome"] as? String == "failed" {
                readFailures[key]=Self.readFailure(failure["reason"] as? String ?? "invalid_response");return
            }
            let data=try JSONSerialization.data(withJSONObject:reply["document"] ?? [:])
            let next=try AgentConnectionDocument.decode(data);document=next
            for agent in next.agents{known[agent.profile]=agent;readFailures[agent.profile]=nil}
            readFailures[key]=nil
            if selected==nil{selected=next.agents.first?.profile}
        } catch GateFailure.notConnected {readFailures[key]=Self.readFailure("not_connected")}
        catch {readFailures[key]=Self.readFailure("invalid_response")}
    }
    func closeInput(){clearChange();values=[:];fields=[];guide=nil;next=nil;choices=[];defaultChoice="";pendingAction=nil;inputError="";showingInput=false;privacy(false)}
    func inputDismissed(){
        showingInput=false
        if !busy {closeInput()}
        else {clearChange();values=[:];privacy(false)} // The in-flight frame owns its copy; its reply can open the next stage.
    }
    private func openInput(_ verb:String,fields:[AgentActionReply.Field],guide:AgentActionReply.Guide?,next:ConnectionNext?,error:String?) {
        self.fields=fields;self.guide=guide;self.next=next;pendingAction=verb
        values=Dictionary(uniqueKeysWithValues:fields.compactMap{field in
            guard !field.secure,let value=field.value else{return nil};return (field.id,value)
        })
        choices=Set((next?.options ?? []).filter{$0.disabled != true && ($0.selected==true || next?.selected?.contains($0.id)==true)}.map(\.id))
        defaultChoice="";inputError=error ?? "";showingInput=true;privacy(true)
    }
    private func authenticated() async ->Bool {confirming=true;defer{confirming=false;restoreFocus()};return await confirm()}

    func close(){polling?.cancel();polling=nil;closeInput()}
    func perform(_ verb:String,item:AgentConnectionItem?=nil,submitted:Bool=false) async {
        guard !busy,let agent,let target=item ?? self.item else{return}
        if verb=="app_connect" && !submitted && target.primaryAction?.label=="설정 바꾸기" {
            detail=target.id
            if let settings=target.settings,settings.count==1 {await change(settings[0].step,item:target)}
            return
        }
        busy=true;defer{busy=false}
        let requested=verb=="secret_set" && !submitted ? "secret_guide":verb
        let read=["secret_guide","check","check_all","oauth_guide","mcp_login"].contains(requested)
        if !submitted && ["app_disconnect","account_disconnect"].contains(requested) {
            guard await confirmDisconnect("\(agent.display_name)의 \(target.label) 연결을 해제할까요? 넣어 둔 값은 남아 다시 연결할 때 그대로 써요.") else{return}
        }
        if requested=="app_undo" {guard await confirmUndo(target.actions?.first{$0.id=="app_undo"}?.label ?? "되돌리기") else{return}}
        if !read {guard await authenticated() else{return}}
        if requested=="gateway_restart" || (submitted && values["resume"]=="gateway_restart") {
            guard await confirmRestart() else{return}
        }
        var frame:[String:Any]=["v":1,"type":"connection_action","profile":agent.profile,"connection":target.id,"action":requested,"reauth":!read]
        let session=changeSession
        if submitted {
            if session != nil {changeValues.merge(values){_,new in new};frame["values"]=changeValues}
            else {frame["values"]=values}
        }
        do {
            let result=try await send(frame)
            if let session,session != changeSession{return}
            let reply=result["reply"] as? [String:Any] ?? [:]
            if reply["committed"] as? Bool==true || ["done","failed","refused"].contains(reply["outcome"] as? String ?? "") {
                clearChange();values=[:]
            }
            if let input=reply["fields"] {
                let fields=try JSONDecoder().decode([AgentActionReply.Field].self,from:JSONSerialization.data(withJSONObject:input))
                let guide=try reply["guide"].map{try JSONDecoder().decode(AgentActionReply.Guide.self,from:JSONSerialization.data(withJSONObject:$0))}
                openInput(verb,fields:fields,guide:guide,next:nil,error:reply["input_error"] as? String);return
            }
            if let raw=reply["next"] {
                let next=try JSONDecoder().decode(ConnectionNext.self,from:JSONSerialization.data(withJSONObject:raw))
                if next.kind != "done" {
                    openInput(verb,fields:next.fields ?? [],guide:next.guide,next:next,error:next.input_error ?? reply["input_error"] as? String);return
                }
            }
            let outcome=reply["outcome"] as? String ?? "done",reason=reply["reason"] as? String ?? "OK"
            if let sid=reply["session_id"] as? String {
                code=reply["user_code"] as? String ?? "";loginURL=(reply["verification_url"] as? String).flatMap(URL.init(string:))
                if let url=loginURL,url.scheme=="https",url.user==nil {NSWorkspace.shared.open(url)}
                startPolling(sid,profile:agent.profile,verb:"oauth_poll");return
            }
            if let job=reply["job"] as? String,outcome=="pending" {startPolling(job,profile:agent.profile,verb:"job_status")}
            if outcome=="done" {closeInput();notice=reply["instruction"] as? String ?? "마쳤어요."}
            else if reason=="write_partial" {notice="저장이 중간에 멈췄어요. 서버에서 이 키를 확인해 주세요"}
            else if reason=="BUSY" {notice="지금 대화를 처리 중이라 시작하지 않았어요. 잠시 뒤 다시 눌러 주세요."}
            else if reason=="BUSY_CHECK_FAILED" {notice="처리 중인지 확인하지 못해 시작하지 않았어요"}
            else if reason=="RATE_LIMITED" {notice="다시 시작은 60분에 한 번만 할 수 있어요."}
            else {
                var wording=reply;wording["action"]=requested
                if let until=wording["undo_until"] as? Double{wording["undo_until"]=ISO8601DateFormatter().string(from:Date(timeIntervalSince1970:until))}
                if let data=try? JSONSerialization.data(withJSONObject:wording),let typed=try? AgentActionReply.decode(data){notice=ConnectionSentence.notice(typed,label:target.label,kind:target.connect_kind).text}
                else{notice="하지 못했어요. 연결과 입력을 확인해 주세요."}
            }
            if showingInput {inputError=notice}
            await refresh()
        } catch {clearChange();values=[:];inputError="응답을 받지 못했어요. 잠시 뒤 다시 해 주세요.";if !showingInput{notice=inputError}}
    }
    func submit() async {
        guard let verb=pendingAction else{return}
        if let next,["gateway_restart","permission_request","internet_accounts"].contains(next.kind){values["resume"]=next.kind}
        if let next,let options=next.options {let selected=options.filter{choices.contains($0.id)}.map(\.id);if next.kind=="choose_sync_root"{values["sync_root"]=selected.first}else{values[next.kind=="choose_account" ? "account":"scope"]=String(data:(try? JSONSerialization.data(withJSONObject:selected)) ?? Data(),encoding:.utf8)}}
        if next?.needs_default==true{values["default"]=defaultChoice}
        await perform(verb,submitted:true)
    }
    func resumeRestart() async {
        guard let agent else{return}
        if let result=try? await send(["v":1,"type":"connection_action","profile":agent.profile,"connection":"latest","action":"job_status","reauth":false]),let reply=result["reply"] as? [String:Any],reply["outcome"] as? String=="pending",let job=reply["job"] as? String {startPolling(job,profile:agent.profile,verb:"job_status")}
    }
    func startPolling(_ id:String,profile:String,verb:String){
        polling?.cancel();polling=Task { [weak self] in
            for _ in 0..<450 {
                guard let self,!Task.isCancelled else{return}
                try? await Task.sleep(nanoseconds:2_000_000_000)
                do {
                    let result=try await send(["v":1,"type":"connection_action","profile":profile,"connection":id,"action":verb,"reauth":false])
                    let reply=result["reply"] as? [String:Any] ?? [:],state=reply["status"] as? String ?? reply["outcome"] as? String ?? "unknown"
                    if state=="approved" || state=="done" {code="";loginURL=nil;notice=verb=="job_status" ? "다시 시작했고 채널 \(reply["connected"] as? Int ?? 0)개가 다시 연결됐어요":"연결을 확인했어요.";await refresh();return}
                    if !["pending","running","waiting"].contains(state) {notice="결과를 확인하지 못했어요. 서버에서 확인해 주세요.";return}
                } catch {continue} // The saved restart job is queried after reconnection; the side effect is never retried.
            }
            self?.notice="동의 시간이 초과됐어요. 다시 연결을 눌러 시작할 수 있어요."
        }
    }
}

@MainActor final class ConnectionsWindow:NSObject,NSWindowDelegate {
    let window:NSWindow
    let model:ConnectionsModel
    private var inputWindow:NSWindow?
    private var inputObservation:AnyCancellable?
    private var confirmingObservation:AnyCancellable?
    private var preferredLevel:NSWindow.Level = .normal
    private var appearanceObserver:NSObjectProtocol?
    private var pending:[String:CheckedContinuation<[String:Any],Error>]=[:]
    private var timeouts:[String:Task<Void,Never>]=[:]
    init(controller:ConversationController){
        var request:(([String:Any])async throws->[String:Any])!
        model=ConnectionsModel(send:{try await request($0)},confirm:{
            let context=LAContext()
            return (try? await context.evaluatePolicy(.deviceOwnerAuthentication,localizedReason:"서버의 연결 설정을 바꾸려면 다시 확인해 주세요"))==true
        })
        window=NSWindow(contentRect:CGRect(x:0,y:0,width:760,height:560),styleMask:[.titled,.closable,.resizable,.miniaturizable],backing:.buffered,defer:false)
        super.init();model.people={ [weak controller] in controller?.model.employees.map{AgentConnectionProfile(profile:$0.id,display_name:$0.name,connections:[])} ?? [] };model.avatar={ [weak controller] in controller?.avatar($0) ?? ProfileAvatar() };window.title="에이전트 연결";window.minSize=CGSize(width:760,height:500);window.isReleasedWhenClosed=false;window.center()
        window.delegate=self
        window.contentView=NSHostingView(rootView:ConnectionsView(model:model))
        model.restoreFocus={ [weak self] in self?.restoreFocus() }
        model.confirmDisconnect={ [weak self] text in await self?.ask("연결을 해제할까요?",text:text,button:"해제") ?? false }
        model.confirmRestart={ [weak self] in await self?.ask("에이전트를 다시 시작할까요?",text:"모든 에이전트가 잠시(약 1분) 응답을 멈춰요. 처리 중인 대화가 있으면 시작하지 않아요.",button:"다시 시작") ?? false }
        model.confirmUndo={ [weak self] label in
            let title=label=="처음부터 다시" ? "이 연결을 처음부터 다시 할까요?":"마지막 연결 변경을 되돌릴까요?"
            return await self?.ask(title,text:"이 연결에서 저장한 값을 이전으로 되돌려요.",button:label) ?? false
        }
        inputObservation=model.$showingInput.removeDuplicates().sink{ [weak self] active in
            // Published sends before assignment; apply presentation on the next main-loop turn.
            Task { @MainActor in self?.presentInput(active) }
        }
        confirmingObservation=model.$confirming.sink{ [weak self] active in self?.updateLevel(confirming:active) }
        window.appearance=ChatAppearance.theme.appearance
        appearanceObserver=NotificationCenter.default.addObserver(forName:ChatAppearance.didChange,object:nil,queue:.main){[weak window] _ in MainActor.assumeIsolated {window?.appearance=ChatAppearance.theme.appearance} }
        request={ [weak self,weak controller] frame in
            guard let self,let controller,controller.canSend else{throw GateFailure.notConnected}
            var frame=frame;let id=UUID().uuidString.lowercased();frame["id"]=id
            return try await withCheckedThrowingContinuation { continuation in
                self.pending[id]=continuation
                self.timeouts[id]=Task { [weak self] in try? await Task.sleep(nanoseconds:180_000_000_000);guard !Task.isCancelled else{return};self?.pending.removeValue(forKey:id)?.resume(throwing:GateFailure.notConnected);self?.timeouts[id]=nil }
                Task {do{try await controller.client.send(frame)}catch{self.timeouts.removeValue(forKey:id)?.cancel();self.pending.removeValue(forKey:id)?.resume(throwing:GateFailure.notConnected)}}
            }
        }
        controller.onConnectionsFrame={ [weak self] frame in
            guard let self,let ref=frame["ref"] as? String else{return}
            timeouts.removeValue(forKey:ref)?.cancel();pending.removeValue(forKey:ref)?.resume(returning:frame)
        }

    }
    deinit {if let appearanceObserver {NotificationCenter.default.removeObserver(appearanceObserver)}}
    func setPreferredLevel(_ level:NSWindow.Level){preferredLevel=level;updateLevel(confirming:model.confirming)}
    private func updateLevel(confirming:Bool){window.level=confirming ? .normal:preferredLevel}
    private func presentInput(_ active:Bool){
        guard active==model.showingInput else{return}
        if !active {
            if let inputWindow {window.endSheet(inputWindow);inputWindow.orderOut(nil);self.inputWindow=nil}
            updateLevel(confirming:model.confirming);return
        }
        guard window.isVisible,inputWindow==nil else{return}
        let sheet=NSWindow(contentRect:CGRect(x:0,y:0,width:440,height:450),styleMask:[.titled,.closable],backing:.buffered,defer:false)
        sheet.title="연결";sheet.isReleasedWhenClosed=false;sheet.delegate=self
        sheet.contentView=NSHostingView(rootView:ConnectionInputView(model:model))
        inputWindow=sheet;updateLevel(confirming:model.confirming)
        window.beginSheet(sheet){ [weak self,weak sheet] _ in
            guard let self,let sheet else{return}
            sheet.orderOut(nil)
            if self.inputWindow === sheet {self.inputWindow=nil;self.model.inputDismissed();self.updateLevel(confirming:self.model.confirming)}
        }
    }
    private func ask(_ title:String,text:String,button:String) async ->Bool {
        model.confirming=true;defer{model.confirming=false;model.restoreFocus()}
        let alert=NSAlert();alert.messageText=title;alert.informativeText=text
        alert.addButton(withTitle:button);alert.addButton(withTitle:"취소")
        return await withCheckedContinuation { continuation in
            alert.beginSheetModal(for:inputWindow ?? window){continuation.resume(returning:$0 == .alertFirstButtonReturn)}
        }
    }
    func restoreFocus(){
        NSApp.activate(ignoringOtherApps:true)
        window.makeKeyAndOrderFront(nil)
        if let inputWindow {inputWindow.makeKeyAndOrderFront(nil)}
    }
    func windowShouldClose(_ sender:NSWindow)->Bool {
        if sender === inputWindow {window.endSheet(sender);return false}
        return true
    }
    func windowWillClose(_ notification:Notification){if notification.object as? NSWindow === window {model.close();presentInput(false)}}
    func show(profile:String?=nil){
        NSApp.activate(ignoringOtherApps:true)
        if let profile{model.selected=profile}
        if let inputWindow,!inputWindow.isVisible {window.endSheet(inputWindow);inputWindow.orderOut(nil);self.inputWindow=nil;model.inputDismissed()}
        for sheet in window.sheets where !sheet.isVisible {window.endSheet(sheet);sheet.orderOut(nil)}
        updateLevel(confirming:model.confirming)
        window.makeKeyAndOrderFront(nil)
        presentInput(model.showingInput)
        if let inputWindow {inputWindow.makeKeyAndOrderFront(nil)}
        Task{await model.refresh();await model.resumeRestart()}
    }

}

struct ConnectionsView:View {
    @ObservedObject var model:ConnectionsModel
    private var card:Color{Color(nsColor:.controlBackgroundColor)}
    var body:some View {
        HStack(spacing:0){
            VStack(alignment:.leading,spacing:8){
                Text("직원").font(.caption).foregroundColor(.secondary).padding(.horizontal,8)
                ForEach(model.roster){agent in
                    Button{model.selected=agent.profile;model.detail=nil}label:{HStack(spacing:10){face(agent,28);Text(agent.display_name).font(.system(size:12,weight:.medium));Spacer();Circle().fill(agent.summary(includingHidden:model.includingHidden)=="연결됨" ? Color.green:agent.summary(includingHidden:model.includingHidden)=="다시 연결 필요" ? .yellow:.gray).frame(width:7,height:7)}.padding(8).background(model.agent?.profile==agent.profile ? Color.primary.opacity(0.08):.clear).cornerRadius(8)}.buttonStyle(.plain)
                };Spacer()
            }.padding(.horizontal,8).padding(.vertical,20).frame(width:200).background(Color(nsColor:.windowBackgroundColor))
            Divider()
            ScrollView{VStack(alignment:.leading,spacing:16){
                if let agent=model.agent {
                    HStack(spacing:12){face(agent,44);Text(agent.display_name).font(.system(size:18,weight:.bold));Spacer();Text(ConnectionTime.label(model.document?.checked_at)).font(.caption).foregroundColor(.secondary);Button("모두 확인"){Task{if let item=agent.connections.first{await model.perform("check_all",item:item)}}};Button("새로 확인"){Task{await model.refresh()}}}
                    if !model.readNotice.isEmpty{Text(model.readNotice).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)}
                    if !model.notice.isEmpty{Text(model.notice).font(.caption).foregroundColor(.secondary).fixedSize(horizontal:false,vertical:true)}
                    if let n=model.document?.unavailable_providers,n>0 {Text("이 서버에서 불러오지 못한 제공자 \(n)개").font(.caption).foregroundColor(.secondary)}
                    if !model.code.isEmpty{Text(model.code).textSelection(.enabled);if let url=model.loginURL{Link("동의 페이지 열기",destination:url)}}
                    HStack(spacing:8){summary(agent,[.connected],"연결됨",.green);summary(agent,[.needsReconnect,.notConnected],"다시 연결 필요",.yellow);summary(agent,[.unknown],"확인 안 됨",.gray)}
                    if let item=model.item{detail(item,agent)}else{
                        HStack(spacing:12){
                            TextField("연결 검색",text:$model.searchText).textFieldStyle(.roundedBorder).accessibilityLabel("연결 검색")
                            Toggle("연결할 수 없는 항목도 보기",isOn:$model.includingHidden).toggleStyle(.checkbox).fixedSize()
                            Toggle("연결된 것만",isOn:$model.connectedOnly).toggleStyle(.checkbox).fixedSize().accessibilityLabel("연결된 것만")
                        }
                        let groups=model.visibleGroups
                        if groups.isEmpty{Text("맞는 연결이 없어요").font(.callout).foregroundColor(.secondary)}
                        ForEach(groups,id:\.id){group in
                            VStack(alignment:.leading,spacing:6){Text(group.title).font(.caption.weight(.semibold)).foregroundColor(.secondary);VStack(spacing:0){ForEach(group.items){item in row(item);if item.id != group.items.last?.id{Divider().padding(.leading,12)}}}.background(card).cornerRadius(10)}
                        }
                    }
                }else{if !model.readNotice.isEmpty{Text(model.readNotice).font(.caption).foregroundColor(.secondary)};Text(model.loading ? "연결 상태를 확인하는 중":"아직 연결 상태가 없어요");Button("새로 확인"){Task{await model.refresh()}}}
            }.padding(22).frame(maxWidth:.infinity,alignment:.leading)}
        }.frame(minWidth:760,minHeight:500).onReceive(NotificationCenter.default.publisher(for:NSApplication.didBecomeActiveNotification)){_ in Task{await model.refresh()}}
        .onChange(of:model.selected){_ in Task{await model.refresh()}}
    }
    private func face(_ agent:AgentConnectionProfile,_ size:CGFloat)->some View {
        let avatar=model.avatar(agent.profile)
        return Group{if let image=avatar.image{Image(nsImage:image).resizable().scaledToFill()}else{Text(ProfileAvatar.initial(agent.display_name)).foregroundColor(Color(nsColor:avatar.foreground)).frame(maxWidth:.infinity,maxHeight:.infinity).background(Color(nsColor:avatar.color))}}.frame(width:size,height:size).clipShape(Circle())
    }
    private func summary(_ agent:AgentConnectionProfile,_ states:[AgentConnectionItem.State],_ title:String,_ color:Color)->some View {
        let count=model.listed(agent).filter{states.contains($0.state)}.count
        return Group{if count>0{HStack(spacing:5){Circle().fill(color).frame(width:6,height:6);Text("\(title) \(count)")}.font(.caption).foregroundColor(.secondary).padding(.horizontal,9).padding(.vertical,4).background(card).clipShape(Capsule())}}
    }
    private func button(_ action:ConnectionAction,_ item:AgentConnectionItem)->some View {
        Button{model.detail=item.id;Task{await model.perform(action.id,item:item)}}label:{
            HStack(spacing:5){if model.busy{ProgressView().controlSize(.small)};Text(model.busy ? "…":action.label)}.font(.system(size:11,weight:.medium)).foregroundColor(action.resolves ? .white:.primary)
                .padding(.horizontal,12).padding(.vertical,7).background(action.resolves ? Color.blue:Color.clear).cornerRadius(6)
                .overlay(RoundedRectangle(cornerRadius:6).stroke(action.resolves ? Color.clear:Color.secondary.opacity(0.35),lineWidth:1))
        }.buttonStyle(.plain).disabled(model.busy).accessibilityLabel("\(model.agent?.display_name ?? ""), \(item.label), \(action.label)")
    }
    private func row(_ item:AgentConnectionItem)->some View {
        HStack(spacing:10){Button{model.detail=item.id}label:{HStack(spacing:10){tile(item.service);VStack(alignment:.leading,spacing:3){Text(item.label).font(.system(size:12,weight:.semibold));Text(item.account ?? item.explanation).font(.system(size:11)).foregroundColor(.secondary).lineLimit(1)}.frame(maxWidth:.infinity,alignment:.leading)}}.buttonStyle(.plain);pill(item.state);if let primary=item.primaryAction{button(primary,item)}else{Button("›"){model.detail=item.id}.buttonStyle(.plain).foregroundColor(.secondary)}
            if !item.otherActions.isEmpty {
                Menu {ForEach(item.otherActions,id:\.id){action in Button(action.label){model.detail=item.id;Task{await model.perform(action.id,item:item)}}}}
                    label:{Text("⋯").font(.title3)}.menuStyle(.borderlessButton).fixedSize().accessibilityLabel("다른 동작")
            }}.padding(.horizontal,12).padding(.vertical,10)
    }
    private func pill(_ state: AgentConnectionItem.State) -> some View {
        let color: Color = state == .connected ? .green : state == .needsReconnect ? .yellow : state == .notConnected ? .red : .secondary
        return Text(state.title).font(.system(size: 10, weight: .medium)).foregroundColor(color).padding(.horizontal, 8).padding(.vertical, 3)
            .background(state == .off ? Color.clear : color.opacity(0.12)).clipShape(Capsule())
            .overlay(Capsule().stroke(state == .off ? Color.secondary.opacity(0.4) : .clear))
    }
    private func tile(_ service: String, size: CGFloat = 30) -> some View {
        let spec: (String, Color, Color) = {
            switch service {
            case "google": return ("G", .white, .black)
            case "notion": return ("N", .white, .black)
            case "synology": return ("S", .blue, .white)
            case "slack": return ("#", .purple, .white)
            case "mail_read": return ("✉", .blue, .white)
            case "notes_read": return ("✎", .yellow, .black)
            case "calendar_read": return ("31", .red, .white)
            case "photon": return ("●", .green, .white)
            case "x": return ("X", .black, .white)
            case "instagram": return ("◎", .pink, .white)
            case "pasteboard": return ("▣", .gray, .white)
            default: return ("⇄", .indigo, .white)
            }
        }()
        return Group {
            if service == "photon" { Image(systemName: "bubble.left.fill") }
            else { Text(spec.0).font(.system(size: size * 0.48, weight: .semibold)) }
        }.foregroundColor(spec.2).frame(width: size, height: size).background(spec.1).cornerRadius(6)
    }
    private func detail(_ item:AgentConnectionItem,_ agent:AgentConnectionProfile)->some View{
        VStack(alignment:.leading,spacing:16){Button("‹ \(agent.display_name)"){model.detail=nil}.buttonStyle(.plain).foregroundColor(.blue);Text(item.label).font(.title2.bold());Text(item.explanation).font(.callout).padding(12).frame(maxWidth:.infinity,alignment:.leading).background(Color.yellow.opacity(0.13)).cornerRadius(8);Text("할 수 있는 일").font(.caption.weight(.semibold));ForEach(item.capabilities,id:\.self){Text($0).font(.callout)};Text("지키는 규칙").font(.caption.weight(.semibold));ForEach(item.rules,id:\.self){Text($0).font(.caption).foregroundColor(.secondary)};if let settings=item.settings,!settings.isEmpty {
            Text("지금 설정").font(.caption.weight(.semibold))
            ForEach(settings){setting in HStack{Text(setting.label);Text(setting.value).foregroundColor(.secondary);Spacer();Button("바꾸기"){Task{await model.change(setting.step,item:item)}}.disabled(model.busy)}}
        };Text("할 수 있는 동작").font(.caption.weight(.semibold));HStack{ForEach(item.actions ?? [],id:\.id){button($0,item)}};Text(ConnectionTime.label(item.checked_at)).font(.caption).foregroundColor(.secondary)}
    }
}

struct ConnectionInputView:View {
    @ObservedObject var model:ConnectionsModel
    var body:some View {
        VStack(alignment:.leading,spacing:14) {
            Text("\(model.agent?.display_name ?? "") · \(model.item?.label ?? "") 연결").font(.title3.bold())
            ScrollView {
                VStack(alignment:.leading,spacing:14) {
                    if let guide=model.guide {
                        ForEach(guide.items) { step in
                            VStack(alignment:.leading) {
                                Text("\(step.n). \(step.text)").font(.callout)
                                HStack {
                                    if let raw=step.open_url,let url=URL(string:raw),["https","http"].contains(url.scheme ?? "") {Link("열기",destination:url)}
                                    if let copy=step.copy {Button("복사"){NSPasteboard.general.clearContents();NSPasteboard.general.setString(copy,forType:.string)}}
                                }
                            }
                        }
                    }
                    ForEach(model.fields,id:\.id) { field in
                        VStack(alignment:.leading,spacing:4) {
                            Text(field.label).font(.caption)
                            ConnectionInputField(label:field.label,secure:field.secure,text:Binding(get:{model.values[field.id] ?? ""},set:{model.values[field.id]=$0})).disabled(model.busy)
                        }
                    }
                    if let next=model.next {
                        if ["permission_request","open_settings","internet_accounts"].contains(next.kind) {Text("서버에서 허용해 주세요").font(.callout)}
                        else if let hint=next.hint {Text(hint).font(.callout)}
                        if let raw=next.url,let url=URL(string:raw),url.scheme=="https",url.user==nil {Link("로그인 페이지 열기",destination:url)}
                        ForEach(next.options ?? []) { option in
                            Toggle(option.label,isOn:Binding(get:{model.choices.contains(option.id)},set:{
                                if $0 {
                                    if model.next?.kind=="choose_sync_root" || (model.next?.multi != true && model.next?.kind=="choose_account") {model.choices=[]}
                                    model.choices.insert(option.id)
                                } else {model.choices.remove(option.id)}
                            })).disabled(option.disabled==true)
                        }
                        if next.needs_default==true {
                            Picker("기본 계정",selection:$model.defaultChoice) {
                                Text("선택해 주세요").tag("")
                                ForEach((next.options ?? []).filter{model.choices.contains($0.id)}) {Text($0.label).tag($0.id)}
                            }
                        }
                    }
                }.frame(maxWidth:.infinity,alignment:.leading)
            }.frame(height:min(340,max(180,(NSScreen.main?.visibleFrame.height ?? 700)-260)))
            Text("입력한 값은 확인을 통과해야 저장해요. 화면과 기록에는 남기지 않아요.").font(.caption).foregroundColor(.secondary)
            Text(model.inputError).font(.caption).foregroundColor(.red)
            HStack {
                Spacer()
                Button("취소"){model.closeInput()}.keyboardShortcut(.cancelAction).disabled(model.busy)
                Button("확인하고 저장"){Task{await model.submit()}}.keyboardShortcut(.defaultAction)
                    .disabled(model.busy || model.fields.contains{$0.required != false && (model.values[$0.id] ?? "").isEmpty} || (model.next?.needs_default==true && model.defaultChoice.isEmpty) || (model.next?.options != nil && model.choices.isEmpty) || model.guide?.error(model.values) != nil)
            }
        }.padding(22).frame(width:440)
    }
}
