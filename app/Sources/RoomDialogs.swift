import AppKit

/// Native room dialogs; they collect intent while the gate owns canonical room state.
@MainActor enum RoomDialogs {
    struct Choice {var title:String;var members:[String];var lead:String}
    final class Picks:NSView {
        override var isFlipped:Bool {true}
        var boxes:[(String,NSButton)]=[]
        init(_ people:[Employee],inside:Set<String>=[]) {
            super.init(frame:.zero)
            let heading=NSTextField(labelWithString:"직원");heading.font = .systemFont(ofSize:11,weight:.semibold);heading.textColor = .secondaryLabelColor;heading.frame=CGRect(x:4,y:4,width:312,height:18);addSubview(heading)
            for (index,person) in people.enumerated() {
                let joined=inside.contains(person.id)
                let box=NSButton(checkboxWithTitle:person.name+(joined ? " (참여 중)":""),target:nil,action:nil)
                box.isEnabled = !joined;box.frame=CGRect(x:10,y:26+index*22,width:302,height:22)
                box.setAccessibilityLabel(box.title);boxes.append((person.id,box));addSubview(box)
            }
            frame=CGRect(x:0,y:0,width:316,height:30+people.count*22)
        }
        required init?(coder:NSCoder){nil}
        var chosen:[String] {boxes.filter{$0.1.isEnabled && $0.1.state == .on}.map(\.0)}
    }
    static func name(_ typed:String)->String {
        var name=typed.trimmingCharacters(in:.whitespacesAndNewlines)
        while name.hasPrefix("#") {name.removeFirst()}
        let words=name.lowercased().components(separatedBy:.whitespacesAndNewlines).filter{!$0.isEmpty}.joined(separator:"-")
        return String(String(String.UnicodeScalarView(words.unicodeScalars.filter{CharacterSet.alphanumerics.contains($0) || $0=="-" || $0=="_"})).prefix(80))
    }
    static func dialog(people:[Employee],room:Room?=nil)->(NSAlert,Picks,NSTextField,NSPopUpButton) {
        let picks=Picks(people,inside:Set(room?.members ?? [])),field=NSTextField(frame:CGRect(x:0,y:0,width:320,height:24)),lead=NSPopUpButton(frame:.zero,pullsDown:false)
        field.placeholderString="방 이름 (예: 새-프로젝트)";field.setAccessibilityLabel("방 이름")
        lead.addItems(withTitles:people.map(\.name));lead.setAccessibilityLabel("대표 직원")
        let scroll=NSScrollView(frame:CGRect(x:0,y:0,width:320,height:min(220,picks.frame.height+2)))
        scroll.documentView=picks;scroll.hasVerticalScroller=true;scroll.borderType = .bezelBorder;scroll.drawsBackground=false
        scroll.widthAnchor.constraint(equalToConstant:320).isActive=true;scroll.heightAnchor.constraint(equalToConstant:scroll.frame.height).isActive=true
        let heading=NSTextField(labelWithString:"초대할 직원");heading.font = .systemFont(ofSize:12,weight:.medium)
        var views:[NSView]=[scroll]
        if room==nil {views=[field,heading,scroll,NSTextField(labelWithString:"대표 직원"),lead]}
        let stack=NSStackView(views:views);stack.orientation = .vertical;stack.alignment = .leading;stack.spacing=8;stack.frame=CGRect(x:0,y:0,width:320,height:stack.fittingSize.height)
        let alert=NSAlert();alert.accessoryView=stack
        alert.messageText=room.map{"#"+$0.title+"에 직원 추가"} ?? "새 방 만들기"
        alert.informativeText=room == nil ? "이름은 소문자로 바뀌고 빈칸은 -가 돼요.":"이 방에 함께할 직원을 고르세요. ‘참여 중’인 직원은 이미 이 방에 있어요. 추가한 뒤 @이름으로 부를 수 있어요."
        alert.addButton(withTitle:room == nil ? "만들기":"초대");alert.addButton(withTitle:"취소");if room != nil {alert.buttons[0].isEnabled=picks.boxes.contains{$0.1.isEnabled}};alert.window.initialFirstResponder=room==nil ? field:picks
        return (alert,picks,field,lead)
    }
    static func create(_ people:[Employee])->Choice? {
        let (alert,picks,field,lead)=dialog(people:people)
        while alert.runModal() == .alertFirstButtonReturn {
            let title=name(field.stringValue),members=picks.chosen
            if !title.isEmpty,members.count>=2,people.indices.contains(lead.indexOfSelectedItem),members.contains(people[lead.indexOfSelectedItem].id) {return .init(title:title,members:members,lead:people[lead.indexOfSelectedItem].id)}
            let error=NSAlert();error.messageText="방 이름과 직원 2명 이상, 대표 직원을 확인해 주세요.";error.runModal()
        }
        return nil
    }
    static func invite(_ people:[Employee],room:Room)->[String]? {
        let (alert,picks,_,_)=dialog(people:people,room:room)
        return alert.runModal() == .alertFirstButtonReturn && !picks.chosen.isEmpty ? room.members+picks.chosen:nil
    }
    static func deletion(_ room:Room)->NSAlert {
        let alert=NSAlert();alert.alertStyle = .warning;alert.messageText="#"+room.title+" 방을 삭제할까요?"
        alert.informativeText="삭제하면 글이 모두 사라지고 되돌릴 수 없어요. 글을 남기려면 ‘보관’을 쓰세요.\n\n이 방에만 쓰인 첨부와 사진도 지워져요. 직원이 이미 받은 내용은 직원 기억에 남을 수 있어요."
        alert.addButton(withTitle:"삭제");alert.addButton(withTitle:"취소");return alert
    }
}

