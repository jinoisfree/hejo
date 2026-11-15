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
    var readSeq: [String: Int] = [:]
    var petName = PetIdentity.defaultName
    var petX: Double?
    var petY: Double?
    /// The Mac's hejo hub (host:port) this member signed in at; nil before the first sign-in.
    var hubAddress: String?
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
        try save()
    }
    func update(_ change: (inout LocalSettings) -> Void) throws { change(&settings); try save() }
    func select(address: String, device: String) throws {
        if address != settings.address {
            try Data().write(to: cacheURL, options: .atomic)
            records = []; settings.applied = 0; settings.readSeq = [:]
            settings.credentialAccount = UUID().uuidString.lowercased()
        }
        settings.address = address; settings.deviceName = device; try save()
    }
    func append(_ frame: [String: Any]) throws {
        guard let seq = frame["seq"] as? Int, seq == settings.applied + 1 else { throw GateFailure.protocolError }
        var data = try JSONSerialization.data(withJSONObject: frame, options: .sortedKeys); data.append(10)
        if !FileManager.default.fileExists(atPath: cacheURL.path) { try Data().write(to: cacheURL) }
        let file = try FileHandle(forWritingTo: cacheURL); defer { try? file.close() }
        try file.seekToEnd(); try file.write(contentsOf: data); try file.synchronize()
        records.append(frame); settings.applied = seq; try save()
    }
    private func save() throws {
        try JSONEncoder().encode(settings).write(to: settingsURL, options: .atomic)
        try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: settingsURL.path)
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
