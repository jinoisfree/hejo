import Foundation

/// Server-derived whole-thread facts. A preview is never a cached message body.
struct HistoryThreadSummary: Decodable {
    struct Key: Decodable { let room: String; let thread: String }
    struct Assessment: Decodable {
        let requestID: String?, pendingID: String?
        let working: Bool, settled: Bool, approved: Bool
    }
    struct Activity: Decodable { let lastSpeaker: String?; let working: Bool; let latestEmployeeTime: Double? }
    let activity: Activity
    let key: Key
    let rootID: String, rootRole: String, rootTime: String, lastTime: String
    let rootSeq: Int, latestSeq: Int, originalMaxSeq: Int, revision: Int
    let title: String, preview: String, rootPreview: String
    let messageCount: Int, unread: Int, waitingButtonCount: Int
    let assessment: Assessment
    let bell: Bool?
    var conversationKey: ConversationKey { .init(employee:key.room, thread:key.thread) }
    var thread: ConversationThread { .init(key:conversationKey,title:title,preview:preview,latestSeq:latestSeq) }
}
struct HistoryQuestion: Decodable {
    let id: String, speaker: String, preview: String
    let key: HistoryThreadSummary.Key
    let seq: Int, revision: Int
    var conversationKey: ConversationKey { .init(employee:key.room,thread:key.thread) }
}
struct HistoryNotice: Decodable {
    let id: String, group: String, title: String, speaker: String, timestamp: String, preview: String
    let key: HistoryThreadSummary.Key
    let questions: Bool
    let revision: Int
    var conversationKey: ConversationKey { .init(employee:key.room,thread:key.thread) }
}
struct HistoryRoomTotals: Decodable {
    let id: String
    let latestActivity: Double
    let unread: Int, questions: Int, alerts: Int, latestSeq: Int
}
struct HistoryPageState {
    let context: String
    let next: String?
    let through: Int
    let complete: Bool
    var anchor: String? = nil
    var newerCount: Int = 0
}

/// Session-only presentation state, separate from the bounded body cache and hub state.
/// An absent total means unknown; it is not inferred from the loaded page.
struct HistoryProjection {
    var context: String?
    var generation = 0
    var intentGeneration = 0
    var refreshing = true
    var summaries: [ConversationKey:HistoryThreadSummary] = [:]
    var noticeRows: [String:[[String:Any]]] = [:]
    var notices: [HistoryNotice] = []
    var questions: [HistoryQuestion] = []
    var totals: [String:HistoryRoomTotals] = [:]
    var threadPages: [String:HistoryPageState] = [:]
    var messagePages: [ConversationKey:HistoryPageState] = [:]
    var threadOrder: [String:[ConversationKey]] = [:]
    var revisions: [String:Int] = [:]
    var deletedMessages = Set<String>()
    var deletedThreads: [ConversationKey:Int] = [:]
    var contentReferences: [String:String] = [:]
    var contentKeys: [String:ConversationKey] = [:]
    var readIntent: ((String,String,ConversationKey?) -> Void)?

    mutating func beginContext(_ context: String, generation: Int) {
        self.context = context; self.generation = generation; refreshing = true
        // Keep last values visible while refreshing; cursors belong to the old context.
        threadPages = [:]; messagePages = [:]
    }
    func accepts(context: String, generation: Int) -> Bool {
        self.context == context && self.generation == generation
    }
}
