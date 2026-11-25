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
    enum Kind: Int { case problem, question, worker }
    enum Action: Equatable { case drawer, reconnect, retry(ConversationKey), question(String, ConversationKey), worker(ConversationKey) }
    struct Question {
        var id: String, key: ConversationKey, speaker: String, text: String, seq: Int
        init(_ message:ConversationMessage) {id=message.id;key=message.key;speaker=message.speaker;text=IslandModel.firstLine(message.text);seq=message.seq}
        init(_ value:HistoryQuestion) {id=value.id;key=value.conversationKey;speaker=value.speaker;text=value.preview;seq=value.seq}
    }
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
        var drawerOpen = false
        var title = "HEJO."
        var todoTotal = 0
        var historyQuestions: [Question]?
        var historyThrough: Int?
        var historyReady = true
        var questions: [Question] {historyQuestions ?? messages.filter{$0.role=="employee" && $0.replyState=="asked"}.map(Question.init)}
    }
    enum Tone: Equatable { case normal, orange, red, green }
    struct Activity {
        var kind: Kind
        var text: String
        var faces: [String] = []
        var shimmering = false
        var action: Action?
        var faceActions: [Action] = []
        var faceEmployees: [String] = []
        var tone: Tone = .normal
    }
    struct Snapshot {
        var title = "HEJO."
        var dot = false
        var activity: Activity?
        var drawerOpen = false
        var disconnected = false
        var restored = false
        var expanded: Kind?
        var hoverQuestion: String?
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
    private var problemVisible: Bool { wasDisconnected || (restoredUntil.map { $0 > now } ?? false) || input.failure != nil || !input.uploads.isEmpty || connectionProblem != nil }
    private var connectionProblem: Activity? {
        let action: Action?
        switch input.status {
        case .revoked, .wrongCode, .storageError: action = .reconnect
        case .tooLarge, .updateRequired: action = nil
        default: return nil
        }
        return Activity(kind: .problem, text: input.status.text, action: action, tone: .red)
    }
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
            case .updateRequired: wasDisconnected=false; retryAt=nil; restoredUntil=nil
            default: wasDisconnected=false; retryAt=nil
            }
        }
        let live=next.typing.filter { $0.value>date }
        for (key,expiry) in live { recentWork[key]=expiry }
        recentWork=recentWork.filter { $0.value>date }
        let employees=Set(live.keys.map(\.employee))
        workingSince=workingSince.filter { employees.contains($0.key) }
        for employee in employees where workingSince[employee] == nil { workingSince[employee]=date }
        guard next.historyReady else {input=next;return}
        let questions=next.questions.sorted { $0.seq < $1.seq }
        if initialized {
            for message in questions where !asked.contains(message.id) && !next.muted.contains(message.key.employee) {
                enqueue(Event(kind:.question,text:Self.firstLine(message.text),name:next.names[message.speaker] ?? message.key.employee,action:.question(message.id,message.key),remaining:4))
            }
            for message in next.messages.sorted(by:{$0.seq<$1.seq}) where message.role == "employee" && message.seq>highSequence && message.key != next.selected && recentWork[message.key] != nil && message.replyState != "asked" && !next.muted.contains(message.key.employee) {
                enqueue(Event(kind:.worker,text:"답글 · 보기 ›",name:next.names[message.speaker] ?? message.key.employee,action:.worker(message.key),remaining:3))
            }
        }
        asked=Set(questions.map(\.id)); highSequence=next.historyThrough ?? next.messages.map(\.seq).max() ?? 0
        input=next; initialized=true
        // A question answered/deleted before its queued preview is shown must not remain actionable.
        func hiddenEvent(_ event: Event) -> Bool {
            switch event.action {
            case .question(let id, let key): return !asked.contains(id) || next.muted.contains(key.employee)
            case .worker(let key), .retry(let key): return next.muted.contains(key.employee)
            case .reconnect, .drawer: return false
            }
        }
        queue.removeAll(where: hiddenEvent)
        if let active, hiddenEvent(active) { self.active = nil }
    }
    func snapshot() -> Snapshot {
        advance()
        let date=now
        let questions=input.questions.sorted { $0.seq<$1.seq }
        var result=Snapshot(title:input.title,dot:input.todoTotal>0,drawerOpen:input.drawerOpen,
            hoverQuestion:questions.last.map { Self.firstLine($0.text)+" · 열기 ›" })
        if wasDisconnected {
            let text: String
            if let retryAt { text="서버 연결 끊김 · \(max(0,Int(ceil(retryAt.timeIntervalSince(date)))))초 뒤 다시 연결 · 지금 연결" }
            else { text="서버 연결 중 · 지금 연결" }
            result.activity=Activity(kind:.problem,text:text,action:.reconnect,tone:.orange);result.disconnected=true
        } else if let until=restoredUntil, until>date {
            result.activity=Activity(kind:.problem,text:"다시 연결됨",tone:.green);result.restored=true
        } else if let connectionProblem {
            result.activity = connectionProblem
        } else if let failure=input.failure {
            let text=(failure.isSend ? "보내지 못함 · "+failure.firstWords+" · " : "")+failure.message+(failure.retryKey == nil ? "":" · 다시 보내기")
            result.activity=Activity(kind:.problem,text:text,action:failure.retryKey.map(Action.retry),tone:.red)
        } else if !input.uploads.isEmpty {
            let k=input.uploads.values.reduce(0){$0+$1.completed},n=input.uploads.values.reduce(0){$0+$1.total}
            result.activity=Activity(kind:.problem,text:"파일 올리는 중 \(k)/\(n)")
        } else if let event=active {
            let action:Action? = event.kind == .question ? questions.first.map { .question($0.id,$0.key) }:event.action
            let employee:String
            switch event.action {case .question(_,let key),.worker(let key),.retry(let key):employee=key.employee;case .reconnect,.drawer:employee=""}
            result.activity=Activity(kind:event.kind,text:event.kind == .question ? event.name+": "+event.text+" · 답하기":event.text,
                faces:[event.name],action:action,faceEmployees:[employee])
            result.expanded=event.kind
        } else {
            let keys=input.typing.filter { $0.value>date }.keys.sorted { $0.employee == $1.employee ? $0.thread<$1.thread:$0.employee<$1.employee }
            let employees=Array(Set(keys.map(\.employee))).sorted()
            if let first=employees.first {
                let elapsed=max(0,Int(date.timeIntervalSince(workingSince[first] ?? date)/60)),shown=Array(employees.prefix(3))
                result.activity=Activity(kind:.worker,text:employees.count==1 ? (input.names[first] ?? first)+" 일하는 중 · \(elapsed)분":"\(employees.count)명 일하는 중",
                    faces:shown.map{input.names[$0] ?? $0},shimmering:true,action:keys.first.map(Action.worker),
                    faceActions:shown.compactMap{employee in keys.first(where:{$0.employee==employee}).map(Action.worker)},faceEmployees:shown,tone:.green)
            }
        }
        return result
    }
}
