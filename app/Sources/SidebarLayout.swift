import Foundation

/// A projection of member state and rooms. No independent settings store.
struct SidebarLayout {
    struct Section: Codable, Equatable, Identifiable {
        var id: String
        var name: String = ""
        var open = false
        var picture: String?
    }
    struct Stack: Codable, Equatable { var name = ""; var open = false; var picture: String? }
    struct Item: Equatable {
        enum Kind { case home, group, direct }
        var id: String, name: String
        var kind: Kind
        var members: [String] = []
        var rank = 0
        var latest: Double = 0
        var unread = 0, questions = 0, alerts = 0
        var muted = false
        var picture: String?
    }
    struct Row {
        enum Kind { case home, room, section, stack, divider }
        var kind: Kind
        var id: String, name: String
        var zone: String? = nil
        var items: [Item] = []
        var open = false
        var picture: String?
        var unread: Int { items.filter { !($0.muted && (kind == .section || kind == .stack)) }.reduce(0) { $0+$1.unread } }
        var questions: Int { items.filter { !$0.muted || kind == .room }.reduce(0) { $0+$1.questions } }
        var alerts: Int { items.filter { !$0.muted || kind == .room }.reduce(0) { $0+$1.alerts } }
        var faces: [String] { var seen=Set<String>(); return Array(items.flatMap(\.members).filter { seen.insert($0).inserted }.prefix(4)) }
        var signals: [String] { [(unread,"unread"),(questions,"question"),(alerts,"alert")].filter { $0.0>0 }.map(\.1) }
    }
    static let defaults = (1...3).map { Section(id:String($0)) }
    var sections: [Section] = defaults
    var stack = Stack()
    var zones: [String: String] = [:]
    var pins: [String: Int] = [:]
    var items: [Item] = []
    func name(_ section: Section) -> String { section.name.isEmpty ? "section \((sections.firstIndex(where:{$0.id==section.id}) ?? 0)+1)" : section.name }
    var stackName: String { stack.name.isEmpty ? "section \(sections.count+1)" : stack.name }
    func zone(_ id: String) -> String { sections.first(where:{$0.id==zones[id]})?.id ?? sections.first?.id ?? "1" }
    var stacked: [Item] {
        items.filter { $0.kind == .direct && pins[$0.id] == nil }.sorted { ($0.rank,$0.name,$0.id)<($1.rank,$1.name,$1.id) }
    }
    func group(_ section: String) -> [Item] {
        Self.sorted(items.filter { $0.kind != .home && !($0.kind == .direct && pins[$0.id] == nil) && zone($0.id)==section }, pins:pins)
    }
    static func sorted(_ items: [Item], pins: [String: Int]) -> [Item] {
        let valid=pins.filter { (1...5).contains($0.value) }
        var held=[Int:Item](), pinned=Set<String>()
        for item in items.sorted(by:{$0.id<$1.id}) {
            if let slot=valid[item.id],held[slot]==nil { held[slot]=item;pinned.insert(item.id) }
        }
        var free=items.enumerated().filter { !pinned.contains($0.element.id) }.sorted {
            $0.element.latest == $1.element.latest ? $0.offset<$1.offset : $0.element.latest>$1.element.latest
        }.map(\.element)
        var result=[Item]()
        for slot in 1...max(5,items.count) {
            if let item=held[slot] { result.append(item) }
            else if !free.isEmpty { result.append(free.removeFirst()) }
        }
        return result
    }
    var rows: [Row] {
        var result=items.filter{$0.kind == .home}.map { Row(kind:.home,id:$0.id,name:$0.name,items:[$0],picture:$0.picture) }
        for (index,section) in sections.enumerated() {
            if index>0 { result.append(Row(kind:.divider,id:"divider:"+section.id,name:"",zone:section.id)) }
            let rooms=group(section.id)
            result.append(Row(kind:.section,id:"section:"+section.id,name:name(section),zone:section.id,items:rooms,open:section.open,picture:section.picture))
            if section.open { result += rooms.map { Row(kind:.room,id:$0.id,name:$0.name,zone:section.id,items:[$0],picture:$0.picture) } }
        }
        if !stacked.isEmpty {
            result.append(Row(kind:.divider,id:"divider:stack",name:""))
            result.append(Row(kind:.stack,id:"stack",name:stackName,items:stacked,open:stack.open,picture:stack.picture))
            if stack.open { result += stacked.map { Row(kind:.room,id:$0.id,name:$0.name,items:[$0],picture:$0.picture) } }
        }
        return result
    }
    func canMove(_ room: String, to section: String) -> Bool {
        sections.contains{$0.id==section} && items.contains{$0.id==room && $0.kind != .home} && !stacked.contains{$0.id==room}
    }
    func deletion(_ section: String) -> (title:String,body:String)? {
        guard let target=sections.first(where:{$0.id==section}),let first=sections.first(where:{$0.id != section}) else { return nil }
        let count=group(section).count
        return ("‘\(name(target))’ 섹션을 삭제할까요?", "섹션만 없어지고 방은 그대로예요."+(count>0 ? " 안에 있는 방 \(count)개는 ‘\(name(first))’로 옮겨져요." : ""))
    }
    static func badge(_ count: Int) -> String { count>99 ? "99+" : String(count) }
}
