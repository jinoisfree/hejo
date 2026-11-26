import Foundation
import CryptoKit

struct OwnerProfile: Decodable, Equatable {
    static let fallbackName = "사장"
    var name: String?
    var avatar: String?

    static func normalized(_ input: String) throws -> String? {
        if input.unicodeScalars.contains(where: { scalar in
            switch scalar.properties.generalCategory {
            case .control, .format, .surrogate, .privateUse, .unassigned, .lineSeparator, .paragraphSeparator:
                return true
            default:
                return false
            }
        }) { throw OwnerProfileFailure.invalidName }
        let name = input.trimmingCharacters(in: .whitespaces)
        guard name.unicodeScalars.count <= 20 else { throw OwnerProfileFailure.invalidName }
        return name.isEmpty ? nil : name
    }
}

enum OwnerProfileFailure: Error { case invalidName }

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
struct ConversationKey: Hashable, Codable {
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
struct ConversationMessage: Identifiable, Equatable, Codable {
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
    var answerTo:String? = nil
    var pending = false
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
    private(set) var owner: OwnerProfile?
    private(set) var ownerRevision = 0
    var ownerName: String { owner?.name ?? OwnerProfile.fallbackName }

    func setOwner(_ profile: OwnerProfile?, notify: Bool = true) {
        guard owner != profile else { return }
        owner = profile
        ownerRevision += 1
        if notify { onChange?() }
    }
    var history = HistoryProjection() { didSet { invalidateRenderValues() } }
    var historyAggregatesReady: Bool { (memberState.account.isEmpty || memberState.hasFetched) && !history.refreshing && rooms.allSatisfy{history.totals[$0.id] != nil} }
    private var bodyCache: HistoryCache?
    private(set) var residentBudget = HistoryResidentBudget()
    private let initialResidentBudget: HistoryResidentBudget
    struct EvictedBody { let key:ConversationKey; let seq:Int }
    private(set) var evictedHistoryBodies: [String:EvictedBody] = [:]
    var historyRestorePin: String?
    func evictedHistoryBody(_ key:ConversationKey,before:Int?=nil,after:Int?=nil) -> String? {
        let candidates=evictedHistoryBodies.filter {$0.value.key==key && (before == nil || $0.value.seq < before!) && (after == nil || $0.value.seq > after!)}
        if after != nil {return candidates.min {($0.value.seq,$0.key)<($1.value.seq,$1.key)}?.key}
        return candidates.max {($0.value.seq,$0.key)<($1.value.seq,$1.key)}?.key
    }
    private var visibleHistoryPins = Set<String>()
    var historyOpenAnchor: String?
    @discardableResult func pinHistoryViewport(_ ids: Set<String>) -> Bool {
        guard store.historyMode,ids != visibleHistoryPins else {return false}
        visibleHistoryPins = ids
        historyRestorePin=nil
        return trimHistoryBodies()
    }
    @discardableResult private func trimHistoryBodies() -> Bool {
        residentBudget.pins = visibleHistoryPins
        if let historyRestorePin {residentBudget.pins.insert(historyRestorePin)}
        if let historyOpenAnchor {residentBudget.pins.insert(historyOpenAnchor)}
        if let selected,let root = history.summaries[selected]?.rootID {residentBudget.pins.insert(root)}
        let victims=residentBudget.evictions()
        for victim in victims {
            if let message=messages[victim] {evictedHistoryBodies[victim] = .init(key:message.key,seq:message.seq)}
            messages[victim] = nil
        }
        return !victims.isEmpty
    }
    private func accountHistoryBody(_ id:String) throws {
        guard store.historyMode else {return}
        let size = try messages[id].map {try JSONEncoder().encode($0).count}
        residentBudget.update(id,bytes:size)
        trimHistoryBodies()
    }
    private(set) var employees: [Employee] = [] { didSet { invalidateRenderValues() } }
    private(set) var groups:[String:Room]=[:] { didSet { invalidateRenderValues() } }
    var rooms: [Room] { employees.map(Room.init(employee:)) + groups.values.sorted{$0.title<$1.title} }
    var homeChannel:Room? {home.settings.channel.flatMap{groups[$0]}.flatMap{$0.archived==true ? nil:$0}}
    var homePicture:String? {if let channel=homeChannel{return channel.picture};return home.settings.picture}
    var homeScope:[String] {homeChannel.map{[$0.id]} ?? home.members.map(\.id)}
    func people(_ room:String)->[Employee] {let ids=groups[room]?.members;return employees.filter{ids?.contains($0.id) ?? true}}
    func room(for employee: String) -> Room? { rooms.first { $0.id==employee } }
    func unread(room: Room) -> Int { unread(employee:room.id) }
    func threads(room: Room, query: String = "") -> [ConversationThread] { threads(employee:room.id,query:query) }
    private(set) var messages: [String: ConversationMessage] = [:] { didSet {
        invalidateRenderValues()
        if !thinkingValues.isEmpty, messages.count <= oldValue.count {
            thinkingValues=thinkingValues.filter{messages[$0.key] != nil}
            thinkingOrder.removeAll{messages[$0]==nil}
        }
        if !assessmentValues.isEmpty, messages.count <= oldValue.count {
            let live=Set(messages.values.map(\.key))
            assessmentValues=assessmentValues.filter{live.contains($0.key)}
            assessmentOrder.removeAll{!live.contains($0)}
        }
    } }
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
        var settings=memberState.value("layout:home").flatMap{$0.data(using:.utf8)}.flatMap{try? JSONDecoder().decode(HomeRoom.Settings.self,from:$0)} ?? HomeRoom.Settings()
        settings.members=nil // The reviewed home view always contains the whole roster.
        return HomeRoom(settings:settings,employees:employees)
    }
    var homeRecipients:HomeRoom {var result=home;if let channel=homeChannel {result.settings.members=channel.members};return result}
    var petMuted:Set<String> {muted.union(home.settings.muted==true ? Set(home.members.map(\.id)+(homeChannel.map{[$0.id]} ?? [])):[])}
    func configureHome(_ update:(inout HomeRoom.Settings)->Void){var settings=home.settings;update(&settings);saveLayout("layout:home",settings);clearHomeChannelFlags()}
    func selectHome(_ key:ConversationKey?=nil,notify:Bool=true){select(key ?? ConversationKey(employee:HomeRoom.id,thread:UUID().uuidString.lowercased()),notify:notify,inHome:true)}
    var homeThreads:[ConversationThread] {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            return withRenderValues {
                if let cached=renderValues?.homeThreads {return cached}
                #if HEJO_PERF_TESTING || HEJO_HISTORY_TRANSPORT_TEST
                onDerive?("home_sort", "home")
                #endif
                let rows=homeScope.flatMap{threads(employee:$0)}
                var dates=[ConversationKey:Date]()
                for row in rows {dates[row.key]=latestDate(row.key)}
                let result=rows.sorted { a,b in
                    let x=dates[a.key]!,y=dates[b.key]!
                    return x==y ? a.id<b.id:x<y
                }
                renderValues?.homeThreads=result
                return result
            }
        }
#endif
        return (history.threadOrder["home"] ?? []).compactMap{history.summaries[$0]?.thread}
    }
    var onChange: (() -> Void)?
    var noticeClock:()->Date=Date.init
    /// Values belong to one synchronous query/render, never to the next refresh.
    private final class RenderValues {
        let now: Date
        var grouped: [ConversationKey:[ConversationMessage]]?
        var threads: [String:[ConversationThread]]=[:]
        struct ParsedDate { let value: Date? }
        var dates: [String:ParsedDate]=[:]
        var latestDates: [ConversationKey:Date]=[:]
        struct NoticeKey: Hashable { let room: String; let now: Date }
        var notices: [NoticeKey:[RoomNotice]]=[:]
        var homeThreads: [ConversationThread]?
        var sidebar: SidebarLayout?
        var assessments: [ConversationKey:ThreadAssessment.Result] = [:]
        lazy var fractional: ISO8601DateFormatter = {
            let value=ISO8601DateFormatter();value.formatOptions=[.withInternetDateTime,.withFractionalSeconds];return value
        }()
        lazy var whole=ISO8601DateFormatter()
        let canonicalWhole=Date.ISO8601FormatStyle(includingFractionalSeconds:false)
        init(now: Date) {self.now=now}
    }
    private var renderValues: RenderValues?
    #if HEJO_PERF_TESTING || HEJO_HISTORY_TRANSPORT_TEST
    /// Test builds count actual derivations; production builds have no observer or content logging.
    var onDerive: ((String,String)->Void)?
    #endif
    func withRenderValues<T>(_ body: () throws -> T) rethrows -> T {
        if renderValues != nil {return try body()}
        renderValues=RenderValues(now:noticeClock())
        defer {renderValues=nil}
        return try body()
    }
    /// A render callback may synchronously change the model. Finish with the new state,
    /// sharing derived values only while that state remains unchanged.
    func withStableRenderValues(_ render: () -> Void) {
        withRenderValues {
            var rendered: RenderValues?
            repeat {
                rendered=renderValues
                render()
            } while renderValues !== rendered
        }
    }
    private func invalidateRenderValues() {
        if let values=renderValues {renderValues=RenderValues(now:values.now)}
    }
    var renderTime: Date {renderValues?.now ?? noticeClock()}
    private func groupedTimelines() -> [ConversationKey:[ConversationMessage]] {
        if let cached=renderValues?.grouped {return cached}
        #if HEJO_PERF_TESTING || HEJO_HISTORY_TRANSPORT_TEST
        onDerive?("grouping", "messages")
        #endif
        let result=Dictionary(grouping:messages.values,by:\.key).mapValues{$0.sorted{$0.seq<$1.seq}}
        renderValues?.grouped=result
        return result
    }
    private func parsedDate(_ text: String) -> Date? {
        guard let values=renderValues else {return nil}
        if let cached=values.dates[text] {return cached.value}
        let result: Date?
        // Recognize the canonical whole-second UTC grammar by an exact round trip.
        // Other forms and normalization cases (including leap seconds) retain the existing parser.
        if text.utf8.count==20,let value=try? values.canonicalWhole.parse(text),values.canonicalWhole.format(value)==text {
            result=value
        } else {result=values.fractional.date(from:text) ?? values.whole.date(from:text)}
        values.dates[text] = .init(value:result)
        return result
    }
    private static let dateCapacity=4096
    private var dateValues:[String:Date]=[:]
    private var dateOrder:[String]=[]
    #if HEJO_PERF_TESTING
    var smoothDateCount:Int {dateValues.count}
    var smoothDateCapacity:Int {Self.dateCapacity}
    #endif
    func date(_ text: String) -> Date {
        if let result=dateValues[text] {return result}
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.dates += 1
        #endif
        let result=renderValues == nil ? ThreadTools.date(text):parsedDate(text) ?? .distantPast
        if dateOrder.count>=Self.dateCapacity {dateValues[dateOrder.removeFirst()]=nil}
        dateOrder.append(text);dateValues[text]=result
        return result
    }
    func latestDate(_ key: ConversationKey) -> Date {
        withRenderValues {
            if let cached=renderValues?.latestDates[key] {return cached}
            let result=timeline(key).map{date($0.timestamp)}.max() ?? .distantPast
            renderValues?.latestDates[key]=result
            return result
        }
    }
    func cachedNotices(_ room: String, now: Date, calculate: () -> [RoomNotice]) -> [RoomNotice] {
        let key=RenderValues.NoticeKey(room:room,now:now)
        if let cached=renderValues?.notices[key] {return cached}
        #if HEJO_PERF_TESTING || HEJO_HISTORY_TRANSPORT_TEST
        onDerive?("notices", room)
        #endif
        let result=calculate()
        renderValues?.notices[key]=result
        return result
    }
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
    private var replaying = false
    var sidebar: SidebarLayout {
        withRenderValues {
            if let cached=renderValues?.sidebar {return cached}
            @MainActor func decoded<T:Decodable>(_ key:String,_ fallback:T) -> T { memberState.value(key).flatMap { $0.data(using:.utf8) }.flatMap { try? JSONDecoder().decode(T.self,from:$0) } ?? fallback }
            var layout=SidebarLayout()
            let sections=decoded("layout:sections",SidebarLayout.defaults)
            if !sections.isEmpty { var ids=Set<String>();layout.sections=sections.filter { !$0.id.isEmpty && ids.insert($0.id).inserted } }
            if layout.sections.isEmpty { layout.sections=SidebarLayout.defaults }
            for index in layout.sections.indices {
                if let open=memberState.value("layout:section-open:"+layout.sections[index].id) {layout.sections[index].open = open == "1"}
            }
            layout.stack=decoded("layout:stack",SidebarLayout.Stack())
            if let open=memberState.value("layout:section-open:stack") {layout.stack.open = open == "1"}
            for (key,entry) in memberState.items {
                if key.hasPrefix("zone:"),let value=entry.v { layout.zones[String(key.dropFirst(5))]=value }
                if key.hasPrefix("pin:"),let value=entry.v,let slot=Int(value),(1...5).contains(slot) { layout.pins[String(key.dropFirst(4))]=slot }
            }
            for (index,id) in pinned.enumerated() where layout.pins[id]==nil { layout.pins[id]=index+1 }
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
            if !store.historyMode {
                layout.items=rooms.enumerated().filter { !hidden.contains($0.element.id) && $0.element.archived != true && $0.element.id != homeChannel?.id }.map { index,room in
                    let posts=messages.values.filter { room.id==$0.key.employee }
                    let latest=posts.map { parsedDate($0.timestamp)?.timeIntervalSince1970 ?? Double($0.latestSeq) }.max() ?? 0
                    return SidebarLayout.Item(id:room.id,name:room.title,kind:room.kind == .direct ? .direct:.group,members:room.members,rank:index,latest:latest,unread:unread(room:room),questions:notices(room.id).filter(\.questions).reduce(0){$0+$1.messages.count},alerts:notices(room.id).filter{!$0.questions}.reduce(0){$0+$1.messages.count},muted:muted.contains(room.id),picture:room.picture)
                }
                let memberIDs=homeChannel?.members ?? home.members.map(\.id),scope=homeScope,posts=messages.values.filter{scope.contains($0.key.employee)}
                layout.items.insert(.init(id:HomeRoom.id,name:store.settings.petName,kind:.home,members:memberIDs,latest:Double(posts.map(\.latestSeq).max() ?? 0),unread:scope.reduce(0){$0+unread(employee:$1)},questions:notices(HomeRoom.id).filter(\.questions).reduce(0){$0+$1.messages.count},alerts:notices(HomeRoom.id).filter{!$0.questions}.reduce(0){$0+$1.messages.count},muted:home.settings.muted==true,picture:homePicture),at:0)
                renderValues?.sidebar=layout
                return layout
            }
#endif
            layout.items=rooms.enumerated().filter { !hidden.contains($0.element.id) && $0.element.archived != true && $0.element.id != homeChannel?.id }.map { index,room in
                let total=history.totals[room.id]
                return SidebarLayout.Item(id:room.id,name:room.title,kind:room.kind == .direct ? .direct:.group,members:room.members,rank:index,latest:total?.latestActivity ?? 0,unread:unread(room:room),questions:total?.questions ?? 0,alerts:total?.alerts ?? 0,muted:muted.contains(room.id),picture:room.picture,freshness:total == nil ? .unknown:history.refreshing ? .updating:.ready)
            }
            let memberIDs=homeChannel?.members ?? home.members.map(\.id),scope=homeScope
            layout.items.insert(.init(id:HomeRoom.id,name:store.settings.petName,kind:.home,members:memberIDs,latest:Double(scope.compactMap{history.totals[$0]?.latestSeq}.max() ?? 0),unread:scope.reduce(0){$0+unread(employee:$1)},questions:scope.reduce(0){$0+(history.totals[$1]?.questions ?? 0)},alerts:scope.reduce(0){$0+(history.totals[$1]?.alerts ?? 0)},muted:home.settings.muted==true,picture:homePicture,freshness:scope.contains{history.totals[$0] == nil} || history.context == nil ? .unknown:history.refreshing ? .updating:.ready),at:0)
            renderValues?.sidebar=layout
            return layout
        }
    }
    private func layoutData<T:Encodable>(_ value:T,key:String)->Data? {
        guard let raw=try? JSONEncoder().encode(value) else {return nil}
        if key == "layout:sections",var rows=(try? JSONSerialization.jsonObject(with:raw)) as? [[String:Any]] {
            for index in rows.indices {rows[index].removeValue(forKey:"open")}
            return try? JSONSerialization.data(withJSONObject:rows,options:[.sortedKeys])
        }
        if key == "layout:stack",var row=(try? JSONSerialization.jsonObject(with:raw)) as? [String:Any] {
            row.removeValue(forKey:"open");return try? JSONSerialization.data(withJSONObject:row,options:[.sortedKeys])
        }
        return raw
    }
    private func saveLayout<T:Encodable>(_ key:String,_ value:T) {
        // Before changing definitions, preserve each legacy open flag in its own key.
        if key == "layout:sections" || key == "layout:stack" { migrateSectionOpen() }
        if let data=layoutData(value,key:key),let json=String(data:data,encoding:.utf8) {
            guard data.count<=4096 else { memberState.onFailure?(true);return }
            changeState([key:json])
        }
    }
    private func migrateSectionOpen() {
        let layout=sidebar
        var values:[String:String?]=[:]
        for section in layout.sections where memberState.items["layout:section-open:"+section.id] == nil {
            values["layout:section-open:"+section.id]=section.open ? "1":"0"
        }
        if memberState.items["layout:section-open:stack"] == nil {values["layout:section-open:stack"]=layout.stack.open ? "1":"0"}
        changeState(values)
    }
    func toggleSection(_ id:String?) {
        let layout=sidebar
        if let id,let section=layout.sections.first(where:{$0.id==id}) {changeState(["layout:section-open:"+id:section.open ? "0":"1"])}
        else if id==nil {changeState(["layout:section-open:stack":layout.stack.open ? "0":"1"])}
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
        guard let data=layoutData(remaining,key:"layout:sections"),let value=String(data:data,encoding:.utf8) else { return }
        var changes:[String:String?]=["layout:sections":value]
        for (room,zone) in layout.zones where zone==id { changes["zone:"+room]=first.id }
        migrateSectionOpen();changes["layout:section-open:"+id] = .some(nil)
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
    init(store: LocalStore, residentBudget:HistoryResidentBudget = HistoryResidentBudget()) throws {
        self.store = store;self.residentBudget=residentBudget;initialResidentBudget=residentBudget
        memberState = MemberState(store: store)
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        for frame in store.records { try apply(frame) }
#endif
        loadingRecords = false
        memberState.onChange = { [weak self] in
            guard let self else { return }
            self.invalidateRenderValues()
            if self.store.historyMode { self.history.context = nil; self.history.refreshing = true; self.history.intentGeneration += 1 }
            if !self.replaying {self.seedUnseenRooms()}
            if self.isHome {
                if let key=self.selected,key.employee != HomeRoom.id,!self.homeScope.contains(key.employee) {self.selectHome(notify:false)}
            } else if let current = self.selected?.employee, self.hidden.contains(current) {
                if let next = self.displayRooms.first { self.select(employee: next.id, notify: false,markRead:false) }
                else { self.selected = nil }
            }
            self.onChange?()
        }
    }
    /// Context input is a view of existing member state, never another member-state store.
    func historyContext(generation: Int) throws -> [String:Any] {
        let values = memberState.items.filter { key, _ in
            ["read:","thread:","bell:","confirm:","check:"].contains(where:key.hasPrefix)
        }
        let items = try JSONSerialization.jsonObject(with:JSONEncoder().encode(values))
        let allowed = Set(rooms.map(\.id))
        return ["generation":generation,"memberRevision":memberState.document.rev,
                "ready":memberState.account.isEmpty || memberState.hasFetched,"items":items,
                "home":homeScope.filter{allowed.contains($0)},"hidden":hidden.intersection(allowed).sorted(),
                "names":Dictionary(uniqueKeysWithValues:rooms.map{($0.id,name($0.id))}),
                "now":noticeClock().timeIntervalSince1970,"locale":Locale.current.identifier]
    }
    func beginHistorySession(through: Int) {
        let intent = history.readIntent
        history = HistoryProjection(); history.readIntent = intent
        messages = [:]; bodyCache = nil; residentBudget = initialResidentBudget; evictedHistoryBodies = [:]; historyRestorePin=nil; visibleHistoryPins = []; historyOpenAnchor = nil; applied = through; replaying = false
    }
    /// Apply all read-plan pages in one existing hub outbox transaction. Caller must
    /// retain its selection/user-intent generation until the final page arrives.
    func applyHistoryReadPlan(_ changes: [String:String], context: String, generation: Int, intent: Int) throws {
        guard history.intentGeneration == intent, store.historyMode, history.accepts(context:context,generation:generation),
              memberState.account.isEmpty || memberState.hasFetched else { throw HistoryFailure.changed }
        guard changes.allSatisfy({ key,value in
            ["read:","thread:","bell:"].contains(where:key.hasPrefix) && Int(value).map{$0 >= 0} == true
        }) else { throw HistoryFailure.invalidResponse }
        guard try JSONSerialization.data(withJSONObject:changes).count <= 1024*1024 else { throw HistoryFailure.tooLarge }
        let at = Date().timeIntervalSince1970
        let device = store.settings.stateDevice ?? UUID().uuidString.lowercased()
        let entries = changes.mapValues { StateEntry(v:$0,at:at,dev:device) }
        let projected = StateDocument(rev:memberState.document.rev+1,items:MemberState.merge(memberState.items,entries))
        guard try JSONEncoder().encode(projected).count <= 1024*1024 else { throw HistoryFailure.tooLarge }
        try memberState.set(changes.mapValues { Optional($0) },at:at)
    }
    func applyHistoryOverview(_ rows: [[String:Any]], context: String, generation: Int) throws {
        guard history.accepts(context:context,generation:generation) else { throw HistoryFailure.changed }
        let decoded = try rows.map { row -> HistoryRoomTotals in
            try HistoryHTTP.validate(row,kind:"overview")
            return try decode(row,as:HistoryRoomTotals.self)
        }
        for row in decoded { history.totals[row.id] = row }
    }
    func applyHistoryThreads(_ page: [String:Any], scope: String, context: String, generation: Int, older: Bool = false) throws {
        guard history.accepts(context:context,generation:generation) else { throw HistoryFailure.changed }
        let rows = page["items"] as? [[String:Any]] ?? []
        let summaries = try rows.filter{$0["removed"] as? Bool != true}.map { row -> HistoryThreadSummary in
            try HistoryHTTP.validate(row,kind:"threads")
            return try decode(row,as:HistoryThreadSummary.self)
        }
        var order = history.threadOrder[scope] ?? []
        for summary in summaries {
            let key = summary.conversationKey
            guard summary.revision > (history.deletedThreads[key] ?? 0),
                  summary.revision >= (history.summaries[key]?.revision ?? 0) else { continue }
            history.summaries[key] = summary
        }
        let incoming = summaries.filter{$0.revision > (history.deletedThreads[$0.conversationKey] ?? 0)}.map(\.conversationKey)
        order = incoming + order.filter{!incoming.contains($0)}
        order = order.filter { history.summaries[$0] != nil && (scope != "home" || homeScope.contains($0.employee)) }
        order.sort {
            guard let a=history.summaries[$0],let b=history.summaries[$1] else{return false}
            if scope == "home" {
                let x=ThreadTools.date(a.lastTime),y=ThreadTools.date(b.lastTime)
                return x == y ? a.key.thread < b.key.thread:x < y
            }
            return a.rootSeq < b.rootSeq
        }
        history.threadOrder[scope] = order
        history.threadPages[scope] = try historyPageState(page,context:context)
    }
    private func historyPageState(_ page: [String:Any], context: String) throws -> HistoryPageState {
        guard let through = HistoryHTTP.integer(page["through"]), let complete = HistoryHTTP.boolean(page["complete"]),
              complete == (page["next"] is NSNull) else { throw HistoryFailure.invalidResponse }
        return .init(context:context,next:page["next"] as? String,through:through,complete:complete)
    }
    enum HistoryMessageMerge { case open, refresh, older, newer }

    func canDisplayHistoryBody(_ id:String,in key:ConversationKey) -> Bool {
        guard let root=history.summaries[key]?.rootID,messages[root] != nil,messages[id]?.key == key else { return false }
        return id == root || historyReplyIDs(key).contains(id)
    }

    func hasUnpagedLiveHistory(_ key: ConversationKey) -> Bool {
        guard history.messagePages[key] == nil, let root = history.summaries[key]?.rootID,
              !history.deletedMessages.contains(root) else { return false }
        // Before a page arrives, only a root received in the ordered live stream
        // proves that the available replies extend from the root to the end.
        return history.messagePageIDs[key]?.contains(root) == true
    }

    func hasUnloadedNewerReplies(_ key: ConversationKey) -> Bool {
        (history.messagePages[key]?.newerCount ?? 0) > 0
    }

    func historyReplyIDs(_ key: ConversationKey, pending: [String] = []) -> [String] {
        let page = history.messagePages[key]
        let completeLiveHistory = hasUnpagedLiveHistory(key)
        guard page != nil || completeLiveHistory else { return [] }
        let root = history.summaries[key]?.rootID
        let replies = (history.messagePageIDs[key] ?? []).filter { $0 != root && !history.deletedMessages.contains($0) }
        return page?.newerCount == 0 || completeLiveHistory ? replies + pending : replies
    }

    /// Historical rows do not call apply(frame): that path advances the live cursor
    /// and handles live side effects. Newer live edits/deletes win over older pages.
    func applyHistoryMessages(_ page: [String:Any], key: ConversationKey, context: String, generation: Int, anchor: String? = nil, merge: HistoryMessageMerge = .open) throws {
        guard history.accepts(context:context,generation:generation) else { throw HistoryFailure.changed }
        var state = try historyPageState(page,context:context)
        state.anchor = anchor; state.newerCount = HistoryHTTP.integer(page["newerCount"]) ?? 0
        if let row = page["root"] as? [String:Any] {
            let summary = try decode(row,as:HistoryThreadSummary.self)
            guard summary.conversationKey == key else { throw HistoryFailure.invalidResponse }
            if summary.revision > (history.deletedThreads[key] ?? 0), summary.revision >= (history.summaries[key]?.revision ?? 0) {
                history.summaries[key] = summary
            }
        }
        let rows = page["items"] as? [[String:Any]] ?? []
        let root = history.summaries[key]?.rootID
        let incoming = rows.compactMap { $0["msg_id"] as? String }.filter { $0 != root }
        guard Set(incoming).count == incoming.count else { throw HistoryFailure.invalidResponse }
        let known = history.messagePageIDs[key] ?? []
        let previous = history.messagePages[key]
        if merge == .refresh, hasUnloadedNewerReplies(key) { return }

        let window = mergeHistoryReplyPage(incoming, into:known, previous:previous, state:&state, merge:merge)
        var order = window.ids
        if state.newerCount == 0 {
            // Live frames may have arrived while the HTTP page was in flight.
            let seen = Set(order)
            order += timeline(key).filter { $0.id != root && $0.seq > state.through && !seen.contains($0.id) }.map(\.id)
        }
        if window.replaced {
            let retained = Set(order).union([root].compactMap { $0 })
            let obsolete = Set(timeline(key).map(\.id))
                .union(known)
                .subtracting(retained)
            for id in obsolete {
                messages[id] = nil
                residentBudget.update(id,bytes:nil)
                evictedHistoryBodies[id] = nil
                history.contentReferences[id] = nil
                history.contentKeys[id] = nil
            }
        }
        if bodyCache == nil { bodyCache = try store.historyCache() }
        try bodyCache?.batch {
            for row in rows {
                // Leave an unchanged, evicted slot to the existing viewport restore path.
                if merge == .refresh,let id=row["msg_id"] as? String,
                   evictedHistoryBodies[id] != nil,let revision=history.revisions[id],
                   revision == HistoryHTTP.integer(row["revision"]) { continue }
                try applyHistoryBody(row,expectedKey:key)
            }
        }
        history.messagePageIDs[key] = order
        history.messagePages[key] = state
    }

    private func mergeHistoryReplyPage(_ incoming: [String], into known: [String], previous: HistoryPageState?,
                                       state: inout HistoryPageState, merge: HistoryMessageMerge) -> (ids: [String], replaced: Bool) {
        // An explicitly anchored opening starts a reading window around that message.
        if merge == .open, state.anchor != nil { return (incoming, true) }
        guard let previous, !known.isEmpty else { return (incoming, !known.isEmpty) }

        let positions = Dictionary(uniqueKeysWithValues: known.enumerated().map { ($0.element,$0.offset) })
        let common = incoming.enumerated().compactMap { index, id in positions[id].map { (index,$0) } }
        if let first = common.first, let last = common.last {
            let prefix = first.0 == 0 ? known.prefix(first.1) : known.prefix(0)
            let suffix = last.0 == incoming.count-1 ? known.suffix(from:last.1+1) : known.suffix(0)
            let newer = !suffix.isEmpty || merge == .older ? previous:state
            if !prefix.isEmpty || (first == (0,0) && (merge == .newer || merge == .refresh)) {
                state = previous
            }
            state.newerCount = newer.newerCount
            state.through = newer.through
            return (Array(prefix) + incoming + suffix, false)
        }
        // The previous-page cursor proves adjacency. An independent snapshot
        // only proves it when both offsets refer to the same journal head.
        if merge == .older || (previous.through == state.through && state.newerCount == previous.newerCount + known.count) {
            state.newerCount = previous.newerCount
            state.through = previous.through
            return (incoming + known, false)
        }
        if previous.through == state.through && previous.newerCount == state.newerCount + incoming.count {
            let newer = state
            state = previous
            state.newerCount = newer.newerCount
            return (known + incoming, false)
        }
        return (incoming, true)
    }

    private func appendHistoryReply(_ message: ConversationMessage) {
        let key = message.key
        guard var page = history.messagePages[key] else {
            // A summary can arrive after the root and its replies. Keep the live
            // order until the summary identifies whether this window has the root.
            if let root = history.summaries[key]?.rootID, root != message.id, !hasUnpagedLiveHistory(key) { return }
            if history.messagePageIDs[key]?.last != message.id {
                history.messagePageIDs[key,default:[]].append(message.id)
            }
            return
        }
        guard page.newerCount == 0, message.seq > page.through,
              message.id != history.summaries[key]?.rootID else { return }
        page.through = message.seq
        history.messagePages[key] = page
        if history.messagePageIDs[key]?.contains(message.id) == false {
            history.messagePageIDs[key]?.append(message.id)
        }
    }

    func applyHistoryBody(_ row: [String:Any], expectedKey: ConversationKey? = nil) throws {
        try HistoryHTTP.validate(row,kind:"messages")
        guard let id = row["msg_id"] as? String else { throw HistoryFailure.invalidResponse }
        if row["missing"] as? Bool == true { return } // Missing is not deletion.
        let revision = HistoryHTTP.integer(row["revision"])!
        guard revision >= (history.revisions[id] ?? 0) else { return }
        if row["deleted"] as? Bool == true {
            history.deletedMessages.insert(id);evictedHistoryBodies[id]=nil
            messages[id] = nil; history.contentReferences[id] = nil; history.revisions[id] = revision
        } else if let ref = row["contentRef"] as? String {
            if bodyCache == nil { bodyCache = try store.historyCache() }
            try bodyCache?.invalidate(id:id,through:revision)
            if revision > (messages[id]?.latestSeq ?? 0) { messages[id] = nil; history.contentReferences[id] = ref; history.contentKeys[id] = expectedKey }
            history.revisions[id] = revision
            try accountHistoryBody(id)
            return
        } else {
            let key = ConversationKey(employee:(row["room"] ?? row["employee"]) as! String,thread:row["thread"] as! String)
            guard expectedKey == nil || expectedKey == key else { throw HistoryFailure.invalidResponse }
            guard revision > (history.deletedThreads[key] ?? 0) else { return }
            let message = try HistoryHTTP.message(row)
            history.deletedMessages.remove(id)
            messages[id] = message; evictedHistoryBodies[id]=nil; history.revisions[id] = revision; history.contentReferences[id] = nil
        }
        if bodyCache == nil { bodyCache = try store.historyCache() }
        try bodyCache?.put(row)
        try accountHistoryBody(id)
    }
    private func changeState(_ values: [String: String?]) {
        do { try memberState.set(values) } catch { memberState.onFailure?(true) }
    }
    func toggleMute(_ employee: String) { if employee==HomeRoom.id {configureHome{$0.muted = $0.muted != true};return};changeState(["mute:" + employee: muted.contains(employee) ? nil : "1"]) }
    func hide(_ employee: String) { changeState(["hide:" + employee: "1", "pin:" + employee: nil]) }
    func restore(_ employee: String) { changeState(["hide:" + employee: nil]) }
    func markAllRead(_ employee: String) {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            if employee==HomeRoom.id {for room in homeScope {markAllRead(room)};return}
            var values: [String: String?] = [:]
            let roomMessages = messages.values.filter { $0.key.employee == employee }
            values["read:" + employee] = String(roomMessages.map(\.seq).max() ?? 0)
            for (key, messages) in Dictionary(grouping: roomMessages, by: \.key) {
                values["thread:" + key.employee + "/" + key.thread] = String(messages.map(\.seq).max() ?? 0)
            }
            changeState(values);readAllNotices(employee)
            return
        }
#endif
        history.readIntent?("mark_all",employee,nil); return
    }
    func resetReplica() { setOwner(nil, notify:false);groups=[:];messages = [:]; typingPeople=[:];typing = [:]; typingSince = [:]; applied = 0; selected = nil; isHome=false; onChange?() }
    private func decode<T: Decodable>(_ value: Any, as type: T.Type) throws -> T {
        try JSONDecoder().decode(type, from: JSONSerialization.data(withJSONObject: value))
    }
    func apply(_ frame: [String: Any], now: Date = Date()) throws {
        let type = frame["type"] as? String ?? ""
        if type=="welcome" {
            if store.historyMode { beginHistorySession(through:(frame["history"] as? [String:Any])?["through"] as? Int ?? 0) }
            else { replaying=true }
        }
        if let seq = frame["seq"] as? Int {
            var revealedHiddenRoom = false
            if seq <= applied { return }
            guard seq == applied + 1 else { throw GateFailure.protocolError }
            if store.historyMode {
                if bodyCache == nil { bodyCache = try store.historyCache() }
                if ["message","edit","state","delete"].contains(type), let id = frame["msg_id"] as? String {
                    try bodyCache?.invalidate(id:id,through:seq)
                } else if type == "delete", frame["scope"] as? String == "thread", let room = frame["room"] as? String, let thread = frame["thread"] as? String {
                    try bodyCache?.invalidate(room:room,thread:thread,through:seq)
                } else if type == "room_deleted", let room = frame["id"] as? String {
                    try bodyCache?.invalidate(room:room,through:seq)
                } else if type == "room", let room = frame["room"] as? [String:Any], let id = room["id"] as? String {
                    try bodyCache?.invalidate(room:id,through:seq)
                }
                if let id = frame["msg_id"] as? String { history.revisions[id] = max(history.revisions[id] ?? 0,seq) }
                if type == "delete", let id = frame["msg_id"] as? String, seq >= (history.revisions[id] ?? 0) { history.deletedMessages.insert(id);evictedHistoryBodies[id]=nil }
                if type == "delete", frame["scope"] as? String == "thread", let room = frame["room"] as? String, let thread = frame["thread"] as? String {
                    let key = ConversationKey(employee:room,thread:thread)
                    history.deletedThreads[key] = seq
                    evictedHistoryBodies=evictedHistoryBodies.filter{$0.value.key != key || (history.revisions[$0.key] ?? 0) > seq}
                    if (history.summaries[key]?.revision ?? 0) <= seq {
                        history.messagePages[key] = nil
                        history.messagePageIDs[key] = nil
                        history.summaries[key] = nil
                        for scope in Array(history.threadOrder.keys) { history.threadOrder[scope]?.removeAll{$0 == key} }
                    }
                }
                history.refreshing = true
            }
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
                if store.historyMode {
                    appendHistoryReply(message)
                    if (messages[id]?.latestSeq ?? 0) > seq { break }
                }
                messages[id] = message;evictedHistoryBodies[id]=nil
                messages[id]?.employee=employee
                messages[id]?.answerTo=frame["answer_to"] as? String
                if let checklist=frame["checklist"] { messages[id]?.checklist=try decode(checklist,as:ReplyChecklist.self) }
                messages[id]?.branchFrom=(frame["branch_from"] as? [String:Any])?["thread"] as? String
                if !loadingRecords, hidden.contains(message.key.employee) { restore(message.key.employee); revealedHiddenRoom = true }
            case "edit":
                guard let id = frame["msg_id"] as? String, let text = frame["text"] as? String, let final = frame["final"] as? Bool else { throw GateFailure.protocolError }
                if var message = messages[id], !store.historyMode || message.latestSeq <= seq {
                    message.text = text; message.streaming = !final; message.finalized = final; message.latestSeq = seq
                    if let buttons = frame["buttons"] { message.buttons = try decode(buttons, as: [MessageButton].self) }
                    if let checklist = frame["checklist"] { message.checklist = try decode(checklist, as: ReplyChecklist.self) }
                    messages[id] = message
                }
            case "delete":
                if frame["scope"] as? String == "thread",let room=frame["room"] as? String,let thread=frame["thread"] as? String {
                    let key=ConversationKey(employee:room,thread:thread)
                    messages=messages.filter { $0.value.key != key || store.historyMode && $0.value.latestSeq > seq };typing[key]=nil;typingSince[key]=nil;typingPeople[key]=nil
                    if selected==key, !store.historyMode || history.summaries[key] == nil { selected=nil }
                } else if let id = frame["msg_id"] as? String, !store.historyMode || (messages[id]?.latestSeq ?? 0) <= seq { messages[id] = nil; history.contentReferences[id] = nil }
            case "state":
                if let id = frame["msg_id"] as? String, var message = messages[id], !store.historyMode || message.latestSeq <= seq {
                    message.replyState = frame["reply_state"] as? String; message.latestSeq = seq; messages[id] = message
                }
            default: break // Future durable kinds still advance the contiguous replica cursor.
            }
            if store.historyMode {
                if let id = frame["msg_id"] as? String {try accountHistoryBody(id)}
                // Scope deletions discard accounting without scanning any disk bodies.
                for id in Array(residentBudget.ids) where messages[id] == nil {residentBudget.update(id,bytes:nil)}
            }
            applied = seq
            if revealedHiddenRoom { onChange?() }
        } else if type == "welcome" || type == "roster" {
            if let profile = frame["owner"] as? [String:Any] { setOwner(try decode(profile, as:OwnerProfile.self), notify:false) }
            else if type == "welcome" { setOwner(nil, notify:false) }
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
        if !loadingRecords && !replaying && ["roster","room"].contains(type) {seedUnseenRooms()}
        if selected == nil, !employees.isEmpty {
            if let last=store.settings.lastRoom, last != HomeRoom.id, rooms.contains(where:{$0.id==last && !hidden.contains(last) && $0.archived != true}) {select(employee:last,notify:false,markRead:false)}
            else {selectHome(notify:false)}
        }
        if type=="sync_done",frame["more"] as? Bool==false {seedUnseenRooms();replaying=false}
        if visible && !replaying && !store.historyMode {enterRoom(selectionIdentity)}
        try markVisibleRead()
        onChange?()
    }
    /// Called only after a fresh welcome/current replay, never for historical room records.
    func clearHomeChannelFlags(){
        guard let id=homeChannel?.id,hidden.contains(id) || muted.contains(id) else{return}
        changeState(["hide:"+id:nil,"mute:"+id:nil])
    }
    func clearArchivedPins(){for room in groups.values where room.archived==true && pinned.contains(room.id) {pin(room.id,slot:nil)}}
    private func removeRoom(_ id:String){
        evictedHistoryBodies=evictedHistoryBodies.filter{$0.value.key.employee != id}
        groups[id]=nil;typingPeople=typingPeople.filter{$0.key.employee != id};messages=messages.filter{$0.value.key.employee != id};typing=typing.filter{$0.key.employee != id};typingSince=typingSince.filter{$0.key.employee != id}
        if selected?.employee==id {selected=nil}
        if pinned.contains(id) {pin(id,slot:nil)}
    }
    func threads(employee: String, query: String = "") -> [ConversationThread] {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            return withRenderValues {
                let term = query.trimmingCharacters(in: .whitespacesAndNewlines)
                if term.isEmpty,let cached=renderValues?.threads[employee] {return cached}
                let result=groupedTimelines().filter{$0.key.employee==employee}.compactMap { key, ordered -> ConversationThread? in
                    guard term.isEmpty || ordered.contains(where: { $0.text.localizedCaseInsensitiveContains(term) }) else { return nil }
                    let title = String((ordered.first?.text.isEmpty == false ? ordered.first!.text : ordered.first?.files.first?.name ?? "대화").prefix(48)).replacingOccurrences(of: "\n", with: " ")
                    return ConversationThread(key: key, title: title, preview: String(ordered.last?.text.prefix(80) ?? ""), latestSeq: ordered.map(\.latestSeq).max() ?? 0)
                }.sorted { $0.latestSeq > $1.latestSeq }
                if term.isEmpty {renderValues?.threads[employee]=result}
                return result
            }
        }
