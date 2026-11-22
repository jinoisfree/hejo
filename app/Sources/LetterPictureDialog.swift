import AppKit

@MainActor final class LetterPictureControls:NSView,NSTextFieldDelegate {
    let text=NSTextField(string:"")
    let preview=NSImageView()
    private(set) var color:UserBubbleColor = .blue
    private(set) var swatches:[AppearanceSwatch]=[]
    init(name:String) {
        super.init(frame:CGRect(x:0,y:0,width:320,height:285))
        text.stringValue=String(name.prefix(1));text.placeholderString="최대 8글자 · 비우면 색만";text.setAccessibilityLabel("사진에 넣을 글자")
        text.frame=CGRect(x:8,y:150,width:304,height:24);text.delegate=self;addSubview(text)
        for (index,color) in UserBubbleColor.allCases.enumerated() {
            let button=AppearanceSwatch(frame:CGRect(x:8+(index%7)*44,y:242-(index/7)*40,width:36,height:36))
            button.color=color;button.darkColors=false;button.tag=index;button.title="";button.setButtonType(.toggle)
            button.setAccessibilityLabel(color.title);button.toolTip=color.title;button.target=self;button.action=#selector(selectColor(_:))
            swatches.append(button);addSubview(button)
        }
        preview.frame=CGRect(x:96,y:8,width:128,height:128);preview.imageScaling = .scaleAxesIndependently
        preview.setAccessibilityLabel("색과 글자 사진 미리보기");addSubview(preview);refresh()
    }
    required init?(coder:NSCoder){nil}
    @objc private func selectColor(_ sender:NSButton) {setColor(UserBubbleColor.allCases[sender.tag])}
    func setColor(_ value:UserBubbleColor) {color=value;refresh()}
    func controlTextDidChange(_ notification:Notification) {
        guard (text.currentEditor() as? NSTextView)?.hasMarkedText() != true else {return}
        text.stringValue=PictureCodec.pictureText(text.stringValue);refresh()
    }
    func png() throws -> Data {try PictureCodec.letterPicture(color:color,text:text.stringValue)}
    private func refresh() {
        for button in swatches {button.state=button.color==color ? .on:.off;button.needsDisplay=true}
        preview.image=(try? png()).flatMap(NSImage.init(data:))
    }
}

@MainActor enum LetterPictureDialog {
    static var present:(NSAlert)->NSApplication.ModalResponse = {OptionWindows.runModal($0)}
    static func choose(name:String) throws -> Data? {
        let controls=LetterPictureControls(name:name),alert=NSAlert()
        alert.messageText="색과 글자로 만들기";alert.informativeText="색을 고르고 글자를 넣어 주세요. 글자 크기는 네모에 맞춰져요."
        alert.accessoryView=controls;alert.addButton(withTitle:"저장");alert.addButton(withTitle:"취소")
        alert.window.initialFirstResponder=controls.text
        guard present(alert) == .alertFirstButtonReturn else {return nil}
        return try controls.png()
    }
}

extension ConversationView {
    func pictureMenu(kind:String,id:String,name:String,section:String?=nil)->NSMenuItem {
        let item=NSMenuItem(title:"사진 바꾸기…",action:nil,keyEquivalent:""),choices=NSMenu()
        choices.addItem(RoomActionItem("사진 고르기…"){[weak self] in self?.choosePicture(kind:kind,id:id,section:section)})
        choices.addItem(RoomActionItem("색과 글자로 만들기…"){[weak self] in self?.chooseLetterPicture(kind:kind,id:id,name:name,section:section)})
        item.submenu=choices;return item
    }
    func pictureUploaded(_ picture:String,id:String,section:String?) {
        if let section {controller.model.editSection(section,picture:picture)}
        else if id==HomeRoom.pictureID {controller.model.configureHome{$0.picture=picture}}
    }
    func chooseLetterPicture(kind:String,id:String,name:String,section:String?=nil) {
        let client=controller.client,address=client.store.settings.address,token=client.bearer,epoch=client.connectionEpoch
        do {
            guard let png=try LetterPictureDialog.choose(name:name),address==client.store.settings.address,token==client.bearer,epoch==client.connectionEpoch else{return}
            Task {
                guard address==client.store.settings.address,token==client.bearer,epoch==client.connectionEpoch else{return}
                if let picture=await controller.changePicture(kind:kind,id:id,url:nil,png:png) {pictureUploaded(picture,id:id,section:section)}
            }
        } catch {controller.notice="사진을 바꾸지 못했어요. 연결을 확인해 주세요."}
    }
}
