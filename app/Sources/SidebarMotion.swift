import AppKit
import QuartzCore

/// SwiftUI opacity multiplies the primary color's native alpha rather than replacing it.
enum SidebarTone {
    static func column(dark:Bool)->NSColor { primary(dark ? 0.035:0.025) }
    static func selection(dark:Bool)->NSColor { NSColor.controlAccentColor.withAlphaComponent(dark ? 0.22:0.12) }
    static func cardFill(selected:Bool,hovered:Bool,dark:Bool)->NSColor {selected ? selection(dark:dark):primary(hovered ? 0.075:0.035)}
    static func cardBorder(selected:Bool,hovered:Bool)->NSColor {selected ? .controlAccentColor:primary(hovered ? 0.22:0.1)}
    static func primary(_ opacity:CGFloat=1)->NSColor {let color=NSColor.labelColor;return color.withAlphaComponent(color.alphaComponent*opacity)}
}

/// Native row differences own the positions; overlays share the same transaction and presentation state.
@MainActor enum SidebarMotion {
    static let duration:Double=0.24
    static let curve=CAMediaTimingFunction(controlPoints:0.42,0,0.58,1)
    static func change(_ layer:CALayer,key:String,to value:Any,duration:Double,spring:Bool=false) {
        let model=layer.value(forKeyPath:key)
        if let model,CFEqual(model as CFTypeRef,value as CFTypeRef){if duration==0 {layer.removeAnimation(forKey:key)};return}
        let current=layer.presentation()?.value(forKeyPath:key) ?? model
        CATransaction.begin();CATransaction.setDisableActions(true);layer.setValue(value,forKeyPath:key);CATransaction.commit()
        guard duration>0,let current else {layer.removeAnimation(forKey:key);return}
        let animation:CABasicAnimation
        if spring {
            let response=2*Double.pi/0.34,a=CASpringAnimation(keyPath:key);a.mass=1;a.stiffness=response*response;a.damping=2*0.88*response;a.duration=a.settlingDuration;animation=a
        } else {let a=CABasicAnimation(keyPath:key);a.duration=duration;a.timingFunction=curve;animation=a}
        animation.fromValue=current;animation.toValue=value;layer.add(animation,forKey:key)
    }
    static func update(_ table:NSTableView,old:[String],new:[String],animated:Bool) {
        NSAnimationContext.runAnimationGroup {context in
            context.duration=animated ? duration:0;context.timingFunction=curve
            table.beginUpdates()
            table.removeRows(at:IndexSet(old.indices.filter{!new.contains(old[$0])}),withAnimation:animated ? .effectFade:[])
            var current=old.filter{new.contains($0)}
            for (index,id) in new.enumerated() where !old.contains(id) {
                table.insertRows(at:IndexSet(integer:index),withAnimation:animated ? .effectFade:[]);current.insert(id,at:index)
            }
            for (index,id) in new.enumerated() {
                if let from=current.firstIndex(of:id),from != index {table.moveRow(at:from,to:index);current.insert(current.remove(at:from),at:index)}
            }
            table.endUpdates()
            table.noteHeightOfRows(withIndexesChanged:IndexSet(integersIn:0..<new.count))
        }
    }
}

final class SidebarSearchRow:NSView {
    let field:NSSearchField,clear=NSButton(),glass=NSImageView(),background=NSView()
    var onClear:(()->Void)?
    init(field:NSSearchField){
        self.field=field;super.init(frame:.zero);wantsLayer=true;background.wantsLayer=true;background.layer?.cornerRadius=8
        for view in [background,glass,field,clear]{addSubview(view)}
        field.isBordered=false;field.drawsBackground=false;field.focusRingType = .none
        if let cell=field.cell as? NSSearchFieldCell {cell.searchButtonCell=nil;cell.cancelButtonCell=nil}
        field.placeholderString="검색";field.setAccessibilityLabel("방과 글 검색");field.font = .systemFont(ofSize:12)
        clear.isBordered=false;clear.image=NSImage(systemSymbolName:"xmark.circle.fill",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:11,weight:.regular));clear.target=self;clear.action=#selector(clearQuery);clear.setAccessibilityLabel("검색 지우기")
        glass.image=NSImage(systemSymbolName:"magnifyingglass",accessibilityDescription:nil)?.withSymbolConfiguration(.init(pointSize:11,weight:.regular))
    }
    required init?(coder:NSCoder){nil}
    override var isFlipped:Bool{true}
    @objc private func clearQuery(){onClear?()}
    override func layout(){super.layout();let rect=CGRect(x:12,y:8,width:max(1,bounds.width-22),height:36);background.frame=rect;background.layer?.backgroundColor=SidebarTone.primary(0.09).cgColor
        glass.frame=CGRect(x:rect.minX+10,y:rect.midY-6,width:11,height:12);glass.contentTintColor = SidebarTone.primary(0.7)
        clear.isHidden=field.stringValue.isEmpty;clear.frame=CGRect(x:rect.maxX-23,y:rect.midY-8,width:13,height:16);clear.contentTintColor = SidebarTone.primary(0.7)
        field.frame=CGRect(x:rect.minX+26,y:rect.midY-10,width:max(1,rect.width-36-(clear.isHidden ? 0:18)),height:22)
    }
}
final class SidebarHitCell:NSTableCellView {
    static func bodyHeight(_ text:String,query:String,width:CGFloat)->CGFloat {
        let font=NSFont.systemFont(ofSize:11),line=NSLayoutManager().defaultLineHeight(for:font)
        let measured=(WorkspaceSearch.snippet(text,query:query) as NSString).boundingRect(with:CGSize(width:max(1,width-28),height:.greatestFiniteMagnitude),options:[.usesLineFragmentOrigin,.usesFontLeading],attributes:[.font:font]).height
        return min(ceil(line*2),max(ceil(line),ceil(measured)))
    }
    static func height(_ text:String,query:String,width:CGFloat)->CGFloat {14+2+bodyHeight(text,query:query,width:width)+12+2}

