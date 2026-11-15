import Foundation

struct Employee: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var aliases: [String]
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
    var displayRooms: [Room] {
        rooms.filter { !hidden.contains($0.id) }.sorted { left, right in
            let a = pinned.firstIndex(of: left.id), b = pinned.firstIndex(of: right.id)
            if let a, let b { return a < b }
            if a != nil { return true }; if b != nil { return false }
            return (employees.firstIndex(where: { $0.id == left.id }) ?? Int.max) < (employees.firstIndex(where: { $0.id == right.id }) ?? Int.max)
        }
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
                if !loadingRecords, hidden.contains(employee) { restore(employee); revealedHiddenRoom = true }
            case "edit":
                guard let id = frame["msg_id"] as? String, let text = frame["text"] as? String, let final = frame["final"] as? Bool else { throw GateFailure.protocolError }
                if var message = messages[id] {
                    message.text = text; message.streaming = !final; message.latestSeq = seq
                    if let buttons = frame["buttons"] { message.buttons = try decode(buttons, as: [MessageButton].self) }
                    messages[id] = message
                }
            case "delete": if let id = frame["msg_id"] as? String { messages[id] = nil }
            case "state":
                if let id = frame["msg_id"] as? String, var message = messages[id] {
                    message.replyState = frame["reply_state"] as? String; message.latestSeq = seq; messages[id] = message
                }
            default: throw GateFailure.protocolError
            }
            applied = seq
            if revealedHiddenRoom { onChange?() }
        } else if type == "welcome" || type == "roster" {
            let rows = frame["employees"] as? [[String: Any]] ?? []
            employees = try rows.map { row in try decode(row.filter { $0.key != "avatar" }, as: Employee.self) }
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
