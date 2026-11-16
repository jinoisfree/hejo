import AppKit

enum ThreadTools {
    static let undo = "방금 중지한 작업에서 이미 바꾼 것(메모·파일·Notion·NAS·보낸 메시지 등)을 목록으로 먼저 보여 줘. 내가 확인하면 원래대로 되돌려 줘. 확인 전에는 아무것도 바꾸지 마."
    static func thinking(_ text:String)->Bool {
        String(text.split(separator:"\n",omittingEmptySubsequences:false).first ?? "").range(of:#"^[◐◓◑◒🤔\s]*생각\s*중\s*(\.{2,}|…)?\s*$"#,options:.regularExpression) != nil
    }
    static func date(_ value:String)->Date {
        let iso=ISO8601DateFormatter();iso.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        return iso.date(from:value) ?? ISO8601DateFormatter().date(from:value) ?? .distantPast
    }
    static func link(_ key:ConversationKey)->URL {
        var parts=URLComponents();parts.scheme="hejo";parts.host="thread"
        parts.queryItems=[.init(name:"room",value:key.employee),.init(name:"thread",value:key.thread)]
        return parts.url!
    }
    static func destination(_ url:URL)->ConversationKey? {
        guard url.scheme?.lowercased()=="hejo",url.host=="thread",url.path.isEmpty,url.user==nil,url.password==nil,url.fragment==nil,
              let parts=URLComponents(url:url,resolvingAgainstBaseURL:false),let items=parts.queryItems,items.count==2,
              let room=items.first(where:{$0.name=="room"})?.value,!room.isEmpty,
              let thread=items.first(where:{$0.name=="thread"})?.value,UUID(uuidString:thread) != nil else { return nil }
        return .init(employee:room,thread:thread)
    }
    static func color(_ title:String)->NSColor? {
        let plain=String(title.split(separator:"\n").first ?? "").replacingOccurrences(of:"\u{FE0F}",with:"")
        for (hex,marks) in [("#E01E5A",["🔴","❌","🚨","⛔"]),("#ECB22E",["🟡","🟠","⚠"]),("#2EB67D",["🟢","✅","☑","✔"]),("#1D9BD1",["🔵","ℹ","📌"])] {
            if marks.contains(where:plain.contains) { return MessageFormat.color(hex) }
        };return nil
    }
    static func stateLabel(_ state:String)->String {state=="asked" ? "답을 기다리는 중":state=="answered" || state=="closed" ? "처리 완료":state}
    static func answeredFaces(_ messages:[ConversationMessage])->[String] {
        var seen=Set<String>()
        return Array(messages.dropLast().filter{$0.role=="employee" && seen.insert($0.key.employee).inserted}.prefix(3)).map{$0.key.employee}
    }
    static func copy(_ messages:[ConversationMessage],key:ConversationKey,name:(String)->String,zone:TimeZone = .current)->String {
        let stamp=DateFormatter();stamp.locale=Locale(identifier:"en_US_POSIX");stamp.timeZone=zone;stamp.dateFormat="yyyy-MM-dd HH:mm"
        let lines=messages.filter{$0.role=="owner" || !thinking($0.text)}
        var sections=["@"+name(key.employee)+" 스레드 · 글 \(lines.count)개\n"+link(key).absoluteString]
        sections += lines.map { message in
            let body=message.text.replacingOccurrences(of:#"<((?:https?://|mailto:)[^<>\s]+)>"#,with:"$1",options:.regularExpression)
            var parts=["["+stamp.string(from:date(message.timestamp))+"] "+(message.role=="owner" ? "나":name(message.key.employee))]
            if !body.isEmpty { parts.append(body) }
            if let state=message.replyState { parts.append("["+stateLabel(state)+"]") }
            parts += message.files.map{"📎 "+$0.name}
            return parts.joined(separator:"\n")
        };return sections.joined(separator:"\n\n")
    }
    static func toggle(_ labels:[String],selected:Set<String>,label:String)->Set<String> {
        var next=selected.intersection(labels)
        let on = !next.contains(label)
        if on { next.insert(label) } else { next.remove(label) }
        if labels.count>1,labels.first=="전체" {
            if label=="전체" { return on ? Set(labels):[] }
            if Set(labels.dropFirst()).isSubset(of:next) { next.insert("전체") } else { next.remove("전체") }
        };return next
    }
    static func answer(_ labels:[String],selected:Set<String>)->String? {
        let chosen=labels.filter{selected.contains($0)}
        guard !chosen.isEmpty else { return nil }
        return "선택: "+(chosen.contains("전체") ? "전체":chosen.joined(separator:", "))
    }
}

@MainActor final class ReplyChecklistView:NSStackView {
    private let checklist:ReplyChecklist,send:(String)->Void
    private let changed:(Set<String>)->Void
    private(set) var selected:Set<String>
    init(_ checklist:ReplyChecklist,changed:@escaping(Set<String>)->Void={_ in},send:@escaping(String)->Void) {
        self.checklist=checklist;self.send=send;selected=Set(checklist.selected).intersection(checklist.items)
        self.changed=changed
        super.init(frame:.zero);orientation = .vertical;alignment = .leading;spacing=8;refresh()
    }
    required init?(coder:NSCoder){fatalError()}
    private func refresh() {
        for child in arrangedSubviews { removeArrangedSubview(child);child.removeFromSuperview() }
        for start in stride(from:0,to:checklist.items.count,by:2) {
            let row=NSStackView();row.spacing=8
            for label in checklist.items[start..<min(start+2,checklist.items.count)] {
                let button=FileChip(title:(selected.contains(label) ? "✅ ":"☐ ")+label)
                button.font = .systemFont(ofSize:12);button.invoke={ [weak self] in guard let self else{return};self.selected=ThreadTools.toggle(self.checklist.items,selected:self.selected,label:label);self.changed(self.selected);self.refresh() };row.addArrangedSubview(button)
            };addArrangedSubview(row)
        }
        let row=NSStackView();row.spacing=8
        let submit=FileChip(title:"작성");submit.isEnabled = !selected.isEmpty
        submit.invoke={ [weak self] in guard let self,let text=ThreadTools.answer(self.checklist.items,selected:self.selected) else{return};self.send(text) };row.addArrangedSubview(submit)
        if checklist.canSkip { let skip=FileChip(title:"건너뛰기");skip.invoke={ [weak self] in self?.send("건너뛰기") };row.addArrangedSubview(skip) };addArrangedSubview(row)
    }
}