#endif
        // Search has its own server result pages; never search a partial body set.
        guard query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return [] }
        return history.summaries.values.filter{$0.key.room == employee}.map(\.thread).sorted{$0.latestSeq > $1.latestSeq}
    }
    func timeline(_ key: ConversationKey) -> [ConversationMessage] {
        if renderValues != nil {return groupedTimelines()[key] ?? []}
        return messages.values.filter { $0.key == key }.sorted { $0.seq < $1.seq }
    }
    func unread(_ key: ConversationKey) -> Int {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            let read = max(memberState.read("read:" + key.employee), memberState.read("thread:" + key.employee + "/" + key.thread), store.settings.readSeq?[key.readKey] ?? 0)
            return timeline(key).filter { $0.role == "employee" && $0.seq > read && !thinking($0) }.count
        }
#endif
        return history.summaries[key]?.unread ?? 0
    }
    private struct ThinkingValue {let text:String;let result:Bool}
    private var thinkingValues:[String:ThinkingValue]=[:]
    private var thinkingOrder:[String]=[]
    private static let thinkingCapacity=4096
    func thinking(_ message:ConversationMessage)->Bool {
        if let cached=thinkingValues[message.id],cached.text==message.text {return cached.result}
        #if HEJO_PERF_TESTING
        HejoSmoothProbe.thinking[message.id,default:0]+=1
        #endif
        let result=ThreadTools.thinking(message.text)
        if thinkingValues[message.id]==nil {
            if thinkingOrder.count>=Self.thinkingCapacity {thinkingValues[thinkingOrder.removeFirst()]=nil}
            thinkingOrder.append(message.id)
        }
        thinkingValues[message.id]=ThinkingValue(text:message.text,result:result)
        return result
    }
    #if HEJO_PERF_TESTING
    var smoothThinkingKeys:Set<String> {Set(thinkingValues.keys)}
    var smoothThinkingCapacity:Int {Self.thinkingCapacity}
    #endif
    private struct AssessmentValue {
        let lines:[ConversationMessage]
        let confirmed:Set<String>
        let result:ThreadAssessment.Result
    }
    private static let assessmentCapacity=2048
    private var assessmentValues:[ConversationKey:AssessmentValue]=[:]
    private var assessmentOrder:[ConversationKey]=[]
    #if HEJO_PERF_TESTING
    var smoothAssessmentKeys:Set<ConversationKey> {Set(assessmentValues.keys)}
    var smoothAssessmentCapacity:Int {Self.assessmentCapacity}

    #endif
    func assessment(_ key:ConversationKey)->ThreadAssessment.Result {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            if let result=renderValues?.assessments[key] {return result}
            #if HEJO_PERF_TESTING
            HejoSmoothProbe.assessmentInputs[key.readKey,default:0]+=1
            #endif
            let lines=timeline(key),checked=Set(lines.filter{confirmed($0.id)}.map(\.id))
            if let cached=assessmentValues[key],cached.lines==lines && cached.confirmed==checked {
                renderValues?.assessments[key]=cached.result
                return cached.result
            }
            #if HEJO_PERF_TESTING
            HejoSmoothProbe.assessments[key.readKey,default:0]+=1
            onDerive?("assessment", key.readKey)
            #endif
            let result=ThreadAssessment.assess(lines,confirmed:checked)
            renderValues?.assessments[key]=result
            if !lines.isEmpty {
                if assessmentValues[key]==nil {
                    if assessmentOrder.count>=Self.assessmentCapacity {assessmentValues[assessmentOrder.removeFirst()]=nil}
                    assessmentOrder.append(key)
                }
                assessmentValues[key]=AssessmentValue(lines:lines,confirmed:checked,result:result)
            }
            return result
        }
