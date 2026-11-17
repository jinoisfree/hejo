import AppKit

/// Disposable rendering calculations. Journal text and file ownership remain authoritative.
enum CardText {
    static func quiet(dark:Bool)->NSColor {
        var result=NSColor(white:dark ? 1:0,alpha:0.595)
        NSAppearance(named:dark ? .darkAqua:.aqua)?.performAsCurrentDrawingAppearance {
            if let primary=NSColor.labelColor.usingColorSpace(.sRGB) {result=primary.withAlphaComponent(primary.alphaComponent*0.7)}
        };return result
    }
    static func mayOpen(_ url: URL) -> Bool { ["http", "https", "mailto", "obsidian"].contains(url.scheme?.lowercased() ?? "") }

    private static let bareLink = try? NSRegularExpression(pattern: #"\b(?:https?|obsidian)://[^\s<>"]+"#, options: .caseInsensitive)
    private static let linkCharacters = CharacterSet.urlQueryAllowed.union(CharacterSet(charactersIn: "%#[]"))

    /// Add bare links to an already parsed native body without parsing Markdown again.
    static func linkifiedNative(_ text: NSAttributedString) -> NSAttributedString {
        guard let bareLink else { return text }
        let plain = text.string
        let result = NSMutableAttributedString(attributedString: text)
        for match in bareLink.matches(in: plain, range: NSRange(plain.startIndex..., in: plain)) {
            guard var range = Range(match.range, in: plain) else { continue }
            while let last = plain[range].last, ".,;:!?)]}'\"…*".contains(last) { range = range.lowerBound..<plain.index(before: range.upperBound) }
            guard !range.isEmpty, let url = String(plain[range]).addingPercentEncoding(withAllowedCharacters: linkCharacters).flatMap(URL.init(string:)) else { continue }
            let nativeRange = NSRange(range, in: plain)
            var linked = false
            result.enumerateAttribute(.link, in: nativeRange) { value, _, _ in if value != nil { linked = true } }
            if !linked { result.addAttribute(.link, value: url, range: nativeRange) }
        }
        return result
    }

    static func sizeText(_ bytes: Int) -> String {
        if bytes <= 0 { return "" }
        if bytes < 1024 { return "\(bytes)B" }
        let units = ["KB", "MB", "GB"]
        var value = Double(bytes) / 1024, unit = 0
        while value >= 1024, unit < units.count - 1 { value /= 1024; unit += 1 }
        return (value < 10 ? String(format: "%.1f", value) : String(Int(value.rounded()))) + units[unit]
    }
    static func fittedRules(_ text:String)->String {
        text.components(separatedBy:"\n").map { line in
            let bare=line.trimmingCharacters(in:.whitespaces)
            return bare.count>15 && bare.allSatisfy{$0=="─"} ? String(repeating:"─",count:15):line
        }.joined(separator:"\n")
    }
    static func uniformSize(_ text:NSMutableAttributedString) {
        text.enumerateAttribute(.font,in:NSRange(location:0,length:text.length)) { value,range,_ in
            if text.attributedSubstring(from:range).string=="\u{200B}" {return}
            let font=value as? NSFont ?? .systemFont(ofSize:ChatMetrics.bodyFont)
            text.addAttribute(.font,value:NSFontManager.shared.convert(font,toSize:NSFontManager.shared.traits(of:font).contains(.fixedPitchFontMask) ? ChatMetrics.bodyFont-1:ChatMetrics.bodyFont),range:range)
        }
    }
    static func day(_ date:Date)->String {
        let f=DateFormatter();f.dateStyle = .medium;f.timeStyle = .none;f.doesRelativeDateFormatting=true;return f.string(from:date)
    }
}

/// StreamPreview's local reveal, adapted to journal message IDs; never writes a message.
struct StreamReveal {
    private struct State {var body:String;var characters:[Character];var count:Int;var start:Int;var at:Double;var duration:Double}
    private var states:[String:State]=[:]
    mutating func receive(_ messages:[ConversationMessage],now:Double) {
        let ids=Set(messages.filter { message in
            message.streaming || states[message.id].map{$0.count<$0.characters.count && now-$0.at<$0.duration} == true
        }.map(\.id));states=states.filter{ids.contains($0.key)}
        for message in messages where !message.streaming {
            guard var state=states[message.id],state.body != message.text else{continue}
            let old=max(1,state.characters.count);state.characters=Array(message.text);state.body=message.text
            state.count=min(state.characters.count,Int(ceil(Double(state.characters.count)*Double(state.count)/Double(old))))
            state.start=min(state.count,Int(ceil(Double(state.characters.count)*Double(state.start)/Double(old))));states[message.id]=state
        }
        for message in messages where message.streaming {
            if states[message.id]?.body==message.text {continue}
            let chars=Array(message.text),count=min(states[message.id]?.count ?? 1,chars.count)
            states[message.id]=State(body:message.text,characters:chars,count:count,start:count,at:now,duration:min(3,max(0.35,Double(chars.count-count)/150)))
        }
    }
    mutating func frame(_ id:String,now:Double,immediately:Bool)->String? {
        guard var state=states[id] else{return nil}
        let fraction=immediately ? 1:min(1,max(0,(now-state.at)/state.duration))
        state.count=max(state.count,state.start+Int(ceil(Double(state.characters.count-state.start)*fraction)));states[id]=state
        return Self.visiblePrefix(String(state.characters.prefix(state.count)))
    }
    mutating func advance(now:Double,immediately:Bool) {for id in Array(states.keys) {_ = frame(id,now:now,immediately:immediately)}}
    func revealing(_ id:String)->Bool {states[id].map{$0.count<$0.characters.count} ?? false}
    var pending:Bool {states.values.contains{$0.count<$0.characters.count}}
    static func visiblePrefix(_ body: String) -> String {
        let body = withoutOpenLink(body)
        // Do not briefly draw a half-received rich-text tag as a long line and
        // then remove it when '>' arrives. Completed tags use the normal renderer.
        guard let start = body.lastIndex(of: "<"), !body[start...].contains(">") else { return body }
        let tail = body[start...].lowercased()
        let tags = ["<span", "</span", "<b", "</b", "<strong", "</strong", "<i", "</i", "<em", "</em", "<u", "</u", "<s", "</s", "<del", "</del"]
        if tags.contains(where: { $0.hasPrefix(tail) || tail == $0 || tail.hasPrefix($0 + " ") })
            || ["<http", "<mailto"].contains(where: { tail.hasPrefix($0) || $0.hasPrefix(tail) && tail.count > 1 }) {
            return String(body[..<start])
        }
        return body
    }
    /// A Markdown link whose address is still arriving shows only its words. Drawn raw, the address
    /// stretched the line for a moment, and the answer kept that extra height into its final form.
    private static func withoutOpenLink(_ body: String) -> String {
        guard let middle = body.range(of: "](", options: .backwards),
              !body[middle.upperBound...].contains(")"), !body[middle.upperBound...].contains("\n"),
              let open = body[..<middle.lowerBound].lastIndex(of: "["),
              !body[body.index(after: open)..<middle.lowerBound].contains("]") else { return body }
        return String(body[..<open]) + String(body[body.index(after: open)..<middle.lowerBound])
    }
}
