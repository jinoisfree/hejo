import Foundation

struct Employee: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var aliases: [String]
    var avatar: String? = nil
    var color: String? = nil
    var avatarCustom: Bool? = nil
    enum CodingKeys: String,CodingKey { case id,name,aliases,avatar,color;case avatarCustom="avatar_custom" }
}
/// The UI's conversation unit. The roster is authoritative; this is its direct-room projection.
struct Room: Identifiable, Equatable {
    enum Kind: String { case direct }
    var id: String
    var kind: Kind
    var title: String
    var members: [String]
    init(employee: Employee) { id=employee.id; kind = .direct; title=employee.name; members=[employee.id] }
}
struct ConversationKey: Hashable {
    var employee: String
    var thread: String
    var readKey: String { employee + ":" + thread }
}
struct MessageFile: Codable, Equatable, Identifiable {
    var fileID: String
    var name: String
    var mime: String
    var size: Int
    var id: String { fileID }
    enum CodingKeys: String, CodingKey { case fileID = "file_id", name, mime, size }
}
struct MessageButton: Codable, Equatable, Identifiable {
    var id: String
    var label: String
    var kind: String
    var style: String
}
struct ConversationMessage: Identifiable, Equatable {
    var id: String
    var key: ConversationKey
    var role: String
    var text: String
    var files: [MessageFile]
    var buttons: [MessageButton]
    var replyState: String?
    var streaming = false
    var seq: Int
    var latestSeq: Int
    var timestamp: String
    var clientMessageID: String?
    var checklist: ReplyChecklist? = nil
    var branchFrom: String? = nil
}
struct ReplyChecklist: Codable, Equatable {
    var items: [String]
    var selected: [String]
    var canSkip: Bool
    enum CodingKeys:String,CodingKey { case items,selected;case canSkip="can_skip" }
}
struct ConversationThread: Identifiable {
    var key: ConversationKey
    var title: String
    var preview: String
    var latestSeq: Int
    var id: String { key.thread }
}
/// The gateway journal is the authority. This projection is rebuilt from the durable frame replica.
@MainActor final class ConversationModel {
    let store: LocalStore
    private(set) var employees: [Employee] = []
    var rooms: [Room] { employees.map(Room.init(employee:)) }
    func room(for employee: String) -> Room? { rooms.first { $0.members.contains(employee) } }
    func unread(room: Room) -> Int { room.members.reduce(0) { $0 + unread(employee: $1) } }
    func threads(room: Room, query: String = "") -> [ConversationThread] { room.members.flatMap { threads(employee: $0, query: query) } }
    private(set) var messages: [String: ConversationMessage] = [:]
    private(set) var applied = 0
    private(set) var typing: [ConversationKey: Date] = [:]
    /// When each live typing indicator first turned on; refreshes keep it, expiry or `on:false` forget it.
    private(set) var typingSince: [ConversationKey: Date] = [:]
    private(set) var selected: ConversationKey?
    private(set) var visible = false
    var onChange: (() -> Void)?
    let memberState: MemberState
    var pinned: [String] {
        var slots: [String: Int] = [:]
        if store.settings.stateAccount == nil {
            for (index, room) in (store.settings.pinnedEmployees ?? []).prefix(5).enumerated() { slots[room] = index+1 }
        }
        for (key, entry) in memberState.items where key.hasPrefix("pin:") {
            let slot = Int(entry.v ?? "") ?? 0
            slots[String(key.dropFirst(4))] = (1...5).contains(slot) ? slot : nil
        }
        return slots.sorted { ($0.value, $0.key) < ($1.value, $1.key) }.map(\.key)
    }
    var muted: Set<String> { flagged("mute:", legacy: store.settings.mutedEmployees) }
    var hidden: Set<String> { flagged("hide:", legacy: store.settings.hiddenEmployees) }
    private func flagged(_ prefix: String, legacy: [String]?) -> Set<String> {
        var result = Set(store.settings.stateAccount == nil ? legacy ?? [] : [])
        for (key, entry) in memberState.items where key.hasPrefix(prefix) {
            let room = String(key.dropFirst(prefix.count)); if entry.v != nil { result.insert(room) } else { result.remove(room) }
        }
        return result
    }
    private var loadingRecords = true
    var sidebar: SidebarLayout {
        func decoded<T:Decodable>(_ key:String,_ fallback:T) -> T { memberState.value(key).flatMap { $0.data(using:.utf8) }.flatMap { try? JSONDecoder().decode(T.self,from:$0) } ?? fallback }
        var layout=SidebarLayout()
        let sections=decoded("layout:sections",SidebarLayout.defaults)
        if !sections.isEmpty { var ids=Set<String>();layout.sections=sections.filter { !$0.id.isEmpty && ids.insert($0.id).inserted } }
        if layout.sections.isEmpty { layout.sections=SidebarLayout.defaults }
        layout.stack=decoded("layout:stack",SidebarLayout.Stack())
        for (key,entry) in memberState.items {
            if key.hasPrefix("zone:"),let value=entry.v { layout.zones[String(key.dropFirst(5))]=value }
            if key.hasPrefix("pin:"),let value=entry.v,let slot=Int(value),(1...5).contains(slot) { layout.pins[String(key.dropFirst(4))]=slot }
        }
        for (index,id) in pinned.enumerated() where layout.pins[id]==nil { layout.pins[id]=index+1 }
        let fractional=ISO8601DateFormatter();fractional.formatOptions=[.withInternetDateTime,.withFractionalSeconds]
        let seconds=ISO8601DateFormatter()
        layout.items=rooms.enumerated().filter { !hidden.contains($0.element.id) }.map { index,room in
            let posts=messages.values.filter { room.members.contains($0.key.employee) }
            let latest=posts.map { (fractional.date(from:$0.timestamp) ?? seconds.date(from:$0.timestamp))?.timeIntervalSince1970 ?? Double($0.latestSeq) }.max() ?? 0
            return SidebarLayout.Item(id:room.id,name:room.title,kind:.direct,members:room.members,rank:index,latest:latest,unread:unread(room:room),questions:posts.filter { $0.replyState=="asked" && !confirmed($0.id) }.count,muted:muted.contains(room.id))
        }
        return layout
    }
    private func saveLayout<T:Encodable>(_ key:String,_ value:T) {
        if let data=try? JSONEncoder().encode(value),let json=String(data:data,encoding:.utf8) {
            guard data.count<=4096 else { memberState.onFailure?(true);return }
            changeState([key:json])
        }
    }
    func toggleSection(_ id:String?) {
        var layout=sidebar
        if let id,let index=layout.sections.firstIndex(where:{$0.id==id}) { layout.sections[index].open.toggle();saveLayout("layout:sections",layout.sections) }
        else if id==nil { layout.stack.open.toggle();saveLayout("layout:stack",layout.stack) }
    }
    func addSection() {
        var sections=sidebar.sections
        let next=(sections.compactMap { Int($0.id) }+[4]).max()!+1
        sections.append(.init(id:String(next)));saveLayout("layout:sections",sections)
    }
    func editSection(_ id:String?,name:String?=nil,picture:String?=nil,clearPicture:Bool=false) {
        var layout=sidebar
        if let id,let index=layout.sections.firstIndex(where:{$0.id==id}) {
            if let name { layout.sections[index].name=String(name.prefix(30)) }
            if picture != nil || clearPicture { layout.sections[index].picture=picture }
            saveLayout("layout:sections",layout.sections)
        } else if id==nil { if let name { layout.stack.name=String(name.prefix(30)) };saveLayout("layout:stack",layout.stack) }
    }
    func removeSection(_ id:String) {
        let layout=sidebar
        guard layout.sections.count>1,layout.sections.contains(where:{$0.id==id}),let first=layout.sections.first(where:{$0.id != id}) else { return }
        let remaining=layout.sections.filter{$0.id != id}
        guard let data=try? JSONEncoder().encode(remaining),let value=String(data:data,encoding:.utf8) else { return }
        var changes:[String:String?]=["layout:sections":value]
        for (room,zone) in layout.zones where zone==id { changes["zone:"+room]=first.id }
        changeState(changes)
    }
    func move(_ id:String,to section:String) { if sidebar.canMove(id,to:section) { changeState(["zone:"+id:section]) } }
    func pin(_ id:String,slot:Int?) {
        if let slot,!(1...5).contains(slot) { return }
        var changes:[String:String?]=["pin:"+id:slot.map(String.init)]
        if let slot { for (other,position) in sidebar.pins where position==slot && other != id { changes["pin:"+other] = .some(nil) } }
        changeState(changes)
    }
    var displayRooms: [Room] {
        let layout=sidebar,ordered=layout.sections.flatMap { layout.group($0.id) }+layout.stacked
        return ordered.compactMap { item in rooms.first{$0.id==item.id} }
    }
    var visibleUnreadTotal: Int { rooms.filter { !muted.contains($0.id) && !hidden.contains($0.id) }.reduce(0) { $0 + unread(room: $1) } }
    init(store: LocalStore) throws {
        self.store = store
        memberState = MemberState(store: store)
        for frame in store.records { try apply(frame) }
        loadingRecords = false
        memberState.onChange = { [weak self] in
            guard let self else { return }
            if let current = self.selected?.employee, self.hidden.contains(current) {
                if let next = self.displayRooms.first { self.select(employee: next.id, notify: false) }
                else { self.selected = nil }
            }
            self.onChange?()
        }
    }
    private func changeState(_ values: [String: String?]) {
        do { try memberState.set(values) } catch { memberState.onFailure?(true) }
    }
    func togglePin(_ employee: String) {
        if pinned.contains(employee) { changeState(["pin:" + employee: nil]) }
        else {
            let used = Set(pinned.enumerated().map { index, room in memberState.value("pin:" + room).flatMap(Int.init) ?? index+1 })
            if let free = (1...5).first(where: { !used.contains($0) }) { changeState(["pin:" + employee: String(free)]) }
        }
    }
    func toggleMute(_ employee: String) { changeState(["mute:" + employee: muted.contains(employee) ? nil : "1"]) }
    func hide(_ employee: String) { changeState(["hide:" + employee: "1", "pin:" + employee: nil]) }
    func restore(_ employee: String) { changeState(["hide:" + employee: nil]) }
    func markAllRead(_ employee: String) {
        var values: [String: String?] = [:]
        let roomMessages = messages.values.filter { $0.key.employee == employee }
        values["read:" + employee] = String(roomMessages.map(\.latestSeq).max() ?? 0)
        for (key, messages) in Dictionary(grouping: roomMessages, by: \.key) {
            values["thread:" + key.employee + "/" + key.thread] = String(messages.map(\.latestSeq).max() ?? 0)
        }
        changeState(values)
    }
    func resetReplica() { messages = [:]; typing = [:]; typingSince = [:]; applied = 0; selected = nil; onChange?() }
    private func decode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
    }
    func apply(_ frame: [String: Any], now: Date = Date()) throws {
        let type = frame["type"] as? String ?? ""
        if let seq = frame["seq"] as? Int {
            var revealedHiddenRoom = false
            if seq <= applied { return }
            guard seq == applied + 1 else { throw GateFailure.protocolError }
            switch type {
            case "message":
                guard let id = frame["msg_id"] as? String, let employee = frame["employee"] as? String,
                      let thread = frame["thread"] as? String, let text = frame["text"] as? String,
                      let role = frame["role"] as? String, let ts = frame["ts"] as? String else { throw GateFailure.protocolError }
                let message = ConversationMessage(id: id, key: ConversationKey(employee: employee, thread: thread), role: role, text: text,
                    files: try decode(frame["files"] ?? [], as: [MessageFile].self), buttons: try decode(frame["buttons"] ?? [], as: [MessageButton].self),
                    replyState: frame["reply_state"] as? String, seq: seq, latestSeq: seq, timestamp: ts, clientMessageID: frame["client_msg_id"] as? String)
                messages[id] = message
                if let checklist=frame["checklist"] { messages[id]?.checklist=try decode(checklist,as:ReplyChecklist.self) }
                messages[id]?.branchFrom=(frame["branch_from"] as? [String:Any])?["thread"] as? String
                if !loadingRecords, hidden.contains(employee) { restore(employee); revealedHiddenRoom = true }
            case "edit":
                guard let id = frame["msg_id"] as? String, let text = frame["text"] as? String, let final = frame["final"] as? Bool else { throw GateFailure.protocolError }
                if var message = messages[id] {
                    message.text = text; message.streaming = !final; message.latestSeq = seq
                    if let buttons = frame["buttons"] { message.buttons = try decode(buttons, as: [MessageButton].self) }
                    if let checklist = frame["checklist"] { message.checklist = try decode(checklist, as: ReplyChecklist.self) }
                    messages[id] = message
                }
            case "delete":
                if frame["scope"] as? String == "thread",let room=frame["room"] as? String,let thread=frame["thread"] as? String {
                    let key=ConversationKey(employee:room,thread:thread)
                    messages=messages.filter { $0.value.key != key };typing[key]=nil;typingSince[key]=nil
                    if selected==key { selected=nil }
                } else if let id = frame["msg_id"] as? String { messages[id] = nil }
            case "state":
                if let id = frame["msg_id"] as? String, var message = messages[id] {
                    message.replyState = frame["reply_state"] as? String; message.latestSeq = seq; messages[id] = message
                }
            default: break // Future durable kinds still advance the contiguous replica cursor.
            }
            applied = seq
            if revealedHiddenRoom { onChange?() }
        } else if type == "welcome" || type == "roster" {
            let rows = frame["employees"] as? [[String: Any]] ?? []
            employees = try rows.map { row in try decode(row, as: Employee.self) }
            if let selected, !employees.contains(where: { $0.id == selected.employee }) { self.selected = nil }
        } else if type == "typing", let employee = frame["employee"] as? String, let thread = frame["thread"] as? String {
            let key = ConversationKey(employee: employee, thread: thread)
            if frame["on"] as? Bool == true {
                if (typing[key].map { $0 <= now } ?? true) { typingSince[key] = now }
                typing[key] = now.addingTimeInterval(TimeInterval(frame["ttl_seconds"] as? Int ?? 6))
            } else { typing[key] = nil; typingSince[key] = nil }
        }
        if selected == nil, let first = displayRooms.first { select(employee: first.id, notify: false) }
        try markVisibleRead()
        onChange?()
    }
    func threads(employee: String, query: String = "") -> [ConversationThread] {
        let grouped = Dictionary(grouping: messages.values.filter { $0.key.employee == employee }, by: \.key)
        let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
        return grouped.compactMap { key, values in
            let ordered = values.sorted { $0.seq < $1.seq }
            guard term.isEmpty || ordered.contains(where: { $0.text.localizedCaseInsensitiveContains(term) }) else { return nil }
            let title = String((ordered.first?.text.isEmpty == false ? ordered.first!.text : ordered.first?.files.first?.name ?? "대화").prefix(48)).replacingOccurrences(of: "\n", with: " ")
            return ConversationThread(key: key, title: title, preview: String(ordered.last?.text.prefix(80) ?? ""), latestSeq: values.map(\.latestSeq).max() ?? 0)
        }.sorted { $0.latestSeq > $1.latestSeq }
    }
    func timeline(_ key: ConversationKey) -> [ConversationMessage] { messages.values.filter { $0.key == key }.sorted { $0.seq < $1.seq } }
    func unread(_ key: ConversationKey) -> Int {
        let read = max(memberState.read("read:" + key.employee), memberState.read("thread:" + key.employee + "/" + key.thread), store.settings.readSeq?[key.readKey] ?? 0)
        return messages.values.filter { $0.key == key && $0.role == "employee" && $0.latestSeq > read }.count
    }
    func bell(_ key:ConversationKey) -> Bool? {
        let latest=timeline(key).filter{$0.role=="employee"}.map(\.latestSeq).max() ?? 0
        guard latest>0 else { return nil }
        let value=memberState.read("bell:"+key.employee+"/"+key.thread)
        if value>=latest { return false }
        if memberState.items["bell:"+key.employee+"/"+key.thread] != nil || unread(key)>0 { return true }
        return nil
    }
    func toggleBell(_ key:ConversationKey) {
        let name="bell:"+key.employee+"/"+key.thread
        if bell(key)==false { changeState([name:nil]) }
        else {
            let seq=String(timeline(key).map(\.latestSeq).max() ?? 0)
            changeState([name:seq,"thread:"+key.employee+"/"+key.thread:seq])
        }
    }
    func confirm(_ message:ConversationMessage) { changeState(["confirm:"+message.id:"1"]) }
    func confirmed(_ id:String)->Bool { memberState.value("confirm:"+id) != nil }
    func check(_ id:String,line:Int,original:Bool)->Bool { memberState.value("check:"+id+":"+String(line)).map{$0=="1"} ?? original }
    func toggleCheck(_ id:String,line:Int,original:Bool) { changeState(["check:"+id+":"+String(line):check(id,line:line,original:original) ? "0":"1"]) }
    func unread(employee: String) -> Int { Set(messages.values.filter { $0.key.employee == employee }.map(\.key)).reduce(0) { $0 + unread($1) } }
    func name(_ employee: String) -> String { employees.first { $0.id == employee }?.name ?? employee }
    func select(employee: String, notify: Bool = true) {
        guard employees.contains(where: { $0.id == employee }) else { return }
        select(threads(employee: employee).first?.key ?? ConversationKey(employee: employee, thread: UUID().uuidString.lowercased()), notify: notify)
    }
    func select(_ key: ConversationKey, notify: Bool = true) {
        selected = key; try? markVisibleRead(); if notify { onChange?() }
    }
    func newThread() { if let selected { select(ConversationKey(employee: selected.employee, thread: UUID().uuidString.lowercased())) } }
    func setVisible(_ value: Bool) { visible = value; try? markVisibleRead(); onChange?() }
    private func markVisibleRead() throws {
        guard visible, let selected else { return }
        let seq = timeline(selected).map(\.latestSeq).max() ?? 0
        let key = "thread:" + selected.employee + "/" + selected.thread
        guard seq > memberState.read(key) else { return }
        try memberState.set([key: String(seq)])
    }
    func expireTyping(now: Date = Date()) {
        let kept = typing.filter { $0.value > now }
        if kept.count != typing.count { typing = kept; typingSince = typingSince.filter { kept[$0.key] != nil }; onChange?() }
    }
    static func click(message: ConversationMessage, button: MessageButton) throws -> [String: Any] {
        guard message.buttons.contains(button) else { throw GateFailure.protocolError }
        return ["v": 1, "type": "click", "id": UUID().uuidString.lowercased(), "msg_id": message.id, "button_id": button.id]
    }
}