#endif
        guard let state = history.summaries[key]?.assessment else { return .init() }
            return .init(request:state.requestID.flatMap{messages[$0]},pending:state.pendingID.flatMap{messages[$0]},
                         requestID:state.requestID,pendingID:state.pendingID,working:state.working,settled:state.settled,approved:state.approved)
    }
    func originalSeq(_ key:ConversationKey)->Int {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {return timeline(key).map(\.seq).max() ?? 0}
#endif
        return history.summaries[key]?.originalMaxSeq ?? 0
    }
    func bell(_ key:ConversationKey) -> Bool? {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            let state=assessment(key)
            guard !state.working,!state.settled,!(state.request.map{confirmed($0.id)} ?? false) else{return nil}
            let latest=originalSeq(key)
            if latest>0,memberState.value("bell:"+key.employee+"/"+key.thread) != nil,memberState.read("bell:"+key.employee+"/"+key.thread)>=latest {return false}
            return notices(key.employee).flatMap(\.messages).contains{messages[$0]?.key==key} ? true:nil
        }
#endif
        return history.summaries[key]?.bell
    }
    func toggleBell(_ key:ConversationKey) {
        if store.historyMode, history.refreshing || history.summaries[key] == nil { return }
        let name="bell:"+key.employee+"/"+key.thread
        if bell(key)==false {changeState([name:nil])}
        else {let seq=String(originalSeq(key));changeState([name:seq,"thread:"+key.employee+"/"+key.thread:seq])}
    }
    func confirm(_ message:ConversationMessage) {changeState(["confirm:"+message.id:"1"])}
    func confirmed(_ id:String)->Bool {memberState.value("confirm:"+id) != nil}
    private func checkKey(_ id:String,_ offset:Int,body:String?)->String {
        let revision=SHA256.hash(data:Data((body ?? messages[id]?.text ?? "").utf8)).map{String(format:"%02x",$0)}.joined()
        return "check:"+id+":"+revision+":"+String(offset)
    }
    func check(_ id:String,line:Int,original:Bool,body:String?=nil)->Bool {memberState.value(checkKey(id,line,body:body)).map{$0=="1"} ?? original}
    func toggleCheck(_ id:String,line:Int,original:Bool,body:String?=nil) {changeState([checkKey(id,line,body:body):check(id,line:line,original:original,body:body) ? "0":"1"])}
    /// The first completed replay is the boundary between existing history and new arrivals.
    private func seedUnseenRooms() {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            guard memberState.account.isEmpty || memberState.hasFetched else {return}
            var values:[String:String?]=[:]
            for room in rooms where memberState.items["read:"+room.id]==nil {
                let seen=memberState.items.keys.contains{$0.hasPrefix("thread:"+room.id+"/")}
                values["read:"+room.id]=String(seen ? 0:messages.values.filter{$0.key.employee==room.id}.map(\.seq).max() ?? 0)
            }
            changeState(values)
            return
        }
