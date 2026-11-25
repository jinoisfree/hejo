import AppKit

/// Frozen local search semantics used only as an independent test oracle.
extension WorkspaceSearch {
    struct Group {
        var key: ConversationKey
        var root: ConversationMessage
        var matches: [ConversationMessage]
        var exact: Bool
        var latest: Date { ThreadTools.date(matches.first?.timestamp ?? root.timestamp) }
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
        let term=normalized(query);guard !term.isEmpty else{return []}
        return messages.filter {line in
            let content=([line.text]+line.files.map(\.name)+[line.role=="owner" ? "나":names[line.speaker] ?? line.speaker,line.replyState.map(ThreadTools.stateLabel) ?? ""]).joined(separator:"\n")
            return normalized(content).contains(term)
        }.sorted{(ThreadTools.date($0.timestamp),$0.id)>(ThreadTools.date($1.timestamp),$1.id)}.prefix(30).map{$0}
    }
}