extension ConversationView {
    func memberMenu(_ employee:String)->NSMenu? {
        let model=controller.model
        guard let room=model.isHome ? model.homeChannel:model.selected.flatMap({model.groups[$0.employee]}),room.members.contains(employee) else{return nil}
        let menu=NSMenu();let item=RoomActionItem("이 방에서 빼기"){[weak self] in Task{await self?.controller.roomCommand("room_save",room:room,members:room.members.filter{$0 != employee})}}
        item.isEnabled=room.members.count>2 && room.lead != employee
        item.toolTip=room.lead==employee ? "대표 직원을 먼저 바꿔 주세요.":room.members.count<=2 ? "직원은 2명 이상이어야 해요.":nil
        menu.addItem(item);return menu
    }
    func createRoom(){if let choice=RoomDialogs.create(controller.model.employees){Task {await controller.roomCommand("room_save",title:choice.title,members:choice.members,lead:choice.lead)}}}
    func groupMenu(_ room:Room)->NSMenu {
        let menu=NSMenu(),model=controller.model
        for slot in 1...5 {menu.addItem(RoomActionItem((slot==1 ? "맨 위에 고정":"\(slot)번째 자리에 고정")+(model.sidebar.pins[room.id]==slot ? " ✓":"")){model.pin(room.id,slot:slot)})}
        if model.pinned.contains(room.id) {menu.addItem(.separator());menu.addItem(RoomActionItem("고정 해제"){model.pin(room.id,slot:nil)})}
        menu.addItem(RoomActionItem("모두 읽음"){model.markAllRead(room.id)})
        menu.addItem(RoomActionItem(model.muted.contains(room.id) ? "알림 켜기":"알림 끄기"){model.toggleMute(room.id)})
        menu.addItem(.separator())
        menu.addItem(RoomActionItem("이름 바꾸기…"){[weak self] in
            guard let self else{return};let alert=NSAlert(),field=NSTextField(string:room.title);field.frame=CGRect(x:0,y:0,width:320,height:24)
            alert.messageText="#"+room.title+" 이름 바꾸기";alert.informativeText="이름은 소문자로 바뀌고 빈칸은 -가 돼요.";alert.accessoryView=field;alert.addButton(withTitle:"바꾸기");alert.addButton(withTitle:"취소");alert.window.initialFirstResponder=field
            if alert.runModal() == .alertFirstButtonReturn {Task {await self.controller.roomCommand("room_save",room:room,title:RoomDialogs.name(field.stringValue))}}
        })
        menu.addItem(RoomActionItem("사진 바꾸기…"){[weak self] in self?.chooseGroupPicture(room)})
        if room.picture != nil {menu.addItem(RoomActionItem("사진 지우기"){[weak self] in Task{_ = await self?.controller.changePicture(kind:"room",id:room.id,url:nil)}})}
        menu.addItem(.separator())
        menu.addItem(RoomActionItem("직원 추가…"){[weak self] in guard let self,let members=RoomDialogs.invite(model.employees,room:room) else{return};Task{await self.controller.roomCommand("room_save",room:room,members:members)}})
        let lead=NSMenuItem(title:"대표 직원 바꾸기",action:nil,keyEquivalent:""),choices=NSMenu()
        for person in model.employees where room.members.contains(person.id) {let item=RoomActionItem(person.name){[weak self] in Task{await self?.controller.roomCommand("room_save",room:room,lead:person.id)}};item.state=room.lead==person.id ? .on:.off;choices.addItem(item)}
        lead.submenu=choices;menu.addItem(lead)
        menu.addItem(RoomActionItem("목록에서 빼기"){model.hide(room.id)})
        menu.addItem(RoomActionItem("보관…"){[weak self] in
            let alert=NSAlert();alert.messageText="#"+room.title+" 방을 보관할까요?";alert.informativeText="글은 그대로 남고, 방 목록 아래 ‘방 추가’의 ‘보관된 방’에서 다시 꺼낼 수 있어요.";alert.addButton(withTitle:"보관");alert.addButton(withTitle:"취소")
            if alert.runModal() == .alertFirstButtonReturn {Task{await self?.controller.roomCommand("room_archive",room:room,archived:true)}}
        })
        menu.addItem(RoomActionItem("삭제…"){[weak self] in if RoomDialogs.deletion(room).runModal() == .alertFirstButtonReturn {Task{await self?.controller.roomCommand("room_delete",room:room)}}})
        return menu
    }
    func chooseGroupPicture(_ room:Room){
        let picker=NSOpenPanel();picker.canChooseDirectories=false;picker.allowsMultipleSelection=false;picker.allowedContentTypes=[.png,.jpeg,.heic];picker.title="방 사진 고르기";picker.prompt="넣기"
        picker.begin{[weak self] response in if response == .OK,let url=picker.url {Task{_ = await self?.controller.changePicture(kind:"room",id:room.id,url:url)}}}
    }
}
