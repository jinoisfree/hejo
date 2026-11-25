import Foundation

/// One active bootstrap/refresh per connection. Live dirtiness is coalesced;
/// changed member/selection input cancels obsolete work before publishing it.
@MainActor final class HistoryCoordinator {
    private let client: GateClient
    private let model: ConversationModel
    private var task: Task<Void,Never>?
    private var input: Data?
    private var session: String?
    private var generation = 0
    private var operation = 0
    private var dirty = false
    private var contextDirty = true
    private var contextVersion = 0
    private var seedNeeded = true
    private var chooseInitialThread = true
    private var expiry: Double?
    private var selection: ConversationKey?
    private var selectionScope = ""
    private var visible = false
    private var reads: [(String,String,ConversationKey?,Int)] = []
    private var automaticRead: String?
    private enum Demand: Equatable { case threads(String), messages(ConversationKey), restore(ConversationKey,String), open(ConversationKey,String?), content(ConversationKey,String) }
    private var demands: [Demand] = []
    func olderThreads() { enqueue(.threads(scope)) }
    func olderMessages(_ key: ConversationKey) { enqueue(.messages(key)) }
    @discardableResult func restoreEvicted(_ key:ConversationKey,before:Int?=nil,after:Int?=nil) -> Bool {
        guard let id=model.evictedHistoryBody(key,before:before,after:after) else{return false}
        enqueue(.restore(key,id));return true
    }
    func open(_ key: ConversationKey, anchor: String? = nil) { model.historyOpenAnchor = anchor; enqueue(.open(key,anchor)) }
    func content(_ id: String, key: ConversationKey) { enqueue(.content(key,id)) }
    func copy(_ key: ConversationKey, progress: (Int,Int)->Void) async throws -> String {
        guard let context = model.history.context, client.isConnected else { throw HistoryFailure.changed }
        let run = operation
        let names=Dictionary(uniqueKeysWithValues:Set(model.employees.map(\.id)).union(model.groups.keys).union([HomeRoom.id]).map{($0,model.name($0))})
        return try await HistoryCopy.collect(http:client.history,key:key,context:context,name:{ names[$0] ?? $0 },group:model.groups[key.employee] != nil,check:{
            try self.check(run)
            guard self.model.history.context == context else { throw HistoryFailure.changed }
        },progress:progress)
    }
    private func enqueue(_ demand: Demand) {
        guard client.store.historyMode else { return }
        inputsChanged()
        if !demands.contains(demand) { demands.append(demand) }
        failure = nil; start()
    }
    private func demand(_ demand: Demand, context: String, run: Int) async throws {
        switch demand {
        case .threads(let scope):
            guard let state = model.history.threadPages[scope], state.context == context, let cursor = state.next else { return }
            let page = try await query("threads",scope:scope,context:context,run:run,fields:["cursor":cursor])
            try model.applyHistoryThreads(page,scope:scope,context:context,generation:generation,older:true)
        case .messages(let key):
            guard let state = model.history.messagePages[key], state.context == context, let cursor = state.next else { return }
            var fields:[String:Any] = ["target":["room":key.employee,"thread":key.thread],"cursor":cursor]
            if let anchor = state.anchor {fields["anchor"] = anchor}
            let page = try await query("messages",scope:key.employee,context:context,run:run,fields:fields)
            try model.applyHistoryMessages(page,key:key,context:context,generation:generation,anchor:state.anchor)
        case .restore(let key,let id):
            guard model.evictedHistoryBodies[id]?.key == key else {return}
            let page=try await query("resolve",scope:key.employee,context:context,run:run,fields:["target":[id],"limit":1])
            guard let rows=page["items"] as? [[String:Any]],rows.count==1,rows[0]["msg_id"] as? String == id else {throw HistoryFailure.invalidResponse}
            if rows[0]["missing"] as? Bool == true {throw HistoryFailure.server("not_found",retryable:true)}
            model.historyRestorePin=id
            do {
                try model.applyHistoryBody(rows[0],expectedKey:key)
                try await content(id,key:key,context:context,run:run)
                if model.evictedHistoryBodies[id] != nil {throw HistoryFailure.server("restore_changed",retryable:true)}
            } catch {
                if operation == run,model.historyRestorePin == id {model.historyRestorePin=nil}
                throw error
            }
        case .content(let key,let id):
            try await content(id,key:key,context:context,run:run)
        case .open(let key,let anchor):
            var fields:[String:Any] = ["target":["room":key.employee,"thread":key.thread]]
            if let anchor {fields["anchor"] = anchor}
            let page = try await query("resolve",scope:key.employee,context:context,run:run,fields:fields)
            try model.applyHistoryMessages(page,key:key,context:context,generation:generation,anchor:anchor)
            guard let summary = model.history.summaries[key] else { return }
            // Root is an explicit ID, never the first body of a partial page.
            let root = try await query("resolve",scope:key.employee,context:context,run:run,fields:["target":[summary.rootID]])
            for row in root["items"] as! [[String:Any]] { try model.applyHistoryBody(row,expectedKey:key) }
            // Large bodies are fetched only by this explicit open action, not bootstrap.
            try await content(summary.rootID,key:key,context:context,run:run)
            if let anchor {try await content(anchor,key:key,context:context,run:run)}
        }
        onChange?()
        try check(run)
        if case .open(let key,let anchor) = demand {onAnchor?(key,anchor)}
    }
    private func content(_ id: String, key: ConversationKey, context: String, run: Int) async throws {
        guard model.history.contentKeys[id] == key, let reference = model.history.contentReferences[id],
              let revision = model.history.revisions[id] else { return }
        let body = try await client.history.content(reference:reference,id:id,revision:revision)
        try check(run)
        guard model.history.context == context else { throw HistoryFailure.changed }
        try model.applyHistoryBody(body,expectedKey:key)
    }
    var onChange: (() -> Void)?
    var onAnchor: ((ConversationKey,String?) -> Void)?
    var onReceipts: (([[String:Any]]) -> Void)?
    var pendingReceipts: (() -> [(String,String)])?
    private(set) var failure: Error?
    var busy: Bool { task != nil }
    init(client: GateClient, model: ConversationModel) { self.client = client; self.model = model }
    deinit { task?.cancel() }
    func stop() { model.historyRestorePin=nil; operation += 1; task?.cancel(); task = nil; reads = []; demands = []; input = nil; session = nil }
    private var scope: String { model.isHome ? "home":model.selected?.employee ?? "home" }
    func inputsChanged() {
        guard client.store.historyMode, client.isConnected, let current = client.historySession else { return }
        do {
            var fields = try model.historyContext(generation:0)
            fields.removeValue(forKey:"now")
            let encoded = try JSONSerialization.data(withJSONObject:fields,options:.sortedKeys)
            let newSession = current != session
            let newInput = encoded != input
            let newSelection = selection != model.selected || selectionScope != scope || visible != model.visible
            guard newSession || newInput || newSelection else { return }
            operation += 1; model.historyRestorePin=nil; task?.cancel(); task = nil; reads = []; demands = []; failure = nil
            if newSession { generation = 0; seedNeeded = true; automaticRead = nil }
            if newSession || newInput { contextDirty = true; contextVersion += 1; model.history.context = nil }
            input = encoded; session = current; selection = model.selected; selectionScope = scope; visible = model.visible
            dirty = true; start()
        } catch { failure = error; onChange?() }
    }
    func liveChanged() { contextVersion += 1; contextDirty = true; dirty = true; start() }
    func tick() {
        inputsChanged()
        if let expiry, model.noticeClock().timeIntervalSince1970 >= expiry {
            self.expiry = nil; contextVersion += 1; contextDirty = true; dirty = true; start()
        }
    }
    func retry() { failure = nil; contextVersion += 1; contextDirty = true; dirty = true; start() }
    func read(action: String, room: String, key: ConversationKey?) {
        guard client.store.historyMode, model.memberState.account.isEmpty || model.memberState.hasFetched else { return }
        failure = nil
        let scope = room == HomeRoom.id ? "home":room
        let intent = model.history.intentGeneration
        if !reads.contains(where:{$0.0 == action && $0.1 == scope && $0.2 == key && $0.3 == intent}) {
            reads.append((action,scope,key,intent))
        }
        start()
    }
    private func check(_ run: Int) throws {
        try Task.checkCancellation()
        guard operation == run, client.historySession == session, client.isConnected else { throw HistoryFailure.changed }
    }
    private func start() {
        guard task == nil, client.isConnected, client.historySession != nil else { return }
        let run = operation
        task = Task { [weak self] in
            guard let self else { return }
            do {
                // Collect same-turn roster/member/visibility notifications first.
                await Task.yield()
                while self.dirty || !self.reads.isEmpty || !self.demands.isEmpty {
                    try self.check(run)
                    let refresh = self.dirty; self.dirty = false
                    let context = try await self.context(run)
                    if self.seedNeeded && (self.model.memberState.account.isEmpty || self.model.memberState.hasFetched) {
                        try await self.readPlan("seed",scope:"home",key:nil,intent:self.model.history.intentGeneration,context:context,run:run,sidebar:true)
                        try self.check(run)
                        self.seedNeeded = false
                    }
                    if refresh { try await self.refresh(context:context,run:run) }
                    while let request = self.demands.first {
                        try await self.demand(request,context:context,run:run)
                        try self.check(run)
                        self.demands.removeFirst()
                    }
                    while !self.reads.isEmpty {
                        let request = self.reads.removeFirst()
                        guard request.3 == self.model.history.intentGeneration else { continue }
                        try await self.readPlan(request.0,scope:request.1,key:request.2,intent:request.3,context:context,run:run)
                        try self.check(run)
                    }
                }
                try self.check(run)
                self.task = nil; self.failure = nil; self.onChange?()
            } catch {
                guard self.operation == run else { return }
                self.task = nil
                if !(error is CancellationError) && error as? HistoryFailure != .changed { self.failure = error }
                self.onChange?()
            }
        }
    }
    private func context(_ run: Int) async throws -> String {
        if !contextDirty, let current = model.history.context { return current }
        generation += 1
        let currentGeneration = generation, version = contextVersion
        let token = try await client.history.context(model.historyContext(generation:currentGeneration))
        try check(run)
        model.history.beginContext(token,generation:currentGeneration); contextDirty = version != contextVersion
        return token
    }
    private func query(_ kind: String, scope: String, context: String, run: Int, fields: [String:Any] = [:]) async throws -> [String:Any] {
        let page = try await client.history.query(context:context,kind:kind,scope:scope,fields:fields)
        try check(run)
        guard model.history.context == context else { throw HistoryFailure.changed }
        return page
    }
    private func readPlan(_ action: String, scope: String, key: ConversationKey?, intent: Int, context: String, run: Int, sidebar: Bool = false) async throws {
        var fields: [String:Any] = ["action":action]
        if sidebar { fields["mode"] = "sidebar" }
        if let key { fields["target"] = ["room":key.employee,"thread":key.thread] }
        var changes: [String:String] = [:], cursors = Set<String>(), through: Int?
        repeat {
            let page = try await query("read_plan",scope:scope,context:context,run:run,fields:fields)
            guard model.history.intentGeneration == intent else { throw HistoryFailure.changed }
            let head = page["through"] as! Int
            guard through == nil || through == head else { throw HistoryFailure.invalidResponse }
            through = head
            for (key,value) in page["changes"] as! [String:String] {
                guard changes[key] == nil || changes[key] == value else { throw HistoryFailure.invalidResponse }
                changes[key] = value
            }
            guard try JSONSerialization.data(withJSONObject:changes).count <= 1024*1024 else { throw HistoryFailure.tooLarge }
            if let next = page["next"] as? String {
                guard cursors.insert(next).inserted else { throw HistoryFailure.invalidResponse }
                fields["cursor"] = next
            } else { break }
        } while true
        // No partial-page state writes. MemberState's callback invalidates the input
        // and starts a fresh generation if this transaction actually changes state.
        try model.applyHistoryReadPlan(changes,context:context,generation:generation,intent:intent)
    }
    private func refresh(context: String, run: Int) async throws {
        model.history.refreshing = true
        var fields: [String:Any] = ["mode":"sidebar"], totals: [[String:Any]] = []
        repeat {
            let page = try await query("overview",scope:"home",context:context,run:run,fields:fields)
            totals += page["items"] as! [[String:Any]]
            expiry = (page["totals"] as? [String:Any])?["nextNoticeExpiry"] as? Double
            if let next = page["next"] as? String { fields["cursor"] = next } else { break }
        } while true
        try model.applyHistoryOverview(totals,context:context,generation:generation)
        let currentScope = scope
        let threads = try await query("threads",scope:currentScope,context:context,run:run)
        try model.applyHistoryThreads(threads,scope:currentScope,context:context,generation:generation)
        // Publish complete metadata atomically; never count only the first page.
        var noticeFields:[String:Any] = ["mode":"sidebar"], noticeRows:[[String:Any]] = [], noticeHead:Int?, cursors=Set<String>()
        repeat {
            let page = try await query("notices",scope:"home",context:context,run:run,fields:noticeFields)
            let head = HistoryHTTP.integer(page["through"])!
            if let noticeHead, noticeHead != head { throw HistoryFailure.changed }
            noticeHead = head
            noticeRows += page["items"] as! [[String:Any]]
            guard let next = page["next"] as? String else { break }
            guard cursors.insert(next).inserted else { throw HistoryFailure.invalidResponse }
            noticeFields["cursor"] = next
        } while true
        let notices = try JSONDecoder().decode([HistoryNotice].self,from:JSONSerialization.data(withJSONObject:noticeRows))
        guard Set(notices.map(\.id)).count == notices.count else { throw HistoryFailure.invalidResponse }
        model.history.notices = notices
        model.history.noticeRows = Dictionary(grouping:noticeRows,by:{ ($0["key"] as! [String:String])["room"]! })
        model.history.noticeRows["home"] = noticeRows.filter { model.homeScope.contains(($0["key"] as! [String:String])["room"]!) }
        var questionRows:[[String:Any]]=[],questionFields:[String:Any]=[:],questionHead:Int?,questionCursors=Set<String>()
        repeat {
            let page=try await query("questions",scope:"home",context:context,run:run,fields:questionFields)
            let head=HistoryHTTP.integer(page["through"])!
            if let questionHead,questionHead != head {throw HistoryFailure.changed}
            questionHead=head;questionRows += page["items"] as! [[String:Any]]
            guard let next=page["next"] as? String else {break}
            guard questionCursors.insert(next).inserted else {throw HistoryFailure.invalidResponse}
            questionFields["cursor"]=next
        } while true
        let questions=try JSONDecoder().decode([HistoryQuestion].self,from:JSONSerialization.data(withJSONObject:questionRows))
        guard Set(questions.map(\.id)).count==questions.count else {throw HistoryFailure.invalidResponse}
        model.history.questions=questions
        if chooseInitialThread {
            chooseInitialThread = false
            if model.selected.flatMap({model.history.summaries[$0]}) == nil {
                let choice = try await query("threads",scope:currentScope,context:context,run:run,fields:["mode":"selection","limit":1])
                if let row = (choice["items"] as? [[String:Any]])?.first {
                    let summary = try JSONDecoder().decode(HistoryThreadSummary.self,from:JSONSerialization.data(withJSONObject:row))
                    model.history.summaries[summary.conversationKey] = summary
                    model.select(summary.conversationKey,notify:false,inHome:model.isHome,markRead:false)
                    selection = model.selected
                }
            }
        }
        if let selected = model.selected, model.history.summaries[selected] != nil {
            let page = try await query("messages",scope:selected.employee,context:context,run:run,
                                       fields:["target":["room":selected.employee,"thread":selected.thread]])
            try model.applyHistoryMessages(page,key:selected,context:context,generation:generation)
        }
        let receipts = Dictionary(grouping:pendingReceipts?() ?? [],by:{$0.1})
        for (room, pending) in receipts {
            let ids = pending.map{$0.0}
            for start in stride(from:0,to:ids.count,by:50) {
                let page = try await query("receipt",scope:room,context:context,run:run,fields:["target":Array(ids[start..<min(start+50,ids.count)])])
                onReceipts?(page["items"] as! [[String:Any]])
            }
        }
        model.history.refreshing = dirty || contextDirty
        if model.visible && (model.memberState.account.isEmpty || model.memberState.hasFetched) {
            let signature = currentScope + ":" + String(threads["through"] as! Int) + ":" + String(model.history.intentGeneration)
            if automaticRead != signature {
                automaticRead = signature
                read(action:"enter",room:model.selectionIdentity,key:nil)
            }
        }
        onChange?()
    }
}
