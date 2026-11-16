import Foundation

struct IslandFailure: Equatable {
    var message: String
    var firstWords = ""
    var retryKey: ConversationKey?
    var isSend = false
}
struct IslandUpload: Equatable { var completed: Int; var total: Int }

/// Ephemeral presentation state only. Messages, read positions and drafts remain owned by their existing stores.
final class IslandModel {
    enum Kind: Int { case problem, owner, worker }
    enum Action: Equatable { case reconnect, retry(ConversationKey), question(String, ConversationKey), worker(ConversationKey) }
    struct Input {
        var messages: [ConversationMessage] = []
        var typing: [ConversationKey: Date] = [:]
        var names: [String: String] = [:]
        var unread = 0
        var selected: ConversationKey?
        var status: ConnectionStatus = .connected
        var failure: IslandFailure?
        var uploads: [ConversationKey: IslandUpload] = [:]
        var muted: Set<String> = []
    }
    struct Part {
        var kind: Kind
        var text: String
        var faces: [String] = []
        var redDot = false
        var shimmering = false
        var iconOnly = false
        var action: Action?
        var faceActions: [Action] = []
        var faceEmployees: [String] = []
    }
    struct Snapshot {
        var parts: [Part] = []
        var disconnected = false
        var restored = false
        var expanded: Kind?
        var hoverQuestion: String?
        var idle: Bool { parts.isEmpty }
    }
    private struct Event { var kind: Kind; var text: String; var name: String; var action: Action; var remaining: TimeInterval }
    private let clock: () -> Date
    var now: Date { clock() }
    private var input = Input(), initialized = false
    private var asked = Set<String>(), highSequence = 0
    private var workingSince: [String: Date] = [:], recentWork: [ConversationKey: Date] = [:]
    private var queue: [Event] = [], active: Event?, lastTick: Date?
    private var retryAt: Date?, restoredUntil: Date?
    private var wasDisconnected = false
    init(clock: @escaping () -> Date = Date.init) { self.clock = clock }
    static func firstLine(_ text: String, limit: Int = 24) -> String { String((text.split(whereSeparator: \.isNewline).first.map(String.init) ?? "").prefix(limit)) }
    private var problemVisible: Bool { wasDisconnected || (restoredUntil.map { $0 > now } ?? false) || input.failure != nil || !input.uploads.isEmpty || [.revoked,.wrongCode,.storageError,.tooLarge].contains(input.status) }
    private func advance() {
        let date=now
        if let lastTick, !problemVisible, var event=active { event.remaining -= max(0,date.timeIntervalSince(lastTick)); active=event.remaining>0 ? event : nil }
        lastTick=date
        if active == nil, !queue.isEmpty { active=queue.removeFirst() }
    }
    private func enqueue(_ event: Event) {
        if let current=active, event.kind.rawValue < current.kind.rawValue { queue.insert(current,at:0); active=nil }
        queue.append(event); queue.sort { $0.kind.rawValue < $1.kind.rawValue }
        if active == nil { active=queue.removeFirst() }
    }
    func update(_ next: Input) {
        advance()
        let date=now
        if next.status != input.status || !initialized {
            switch next.status {
            case .disconnected(let seconds): retryAt=date.addingTimeInterval(Double(seconds)); wasDisconnected=true
            case .connecting: wasDisconnected=true; retryAt=nil
            case .connected, .tooLarge:
                if wasDisconnected && next.status == .connected { restoredUntil=date.addingTimeInterval(2) }
                wasDisconnected=false; retryAt=nil
            default: wasDisconnected=false; retryAt=nil
            }
        }
        let live=next.typing.filter { $0.value>date }
        for (key,expiry) in live { recentWork[key]=expiry }
        recentWork=recentWork.filter { $0.value>date }
        let employees=Set(live.keys.map(\.employee))
        workingSince=workingSince.filter { employees.contains($0.key) }
        for employee in employees where workingSince[employee] == nil { workingSince[employee]=date }
        let questions=next.messages.filter { $0.role == "employee" && $0.replyState == "asked" }.sorted { $0.seq < $1.seq }
        if initialized {
            for message in questions where !asked.contains(message.id) && !next.muted.contains(message.key.employee) {
                enqueue(Event(kind:.owner,text:Self.firstLine(message.text)+" · 답 요청",name:next.names[message.key.employee] ?? message.key.employee,action:.question(message.id,message.key),remaining:4))
            }
            for message in next.messages.sorted(by:{$0.seq<$1.seq}) where message.role == "employee" && message.seq>highSequence && message.key != next.selected && recentWork[message.key] != nil && message.replyState != "asked" && !next.muted.contains(message.key.employee) {
                enqueue(Event(kind:.worker,text:"답글 · 보기 ›",name:next.names[message.key.employee] ?? message.key.employee,action:.worker(message.key),remaining:3))
            }
        }
        asked=Set(questions.map(\.id)); highSequence=next.messages.map(\.seq).max() ?? 0
        input=next; initialized=true
        // A question answered/deleted before its queued preview is shown must not remain actionable.
        func hiddenEvent(_ event: Event) -> Bool {
            switch event.action {
            case .question(let id, let key): return !asked.contains(id) || next.muted.contains(key.employee)
            case .worker(let key), .retry(let key): return next.muted.contains(key.employee)
            case .reconnect: return false
            }
        }
        queue.removeAll(where: hiddenEvent)
        if let active, hiddenEvent(active) { self.active = nil }
    }
    func snapshot() -> Snapshot {
        advance()
        let date=now
        if wasDisconnected {
            let text: String
            if let retryAt { text="서버 연결 끊김 · \(max(0,Int(ceil(retryAt.timeIntervalSince(date)))))초 뒤 다시 연결 · 지금 연결" }
            else { text="서버 연결 중 · 지금 연결" }
            return Snapshot(parts:[Part(kind:.problem,text:text,action:.reconnect)],disconnected:true)
        }
        if let until=restoredUntil, until>date { return Snapshot(parts:[Part(kind:.problem,text:"다시 연결됨")],restored:true) }
        var parts:[Part]=[]
        if [.revoked,.wrongCode,.storageError,.tooLarge].contains(input.status) { parts.append(Part(kind:.problem,text:input.status.text,action:input.status == .tooLarge ? nil : .reconnect)) }
        else if let failure=input.failure {
            let text=(failure.isSend ? "보내지 못함 · "+failure.firstWords+" · " : "")+failure.message+(failure.retryKey == nil ? "" : " · 다시 보내기")
            parts.append(Part(kind:.problem,text:text,action:failure.retryKey.map(Action.retry)))
        } else if !input.uploads.isEmpty {
            let k=input.uploads.values.reduce(0){$0+$1.completed},n=input.uploads.values.reduce(0){$0+$1.total}
            parts.append(Part(kind:.problem,text:"파일 올리는 중 \(k)/\(n)"))
        }
        let questions=input.messages.filter { $0.role == "employee" && $0.replyState == "asked" }.sorted { $0.seq<$1.seq }
        let oldest=questions.first, latest=questions.last
        if !questions.isEmpty || input.unread>0 {
            parts.append(Part(kind:.owner,text:questions.isEmpty ? String(input.unread) : "\(questions.count) · \(input.unread)",redDot:!questions.isEmpty,action:oldest.map { .question($0.id,$0.key) }))
        }
        let keys=input.typing.filter { $0.value>date }.keys.sorted { $0.employee == $1.employee ? $0.thread<$1.thread : $0.employee<$1.employee }
        let employees=Array(Set(keys.map(\.employee))).sorted()
        if !employees.isEmpty {
            let elapsed=max(0,Int(date.timeIntervalSince(workingSince[employees[0]] ?? date)/60))
            let shownEmployees=Array(employees.prefix(3))
            let faceActions=shownEmployees.compactMap { employee in keys.first(where:{$0.employee == employee}).map(Action.worker) }
            parts.append(Part(kind:.worker,text:employees.count==1 ? "일하는 중 · \(elapsed)분" : "\(employees.count)명 일하는 중",faces:shownEmployees.map { input.names[$0] ?? $0 },shimmering:true,action:keys.first.map(Action.worker),faceActions:faceActions,faceEmployees:shownEmployees))
        }
        let event=parts.contains(where:{$0.kind == .problem}) ? nil : active
        if let event {
            let action:Action? = event.kind == .owner ? oldest.map { .question($0.id,$0.key) } : event.action
            let employee:String
            switch event.action { case .question(_,let key),.worker(let key),.retry(let key):employee=key.employee;case .reconnect:employee="" }
            let part=Part(kind:event.kind,text:event.text,faces:[event.name],redDot:event.kind == .owner,action:action,faceEmployees:[employee])
            if let index=parts.firstIndex(where:{$0.kind == event.kind}) { parts[index]=part } else { parts.append(part) }
            for index in parts.indices where parts[index].kind != event.kind { parts[index].iconOnly=true }
        } else if parts.contains(where:{$0.kind == .problem}) {
            for index in parts.indices where parts[index].kind != .problem { parts[index].iconOnly=true }
        }
        return Snapshot(parts:parts.sorted{$0.kind.rawValue<$1.kind.rawValue},expanded:event?.kind,hoverQuestion:latest.map { Self.firstLine($0.text)+" · 열기 ›" })
    }
}