#endif
        return
    }
    /// Entering a room reads non-ringing threads, without advancing a receipt over a ringing root.
    func enterRoom(_ employee:String) {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            guard employee==HomeRoom.id || room(for:employee) != nil else{return}
            let scope=employee==HomeRoom.id ? homeScope:[employee]
            var values:[String:String?]=[:]
            for room in scope {
                let keys=threads(employee:room).map(\.key),ringing=Set(notices(room).flatMap(\.messages).compactMap{messages[$0]?.key})
                for key in keys where !ringing.contains(key) {values["thread:"+key.employee+"/"+key.thread]=String(originalSeq(key))}
                let cap=ringing.compactMap{timeline($0).first?.seq}.min().map{$0-1}
                let newest=messages.values.filter{$0.key.employee==room}.map(\.seq).max() ?? 0
                values["read:"+room]=String(min(newest,cap ?? newest))
            }
            changeState(values)
            return
        }
#endif
        history.readIntent?("enter",employee,nil); return
    }
    func markThreadRead(_ key:ConversationKey) {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            let seq=originalSeq(key);guard seq>0 else{return}
            changeState(["thread:"+key.employee+"/"+key.thread:String(seq)])
            return
        }
#endif
        history.readIntent?("thread",key.employee,key); return
    }
    func person(matching value:String)->Employee? {
        func key(_ s:String)->String {s.filter{!$0.isWhitespace && $0 != "-" && $0 != "_"}.lowercased()}
        let wanted=key(value);guard !wanted.isEmpty else{return nil}
        return employees.first{([ $0.id,$0.name ]+$0.aliases).contains{key($0)==wanted}}
    }
    func unread(employee: String) -> Int {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        if !store.historyMode {
            return Set(messages.values.filter { $0.key.employee == employee }.map(\.key)).reduce(0) { $0 + unread($1) }
        }
#endif
        return history.totals[employee]?.unread ?? 0
    }
    func name(_ employee: String) -> String { if employee==HomeRoom.id {return store.settings.petName};return groups[employee]?.title ?? person(matching:employee)?.name ?? employee }
    func select(employee: String, notify: Bool = true,markRead:Bool=true) {
        guard rooms.contains(where: { $0.id == employee }) else { return }
        select(threads(employee: employee).first?.key ?? ConversationKey(employee: employee, thread: UUID().uuidString.lowercased()), notify: notify,markRead:markRead)
    }
    func select(_ key: ConversationKey, notify: Bool = true,inHome:Bool=false,markRead:Bool=true) {
        let changed=selected != key || isHome != inHome
        if changed && store.historyMode { history.intentGeneration += 1; historyOpenAnchor = nil; visibleHistoryPins = [] }
        isHome=inHome;selected = key
        if changed && store.historyMode {trimHistoryBodies()}
        if changed && !loadingRecords {try? store.update{$0.lastRoom=selectionIdentity}}
        if visible && markRead {markThreadRead(key)}
        if notify {onChange?()}
    }
    func newThread() { if let selected { select(ConversationKey(employee: selected.employee, thread: UUID().uuidString.lowercased())) } }
    func setVisible(_ value: Bool) {
        // Opening the chat can finish a direct selection already prepared by the bubble.
        if visible && !value && store.historyMode { history.intentGeneration += 1 }
        visible = value
        if value { enterRoom(selectionIdentity) }
        try? markVisibleRead()
        onChange?()
    }
    private func markVisibleRead() throws {
#if HEJO_LEGACY_REFERENCE || HEJO_HISTORY_BASELINE || HEJO_THREE_TAP_DIAGNOSTIC
        guard visible, let selected,bell(selected) != true else { return }
        if store.historyMode { return } // Visibility coordinator owns automatic read intent.
        let seq = originalSeq(selected)
        let key = "thread:" + selected.employee + "/" + selected.thread
        guard seq > memberState.read(key) else { return }
        try memberState.set([key: String(seq)])
#endif
    }
    func expireTyping(now: Date = Date()) {
        typingPeople=typingPeople.mapValues{$0.filter{$0.value>now}}.filter{!$0.value.isEmpty}
        let kept = typing.filter { $0.value > now }
        if kept.count != typing.count { typing = kept; typingSince = typingSince.filter { kept[$0.key] != nil }; onChange?() }
    }
    static func click(messageID: String, buttons: [MessageButton], button: MessageButton) throws -> [String: Any] {
        guard buttons.contains(button) else { throw GateFailure.protocolError }
        return ["v": 1, "type": "click", "id": UUID().uuidString.lowercased(), "msg_id": messageID, "button_id": button.id]
    }
}
