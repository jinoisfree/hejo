import Foundation

/// Ephemeral, at most two display bodies. Message state comes from the authenticated
/// journal query, never from cache membership; no member-state writes happen here.
struct HistoryMessageState: Decodable {
    let id: String, status: String
    let key: HistoryThreadSummary.Key?
    let seq: Int?, revision: Int?
    let read: Bool?, eligible: Bool?
    var conversationKey: ConversationKey? { key.map { .init(employee:$0.room,thread:$0.thread) } }
}
@MainActor final class HistoryBubbleResolver {
    private var task: Task<Void,Never>?
    private var signature: String?
    private var context: String?
    private(set) var states: [String:HistoryMessageState] = [:]
    private(set) var bodies: [ConversationMessage] = []
    private(set) var failed = false
    var onChange: (() -> Void)?
    deinit { task?.cancel() }
    func currentStates(context: String?) -> [String:HistoryMessageState] { self.context == context ? states:[:] }
    func currentBodies(context: String?) -> [ConversationMessage] { self.context == context ? bodies:[] }
    func refresh(client:GateClient,model:ConversationModel,bubble:BubbleReveal,chatOpen:Bool,now:Date) {
        guard client.store.historyMode else {return}
        guard client.isConnected,!model.history.refreshing,let context=model.history.context else {
            task?.cancel();task=nil;signature=nil;self.context=nil;states=[:];bodies=[];return
        }
        let questions=Set(model.history.notices.filter(\.questions).map(\.id))
        let ids=Set(bubble.reminders.keys).union(questions).union(bubble.notice.id.map{[$0]} ?? []).sorted()
        let due=bubble.reminders.filter{$0.value<=now.timeIntervalSince1970}.keys.sorted()
        let stamp=[context,String(client.liveSequence),ids.joined(separator:"\n"),due.joined(separator:"\n"),String(chatOpen),model.selected?.readKey ?? "",model.petMuted.sorted().joined(separator:"\n"),bubble.historyDismissalKey].joined(separator:"\u{0}")
        guard stamp != signature else {return}
        signature=stamp;task?.cancel();failed=false
        let session=client.historySession,through=client.liveSequence
        task=Task { [weak self] in
            guard let self else {return}
            do {
                @MainActor func check() throws {
                    try Task.checkCancellation()
                    guard self.signature==stamp,client.historySession==session,model.history.context==context,client.liveSequence==through else {throw HistoryFailure.changed}
                }
                var resolved:[String:HistoryMessageState]=[:]
                for start in stride(from:0,to:ids.count,by:50) {
                    let requested=Array(ids[start..<min(start+50,ids.count)])
                    let page=try await client.history.query(context:context,kind:"message_state",scope:"home",fields:["target":requested])
                    try check()
                    guard HistoryHTTP.integer(page["through"])==through else {throw HistoryFailure.changed}
                    let rows=try JSONDecoder().decode([HistoryMessageState].self,from:JSONSerialization.data(withJSONObject:page["items"]!))
                    guard rows.count==requested.count,Set(rows.map(\.id))==Set(requested) else {throw HistoryFailure.invalidResponse}
                    for row in rows {resolved[row.id]=row}
                }
                let candidates=bubble.historyBodyCandidates(states:resolved,questions:questions,muted:model.petMuted,opened:chatOpen ? model.selected:nil,now:now)
                var bodies:[ConversationMessage]=[]
                for id in candidates {
                    guard let state=resolved[id],let key=state.conversationKey else {throw HistoryFailure.invalidResponse}
                    let page=try await client.history.query(context:context,kind:"resolve",scope:key.employee,fields:["target":[id]])
                    try check()
                    guard HistoryHTTP.integer(page["through"])==through,let rows=page["items"] as? [[String:Any]],rows.count==1,let row=rows.first,row["msg_id"] as? String==id,HistoryHTTP.integer(row["revision"])==state.revision else {throw HistoryFailure.changed}
                    let body:[String:Any]
                    if let reference=row["contentRef"] as? String {body=try await client.history.content(reference:reference,id:id,revision:state.revision!)} else {body=row}
                    try check()
                    let message=try HistoryHTTP.message(body)
                    guard message.key==key else {throw HistoryFailure.invalidResponse}
                    bodies.append(message)
                }
                try check()
                self.context=context;self.states=resolved;self.bodies=bodies;self.task=nil;self.onChange?()
            } catch {
                guard self.signature==stamp else {return}
                self.task=nil;self.context=nil;self.states=[:];self.bodies=[]
                self.failed = !(error is CancellationError) && error as? HistoryFailure != .changed
                self.onChange?()
            }
        }
    }
}
