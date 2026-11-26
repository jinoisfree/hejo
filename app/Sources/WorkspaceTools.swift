import AppKit

/// Shared text highlighting and snippet presentation. Search results come from the server.
enum WorkspaceSearch {
    static func normalized(_ text: String) -> String { text.trimmingCharacters(in:.whitespacesAndNewlines).precomposedStringWithCanonicalMapping.lowercased() }
    static func highlights(_ text: String, query: String) -> [Range<String.Index>] {
        let term=normalized(query);guard !term.isEmpty else{return []}
        let terms=text.range(of:term,options:.caseInsensitive) != nil ? [term]:term.split(whereSeparator:\.isWhitespace).map(String.init)
        var found:[Range<String.Index>]=[]
        for word in terms {
            var start=text.startIndex
            while start<text.endIndex,let range=text.range(of:word,options:.caseInsensitive,range:start..<text.endIndex) {found.append(range);start=text.index(after:range.lowerBound)}
        }
        var merged:[Range<String.Index>]=[]
        for range in found.sorted(by:{$0.lowerBound<$1.lowerBound}) {
            if let last=merged.last,range.lowerBound<=last.upperBound {merged[merged.count-1]=last.lowerBound..<max(last.upperBound,range.upperBound)} else {merged.append(range)}
        };return merged
    }
    static func snippet(_ text:String,query:String)->String {
        guard let match=highlights(text,query:query).first else{return String(text.prefix(60))}
        let start=text.index(match.lowerBound,offsetBy:-30,limitedBy:text.startIndex) ?? text.startIndex
        let end=text.index(match.upperBound,offsetBy:30,limitedBy:text.endIndex) ?? text.endIndex
        return (start>text.startIndex ? "…":"")+String(text[start..<end]).replacingOccurrences(of:"\n",with:" ")+(end<text.endIndex ? "…":"")
    }
    static func attributed(_ text:String,query:String)->NSAttributedString {
        let result=NSMutableAttributedString(string:text,attributes:[.font:NSFont.systemFont(ofSize:12),.foregroundColor:NSColor.labelColor])
        for range in highlights(text,query:query) {result.addAttributes([.backgroundColor:NSColor.systemYellow,.foregroundColor:NSColor.black],range:NSRange(range,in:text))};return result
    }

}
struct RoomNotice: Equatable {
    var id:String, title:String
    var questions:Bool
    var messages:[String]
}
@MainActor extension ConversationModel {
    func notices(_ employee:String,now:Date?=nil)->[RoomNotice] {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            return withRenderValues {
                let now=now ?? renderTime
                return cachedNotices(employee,now:now) {
                    var result:[RoomNotice]=[]
                    let scope=employee==HomeRoom.id ? homeScope:[employee]
                    let ordered=scope.flatMap{threads(employee:$0)}.sorted{a,b in
                        let x=timeline(a.key).first!,y=timeline(b.key).first!
                        return (date(x.timestamp),x.seq)<(date(y.timestamp),y.seq)
                    }
                    for thread in ordered {
                        let posts=timeline(thread.key).filter{$0.role=="owner" || !thinking($0)},state=assessment(thread.key)
                        guard let root=posts.first,posts.last?.role != "owner",!state.working,!state.settled,!(state.request.map{confirmed($0.id)} ?? false),memberState.read("bell:"+thread.key.employee+"/"+thread.key.thread)<originalSeq(thread.key) else{continue}
                        let id:String,title:String,message:String,questions:Bool
                        if let asked=state.pending {id="question:"+asked.speaker;title=name(asked.speaker)+" 질문";message=asked.id;questions=true}
                        else if state.request==nil,root.role=="employee",!posts.contains(where:{$0.role=="owner"}),now>=date(root.timestamp),now.timeIntervalSince(date(root.timestamp))<86400 {id="alert";title="알림";message=root.id;questions=false}
                        else {continue}
                        if let i=result.firstIndex(where:{$0.id==id}) {result[i].messages.append(message)} else {result.append(.init(id:id,title:title,questions:questions,messages:[message]))}
                    }
                    return result.filter(\.questions)+result.filter{!$0.questions}
                }
            }
        }
#endif
        var result: [RoomNotice] = []
            for row in history.noticeRows[employee == HomeRoom.id ? "home":employee] ?? [] {
                guard let group = row["group"] as? String, let id = row["id"] as? String,
                      let title = row["title"] as? String, let questions = row["questions"] as? Bool else { continue }
                if let i = result.firstIndex(where:{$0.id == group}) { result[i].messages.append(id) }
                else { result.append(.init(id:group,title:title,questions:questions,messages:[id])) }
            }
            return result
    }
    private func markAlertSeen(_ key: ConversationKey) -> Bool {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            guard notices(key.employee).filter({ !$0.questions }).flatMap(\.messages)
                .contains(where: { messages[$0]?.key == key }) else { return false }
            markNoticeRead(key)
            return true
        }