    let speaker=NSTextField(labelWithString:""),room=NSTextField(labelWithString:""),body=NSTextField(wrappingLabelWithString:"")
    override init(frame:CGRect){super.init(frame:frame);for field in [speaker,room,body]{addSubview(field)};speaker.font = .systemFont(ofSize:11,weight:.semibold);room.font = .systemFont(ofSize:10);room.textColor = SidebarTone.primary(0.7);body.font = .systemFont(ofSize:11);body.maximumNumberOfLines=2;body.lineBreakMode = .byTruncatingTail}
    required init?(coder:NSCoder){nil}
    override var isFlipped:Bool{true}
    func configure(_ message:ConversationMessage,name:String,room title:String,query:String){speaker.stringValue=message.role=="owner" ? "나":name;room.stringValue=title
        let text=NSMutableAttributedString(attributedString:WorkspaceSearch.attributed(WorkspaceSearch.snippet(message.text,query:query),query:query));text.addAttribute(.font,value:NSFont.systemFont(ofSize:11),range:NSRange(location:0,length:text.length));text.enumerateAttribute(.backgroundColor,in:NSRange(location:0,length:text.length)){value,range,_ in if value==nil {text.addAttribute(.foregroundColor,value:SidebarTone.primary(0.7),range:range)}};body.attributedStringValue=text;needsLayout=true}
    override func layout(){super.layout();let width=max(1,bounds.width-28),trailing=min(width/2,room.intrinsicContentSize.width);speaker.frame=CGRect(x:16,y:6,width:max(1,width-trailing-4),height:14);room.frame=CGRect(x:bounds.width-12-trailing,y:6,width:trailing,height:14);body.frame=CGRect(x:16,y:22,width:width,height:max(1,bounds.height-30));body.preferredMaxLayoutWidth=width}
}
final class SidebarBlank:NSView {
    var toggle:(()->Void)?
    override init(frame:CGRect){super.init(frame:frame);toolTip="빈 공간 더블클릭: 방 목록 너비 전환";setAccessibilityElement(true);setAccessibilityRole(.button);setAccessibilityLabel("방 목록 너비 전환")}
    required init?(coder:NSCoder){nil}
    override func mouseDown(with event:NSEvent){if event.clickCount==2 {toggle?()}}
    override func accessibilityPerformPress()->Bool{toggle?();return true}

}

final class SidebarHitsHeading:NSTableCellView {
    let title=NSTextField(labelWithString:"")
    override init(frame:CGRect){super.init(frame:frame);addSubview(title);title.font = .systemFont(ofSize:10,weight:.medium);title.textColor = SidebarTone.primary(0.7)}
    required init?(coder:NSCoder){nil}
    override var isFlipped:Bool{true}
    override func layout(){super.layout();title.frame=CGRect(x:16,y:10,width:max(1,bounds.width-28),height:14)}
}

/// One inset and colour for the attention rail in chat and the todo column.
enum AttentionRail {
    static let width:CGFloat=3, inset:CGFloat=6, vertical:CGFloat=10
    static var color:NSColor {MessageFormat.color("#E01E5A")!}
    static func rect(in bounds:CGRect)->CGRect {CGRect(x:bounds.minX+inset,y:bounds.minY+vertical,width:width,height:max(0,bounds.height-2*vertical))}
}
