import Foundation
import Network

/// Finding the hejo hub for sign-in (REQ-HF-20). The 0600 `local-pair.json` of this account's Hermes marks a Mac that
/// runs the member's Hermes and carries the one-time proof for password reset without the old password.
enum AirportFinder {
    struct LocalPair: Equatable { var port: Int; var code: String }
    static let port = 47820
    static var defaultHome: URL { FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent(".hermes") }
    static var deviceName: String { String((Host.current().localizedName ?? "Mac").prefix(100)) }
    static let tailscaleCandidates = ["/opt/homebrew/bin/tailscale", "/usr/local/bin/tailscale", "/Applications/Tailscale.app/Contents/MacOS/Tailscale"]

    static func localPair(home: URL = defaultHome) -> LocalPair? {
        guard let data = try? Data(contentsOf: home.appendingPathComponent("hejo/local-pair.json")),
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let port = value["port"] as? Int, (1...65535).contains(port),
              let code = value["code"] as? String, code.range(of: "^[A-Za-z0-9_-]{12}$", options: .regularExpression) != nil else { return nil }
        return LocalPair(port: port, code: code)
    }
    /// Online peers' Tailscale IPv4 addresses, Macs first (the airport is a Mac).
    static func peers(statusJSON data: Data) -> [String] {
        guard let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let peers = value["Peer"] as? [String: [String: Any]] else { return [] }
        let online = peers.values.filter { $0["Online"] as? Bool == true }
            .sorted { ($0["OS"] as? String == "macOS" ? 0 : 1, $0["HostName"] as? String ?? "") < ($1["OS"] as? String == "macOS" ? 0 : 1, $1["HostName"] as? String ?? "") }
        return online.compactMap { ($0["TailscaleIPs"] as? [String])?.first { $0.hasPrefix("100.") } }
    }
    static func tailscaleStatus() async -> Data? {
        await Task.detached {
            guard let tool = tailscaleCandidates.first(where: { FileManager.default.isExecutableFile(atPath: $0) }) else { return nil }
            let process = Process(), pipe = Pipe()
            process.executableURL = URL(fileURLWithPath: tool); process.arguments = ["status", "--json"]
            process.standardOutput = pipe; process.standardError = FileHandle.nullDevice
            do { try process.run() } catch { return nil }
            let killer = DispatchWorkItem { if process.isRunning { process.terminate() } }
            DispatchQueue.global().asyncAfter(deadline: .now() + 3, execute: killer)
            let data = pipe.fileHandleForReading.readDataToEndOfFile(); process.waitUntilExit(); killer.cancel()
            return process.terminationStatus == 0 ? data : nil
        }.value
    }
    static func reachable(_ host: String, port: Int = port, timeout: TimeInterval = 1.5) async -> Bool {
        await withCheckedContinuation { continuation in
            let connection = NWConnection(host: NWEndpoint.Host(host), port: NWEndpoint.Port(integerLiteral: UInt16(port)), using: .tcp)
            let lock = NSLock(); var done = false
            func finish(_ value: Bool) {
                lock.lock(); defer { lock.unlock() }
                guard !done else { return }; done = true; connection.cancel(); continuation.resume(returning: value)
            }
            connection.stateUpdateHandler = { state in
                switch state { case .ready: finish(true); case .failed, .cancelled: finish(false); default: break }
            }
            connection.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + timeout) { finish(false) }
        }
    }
    /// The Mac's hejo hub without typing: this Mac first, then online Tailscale Macs (one hub per Mac).
    static func findHub(status: () async -> Data? = { await tailscaleStatus() },
                        reach: (String) async -> Bool = { await reachable($0, port: HubClient.port, timeout: 0.8) },
                        probe: (String) async -> Bool = { await HubClient(address: $0).info() != nil }) async -> String? {
        let local = "127.0.0.1:\(HubClient.port)"
        if await probe(local) { return local }
        guard let data = await status() else { return nil }
        for host in peers(statusJSON: data) {
            let address = "\(host):\(HubClient.port)"
            if await reach(host), await probe(address) { return address }
        }
        return nil
    }
}
