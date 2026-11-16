import AppKit

/// A view of the journal's direct conversations. Settings belong to member state, never to another store.
struct HomeRoom {
    static let id="@home",pictureID="home-main"
    struct Settings:Codable,Equatable {
        var members:[String]?
        var recipient:String?
        var muted:Bool?
        var picture:String?
        var channel:String?
    }
    var settings:Settings
    var employees:[Employee]
    var members:[Employee] {employees.filter{settings.members?.contains($0.id) ?? true}}
    var defaultRecipient:String? {members.first{$0.id==settings.recipient}?.id ?? members.first?.id}
    static let multiple="홈에서는 한 명에게 보내요. 여럿은 단체방에서 불러 주세요"
    enum Destination {case employee(String),refused(String)}
    /// Match longest names first, with the source mention boundary; two aliases of one person are one call.
    func mentioned(_ text:String)->Set<String> {
        var candidates:[(NSRange,String)]=[]
        for person in employees {
            for name in Set([person.id,person.name]+person.aliases) where !name.isEmpty {
                guard let regex=try? NSRegularExpression(pattern:"@"+NSRegularExpression.escapedPattern(for:name)+#"(?![\p{L}\p{N}])"#) else{continue}
                candidates += regex.matches(in:text,range:NSRange(text.startIndex...,in:text)).map{($0.range,person.id)}
            }
        }
        var used:[NSRange]=[],result=Set<String>()
        for (range,id) in candidates.sorted(by:{$0.0.length == $1.0.length ? $0.0.location<$1.0.location:$0.0.length>$1.0.length}) {
            if !used.contains(where:{NSIntersectionRange($0,range).length>0}) {used.append(range);result.insert(id)}
        }
        return result
    }
    /// Channel mode follows Ddots.post: explicit calls win; only a leading alias is normalized.
    func channelPost(_ text:String,picked:String?)->String {
        var shown=text
        if text.hasPrefix("@") {
            let aliases=employees.flatMap{person in person.aliases.filter{!$0.isEmpty}.map{($0,person.name)}}.sorted{$0.0.count>$1.0.count}
            for (alias,name) in aliases {
                let call="@"+alias
                guard text.hasPrefix(call) else{continue}
                let tail=String(text.dropFirst(call.count))
                if tail.isEmpty || tail.first.map({!$0.isLetter && !$0.isNumber})==true {shown="@"+name+tail;break}
            }
        }
        // Calls to employees outside this room also count: the gate ignores them then falls back to lead.
        if mentioned(shown).isEmpty,let picked,let person=employees.first(where:{$0.id==picked}) {
            return "@"+person.name+(shown.isEmpty ? "":" "+shown)
        }
        return shown
    }
    func destination(text:String,picked:String?)->Destination {
        let called=mentioned(text),allowed=Set(members.map(\.id))
        if called.count>1 {return .refused(Self.multiple)}
        if let absent=employees.first(where:{called.contains($0.id) && !allowed.contains($0.id)}) {return .refused(absent.name+"은 홈에 없어요")}
        if let picked {
            guard allowed.contains(picked) else{return .refused((employees.first{$0.id==picked}?.name ?? "선택한 직원")+"은 홈에 없어요")}
            return .employee(picked)
        }
        if let called=called.first {return .employee(called)}
        if let fallback=defaultRecipient {return .employee(fallback)}
        return .refused("홈에 보일 직원을 선택해 주세요")
    }
    func light(text:String,picked:String?,replying:String?)->(id:String?,ring:Bool) {
        if let replying {return (replying,true)}
        if let picked,members.contains(where:{$0.id==picked}) {return (picked,true)}
        let called=mentioned(text)
        return (called.count==1 ? members.first{called.contains($0.id)}?.id:nil,false)
    }
}

final class HomeOwnerView:NSView {
    let name:String,avatar:ProfileAvatar
    init(name:String,avatar:ProfileAvatar){self.name=name;self.avatar=avatar;super.init(frame:.zero);setAccessibilityElement(true);setAccessibilityLabel(name)}
    required init?(coder:NSCoder){fatalError()}
    override func hitTest(_ point:NSPoint)->NSView?{nil}
    override var isFlipped:Bool{true}
    override func draw(_ rect:NSRect){
        avatar.draw(in:CGRect(x:0,y:2,width:20,height:20),name:name)
        (name as NSString).draw(at:CGPoint(x:28,y:4),withAttributes:[.font:NSFont.systemFont(ofSize:12,weight:.semibold),.foregroundColor:avatar.color])
    }
}
