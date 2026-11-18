import Foundation

struct StateEntry: Codable, Equatable {
    var v: String?
    var at: Double
    var dev: String
    enum CodingKeys: String, CodingKey { case v, at, dev }
    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        if let v { try c.encode(v, forKey: .v) } else { try c.encodeNil(forKey: .v) }
        try c.encode(at, forKey: .at); try c.encode(dev, forKey: .dev)
    }
}
struct StateDocument: Codable, Equatable {
    var rev = 0
    var items: [String: StateEntry] = [:]
}

/// A durable replica and outbox for the hub's member state. No credentials are stored here.
@MainActor final class MemberState {
    static let interval: TimeInterval = 30
    static let sendInterval: TimeInterval = 1.5
    let store: LocalStore
    var onChange: (() -> Void)?
    var onFailure: ((Bool) -> Void)?
    var onUnpinned: ((Int) -> Void)?
    var fetch: ((Int?) async throws -> StateDocument)?
    var push: (([String: StateEntry]) async throws -> StateDocument)?
    private(set) var timer: Timer?
    private var syncing = false
    private var sendTimer: Timer?
    private var receiver: Task<Void, Never>?
    private(set) var waitingSupported = false
    private var generation = 0
    private(set) var connected = false
    var account: String { store.settings.stateAccount ?? "" }
    var document: StateDocument { store.settings.memberStates?[account] ?? StateDocument() }
    var pending: [String: StateEntry] { store.settings.pendingState?[account] ?? [:] }
    var items: [String: StateEntry] { Self.merge(document.items, pending) }
    init(store: LocalStore) { self.store = store }
    deinit { timer?.invalidate(); sendTimer?.invalidate(); receiver?.cancel() }
    static func isRead(_ key: String) -> Bool { ["read:", "thread:"].contains { key.hasPrefix($0) } }
    static func isLayout(_ key: String) -> Bool { ["layout:", "zone:", "pin:", "hide:", "mute:", "title:"].contains { key.hasPrefix($0) } }
    static func wins(_ key: String, _ new: StateEntry, _ old: StateEntry?) -> Bool {
        guard let old else { return true }
        if isRead(key) { return (Int(new.v ?? "") ?? 0) > (Int(old.v ?? "") ?? 0) }
        return new.at > old.at || (new.at == old.at && new.dev > old.dev)
    }
    static func merge(_ old: [String: StateEntry], _ changes: [String: StateEntry]) -> [String: StateEntry] {
        var result = old
        for (key, entry) in changes where wins(key, entry, result[key]) { result[key] = entry }
        return result
    }
    func value(_ key: String) -> String? { items[key]?.v }
    func read(_ key: String) -> Int { Int(value(key) ?? "") ?? 0 }
    private func persist(document: StateDocument, pending: [String: StateEntry]) throws {
        let name = account
        try store.update {
            if $0.memberStates == nil { $0.memberStates = [:] }; $0.memberStates?[name] = document
            if $0.pendingState == nil { $0.pendingState = [:] }; $0.pendingState?[name] = pending
        }
        onChange?()
    }
    /// All migration effects, including the join marker, commit in the same atomic local write.
    func join(member: String, hub: String, legacy: [String: String]) throws {
        let name = hub + "/" + member
        let first = store.settings.stateJoined?[name] != true
        var outbox = store.settings.pendingState?[name] ?? [:]
        let dev = store.settings.stateDevice ?? UUID().uuidString.lowercased()
        var releasedPins = 0
        if first {
            func ids(_ key: String, _ fallback: [String]?) -> [String] {
                let list = legacy[key].map { $0.split(separator: ",").map(String.init) } ?? fallback ?? []
                var seen = Set<String>(); return list.filter { seen.insert($0).inserted }
            }
            var seed: [String: StateEntry] = [:]
            let pins = ids("pinned", store.settings.pinnedEmployees)
            for (slot, room) in pins.prefix(5).enumerated() { seed["pin:" + room] = StateEntry(v: String(slot+1), at: 1, dev: dev) }
            releasedPins = max(0, pins.count-5)
            for (old, prefix, fallback) in [("muted", "mute:", store.settings.mutedEmployees), ("hidden", "hide:", store.settings.hiddenEmployees)] {
                for room in ids(old, fallback) { seed[prefix + room] = StateEntry(v: "1", at: 1, dev: dev) }
            }
            for (key, seq) in store.settings.readSeq ?? [:] {
                guard let split = key.firstIndex(of: ":") else { continue }
                let room = key[..<split], thread = key[key.index(after: split)...]
                seed["thread:\(room)/\(thread)"] = StateEntry(v: String(seq), at: 1, dev: dev)
            }
            outbox = Self.merge(seed, outbox)
            outbox = Self.merge(outbox, store.settings.pendingState?[""] ?? [:])
        }
        try store.update {
            $0.stateAccount = name; $0.stateDevice = dev
            if $0.stateJoined == nil { $0.stateJoined = [:] }; $0.stateJoined?[name] = true
            if $0.pendingState == nil { $0.pendingState = [:] }; $0.pendingState?[name] = outbox
            $0.pendingState?.removeValue(forKey: "")
            $0.readSeq = nil; $0.pinnedEmployees = nil; $0.mutedEmployees = nil; $0.hiddenEmployees = nil
        }
        generation += 1; onChange?()
        if releasedPins > 0 { onUnpinned?(releasedPins) }
    }
    func configure(hub: HubClient, token: String) {
        connect(fetch: { try await hub.state(since: $0, token: token) }, push: { try await hub.patch(state: $0, token: token) }, wait: { try await hub.waitState(revision: $0, token: token) })
    }
    func connect(fetch: @escaping (Int?) async throws -> StateDocument, push: @escaping ([String: StateEntry]) async throws -> StateDocument, wait: ((Int) async throws -> (StateDocument, Bool))? = nil) {
        disconnect()
        self.fetch = fetch; self.push = push
        connected = true; generation += 1
        startFallbackTimer()
        if let wait {
            let epoch = generation
            receiver = Task { [weak self] in
                while !Task.isCancelled {
                    guard let revision = self?.document.rev, self?.generation == epoch else { return }
                    do {
                        let (remote, supported) = try await wait(revision)
                        guard let self, self.generation == epoch, !Task.isCancelled else { return }
                        try self.accept(remote)
                        self.waitingSupported = supported
                        guard supported else { return } // Old hub: preserve thirty-second polling.
                        self.timer?.invalidate(); self.timer = nil
                        self.onFailure?(false)
                    } catch {
                        guard let self, self.generation == epoch, !Task.isCancelled else { return }
                        self.onFailure?(true)
                        do { try await Task.sleep(nanoseconds: 1_500_000_000) } catch { return }
                    }
                }
            }
        } else { activate() }
        if !pending.isEmpty { scheduleSend() }
    }
    private func startFallbackTimer() {
        timer = Timer.scheduledTimer(withTimeInterval: Self.interval, repeats: true) { [weak self] _ in
            Task { @MainActor in await self?.sync() }
        }
    }
    func disconnect() {
        connected = false; generation += 1; timer?.invalidate(); timer = nil
        sendTimer?.invalidate(); sendTimer = nil; receiver?.cancel(); receiver = nil
        waitingSupported = false; fetch = nil; push = nil
    }
    func activate() { if !waitingSupported { Task { await sync() } } }
    private func scheduleSend() {
        guard connected, sendTimer == nil else { return }
        sendTimer = Timer.scheduledTimer(withTimeInterval: Self.sendInterval, repeats: false) { [weak self] _ in
            Task { @MainActor in
                guard let self else { return }; self.sendTimer = nil
                await self.flush()
                if !self.pending.isEmpty { self.scheduleSend() }
            }
        }
    }
    func set(_ values: [String: String?], at: Double = Date().timeIntervalSince1970) throws {
        let dev = store.settings.stateDevice ?? UUID().uuidString.lowercased()
        var edits: [String: StateEntry] = [:]
        for (key, value) in values {
            let entry = StateEntry(v: value, at: at, dev: dev)
            if Self.wins(key, entry, items[key]) { edits[key] = entry }
        }
        guard !edits.isEmpty else { return }
        let queued = Self.merge(pending, edits)
        try store.update {
            $0.stateDevice = dev
            if $0.pendingState == nil { $0.pendingState = [:] }; $0.pendingState?[account] = queued
        }
        onChange?(); scheduleSend()
    }
    /// GET gives a complete snapshot on a changed revision, or no items at the same revision.
    private func accept(_ remote: StateDocument, sent: [String: StateEntry] = [:]) throws {
        var queue = pending
        for (key, entry) in sent where queue[key] == entry { queue[key] = nil }
        let next = remote.rev > document.rev ? remote : document
        if next != document || queue != pending { try persist(document: next, pending: queue) }
    }
    func sync() async {
        guard !syncing, let fetch, let push else { return }
        syncing = true; let epoch = generation
        defer { syncing = false }
        do {
            let remote = try await fetch(document.rev)
            guard epoch == generation else { return }
            try accept(remote)
            while !pending.isEmpty {
                let sent = pending
                let response = try await push(sent)
                guard epoch == generation else { return }
                try accept(response, sent: sent)
            }
            onFailure?(false)
        } catch { if epoch == generation { onFailure?(true) } }
    }
    private func flush() async {
        guard !syncing, let push, !pending.isEmpty else { return }
        syncing = true; let epoch = generation; let sent = pending
        defer { syncing = false }
        do {
            let response = try await push(sent)
            guard epoch == generation else { return }
            try accept(response, sent: sent); onFailure?(false)
        } catch { if epoch == generation { onFailure?(true) } }
    }
    /// Capture this Mac before fetching other Mac keys; absent local layout keys become tombstones.
    func makeLayoutStandard() async throws {
        guard let fetch, !syncing else { throw HubClient.Failure.unreachable }
        syncing = true; let epoch = generation
        defer { syncing = false }
        let local = items.filter { Self.isLayout($0.key) }
        do {
            let remote = try await fetch(nil)
            guard epoch == generation else { throw HubClient.Failure.unreachable }
            try accept(remote)
            var values = Dictionary<String, String?>()
            for key in Set(remote.items.keys).union(local.keys) where Self.isLayout(key) { values[key] = .some(local[key]?.v) }
            try set(values)
        } catch { onFailure?(true); throw error }
        // The durable queue is retained if the subsequent request fails.
    }
}
