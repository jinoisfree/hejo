import Foundation

enum GateFailure: Error { case tooLarge, protocolError, storage, alreadyRunning, badAddress, badCode, notConnected }
enum ConnectionStatus: Equatable {
    case disconnected(Int), connecting, connected, wrongCode, revoked, tooLarge, storageError
    var text: String {
        switch self {
        case .disconnected(let n): return "공항과 연결이 끊겼어요 · \(n)초 뒤 다시 연결"
        case .connecting: return "공항에 연결 중"
        case .connected: return "공항에 연결됨"
        case .wrongCode: return "로그인하지 못했어요 · 다시 로그인해 주세요"
        case .revoked: return "이 기기가 로그아웃됐어요 · 다시 로그인해 주세요"
        case .tooLarge: return "너무 큼 · 보낼 내용을 줄여 주세요"
        case .storageError: return "연결 정보를 저장하지 못했어요 · 다시 시도해 주세요"
        }
    }
}
struct ReconnectDelay {
    private var attempt = 0
    mutating func next() -> Int { defer { attempt = min(5, attempt + 1) }; return min(30, 1 << attempt) }
    mutating func reset() { attempt = 0 }
}
@MainActor final class GateClient {
    static let maxFrameBytes = 1_048_576
    let store: LocalStore
    private let credentials: GateCredentialStore
    private var worker: Task<Void, Never>?
    private var socket: URLSessionWebSocketTask?
    private var generation = 0
    private var token: String?
    private var pairCode: String?
    /// One-shot sign-in fields for the next hello (`login`, `google` or `local`); cleared on welcome or rejection.
    private var signInFields: [String: Any]?
    private(set) var rejection: String?
    private var backoff = ReconnectDelay()
    private var syncing = false
    private var welcomed = false
    private(set) var replayComplete = false
    private(set) var connectionEpoch = 0
    private(set) var status = ConnectionStatus.disconnected(0) { didSet { onStatus?(status) } }
    var isConnected: Bool { welcomed && socket?.state == .running }
    var onStatus: ((ConnectionStatus) -> Void)?
    var onFrame: (([String: Any]) -> Void)?
    var onRetry: ((Int) -> Void)?
    init(store: LocalStore, credentials: GateCredentialStore = GateKeychain()) { self.store = store; self.credentials = credentials }
    static func endpoint(_ address: String) throws -> URL {
        let raw = address.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var parts = URLComponents(string: raw.contains("://") ? raw : "ws://" + raw),
              ["ws", "wss"].contains(parts.scheme ?? ""), parts.host?.isEmpty == false,
              parts.user == nil, parts.password == nil, parts.query == nil, parts.fragment == nil,
              parts.path.isEmpty || parts.path == "/" || parts.path == "/v1/ws" else { throw GateFailure.badAddress }
        parts.path = "/v1/ws"; guard let url = parts.url else { throw GateFailure.badAddress }; return url
    }
    static func encoded(_ frame: [String: Any]) throws -> String {
        let data = try JSONSerialization.data(withJSONObject: frame, options: .sortedKeys)
        guard data.count <= maxFrameBytes else { throw GateFailure.tooLarge }
        return String(decoding: data, as: UTF8.self)
    }
    func pair(address: String, code: String, device: String) throws {
        _ = try Self.endpoint(address)
        guard code.range(of: "^[A-Za-z0-9_-]{12}$", options: .regularExpression) != nil else { throw GateFailure.badCode }
        stop(); try store.select(address: address, device: String(device.prefix(100)))
        pairCode = code; token = nil; launch()
    }
    /// Owner sign-in: `["login": [...]]`, `["google": [...]]` or `["local": [...]]` (airport Mac only).
    func signIn(address: String, device: String, fields: [String: Any]) throws {
        _ = try Self.endpoint(address)
        stop(); try store.select(address: address, device: String(device.prefix(100)))
        signInFields = fields; rejection = nil; token = nil; launch()
    }
    func resume() { stop(); pairCode = nil; token = nil; launch() }
    private func launch() {
        generation += 1; let run = generation
        worker = Task { [weak self] in await self?.connectLoop(run: run) }
    }
    func stop() {
        generation += 1; worker?.cancel(); worker = nil
        socket?.cancel(with: .goingAway, reason: nil); socket = nil; pairCode = nil; signInFields = nil; token = nil
        backoff.reset(); welcomed = false; syncing = false; replayComplete = false
    }
    private func connectLoop(run: Int) async {
        if pairCode == nil && signInFields == nil {
            let account = store.settings.credentialAccount
            let keychain = credentials
            token = await Task.detached { keychain.read(account: account) }.value
        }
        guard run == generation else { return }
        guard pairCode != nil || signInFields != nil || token != nil else { status = .revoked; return }
        while !Task.isCancelled && run == generation {
            status = .connecting; welcomed = false; syncing = false; replayComplete = false
            do {
                let url = try Self.endpoint(store.settings.address)
                var request = URLRequest(url: url); request.timeoutInterval = 5
                let ws = URLSession.shared.webSocketTask(with: request); socket = ws; ws.maximumMessageSize = Self.maxFrameBytes; ws.resume()
                let deadline = Task { [weak self, weak ws] in
                    do { try await Task.sleep(nanoseconds: 5_000_000_000) } catch { return }
                    guard let self, let ws, self.generation == run, self.socket === ws, !self.welcomed else { return }
                    ws.cancel(with: .goingAway, reason: nil)
                }
                defer { deadline.cancel() }
                var hello: [String: Any] = ["v": 1, "type": "hello", "device_name": store.settings.deviceName, "app_version": AppIdentity.version, "since": store.settings.applied]
                if let pairCode { hello["pair_code"] = pairCode } else if let signInFields { hello.merge(signInFields) { $1 } } else { hello["token"] = token! }
                try await ws.send(.string(Self.encoded(hello)))
                while !Task.isCancelled && run == generation {
                    let message = try await ws.receive()
                    guard run == generation else { return }
                    let data: Data
                    switch message { case .string(let s): data = Data(s.utf8); case .data(let d): data = d; @unknown default: throw GateFailure.protocolError }
                    guard data.count <= Self.maxFrameBytes, let frame = try JSONSerialization.jsonObject(with: data) as? [String: Any] else { throw GateFailure.protocolError }
                    if try await receive(frame, run: run) == false { ws.cancel(with: .normalClosure, reason: nil); return }
                }
            } catch {
                guard run == generation, !Task.isCancelled else { return }
                welcomed = false
                if socket?.closeCode.rawValue == 1009 { status = .tooLarge }
                if error is GateFailure { // Durable storage/protocol failures must not spin on reconnect.
                    if case GateFailure.storage = error { status = .storageError; return }
                }
            }
            guard run == generation, !Task.isCancelled else { return }
            socket?.cancel(with: .goingAway, reason: nil)
            // A one-time pairing code cannot safely be retried after an ambiguous welcome.
            if pairCode != nil || signInFields != nil { pairCode = nil; signInFields = nil; status = .wrongCode; return }
            let seconds = backoff.next(); if status != .tooLarge { status = .disconnected(seconds) }; onRetry?(seconds)
            do { try await Task.sleep(nanoseconds: UInt64(seconds) * 1_000_000_000) } catch { return }
        }
    }
    @discardableResult func receive(_ frame: [String: Any], run: Int? = nil) async throws -> Bool {
        guard frame["v"] as? Int == 1, let type = frame["type"] as? String else { throw GateFailure.protocolError }
        if !welcomed {
            guard type == "welcome" || type == "pair_rejected" || type == "auth_rejected" else { throw GateFailure.protocolError }
        }
        switch type {
        case "welcome":
            if let issued = frame["token"] as? String {
                let keychain = credentials, account = store.settings.credentialAccount
                let saved = await Task.detached { keychain.save(issued, account: account) }.value
                if let run, run != generation { return false }
                guard saved else { status = .storageError; return false }
                token = issued; pairCode = nil; signInFields = nil
            }
            welcomed = true; connectionEpoch += 1; replayComplete = false; backoff.reset(); status = .connected
        case "pair_rejected": pairCode = nil; signInFields = nil; rejection = frame["reason"] as? String; status = .wrongCode; return false
        case "auth_rejected":
            let keychain = credentials, account = store.settings.credentialAccount
            await Task.detached { keychain.delete(account: account) }.value
            if let run, run != generation { return false }
            token = nil; status = .revoked; return false
        case "message", "edit", "delete", "state":
            guard let seq = frame["seq"] as? Int, seq > 0 else { throw GateFailure.protocolError }
            if seq <= store.settings.applied { return true }
            if seq > store.settings.applied + 1 { replayComplete = false; if !syncing { syncing = true; try await sync() }; return true }
            do { try store.append(frame) } catch { throw GateFailure.storage }
        case "sync_done":
            guard let through = frame["through"] as? Int, let more = frame["more"] as? Bool else { throw GateFailure.protocolError }
            syncing = false; replayComplete = !more && through <= store.settings.applied
            if more || through > store.settings.applied { syncing = true; try await sync() }
        case "ping": try await send(["v": 1, "type": "pong"])
        case "error": if frame["code"] as? String == "too_large" { status = .tooLarge }
        default: break
        }
        onFrame?(frame); return true
    }
    func authorizedRequest(components: [String], query: [URLQueryItem] = []) throws -> URLRequest {
        guard let token else { throw GateFailure.notConnected }
        var parts = URLComponents(url: try Self.endpoint(store.settings.address), resolvingAgainstBaseURL: false)!
        parts.scheme = parts.scheme == "wss" ? "https" : "http"
        let safe = CharacterSet.alphanumerics.union(CharacterSet(charactersIn: "_-"))
        parts.percentEncodedPath = "/" + components.map { $0.addingPercentEncoding(withAllowedCharacters: safe)! }.joined(separator: "/")
        parts.queryItems = query.isEmpty ? nil : query
        var request = URLRequest(url: parts.url!); request.timeoutInterval = 30
        request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization")
        return request
    }
    private func sync() async throws { try await send(["v": 1, "type": "sync", "id": UUID().uuidString.lowercased(), "since": store.settings.applied]) }
    func send(_ frame: [String: Any]) async throws {
        let string: String
        do { string = try Self.encoded(frame) } catch { status = .tooLarge; throw error }
        guard let socket else { throw GateFailure.notConnected }; try await socket.send(.string(string))
    }
}
