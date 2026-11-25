import Foundation

/// Ephemeral search presentation. Never convertible to a cached message body.
struct HistorySearchHit: Decodable {
    let id: String, snippet: String, role: String, speaker: String, timestamp: String
    let key: HistoryThreadSummary.Key
    let notes: [String]
    let revision: Int
    var conversationKey: ConversationKey { .init(employee:key.room,thread:key.thread) }
}
struct HistorySearchGroup: Decodable {
    let key: HistoryThreadSummary.Key
    let matches: [HistorySearchHit]
    let rootSnippet: String, latest: String
    let exact: Bool
    var conversationKey: ConversationKey { .init(employee:key.room,thread:key.thread) }
}

@MainActor extension HistoryHTTP {
    func search(context: String, query: String, mode: String) async throws -> [[String:Any]] {
        var rows: [[String:Any]] = [], cursor: String?, seen = Set<String>(), through: Int?
        repeat {
            var fields: [String:Any] = ["mode":mode,"query":query]
            if let cursor { fields["cursor"] = cursor }
            let page = try await self.query(context:context,kind:"search",scope:"home",fields:fields)
            let head = Self.integer(page["through"])!
            if let through, through != head { throw HistoryFailure.changed }
            through = head
            rows += page["items"] as! [[String:Any]]
            guard rows.count <= (mode == "sidebar" ? 30:200) else { throw HistoryFailure.invalidResponse }
            if mode == "groups" {
                let candidates=rows.reduce(0) { $0 + (($1["matches"] as? [[String:Any]])?.count ?? 0) }
                guard candidates <= 200 else { throw HistoryFailure.invalidResponse }
            }
            cursor = page["next"] as? String
            if let cursor, !seen.insert(cursor).inserted { throw HistoryFailure.invalidResponse }
        } while cursor != nil
        return rows
    }
    static func validateSearchHit(_ row: [String:Any]) throws {
        guard integer(row["revision"]) != nil, ["owner","employee"].contains(row["role"] as? String ?? "") else { throw HistoryFailure.invalidResponse }
        _ = try JSONDecoder().decode(HistorySearchHit.self,from:JSONSerialization.data(withJSONObject:row))
    }
}

/// Owns one cancellable search, independent of the conversation body projection.
@MainActor final class HistorySearchState {
    private var task: Task<Void,Never>?
    private var identity = ""
    private var generation = 0
    private(set) var groups: [HistorySearchGroup] = []
    private(set) var hits: [HistorySearchHit] = []
    private(set) var busy = false
    private(set) var failed = false
    var onChange: (() -> Void)?
    deinit { task?.cancel() }
    func reset() {
        generation += 1; task?.cancel(); task=nil;identity="";groups=[];hits=[];busy=false;failed=false
    }
    func retry() { identity="";onChange?() }
    func update(query:String,mode:String,client:GateClient,model:ConversationModel) {
        let key = query+"|"+mode+"|"+(client.historySession ?? "")+"|"+(model.history.context ?? "")+"|"+String(model.applied)
        guard identity != key else { return }
        reset(); identity=key
        guard !query.trimmingCharacters(in:.whitespacesAndNewlines).isEmpty else { return }
        busy=true
        guard let context=model.history.context,client.isConnected else { return }
        let run=generation
        task=Task { [weak self] in
            do {
                try await Task.sleep(nanoseconds:250_000_000)
                let rows=try await client.history.search(context:context,query:query,mode:mode)
                try Task.checkCancellation()
                guard let self,self.generation==run,model.history.context==context else { return }
                let data=try JSONSerialization.data(withJSONObject:rows)
                if mode=="groups" {self.groups=try JSONDecoder().decode([HistorySearchGroup].self,from:data)}
                else {self.hits=try JSONDecoder().decode([HistorySearchHit].self,from:data)}
                self.busy=false;self.task=nil;self.onChange?()
            } catch {
                guard let self,self.generation==run,!Task.isCancelled else{return}
                self.busy=false;self.failed=true;self.task=nil;self.onChange?()
            }
        }
    }
}
