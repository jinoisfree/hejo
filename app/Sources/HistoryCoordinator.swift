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
    private var refreshFailed = false
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
    private enum Demand: Equatable {
        case threads(String), messages(ConversationKey), restore(ConversationKey,String)
        case open(ConversationKey,String?), openForReply(ConversationKey), content(ConversationKey,String)
    }
    enum AutoLoad: Hashable {
        case thread(ConversationKey), root(ConversationKey), content(ConversationKey,String)
        case restore(ConversationKey,String), older(ConversationKey,String), newer(ConversationKey,String)

        var key: ConversationKey {
            switch self {
            case .thread(let key), .root(let key), .content(let key,_), .restore(let key,_),
                 .older(let key,_), .newer(let key,_): return key
            }
        }
    }
    private enum AutoState { case waiting(until: Date), failed(quiet: Bool) }
    private static let snapshotRetryDelay: TimeInterval = 60
    private var loadingTargets: [AutoLoad] = []
    struct CardTarget: Equatable {
        let key: ConversationKey
        let message: String
    }
    private var cardTargets: [CardTarget] = []

    func updateCardTargets(_ targets: [CardTarget]) {
        guard client.store.historyMode,targets != cardTargets else { return }
        cardTargets = targets
        startIfNeeded()
    }

    private func cardLoad(_ target: CardTarget) -> AutoLoad? {
        let key = target.key, id = target.message
        let root = model.history.summaries[key]?.rootID
        if model.history.messagePages[key] == nil && !model.hasUnpagedLiveHistory(key) { return .thread(key) }
        if let root,model.messages[root] == nil,model.evictedHistoryBodies[root] == nil {
            if model.history.contentReferences[root] != nil { return .content(key,root) }
            return loadStates[.thread(key)] == nil ? .root(key):.thread(key)
        }
        guard id == root || model.historyReplyIDs(key).contains(id),
              model.history.contentReferences[id] != nil,model.evictedHistoryBodies[id] == nil else { return nil }
        return .content(key,id)
    }
    private var loadStates: [AutoLoad:AutoState] = [:]
    private var retried = Set<AutoLoad>()
    private var visibleBodies = Set<String>()
    private var automaticAppends = Set<ConversationKey>()
    private var automaticPrependAnchors: [ConversationKey:String] = [:]

    func updateLoadingTargets(_ targets: [AutoLoad], visibleBodies: Set<String>, scope: String) {
        guard scope == self.scope, client.store.historyMode else { return }
        loadingTargets = targets
        self.visibleBodies = visibleBodies
        startIfNeeded()
    }
    func failed(_ target: AutoLoad) -> Bool {
        if case .failed(quiet:false) = loadStates[target] { return true }
        return false
    }
    func retry(_ target: AutoLoad) {
        guard failed(target) else { return }
        loadStates[target] = nil
        retried.remove(target)
        onChange?()
        startIfNeeded()
    }
    func takeAutomaticAppends() -> Set<ConversationKey> {
        defer { automaticAppends.removeAll() }
        return automaticAppends
    }

    func takeAutomaticPrependAnchor(for key: ConversationKey?) -> String? {
        defer { automaticPrependAnchors.removeAll() }
        return key.flatMap { automaticPrependAnchors[$0] }
    }

    private func needsLoad(_ target: AutoLoad) -> Bool {
        let key = target.key
        guard let summary = model.history.summaries[key] else { return false }
        switch target {
        case .thread, .root:
            guard model.messages[summary.rootID] == nil,
                  model.history.contentReferences[summary.rootID] == nil,
                  model.evictedHistoryBodies[summary.rootID] == nil else { return false }
            let useRoot = key == model.selected || (model.history.messagePages[key] != nil && loadStates[.thread(key)] == nil)
            if case .root = target { return useRoot }
            return !useRoot
        case .content(_,let id):
            return model.history.contentReferences[id] != nil && (model.evictedHistoryBodies[id] == nil || visibleBodies.contains(id))
        case .restore(_,let id):
            return model.evictedHistoryBodies[id] != nil && visibleBodies.contains(id)
        case .older(_,let id): return model.history.messagePages[key]?.next != nil && model.historyReplyIDs(key).first == id
        case .newer(_,let id): return model.hasUnloadedNewerReplies(key) && model.historyReplyIDs(key).last == id
        }
    }

    private func nextLoad() -> AutoLoad? {
        guard failure == nil else { return nil }
        let now = model.noticeClock()
        func available(_ target: AutoLoad) -> Bool {
            switch loadStates[target] {
            case nil: return true
            case .waiting(let until): return now >= until
            case .failed: return false
            }
        }
        return loadingTargets.first { needsLoad($0) && available($0) }
            ?? cardTargets.lazy.compactMap { self.cardLoad($0) }.first(where:available)
    }

    private func startIfNeeded() {
        if dirty || (failure == nil && (!reads.isEmpty || !demands.isEmpty || nextLoad() != nil)) { start() }
    }

    private func load(_ target: AutoLoad, context: String, run: Int, forCard: Bool) async throws {
        let key = target.key
        switch target {
        case .thread:
            let page = try await threadPage("resolve",key:key,context:context,run:run,retry:false)
            try model.applyHistoryMessages(page,key:key,context:context,generation:generation)
            if !forCard,let id = model.history.summaries[key]?.rootID,model.messages[id] == nil,
               model.history.contentReferences[id] == nil, model.evictedHistoryBodies[id] == nil {
                try await loadRoot(key,context:context,run:run,retry:false)
            }
        case .root:
            try await loadRoot(key,context:context,run:run,retry:false)
        case .content(_,let id):
            try await content(id,key:key,context:context,run:run,retry:false)
        case .restore(_,let id):
            try await demand(.restore(key,id),context:context,run:run,retry:false,publish:false)
        case .older(_,let id):
            try await loadOlder(key,context:context,run:run,rebuild:true)
            if model.historyOpenAnchor == id { automaticPrependAnchors[key] = id }
        case .newer(_,let id):
            let page = try await threadPage("messages",key:key,context:context,run:run,anchor:id,retry:false)
            try model.applyHistoryMessages(page,key:key,context:context,generation:generation,anchor:id,merge:.newer)
            automaticAppends.insert(key)
        }
    }

    private func threadPage(_ kind: String, key: ConversationKey, context: String, run: Int,
                            anchor: String? = nil, cursor: String? = nil, retry: Bool = true) async throws -> [String:Any] {
        var fields: [String:Any] = ["target":["room":key.employee,"thread":key.thread]]
        fields["anchor"] = anchor
        fields["cursor"] = cursor
        return try await query(kind,scope:key.employee,context:context,run:run,fields:fields,retry:retry)
    }

    private func loadRoot(_ key: ConversationKey, context: String, run: Int, retry: Bool = true) async throws {
        guard let id = model.history.summaries[key]?.rootID else { return }
        let page = try await query("resolve",scope:key.employee,context:context,run:run,fields:["target":[id]],retry:retry)
        guard let row = (page["items"] as? [[String:Any]])?.first, row["msg_id"] as? String == id else {
            throw HistoryFailure.invalidResponse
        }
        if row["missing"] as? Bool == true { throw HistoryFailure.server("target_missing",retryable:false) }
        try model.applyHistoryBody(row,expectedKey:key)
    }

    private func loadOlder(_ key: ConversationKey, context: String, run: Int, rebuild: Bool) async throws {
        guard let state = model.history.messagePages[key], let existing = state.next else { return }
        if !rebuild && state.context != context { return }
        var cursor: String? = state.context == context ? existing : nil
        var anchor = state.anchor
        var attempts = 0
        var missing = Set<String>()
        var rebuiltPage: [String:Any]?
        while true {
            if let active = cursor {
                do {
                    let page = try await threadPage("messages",key:key,context:context,run:run,anchor:anchor,cursor:active,retry:!rebuild)
                    if let rebuiltPage {
                        try model.applyHistoryMessages(rebuiltPage,key:key,context:context,generation:generation,anchor:anchor,merge:.older)
                    }
                    try model.applyHistoryMessages(page,key:key,context:context,generation:generation,anchor:anchor,merge:.older)
                    return
                } catch HistoryFailure.server("cursor_expired", _) where rebuild {
                    cursor = nil
                }
            }
            guard attempts < 2, let candidate = model.historyReplyIDs(key).first(where:{ !missing.contains($0) }) else {
                throw HistoryFailure.server("cursor_expired",retryable:false)
            }
            attempts += 1
            do {
                let page = try await threadPage("messages",key:key,context:context,run:run,anchor:candidate,retry:false)
                anchor = candidate
                cursor = page["next"] as? String
                rebuiltPage = page
                if cursor == nil {
                    try model.applyHistoryMessages(page,key:key,context:context,generation:generation,anchor:anchor,merge:.older)
                    return
                }
            } catch HistoryFailure.server("target_missing", _) {
                missing.insert(candidate)
            }
        }
    }

    private var demands: [Demand] = []
    private struct ReplyOpenWaiter {
        let id: String
        let continuation: CheckedContinuation<Void,Error>
    }
    private var replyOpenWaiters: [ConversationKey:[ReplyOpenWaiter]] = [:]
    func olderThreads() { enqueue(.threads(scope)) }
    func olderMessages(_ key: ConversationKey) { enqueue(.messages(key)) }
    @discardableResult func restoreEvicted(_ key:ConversationKey,before:Int?=nil,after:Int?=nil) -> Bool {
        guard let id=model.evictedHistoryBody(key,before:before,after:after) else{return false}
        enqueue(.restore(key,id));return true
    }
    private var navigation: (key:ConversationKey,message:String?,needsBody:Bool)?

    func beginNavigation(_ key:ConversationKey,message:String?,needsBody:Bool) {
        inputsChanged()
        navigation = (key,message,needsBody)
        if needsBody { open(key,anchor:message) }
    }

    func cancelNavigation() {
        guard let request = navigation else { return }
        navigation = nil
        if let message=request.message,model.historyOpenAnchor == message { model.historyOpenAnchor = nil }
    }

    @discardableResult func open(_ key: ConversationKey, anchor: String? = nil) -> Bool {
        model.historyOpenAnchor = anchor
        if anchor == nil {
            // The viewport restores evicted slots in an already fetched recent page.
            if model.history.messagePages[key] != nil,!model.hasUnloadedNewerReplies(key),
               model.evictedHistoryBody(key) != nil { return false }
            // Selection already refreshes this complete live thread.
            if model.selected == key,model.hasUnpagedLiveHistory(key) { return false }
        }
        enqueue(.open(key,anchor))
        return true
    }
    func prepareReply(_ key: ConversationKey, pendingID: String) async throws {
        guard model.hasUnloadedNewerReplies(key) else { return }
        try Task.checkCancellation()
        guard client.isConnected, client.historySession != nil else { throw HistoryFailure.changed }
        inputsChanged()
        try await withCheckedThrowingContinuation { continuation in
            replyOpenWaiters[key,default:[]].append(.init(id:pendingID,continuation:continuation))
            enqueue(.openForReply(key))
        }
        try Task.checkCancellation()
    }
    private func finishReplyOpen(_ key: ConversationKey, result: Result<Void,Error>) {
        for waiter in replyOpenWaiters.removeValue(forKey:key) ?? [] {
            waiter.continuation.resume(with:result)
        }
    }
    private func failReplyOpens(_ error: Error) {
        for key in Array(replyOpenWaiters.keys) {
            finishReplyOpen(key,result:.failure(error))
        }
        demands.removeAll { if case .openForReply = $0 { return true }; return false }
    }
    func content(_ id: String, key: ConversationKey) { enqueue(.content(key,id)) }
    func copy(_ key: ConversationKey, progress: (Int,Int)->Void) async throws -> String {
        guard let context = model.history.context, client.isConnected else { throw HistoryFailure.changed }
        let run = operation
        let names=Dictionary(uniqueKeysWithValues:Set(model.employees.map(\.id)).union(model.groups.keys).union([HomeRoom.id]).map{($0,model.name($0))})
        return try await HistoryCopy.collect(http:client.history,key:key,context:context,name:{ names[$0] ?? $0 },ownerName:model.ownerName,group:model.groups[key.employee] != nil,check:{
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
    private func demand(_ demand: Demand, context: String, run: Int, retry: Bool = true, publish: Bool = true) async throws {
        switch demand {
        case .threads(let scope):
            guard let state = model.history.threadPages[scope], state.context == context, let cursor = state.next else { return }
            let page = try await query("threads",scope:scope,context:context,run:run,fields:["cursor":cursor])
            try model.applyHistoryThreads(page,scope:scope,context:context,generation:generation,older:true)
        case .messages(let key):
            try await loadOlder(key,context:context,run:run,rebuild:false)
        case .restore(let key,let id):
            guard model.evictedHistoryBodies[id]?.key == key else {return}
            let page=try await query("resolve",scope:key.employee,context:context,run:run,fields:["target":[id],"limit":1],retry:retry)
            guard let rows=page["items"] as? [[String:Any]],rows.count==1,rows[0]["msg_id"] as? String == id else {throw HistoryFailure.invalidResponse}
            if rows[0]["missing"] as? Bool == true {throw HistoryFailure.server("not_found",retryable:true)}
            model.historyRestorePin=id
            do {
                try model.applyHistoryBody(rows[0],expectedKey:key)
                try await content(id,key:key,context:context,run:run,retry:retry)
                if model.evictedHistoryBodies[id] != nil {throw HistoryFailure.server("restore_changed",retryable:true)}
            } catch {
                if operation == run,model.historyRestorePin == id {model.historyRestorePin=nil}
                throw error
            }
        case .content(let key,let id):
            try await content(id,key:key,context:context,run:run)
        case .open(let key,let anchor):
            if anchor != nil || navigation?.key != key || navigation?.needsBody != true
                || model.history.summaries[key] == nil {
                try await loadThreadOpening(key,anchor:anchor,context:context,run:run)
            }
        case .openForReply(let key):
            if model.hasUnloadedNewerReplies(key) {
                try await loadThreadOpening(key,anchor:nil,context:context,run:run)
                if model.selected == key { model.historyOpenAnchor = nil }
            }
        }
        if publish { onChange?() }
        try check(run)
        switch demand {
        case .open(let key,let anchor):
            if navigation?.key == key,navigation?.message == anchor { navigation?.needsBody = false }
            onAnchor?(key,anchor,false)
        case .openForReply(let key):
            if model.selected == key, let waiter = replyOpenWaiters[key]?.last {
                onAnchor?(key,"pending:"+waiter.id,true)
            }
        default: break
        }
    }
    private func loadThreadOpening(_ key: ConversationKey, anchor: String?, context: String, run: Int) async throws {
        func superseded() -> Bool {
            guard let anchor,let navigation,navigation.key == key else { return false }
            return navigation.message != anchor
        }
        guard !superseded() else { return }
        let page: [String:Any]
        do {
            page = try await threadPage("resolve",key:key,context:context,run:run,anchor:anchor)
        } catch {
            if superseded() { return }
            throw error
        }
        guard !superseded() else { return }
        try model.applyHistoryMessages(page,key:key,context:context,generation:generation,anchor:anchor)
        guard let summary = model.history.summaries[key] else { return }
        // Root is an explicit ID, never the first body of a partial page.
        try await loadRoot(key,context:context,run:run)
        try await content(summary.rootID,key:key,context:context,run:run)
        if let anchor {try await content(anchor,key:key,context:context,run:run)}
    }
    private func content(_ id: String, key: ConversationKey, context: String, run: Int, retry: Bool = true) async throws {
        guard model.history.contentKeys[id] == key, let reference = model.history.contentReferences[id],
              let revision = model.history.revisions[id] else { return }
        let body = try await client.history.content(reference:reference,id:id,revision:revision,retry:retry)
        try check(run)
        guard model.history.context == context else { throw HistoryFailure.changed }
        try model.applyHistoryBody(body,expectedKey:key)
    }
    var onChange: (() -> Void)?
    var onRefreshStarted: (() -> Void)?
    var onAnchor: ((ConversationKey,String?,Bool) -> Void)?
    var onReceipts: (([[String:Any]]) -> Void)?
    var pendingReceipts: (() -> [(String,String)])?
    private(set) var failure: Error?
    var busy: Bool { task != nil }
    var showProgress: Bool { busy && (dirty || !demands.isEmpty || model.history.refreshing) }
    init(client: GateClient, model: ConversationModel) { self.client = client; self.model = model }
    deinit { task?.cancel() }
    func stop() { loadingTargets=[]; loadStates=[:]; retried=[]; visibleBodies=[]; automaticAppends=[]; automaticPrependAnchors=[:]; model.historyRestorePin=nil; operation += 1; task?.cancel(); task = nil; reads = []; demands = []; failReplyOpens(HistoryFailure.changed); input = nil; session = nil }
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
            operation += 1; model.historyRestorePin=nil; task?.cancel(); task = nil; demands = []; failure = nil
            if let request = navigation {
                if request.key != model.selected { cancelNavigation() }
                else if request.needsBody { demands.append(.open(request.key,request.message)) }
            }
            if newSession { reads.removeAll() }
            else { reads.removeAll { $0.3 != model.history.intentGeneration } }
            failReplyOpens(HistoryFailure.changed)
            if newSession {
                refreshFailed = false
                generation = 0; seedNeeded = true; automaticRead = nil
                loadStates = [:]; retried = []; visibleBodies = []; automaticAppends = []; automaticPrependAnchors = [:]
            }
            if newSession || selectionScope != scope || !model.visible && visible {
                loadingTargets = []; visibleBodies = []
            }
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
        startIfNeeded()
    }
    func retry() { failure = nil; refreshFailed = false; contextVersion += 1; contextDirty = true; dirty = true; start() }
    func read(action: String, room: String, key: ConversationKey?) {
        guard client.store.historyMode, model.memberState.account.isEmpty || model.memberState.hasFetched else { return }
        let scope = room == HomeRoom.id ? "home":room
        let intent = model.history.intentGeneration
        if !reads.contains(where:{$0.0 == action && $0.1 == scope && $0.2 == key && $0.3 == intent}) {
            reads.append((action,scope,key,intent))
        }
        if !refreshFailed { failure = nil; start() }
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
            var refreshing = false
            do {
                // Collect same-turn roster/member/visibility notifications first.
                await Task.yield()
                while self.dirty || !self.reads.isEmpty || !self.demands.isEmpty || self.nextLoad() != nil {
                    try self.check(run)
                    let refresh = self.dirty; self.dirty = false
                    refreshing = refresh
                    let context = try await self.context(run)
                    if self.seedNeeded && (self.model.memberState.account.isEmpty || self.model.memberState.hasFetched) {
                        try await self.readPlan("seed",scope:"home",key:nil,intent:self.model.history.intentGeneration,context:context,run:run,sidebar:true)
                        try self.check(run)
                        self.seedNeeded = false
                    }
                    if refresh {
                        try await self.refresh(context:context,run:run)
                        self.failure = nil
                        self.refreshFailed = false
                    }
                    refreshing = false
                    while let request = self.demands.first {
                        try await self.demand(request,context:context,run:run)
                        try self.check(run)
                        self.demands.removeFirst()
                        if case .openForReply(let key) = request { self.finishReplyOpen(key,result:.success(())) }
                    }
                    while !self.reads.isEmpty {
                        let request = self.reads.removeFirst()
                        guard request.3 == self.model.history.intentGeneration else { continue }
                        try await self.readPlan(request.0,scope:request.1,key:request.2,intent:request.3,context:context,run:run)
                        try self.check(run)
                    }
                    if !self.dirty, let target = self.nextLoad() {
                        let quiet = !self.loadingTargets.contains(target) || !self.needsLoad(target)
                        if case .waiting = self.loadStates[target] { self.retried.insert(target) }
                        do {
                            try await self.load(target,context:context,run:run,forCard:quiet)
                            try self.check(run)
                            let unresolved = self.needsLoad(target) || self.cardTargets.contains { self.cardLoad($0) == target }
                            self.loadStates[target] = unresolved ? .failed(quiet:quiet) : nil
                            self.retried.remove(target)
                        } catch {
                            try self.check(run)
                            if case .server(_, retryable:true) = error as? HistoryFailure, !self.retried.contains(target) {
                                self.loadStates[target] = .waiting(until:self.model.noticeClock().addingTimeInterval(Self.snapshotRetryDelay))
                            } else {
                                self.loadStates[target] = .failed(quiet:quiet)
                            }
                        }
                        // Keep the displayed slots stable while restoring the bodies currently
                        // visible together. Scrolling still replaces the live target list.
                        if case .restore = target, case .restore? = self.nextLoad(), !self.dirty,
                           self.reads.isEmpty, self.demands.isEmpty { continue }
                        self.onChange?()
                        // Let the list publish its new geometry before choosing the next target.
                        await Task.yield()
                    }
                }
                try self.check(run)
                self.task = nil; self.failure = nil; self.onChange?()
            } catch {
                guard self.operation == run else { return }
                self.task = nil
                self.dirty = false
                self.failReplyOpens(error)
                if !(error is CancellationError) && error as? HistoryFailure != .changed {
                    self.failure = error
                    self.refreshFailed = refreshing
                }
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
    private func query(_ kind: String, scope: String, context: String, run: Int, fields: [String:Any] = [:], retry: Bool = true) async throws -> [String:Any] {
        let page = try await client.history.query(context:context,kind:kind,scope:scope,fields:fields,retry:retry)
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
    private func holdsNavigationMessage(in key: ConversationKey) -> Bool {
        guard let navigation,let message=navigation.message,navigation.key == key,!navigation.needsBody else { return false }
        return model.canDisplayHistoryBody(message,in:key)
    }

    private func refresh(context: String, run: Int) async throws {
        model.history.refreshing = true
        onRefreshStarted?()
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
        if let selected = model.selected, model.history.summaries[selected] != nil,
           !holdsNavigationMessage(in:selected) {
            let page = try await query("messages",scope:selected.employee,context:context,run:run,
                                       fields:["target":["room":selected.employee,"thread":selected.thread]])
            if !demands.contains(where:{ if case .open(let key, .some) = $0 { return key == selected }; return false }) {
                try model.applyHistoryMessages(page,key:selected,context:context,generation:generation,merge:.refresh)
            }
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
