import AppKit

/// Local search of the journal projection, with the original candidate budget before grouping.
enum WorkspaceSearch {
    struct Group {
        var key: ConversationKey
        var root: ConversationMessage
        var matches: [ConversationMessage]
        var exact: Bool
        var latest: Date { ThreadTools.date(matches.first?.timestamp ?? root.timestamp) }
    }
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
        for range in highlights(text,query:query) {result.addAttributes([.backgroundColor:NSColor.yellow,.foregroundColor:NSColor.black],range:NSRange(range,in:text))};return result
    }
    static func words(_ line:ConversationMessage,names:[String:String])->String {
        ([line.text]+line.files.map(\.name)+[line.role=="owner" ? "나":names[line.speaker] ?? line.speaker,line.replyState.map{ThreadTools.stateLabel($0)+" "+$0} ?? ""]).joined(separator:"\n")
    }
    static func preview(_ query:String,message:ConversationMessage)->(body:String,notes:[String]) {
        let terms=normalized(query).split(whereSeparator:\.isWhitespace).map(String.init)
        guard !terms.isEmpty,!terms.allSatisfy({normalized(message.text).contains($0)}) else{return(message.text,[])}
        let notes=message.files.map{"📎 "+$0.name}+[message.replyState.map(ThreadTools.stateLabel) ?? ""]
        return (message.text,notes.filter{note in terms.contains{normalized(note).contains($0)}})
    }
    static func groups(_ query:String,messages:[ConversationMessage],names:[String:String],hidden:Set<String>,limit:Int=200)->[Group] {
        let term=normalized(query),terms=normalized(query).split(whereSeparator:\.isWhitespace).map(String.init)
        guard !term.isEmpty else{return []}
        let visible=messages.filter{!hidden.contains($0.key.employee)}
        let roots=Dictionary(grouping:visible,by:\.key).mapValues{$0.min{$0.seq<$1.seq}!}
        let found=visible.filter{line in
            guard !ThreadTools.thinking(line.text) else{return false}
            let text=normalized(words(line,names:names))
            return text.contains(term) || terms.allSatisfy{text.contains($0)}
        }.sorted{(ThreadTools.date($0.timestamp),$0.id)>(ThreadTools.date($1.timestamp),$1.id)}
        return Dictionary(grouping:Array(found.prefix(max(0,limit))),by:\.key).map{key,lines in
            Group(key:key,root:roots[key]!,matches:lines,exact:lines.contains{line in normalized(words(line,names:names)).contains(term)})
        }.sorted{if $0.exact != $1.exact {return $0.exact};return ($0.latest,$0.key.readKey)>($1.latest,$1.key.readKey)}
    }
    static func sidebar(_ query:String,messages:[ConversationMessage],names:[String:String],hidden:Set<String>)->[ConversationMessage] {
        groups(query,messages:messages,names:names,hidden:hidden,limit:Int.max).flatMap(\.matches).sorted{(ThreadTools.date($0.timestamp),$0.id)>(ThreadTools.date($1.timestamp),$1.id)}.prefix(30).map{$0}
    }
}
struct RoomNotice: Equatable {
    var id:String, title:String
    var questions:Bool
    var messages:[String]
}
@MainActor extension ConversationModel {
    func notices(_ employee:String,now:Date?=nil)->[RoomNotice] {
        let now=now ?? noticeClock()
        var result:[RoomNotice]=[]
        let scope=employee==HomeRoom.id ? homeScope:[employee]
        let ordered=scope.flatMap{threads(employee:$0)}.sorted{a,b in
            let x=timeline(a.key).first!,y=timeline(b.key).first!
            return (ThreadTools.date(x.timestamp),x.seq)<(ThreadTools.date(y.timestamp),y.seq)
        }
        for thread in ordered {
            let posts=timeline(thread.key).filter{$0.role=="owner" || !ThreadTools.thinking($0.text)},state=assessment(thread.key)
            guard let root=posts.first,posts.last?.role != "owner",!state.working,!state.settled,!(state.request.map{confirmed($0.id)} ?? false),memberState.read("bell:"+thread.key.employee+"/"+thread.key.thread)<originalSeq(thread.key) else{continue}
            let id:String,title:String,message:String,questions:Bool
            if let asked=state.pending {id="question:"+asked.speaker;title=name(asked.speaker)+" 질문";message=asked.id;questions=true}
            else if state.request==nil,root.role=="employee",!posts.contains(where:{$0.role=="owner"}),now>=ThreadTools.date(root.timestamp),now.timeIntervalSince(ThreadTools.date(root.timestamp))<86400 {id="alert";title="알림";message=root.id;questions=false}
            else {continue}
            if let i=result.firstIndex(where:{$0.id==id}) {result[i].messages.append(message)} else {result.append(.init(id:id,title:title,questions:questions,messages:[message]))}
        }
        return result.filter(\.questions)+result.filter{!$0.questions}
    }
    func markAlertSeen(_ key:ConversationKey) {
        if notices(key.employee).filter({!$0.questions}).flatMap(\.messages).contains(where:{messages[$0]?.key==key}) {markNoticeRead(key)}
    }
    func markNoticeRead(_ key:ConversationKey) {
        let seq=String(originalSeq(key))
        try? memberState.set(["bell:"+key.employee+"/"+key.thread:seq,"thread:"+key.employee+"/"+key.thread:seq])
    }
    func readAllNotices(_ employee:String,now:Date=Date()) { for id in notices(employee,now:now).filter({!$0.questions}).flatMap(\.messages) {if let message=messages[id] {markNoticeRead(message.key)}} }
    func header(_ employee:String)->(title:String,description:String) {
        if let room=groups[employee] {return (room.title,room.description ?? "")}
        if employee==HomeRoom.id,let channel=homeChannel {return ("#"+channel.title,channel.description ?? "")}
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
