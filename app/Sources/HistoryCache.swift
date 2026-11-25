import Foundation
import CryptoKit

/// Bounded, disposable current-message copies. Never reads legacy frames.jsonl,
/// and never stores credentials, member state, drafts or the live sequence.
final class HistoryCache {
    static let maximumMessages = 500
    static let maximumBytes = 32 * 1024 * 1024
    private struct Entry: Codable {
        let id: String
        let revision: Int
        let size: Int
        var used: UInt64
        var room: String?
        var thread: String?
    }
    private let directory: URL
    private let messageLimit: Int
    private let byteLimit: Int
    private var entries: [String: Entry] = [:]
    private var clock: UInt64 = 0
    private var batching = false
    private var dirty = false
    private var indexURL: URL { directory.appendingPathComponent("index.json") }
    var count: Int { entries.count }
    var byteCount: Int { entries.values.reduce(0) { $0 + $1.size } }
    private static func digest(_ value: String) -> String {
        SHA256.hash(data: Data(value.utf8)).map { String(format: "%02x", $0) }.joined()
    }
    init(directory support: URL, account: String, messageLimit: Int = maximumMessages, byteLimit: Int = maximumBytes) throws {
        precondition((1...Self.maximumMessages).contains(messageLimit) && (1...Self.maximumBytes).contains(byteLimit))
        self.messageLimit = messageLimit; self.byteLimit = byteLimit
        directory = support.appendingPathComponent("cache/history-v1", isDirectory: true)
            .appendingPathComponent(Self.digest(account), isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true,
                                               attributes: [.posixPermissions: 0o700])
        if let size = try? indexURL.resourceValues(forKeys: [.fileSizeKey]).fileSize,
           size <= 1024 * 1024, let data = try? Data(contentsOf: indexURL),
           let stored = try? JSONDecoder().decode([String: Entry].self, from: data),
           stored.count <= messageLimit,
           stored.allSatisfy({ $0.key == Self.digest($0.value.id) && $0.value.revision > 0 && $0.value.size > 0 && $0.value.size <= byteLimit }),
           stored.values.reduce(0, { $0 + $1.size }) <= byteLimit {
            entries = stored.filter { key, entry in
                (try? file(key).resourceValues(forKeys: [.fileSizeKey]).fileSize) == entry.size
            }
            clock = stored.values.map(\.used).max() ?? 0
        }
        // Crash leftovers are disposable; enumerate file names, not message bodies.
        for file in try FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil)
        where file.pathExtension == "json" && file.lastPathComponent != "index.json" {
            if entries[file.deletingPathExtension().lastPathComponent] == nil { try FileManager.default.removeItem(at: file) }
        }
    }
    private func file(_ key: String) -> URL { directory.appendingPathComponent(key + ".json") }
    /// Each response publishes its manifest once; body files remain individually atomic.
    /// On failure, persist the successfully changed subset so restart cannot resurrect evictions.
    func batch(_ body: () throws -> Void) throws {
        if batching { try body(); return }
        batching = true
        do { try body() } catch {
            batching = false
            if dirty { try saveIndex() }
            throw error
        }
        batching = false
        if dirty { try saveIndex() }
    }
    private func saveIndex() throws {
        dirty = true
        if batching { return }
        try JSONEncoder().encode(entries).write(to: indexURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: indexURL.path)
        dirty = false
    }
    /// False means the body is newer in cache or too large to retain, not deleted.
    @discardableResult func put(_ message: [String: Any]) throws -> Bool {
        guard let id = message["msg_id"] as? String, !id.isEmpty,
              let revision = message["revision"] as? Int, revision > 0 else { throw CocoaError(.coderInvalidValue) }
        let key = Self.digest(id)
        if let old = entries[key], old.revision > revision { return false }
        let data = try JSONSerialization.data(withJSONObject: message, options: [.sortedKeys])
        guard data.count <= byteLimit else { return false }
        while entries.count - (entries[key] == nil ? 0 : 1) >= messageLimit ||
                byteCount - (entries[key]?.size ?? 0) + data.count > byteLimit {
            guard let victim = entries.filter({ $0.key != key }).min(by: { $0.value.used < $1.value.used })?.key else { break }
            try FileManager.default.removeItem(at: file(victim)); entries[victim] = nil
        }
        try data.write(to: file(key), options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: file(key).path)
        clock &+= 1
        entries[key] = Entry(id: id, revision: revision, size: data.count, used: clock, room: (message["room"] ?? message["employee"]) as? String, thread: message["thread"] as? String)
        try saveIndex()
        return true
    }
    /// Durable live events invalidate copies even when their bodies are not resident.
    /// Old manifests without scope are conservatively discarded for a scope event.
    func invalidate(id: String? = nil, room: String? = nil, thread: String? = nil, through: Int) throws {
        let victims = entries.filter { _, entry in
            guard entry.revision <= through else { return false }
            if let id { return entry.id == id }
            if let room, let known = entry.room, room != known { return false }
            if let thread, let known = entry.thread, thread != known { return false }
            return true
        }.map(\.key)
        for key in victims {
            if FileManager.default.fileExists(atPath:file(key).path) { try FileManager.default.removeItem(at:file(key)) }
            entries[key] = nil
        }
        if !victims.isEmpty { try saveIndex() }
    }
    func message(_ id: String) throws -> [String: Any]? {
        let key = Self.digest(id)
        guard let entry = entries[key] else { return nil }
        guard let size = try? file(key).resourceValues(forKeys: [.fileSizeKey]).fileSize,
              size == entry.size, let data = try? Data(contentsOf: file(key)),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              value["msg_id"] as? String == id, value["revision"] as? Int == entry.revision else {
            entries[key] = nil; try saveIndex(); return nil
        }
        clock &+= 1; entries[key]?.used = clock
        return value
    }
}
