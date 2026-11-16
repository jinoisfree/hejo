import Foundation

struct Employee: Codable, Equatable, Identifiable {
    var id: String
    var name: String
    var aliases: [String]
    var avatar: String? = nil
    var color: String? = nil
    var avatarCustom: Bool? = nil
    var queued: Bool? = nil
    enum CodingKeys: String,CodingKey { case id,name,aliases,avatar,color,queued;case avatarCustom="avatar_custom" }
}
/// The UI's conversation unit. The roster is authoritative; this is its direct-room projection.
struct Room: Identifiable, Equatable, Codable {
    enum Kind: String, Codable { case direct,group }
    var id: String
    var kind: Kind
    var title: String
    var members: [String]
    var lead:String? = nil
    var picture:String? = nil
    var description:String? = nil
    var archived:Bool? = nil
    init(id:String,title:String,members:[String],lead:String,picture:String?=nil,description:String="",archived:Bool=false){self.id=id;kind = .group;self.title=title;self.members=members;self.lead=lead;self.picture=picture;self.description=description;self.archived=archived}
    init(from decoder:Decoder)throws {let c=try decoder.container(keyedBy:CodingKeys.self);id=try c.decode(String.self,forKey:.id);kind = try c.decodeIfPresent(Kind.self,forKey:.kind) ?? .group;title=try c.decode(String.self,forKey:.title);members=try c.decode([String].self,forKey:.members);lead=try c.decodeIfPresent(String.self,forKey:.lead);picture=try c.decodeIfPresent(String.self,forKey:.picture);description=try c.decodeIfPresent(String.self,forKey:.description);archived=try c.decodeIfPresent(Bool.self,forKey:.archived)}
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
    var finalized = false
    var seq: Int
    var latestSeq: Int
    var timestamp: String
    var clientMessageID: String?
    var checklist: ReplyChecklist? = nil
    var branchFrom: String? = nil
    var employee:String? = nil
    var speaker:String {employee ?? key.employee}
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
    private(set) var groups:[String:Room]=[:]
    var rooms: [Room] { employees.map(Room.init(employee:)) + groups.values.sorted{$0.title<$1.title} }
    var homeChannel:Room? {home.settings.channel.flatMap{groups[$0]}.flatMap{$0.archived==true ? nil:$0}}
    var homeScope:[String] {homeChannel.map{[$0.id]} ?? home.members.map(\.id)}
    func people(_ room:String)->[Employee] {let ids=groups[room]?.members;return employees.filter{ids?.contains($0.id) ?? true}}
    func room(for employee: String) -> Room? { rooms.first { $0.id==employee } }
    func unread(room: Room) -> Int { unread(employee:room.id) }
    func threads(room: Room, query: String = "") -> [ConversationThread] { threads(employee:room.id,query:query) }
    private(set) var messages: [String: ConversationMessage] = [:]
    private(set) var applied = 0
    private(set) var typing: [ConversationKey: Date] = [:]
    /// When each live typing indicator first turned on; refreshes keep it, expiry or `on:false` forget it.
    private(set) var typingPeople:[ConversationKey:[String:Date]]=[:]
    private(set) var typingSince: [ConversationKey: Date] = [:]
    private(set) var selected: ConversationKey?
    private(set) var visible = false
    private(set) var isHome=false
    var selectionIdentity:String {isHome ? HomeRoom.id:selected?.employee ?? ""}
    var home:HomeRoom {
        let settings=memberState.value("layout:home").flatMap{$0.data(using:.utf8)}.flatMap{try? JSONDecoder().decode(HomeRoom.Settings.self,from:$0)} ?? HomeRoom.Settings()
        return HomeRoom(settings:settings,employees:employees)
    }
    var homeRecipients:HomeRoom {var result=home;if let channel=homeChannel {result.settings.members=channel.members};return result}
    var petMuted:Set<String> {muted.union(home.settings.muted==true ? Set(home.members.map(\.id)+(homeChannel.map{[$0.id]} ?? [])):[])}
    func configureHome(_ update:(inout HomeRoom.Settings)->Void){var settings=home.settings;update(&settings);saveLayout("layout:home",settings)}
    func toggleHomeMember(_ employee:String){
        var ids=home.members.map(\.id);if let index=ids.firstIndex(of:employee){ids.remove(at:index)}else{ids.append(employee)}
        configureHome{$0.members=ids}
    }
    func selectHome(_ key:ConversationKey?=nil,notify:Bool=true){select(key ?? ConversationKey(employee:HomeRoom.id,thread:UUID().uuidString.lowercased()),notify:notify,inHome:true)}
    var homeThreads:[ConversationThread] {
        homeScope.flatMap{threads(employee:$0)}.sorted{a,b in
            let x=timeline(a.key).map{ThreadTools.date($0.timestamp)}.max() ?? .distantPast,y=timeline(b.key).map{ThreadTools.date($0.timestamp)}.max() ?? .distantPast
            return x==y ? a.id<b.id:x<y
        }
    }
    var onChange: (() -> Void)?
    var noticeClock:()->Date=Date.init
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
        layout.items=rooms.enumerated().filter { !hidden.contains($0.element.id) && $0.element.archived != true }.map { index,room in
            let posts=messages.values.filter { room.id==$0.key.employee }
            let latest=posts.map { (fractional.date(from:$0.timestamp) ?? seconds.date(from:$0.timestamp))?.timeIntervalSince1970 ?? Double($0.latestSeq) }.max() ?? 0
            return SidebarLayout.Item(id:room.id,name:room.title,kind:room.kind == .direct ? .direct:.group,members:room.members,rank:index,latest:latest,unread:unread(room:room),questions:notices(room.id).filter(\.questions).reduce(0){$0+$1.messages.count},alerts:notices(room.id).filter{!$0.questions}.reduce(0){$0+$1.messages.count},muted:muted.contains(room.id),picture:room.picture)
        }
        let memberIDs=homeChannel?.members ?? home.members.map(\.id),scope=homeScope,posts=messages.values.filter{scope.contains($0.key.employee)}
        layout.items.insert(.init(id:HomeRoom.id,name:store.settings.petName,kind:.home,members:memberIDs,latest:Double(posts.map(\.latestSeq).max() ?? 0),unread:scope.reduce(0){$0+unread(employee:$1)},muted:home.settings.muted==true,picture:home.settings.picture),at:0)
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
    var visibleUnreadTotal: Int { rooms.filter { !petMuted.contains($0.id) && !hidden.contains($0.id) }.reduce(0) { $0 + unread(room: $1) } }
    init(store: LocalStore) throws {
        self.store = store
        memberState = MemberState(store: store)
        for frame in store.records { try apply(frame) }
        loadingRecords = false
        memberState.onChange = { [weak self] in
            guard let self else { return }
            if self.isHome {
                if let key=self.selected,key.employee != HomeRoom.id,!self.homeScope.contains(key.employee) {self.selectHome(notify:false)}
            } else if let current = self.selected?.employee, self.hidden.contains(current) {
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
    func toggleMute(_ employee: String) { if employee==HomeRoom.id {configureHome{$0.muted = $0.muted != true};return};changeState(["mute:" + employee: muted.contains(employee) ? nil : "1"]) }
    func hide(_ employee: String) { changeState(["hide:" + employee: "1", "pin:" + employee: nil]) }
    func restore(_ employee: String) { changeState(["hide:" + employee: nil]) }
    func markAllRead(_ employee: String) {
        if employee==HomeRoom.id {for room in homeScope {markAllRead(room)};return}
        var values: [String: String?] = [:]
        let roomMessages = messages.values.filter { $0.key.employee == employee }
        values["read:" + employee] = String(roomMessages.map(\.latestSeq).max() ?? 0)
        for (key, messages) in Dictionary(grouping: roomMessages, by: \.key) {
            values["thread:" + key.employee + "/" + key.thread] = String(messages.map(\.latestSeq).max() ?? 0)
        }
        changeState(values);readAllNotices(employee)
    }
    func resetReplica() { groups=[:];messages = [:]; typingPeople=[:];typing = [:]; typingSince = [:]; applied = 0; selected = nil; isHome=false; onChange?() }
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
            case "room":
                if let data=frame["room"] as? [String:Any],let id=data["id"] as? String {
                    if data["deleted"] as? Bool == true {removeRoom(id)} else {
                        let room=try decode(data,as:Room.self);let previous=groups[id];groups[id]=room
                        if !loadingRecords,previous==nil,memberState.value("zone:"+id)==nil {move(id,to:sidebar.sections[0].id)}
                    }
                }
            case "room_deleted":if let id=frame["id"] as? String {removeRoom(id)}
            case "message":
                guard let id = frame["msg_id"] as? String, let employee = frame["employee"] as? String,
                      let thread = frame["thread"] as? String, let text = frame["text"] as? String,
                      let role = frame["role"] as? String, let ts = frame["ts"] as? String else { throw GateFailure.protocolError }
                let message = ConversationMessage(id: id, key: ConversationKey(employee: frame["room"] as? String ?? employee, thread: thread), role: role, text: text,
                    files: try decode(frame["files"] ?? [], as: [MessageFile].self), buttons: try decode(frame["buttons"] ?? [], as: [MessageButton].self),
                    replyState: frame["reply_state"] as? String, seq: seq, latestSeq: seq, timestamp: ts, clientMessageID: frame["client_msg_id"] as? String)
                messages[id] = message
                messages[id]?.employee=employee
                if let checklist=frame["checklist"] { messages[id]?.checklist=try decode(checklist,as:ReplyChecklist.self) }
                messages[id]?.branchFrom=(frame["branch_from"] as? [String:Any])?["thread"] as? String
                if !loadingRecords, hidden.contains(message.key.employee) { restore(message.key.employee); revealedHiddenRoom = true }
            case "edit":
                guard let id = frame["msg_id"] as? String, let text = frame["text"] as? String, let final = frame["final"] as? Bool else { throw GateFailure.protocolError }
                if var message = messages[id] {
                    message.text = text; message.streaming = !final; message.finalized = final; message.latestSeq = seq
                    if let buttons = frame["buttons"] { message.buttons = try decode(buttons, as: [MessageButton].self) }
                    if let checklist = frame["checklist"] { message.checklist = try decode(checklist, as: ReplyChecklist.self) }
                    messages[id] = message
                }
            case "delete":
                if frame["scope"] as? String == "thread",let room=frame["room"] as? String,let thread=frame["thread"] as? String {
                    let key=ConversationKey(employee:room,thread:thread)
                    messages=messages.filter { $0.value.key != key };typing[key]=nil;typingSince[key]=nil;typingPeople[key]=nil
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
            if type=="welcome",let rooms=frame["rooms"] as? [[String:Any]] {groups=try Dictionary(uniqueKeysWithValues:rooms.map{row in let room=try decode(row,as:Room.self);return(room.id,room)})}
            employees = try rows.map { row in try decode(row, as: Employee.self) }
            if let selected, !(isHome && selected.employee==HomeRoom.id), !rooms.contains(where: { $0.id == selected.employee }) { if isHome {selectHome(notify:false)} else {self.selected=nil} }
        } else if type == "typing", let employee = frame["employee"] as? String, let thread = frame["thread"] as? String {
            let key = ConversationKey(employee: frame["room"] as? String ?? employee, thread: thread)
            if frame["on"] as? Bool == true {
                if (typing[key].map { $0 <= now } ?? true) { typingSince[key] = now }
                let expiry=now.addingTimeInterval(TimeInterval(frame["ttl_seconds"] as? Int ?? 6));typingPeople[key,default:[:]][employee]=expiry;typing[key]=typingPeople[key]?.values.max()
            } else {typingPeople[key]?[employee]=nil;typing[key]=typingPeople[key]?.values.filter{$0>now}.max();if typing[key]==nil {typingSince[key]=nil}}
        }
        if selected == nil {if isHome {selectHome(notify:false)} else if let first=displayRooms.first {select(employee:first.id,notify:false)}}
        try markVisibleRead()
        onChange?()
    }
    /// Called only after a fresh welcome/current replay, never for historical room records.
    func clearArchivedPins(){for room in groups.values where room.archived==true && pinned.contains(room.id) {pin(room.id,slot:nil)}}
    private func removeRoom(_ id:String){
        groups[id]=nil;typingPeople=typingPeople.filter{$0.key.employee != id};messages=messages.filter{$0.value.key.employee != id};typing=typing.filter{$0.key.employee != id};typingSince=typingSince.filter{$0.key.employee != id}
        if selected?.employee==id {selected=nil}
        if pinned.contains(id) {pin(id,slot:nil)}
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
    func name(_ employee: String) -> String { if employee==HomeRoom.id {return store.settings.petName};return groups[employee]?.title ?? employees.first { $0.id == employee }?.name ?? employee }
    func select(employee: String, notify: Bool = true) {
        guard rooms.contains(where: { $0.id == employee }) else { return }
        select(threads(employee: employee).first?.key ?? ConversationKey(employee: employee, thread: UUID().uuidString.lowercased()), notify: notify)
    }
    func select(_ key: ConversationKey, notify: Bool = true,inHome:Bool=false) {
        isHome=inHome;selected = key; try? markVisibleRead(); if notify { onChange?() }
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
        typingPeople=typingPeople.mapValues{$0.filter{$0.value>now}}.filter{!$0.value.isEmpty}
        let kept = typing.filter { $0.value > now }
        if kept.count != typing.count { typing = kept; typingSince = typingSince.filter { kept[$0.key] != nil }; onChange?() }
    }
    static func click(message: ConversationMessage, button: MessageButton) throws -> [String: Any] {
        guard message.buttons.contains(button) else { throw GateFailure.protocolError }
        return ["v": 1, "type": "click", "id": UUID().uuidString.lowercased(), "msg_id": message.id, "button_id": button.id]
    }
}
