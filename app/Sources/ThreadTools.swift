import AppKit

enum ThreadTools {
    static let undo = "방금 중지한 작업에서 이미 바꾼 것(메모·파일·Notion·NAS·보낸 메시지 등)을 목록으로 먼저 보여 줘. 내가 확인하면 원래대로 되돌려 줘. 확인 전에는 아무것도 바꾸지 마."
    static func thinking(_ text:String)->Bool {
        String(text.split(separator:"\n",omittingEmptySubsequences:false).first ?? "").range(of:#"^[◐◓◑◒🤔\s]*생각\s*중\s*(\.{2,}|…)?\s*$"#,options:.regularExpression) != nil
    }
    private static let dateLock=NSLock()
    private static let fractionalDate:ISO8601DateFormatter = {let value=ISO8601DateFormatter();value.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return value}()
    private static let wholeDate=ISO8601DateFormatter()
    static func date(_ value:String)->Date {
        // Only parser resources are shared. No journal value or parsed-date cache lives here.
        dateLock.lock();defer{dateLock.unlock()}
        return fractionalDate.date(from:value) ?? wholeDate.date(from:value) ?? .distantPast
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
        return Array(messages.dropLast().filter{$0.role=="employee" && seen.insert($0.speaker).inserted}.prefix(3)).map{$0.speaker}
    }
    static func copyHeader(count:Int,key:ConversationKey,name:(String)->String,group:Bool)->String {
        (group ? "#":"@")+name(key.employee)+" 스레드 · 글 \(count)개\n"+link(key).absoluteString
    }
    static func copySections(_ messages:[ConversationMessage],name:(String)->String,ownerName:String = OwnerProfile.fallbackName,zone:TimeZone = .current)->[String] {
        let stamp=DateFormatter();stamp.locale=Locale(identifier:"en_US_POSIX");stamp.timeZone=zone;stamp.dateFormat="yyyy-MM-dd HH:mm"
        return messages.filter{$0.role=="owner" || !thinking($0.text)}.map { message in
            let body=message.text.replacingOccurrences(of:#"<((?:https?://|mailto:)[^<>\s]+)>"#,with:"$1",options:.regularExpression)
            var parts=["["+stamp.string(from:date(message.timestamp))+"] "+(message.role=="owner" ? ownerName:name(message.speaker))]
            if !body.isEmpty { parts.append(body) }
            if let state=message.replyState { parts.append("["+stateLabel(state)+"]") }
            parts += message.files.map{"📎 "+$0.name}
            return parts.joined(separator:"\n")
        }
    }
    static func copy(_ messages:[ConversationMessage],key:ConversationKey,name:(String)->String,ownerName:String = OwnerProfile.fallbackName,group:Bool=false,zone:TimeZone = .current)->String {
        let sections=copySections(messages,name:name,ownerName:ownerName,zone:zone)
        return ([copyHeader(count:sections.count,key:key,name:name,group:group)]+sections).joined(separator:"\n\n")
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

/// Derived from the journal projection; no status or button source is persisted here.
enum ThreadAssessment {
    struct Result {
        var request: ConversationMessage?
        var pending: ConversationMessage?
        var requestID: String?
        var pendingID: String?
        var buttons = Set<String>()
        var working = false
        var settled = false
        var approved = false
        var color: String? { pending != nil || pendingID != nil ? "#E01E5A" : working ? "#ECB22E" : settled || approved ? "#2EB67D" : nil }
    }
    static let yes: Set<String> = ["승인","전송","발송","발송해","승인, 발송해","응","응응","ㅇㅇ","네","예","좋아","진행","그래","오케이","ok","yes"]
    private static let patterns = [
        "nothingWaiting": #"승인(을|이)?\s*(기다리는|해\s*주실|해\s*줄|할|받을|드릴)[^\n.!?]{0,14}없"#,
        "approval1": #"승인(을|이)?\s*((만|좀|다시|한\s*번\s*더)\s*)*(하면|해\s*줘(?!서)|해\s*주|해\s*줄래|해\s*\?|부탁|기다|필요|요청|할래|할까|바라|받아야|줘(?!서)|주면)"#,
        "approval2": #"승인[^\n.!?]{0,14}?(이?라고|한\s*마디)만?\s*((다시|한\s*번(\s*더|만)?|정확히|꼭|바로|그냥)\s*)*(((답(장|변)?|말씀?|입력)\s*)?(해((?![가-힣])|\s*(줘(?!서)|주))|하면)|(보내|적어|남겨|써|알려)((?![가-힣])|\s*(줘(?!서)|주))|보내면|적으면|남기면|쓰면)"#
    ].mapValues { try! NSRegularExpression(pattern:$0) }
    static func requestsApproval(_ body:String)->Bool {
        let own=body.components(separatedBy:"\n").filter{!$0.trimmingCharacters(in:.whitespaces).hasPrefix(">")}.joined(separator:"\n")
        func matches(_ name:String)->Bool { patterns[name]!.firstMatch(in:own,range:NSRange(own.startIndex...,in:own)) != nil }
        return !matches("nothingWaiting") && (matches("approval1") || matches("approval2"))
    }
    static func assess(_ lines:[ConversationMessage],confirmed:Set<String> = [])->Result {
        let posts=lines.filter{$0.role=="owner" || !ThreadTools.thinking($0.text)}
        let asks=posts.indices.filter{index in
            let p=posts[index]
            return p.role=="employee" && (p.replyState != nil || !p.buttons.isEmpty || p.checklist != nil || requestsApproval(p.text))
        }
        guard let last=asks.last else{return Result()}
        func answer(_ index:Int)->Int? {posts.indices.dropFirst(index+1).first{posts[$0].role=="owner" && (posts[$0].answerTo==nil || posts[$0].answerTo==posts[index].id)}}
        let asked=answer(last)==nil ? last:asks.reversed().first{answer($0)==nil && !posts[$0].buttons.isEmpty} ?? last
        let request=posts[asked],answered=answer(asked)
        let said=answered.map{posts[$0].text.trimmingCharacters(in:CharacterSet.whitespacesAndNewlines.union(.punctuationCharacters)).lowercased()} ?? ""
        let finished=answered.map{index in posts.indices.dropFirst(index+1).contains{posts[$0].role=="employee" && !posts[$0].streaming}} == true
        var result=Result(request:request)
        if finished || request.replyState=="closed" {result.settled=true}
        else if request.replyState=="answered" {result.working=true}
        else if answered==nil {if !confirmed.contains(request.id) {result.pending=request}}
        else {result.approved=yes.contains(said)}
        let waiting=posts.indices.filter{index in
            let p=posts[index]
            return p.role=="employee" && !p.buttons.isEmpty && p.replyState != "answered" && p.replyState != "closed" && answer(index)==nil
        }
        result.buttons=waiting.count>=2 ? Set(waiting.map{posts[$0].id}):Set(result.pending.map{[$0.id]} ?? [])
        return result
    }
}

enum ReplyButtonPolicy {
    static let standard = ["승인", "거절", "의견", "확인"]
    static let mail = ["메모", "메모+노션", "확인"]
    static let mailLegend = "메모 = 개인(Obsidian 메모), 메모+노션 = 공용(노션+Obsidian 메모), 확인 = 만들지 않음"
    static let contexts: [(words: [String], legend: String)] = [
        (["확인", "되돌리기"], "앱 쓰기 결과"),
        (mail, mailLegend),
        (mail, "메모 = 개인(Obsidian 메모→미리알림), 메모+노션 = 공용(노션+Obsidian 메모→미리알림), 확인 = 만들지 않음"),
        (["제작해", "수정", "취소"], "제작해 = 이 제작안대로 만들기, 수정 = 고칠 점 말하기, 취소 = 만들지 않기"),
        (["다운", "수정", "종결"], "다운 = 받은 파일 저장, 수정 = 고칠 점 말하기, 종결 = 이 작업 끝내기"),
    ]

    static func word(_ label: String) -> String {
        guard label.hasPrefix(":"), let end = label.dropFirst().firstIndex(of: ":") else { return label }
        return label[label.index(after: end)...].trimmingCharacters(in: .whitespaces)
    }
    static func symbol(_ label: String) -> String? {
        switch word(label) {
        case "승인": return "circle"
        case "거절": return "xmark"
        case "의견": return "pencil"
        case "확인": return "checkmark"
        case "메모": return "note.text"
        case "메모+노션": return "square.stack"
        case "되돌리기": return "arrow.uturn.backward"
        default: return nil
        }
    }
    static func allowed(_ labels: [String], body: String) -> Bool {
        guard !labels.isEmpty, Set(labels).count == labels.count else { return false }
        if labels.allSatisfy(standard.contains) { return true }
        return contexts.contains { context in
            labels.allSatisfy(context.words.contains) && labels.contains { !standard.contains($0) } && body.contains(context.legend)
        }
    }
    static let scriptPending = [
        #"확인 \| 되돌리기"#, #"\d+(?: \| \d+)* \| 거절 \| 의견 \| 확인"#,
    ]
    static func script(_ labels: [String], sets: [String] = scriptPending) -> Bool {
        let joined = labels.joined(separator: " | ")
        return sets.contains { joined.range(of: "^(?:" + $0 + ")$", options: .regularExpression) != nil }
    }
    static func pressable(_ labels: [String], message: ConversationMessage) -> Bool {
        allowed(labels, body: message.text) || script(labels)
    }
    static func split(_ body: String) -> (head: String, detail: String)? {
        let lines = body.components(separatedBy: "\n")
        func heading(_ line: String) -> String? {
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            guard trimmed.range(of: #"^\*{1,2}[^*\n]+\*{1,2}$"#, options: .regularExpression) != nil else { return nil }
            return trimmed.trimmingCharacters(in: CharacterSet(charactersIn: "*")).trimmingCharacters(in: .whitespaces)
        }
        guard let action = lines.firstIndex(where: { line in
            heading(line).map { $0.range(of: #"^(?:소유자가\s*)?(?:할\s*일|검토할\s*일|결정\s*필요)"#, options: .regularExpression) != nil } ?? false
        }), let next = lines.indices.dropFirst(action + 1).first(where: { heading(lines[$0]) != nil }) else { return nil }
        let head = lines[..<next].joined(separator: "\n").trimmingCharacters(in: .newlines)
        let detail = lines[next...].joined(separator: "\n").trimmingCharacters(in: .newlines)
        return head.isEmpty || detail.isEmpty ? nil : (head, detail)
    }
}

@MainActor final class ReplyChecklistView:NSView {
    private let checklist:ReplyChecklist,send:(String)->Void,changed:(Set<String>)->Void
    private(set) var selected:Set<String>
    private var choices:[FileChip]=[]
    private let submit=FileChip(title:"작성"),skip=FileChip(title:"건너뛰기")
    override var isFlipped:Bool{true}
    init(_ checklist:ReplyChecklist,changed:@escaping(Set<String>)->Void={_ in},send:@escaping(String)->Void) {
        self.checklist=checklist;self.send=send;self.changed=changed;selected=Set(checklist.selected).intersection(checklist.items)
        super.init(frame:.zero)
        for label in checklist.items {
            let button=FileChip(title:"");button.font = .systemFont(ofSize:12);button.invoke={ [weak self] in
                guard let self else{return};self.selected=ThreadTools.toggle(self.checklist.items,selected:self.selected,label:label);self.changed(self.selected);self.refresh()
            };choices.append(button);addSubview(button)
        }
        submit.invoke={ [weak self] in guard let self,let text=ThreadTools.answer(self.checklist.items,selected:self.selected) else{return};self.send(text) }
        skip.invoke={ [weak self] in self?.send("건너뛰기") }
        for button in [submit,skip] {button.font = .systemFont(ofSize:12);addSubview(button)}
        skip.isHidden = !checklist.canSkip;refresh()
    }
    required init?(coder:NSCoder){fatalError()}
    // SwiftUI bordered's regular macOS bezel uses the native 13pt control font even with its
    // surrounding 12pt environment. Measured source buttons: ☐ 일정 61×24, 작성 47×24, 건너뛰기 69×24.
    static func buttonSize(_ title:String)->CGSize {let button=NSButton(title:title,target:nil,action:nil);button.bezelStyle = .rounded;button.font = .systemFont(ofSize:13);return button.intrinsicContentSize}
    private static func width(_ label:String,selected:Bool=false)->CGFloat {buttonSize((selected ? "✅ ":"☐ ")+label).width}
    static func columns(_ labels:[String],width:CGFloat,selected:Set<String>=[])->Int {labels.reduce(CGFloat(0)){$0+Self.width($1,selected:selected.contains($1))}+CGFloat(max(0,labels.count-1))*8<=width ? max(1,labels.count):2}
    static func height(_ labels:[String],width:CGFloat,selected:Set<String>=[])->CGFloat {CGFloat((labels.count+columns(labels,width:width,selected:selected)-1)/columns(labels,width:width,selected:selected)+1)*32-8}
    override var fittingSize:CGSize {CGSize(width:checklist.items.reduce(CGFloat(0)){$0+Self.width($1,selected:selected.contains($1))}+CGFloat(max(0,checklist.items.count-1))*8,height:56)}
    private func refresh(){for (i,button) in choices.enumerated() {let label=checklist.items[i];button.font = .systemFont(ofSize:13);button.title=(selected.contains(label) ? "✅ ":"☐ ")+label;button.contentTintColor=selected.contains(label) ? .controlAccentColor:.secondaryLabelColor;button.attributedTitle=NSAttributedString(string:button.title,attributes:[.font:NSFont.systemFont(ofSize:13),.foregroundColor:selected.contains(label) ? NSColor.controlAccentColor:.secondaryLabelColor])};for b in [submit,skip]{b.font = .systemFont(ofSize:13)};submit.isEnabled = !selected.isEmpty;needsLayout=true}
    override func layout(){super.layout();let columns=Self.columns(checklist.items,width:bounds.width,selected:selected),single=columns==checklist.items.count
        var x:CGFloat=0
        for (index,button) in choices.enumerated(){let col=index%columns,row=index/columns,width=Self.width(checklist.items[index],selected:selected.contains(checklist.items[index]));if col==0{x=0};if !single{x=CGFloat(col)*(bounds.width+8)/2};button.frame=CGRect(x:x,y:CGFloat(row)*32,width:width,height:24);x+=width+8}
        let y=CGFloat((choices.count+columns-1)/columns)*32;submit.frame=CGRect(origin:CGPoint(x:0,y:y),size:Self.buttonSize("작성"));skip.frame=CGRect(origin:CGPoint(x:submit.frame.maxX+8,y:y),size:Self.buttonSize("건너뛰기"))
    }
    override func mouseDown(with event:NSEvent){}
}