#endif
        guard history.noticeRows[key.employee]?.contains(where: { row in
            let target = row["key"] as? [String: String]
            return row["questions"] as? Bool == false && target?["room"] == key.employee && target?["thread"] == key.thread
        }) == true else { return false }
        markNoticeRead(key)
        return true
    }
    func selectUserThread(_ key: ConversationKey, notify: Bool = true, inHome: Bool, markRead: Bool = true) {
        select(key, notify: false, inHome: inHome, markRead: false)
        // The notice plan already records both the alert and thread reads.
        if !markAlertSeen(key), visible, markRead { markThreadRead(key) }
        if notify { onChange?() }
    }
    func markNoticeRead(_ key:ConversationKey) {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            let seq=String(originalSeq(key))
            try? memberState.set(["bell:"+key.employee+"/"+key.thread:seq,"thread:"+key.employee+"/"+key.thread:seq])
            return
        }
#endif
        history.readIntent?("notice",key.employee,key); return
    }
    func readAllNotices(_ employee:String,now:Date=Date()) {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            for id in notices(employee,now:now).filter({!$0.questions}).flatMap(\.messages) {if let message=messages[id] {markNoticeRead(message.key)}}
            return
        }
#endif
        history.readIntent?("all_notices",employee,nil); return
    }
    func header(_ employee:String)->(title:String,description:String) {
        if employee==HomeRoom.id {
            if let channel=homeChannel {return (channel.title,"#"+channel.title)}
            let value=memberState.value("title:"+HomeRoom.id).flatMap{$0.data(using:.utf8)}.flatMap{try? JSONDecoder().decode([String:String].self,from:$0)}
            return (value?["title"].flatMap{$0.isEmpty ? nil:$0} ?? "hejo",value?["description"] ?? "조직원들의 소식과 대화")
        }
        if let room=groups[employee] {return (room.title,room.description.flatMap{$0.isEmpty ? nil:$0} ?? "조직원들의 소식과 대화")}
        if let text=memberState.value("title:"+employee),let data=text.data(using:.utf8),let value=try? JSONDecoder().decode([String:String].self,from:data),let title=value["title"],!title.isEmpty {return (title,value["description"] ?? "")}
        return (room(for:employee)?.title ?? name(employee),"함께 나누는 대화")
    }
    func saveHeader(_ employee:String,title:String,description:String) {
        do {
            let data=try JSONEncoder().encode(["title":title,"description":description]);guard data.count<=4096 else{memberState.onFailure?(true);return}
            try memberState.set(["title:"+employee:title.isEmpty ? nil:String(data:data,encoding:.utf8)])
        } catch {memberState.onFailure?(true)}
    }
}
enum WorkspaceMention {
    static func toggle(_ text:String,name:String)->String {
        guard !name.isEmpty,let regex=try? NSRegularExpression(pattern:"@"+NSRegularExpression.escapedPattern(for:name)+#"(?![\p{L}\p{N}])"#) else{return text}
        let matches=regex.matches(in:text,range:NSRange(text.startIndex...,in:text))
        guard !matches.isEmpty else{return "@"+name+" "+text}
        var value=text
        for match in matches.reversed() {if let range=Range(match.range,in:value) {let end=range.upperBound<value.endIndex && value[range.upperBound]==" " ? value.index(after:range.upperBound):range.upperBound;value.removeSubrange(range.lowerBound..<end)}}
        return value
    }
}
