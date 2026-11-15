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
    var onPreferencesChanged: (() -> Void)?
    private(set) var pinned: [String]
    private(set) var muted: Set<String>
    private(set) var hidden: Set<String>
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
        pinned = store.settings.pinnedEmployees ?? []
        muted = Set(store.settings.mutedEmployees ?? [])
        hidden = Set(store.settings.hiddenEmployees ?? [])
        for frame in store.records { try apply(frame) }
        loadingRecords = false
    }
    private func persistPreferences(notifyHub: Bool = true) {
        try? store.update { $0.pinnedEmployees = pinned; $0.mutedEmployees = muted.sorted(); $0.hiddenEmployees = hidden.sorted() }
        onChange?(); if notifyHub { onPreferencesChanged?() }
    }
    func applyMemberSettings(_ settings: [String: String]) {
        func ids(_ value: String?) -> [String]? { value.map { $0.isEmpty ? [] : $0.split(separator: ",").map(String.init) } }
        if let ids = ids(settings["pinned"]) { var seen = Set<String>(); pinned = ids.filter { seen.insert($0).inserted } }
        if let ids = ids(settings["muted"]) { muted = Set(ids) }
        if let ids = ids(settings["hidden"]) { hidden = Set(ids) }
        if let current = selected?.employee, hidden.contains(current) {
            if let next = displayRooms.first { select(employee: next.id, notify: false) }
            else { selected = nil }
        }
        persistPreferences(notifyHub: false)
    }
    var preferenceSettings: [String: String] { ["pinned": pinned.joined(separator: ","), "muted": muted.sorted().joined(separator: ","), "hidden": hidden.sorted().joined(separator: ",")] }
    func togglePin(_ employee: String) {
        if let index = pinned.firstIndex(of: employee) { pinned.remove(at: index) }
        else { pinned.append(employee) }
        persistPreferences()
    }
    func toggleMute(_ employee: String) {
        if !muted.insert(employee).inserted { muted.remove(employee) }
        persistPreferences()
    }
    func hide(_ employee: String) {
        hidden.insert(employee); pinned.removeAll { $0 == employee }
        if selected?.employee == employee {
            if let next = displayRooms.first { select(employee: next.id, notify: false) }
            else { selected = nil }
        }
        persistPreferences()
    }
    func restore(_ employee: String) { hidden.remove(employee); persistPreferences() }
    func markAllRead(_ employee: String) {
        let groups = Dictionary(grouping: messages.values.filter { $0.key.employee == employee }, by: \.key)
        try? store.update { settings in
            for (key, values) in groups { settings.readSeq[key.readKey] = max(settings.readSeq[key.readKey] ?? 0, values.map(\.latestSeq).max() ?? 0) }
        }
        onChange?()
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
                if !loadingRecords, hidden.remove(employee) != nil { revealedHiddenRoom = true }
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
            if revealedHiddenRoom { persistPreferences() }
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
        let read = store.settings.readSeq[key.readKey] ?? 0
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
        guard seq > (store.settings.readSeq[selected.readKey] ?? 0) else { return }
        try store.update { $0.readSeq[selected.readKey] = seq }
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
