import Foundation
import Darwin

enum AppIdentity {
    static let name = "hejo"
    static let bundleID = "io.github.hermes-hejo.hejo"
    static let version = "0.1.0"
    static var support: URL {
        FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0].appendingPathComponent(name)
    }
}
struct LocalSettings: Codable {
    var address = ""
    var deviceName = "이 Mac"
    var credentialAccount = UUID().uuidString.lowercased()
    var applied = 0
    var readSeq: [String: Int]? = [:] // Read only until the first member-state migration.
    var memberStates: [String: StateDocument]?
    var pendingState: [String: [String: StateEntry]]?
    var stateJoined: [String: Bool]?
    var stateAccount: String?
    var stateDevice: String?
    var petName = PetIdentity.defaultName
    var petX: Double?
    var petY: Double?
    /// Mac-specific window geometry; a nil value uses the current native default.
    var chatWidth: Double?
    var chatHeight: Double?
    /// Offline presentation copies of the member's hub settings.
    var petScalePercent: Double?
    var bubbleAlwaysShown: Bool?
    var bubbleReplyEnabled: Bool?
    var reminders: [String:Double]?
    /// Offline mirrors of the member's room-list preferences.
    var pinnedEmployees: [String]?
    var mutedEmployees: [String]?
    var hiddenEmployees: [String]?
    /// The Mac's hejo hub (host:port) this member signed in at; nil before the first sign-in.
    var hubAddress: String?
    /// Sign-in conveniences (nil = default). The password itself lives only in the Keychain.
    var rememberedAccount: String?
    var rememberAccount: Bool?
    var rememberPassword: Bool?
    var autoLogin: Bool?
    var keepsAccount: Bool { rememberAccount ?? true }
    var keepsPassword: Bool { rememberPassword ?? false }
    var signsInAutomatically: Bool { autoLogin ?? true }
}
/// A query replica, never a second conversation authority. Recover applied from the durable cache.
final class LocalStore {
    let directory: URL
    private(set) var settings: LocalSettings
    private(set) var records: [[String: Any]] = []
    var settingsURL: URL { directory.appendingPathComponent("hejo-local.json") }
    var cacheURL: URL { directory.appendingPathComponent("cache/frames.jsonl") }
    init(directory: URL = AppIdentity.support) throws {
        self.directory = directory
        try FileManager.default.createDirectory(at: directory.appendingPathComponent("cache"), withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
        try FileManager.default.setAttributes([.posixPermissions: 0o700], ofItemAtPath: directory.path)
        settings = (try? JSONDecoder().decode(LocalSettings.self, from: Data(contentsOf: directory.appendingPathComponent("hejo-local.json")))) ?? LocalSettings()
        let data = (try? Data(contentsOf: cacheURL)) ?? Data()
        var valid = Data(); var seq = 0
        for line in data.split(separator: 10, omittingEmptySubsequences: false).dropLast() {
            guard let object = try? JSONSerialization.jsonObject(with: Data(line)) as? [String: Any],
                  let n = object["seq"] as? Int, n == seq + 1 else { break }
            records.append(object); seq += 1; valid.append(contentsOf: line); valid.append(10)
        }
        if valid != data { try valid.write(to: cacheURL, options: .atomic) }
        settings.applied = seq
        // Repair an older cache that committed a scope marker before it could be compacted.
        for frame in records where frame["scope"] as? String == "thread" || frame["type"] as? String == "room_deleted" { try redactThread(frame) }
        try save()
    }
    func update(_ change: (inout LocalSettings) -> Void) throws {
        var next = settings; change(&next)
        try save(next); settings = next
    }
    func select(address: String, device: String) throws {
        if address != settings.address {
            try Data().write(to: cacheURL, options: .atomic)
            records = []; settings.applied = 0; settings.stateAccount = nil
            settings.credentialAccount = UUID().uuidString.lowercased()
        }
        settings.address = address; settings.deviceName = device; try save()
    }
    func append(_ frame: [String: Any]) throws {
        guard let seq = frame["seq"] as? Int, seq == settings.applied + 1 else { throw GateFailure.protocolError }
        if frame["type"] as? String == "room_deleted" || (frame["type"] as? String == "delete" && frame["scope"] as? String == "thread") {
            let next = records + [frame]
            let redacted = Self.redacting(next, point: frame)
            try rewrite(redacted)
            settings.applied = seq; try save(); return
        }
        var data = try JSONSerialization.data(withJSONObject: frame, options: .sortedKeys); data.append(10)
        if !FileManager.default.fileExists(atPath: cacheURL.path) { try Data().write(to: cacheURL) }
        let file = try FileHandle(forWritingTo: cacheURL); defer { try? file.close() }
        try file.seekToEnd(); try file.write(contentsOf: data); try file.synchronize()
        records.append(frame); settings.applied = seq; try save()
    }
    private static func redacting(_ rows: [[String: Any]], point: [String: Any]) -> [[String: Any]] {
        let whole=point["type"] as? String == "room_deleted"
        guard let room = (whole ? point["id"]:point["room"]) as? String else {return rows}
        let thread=point["thread"] as? String
        let ids = Set(rows.filter { ($0["room"] as? String ?? $0["employee"] as? String) == room && (whole || $0["thread"] as? String == thread) && $0["type"] as? String == "message" }.compactMap { $0["msg_id"] as? String })
        return rows.map { row in
            if whole,row["type"] as? String == "room",let data=row["room"] as? [String:Any],data["id"] as? String==room {return ["v":1,"type":"room","seq":row["seq"]!,"room":["id":room,"deleted":true]]}
            guard ["message","edit","state"].contains(row["type"] as? String ?? ""),let id=row["msg_id"] as? String,ids.contains(id) else { return row }
            return ["v":1,"type":"delete","seq":row["seq"]!,"msg_id":id]
        }
    }
    private func rewrite(_ rows: [[String: Any]]) throws {
        var bytes=Data()
        for row in rows { bytes.append(try JSONSerialization.data(withJSONObject:row,options:.sortedKeys));bytes.append(10) }
        let fresh=cacheURL.deletingLastPathComponent().appendingPathComponent(".frames-"+UUID().uuidString)
        defer {try? FileManager.default.removeItem(at:fresh)}
        guard FileManager.default.createFile(atPath:fresh.path,contents:bytes,attributes:[.posixPermissions:0o600]) else {throw GateFailure.storage}
        let handle=try FileHandle(forWritingTo:fresh);defer {try? handle.close()};try handle.synchronize()
        guard rename(fresh.path,cacheURL.path)==0 else {throw GateFailure.storage}
        records=rows
        let files=directory.appendingPathComponent("cache/files",isDirectory:true)
        for item in (try? FileManager.default.contentsOfDirectory(at:files,includingPropertiesForKeys:nil)) ?? [] where !hasFile(item.lastPathComponent) {
            try FileManager.default.removeItem(at:item)
        }
    }
    func hasFile(_ id:String)->Bool {records.contains { row in (row["files"] as? [[String:Any]] ?? []).contains{$0["file_id"] as? String==id} }}
    private func redactThread(_ point:[String:Any]) throws { try rewrite(Self.redacting(records,point:point)) }
    private func save(_ value: LocalSettings? = nil) throws {
        let data = try JSONEncoder().encode(value ?? settings)
        let fresh = directory.appendingPathComponent(".settings-" + UUID().uuidString)
        defer { try? FileManager.default.removeItem(at: fresh) }
        guard FileManager.default.createFile(atPath: fresh.path, contents: data, attributes: [.posixPermissions: 0o600]) else { throw GateFailure.storage }
        let handle = try FileHandle(forWritingTo: fresh); defer { try? handle.close() }
        try handle.synchronize()
        guard rename(fresh.path, settingsURL.path) == 0 else { throw GateFailure.storage }
    }
}
final class InstanceLock {
    private let fd: Int32
    init(directory: URL) throws {
        fd = open(directory.appendingPathComponent(".instance.lock").path, O_CREAT | O_RDWR | O_NOFOLLOW, 0o600)
        guard fd >= 0 else { throw GateFailure.storage }
        guard flock(fd, LOCK_EX | LOCK_NB) == 0 else { close(fd); throw GateFailure.alreadyRunning }
    }
    deinit { flock(fd, LOCK_UN); close(fd) }
}
