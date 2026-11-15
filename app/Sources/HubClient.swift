import Foundation

/// The Mac's hejo hub (REQ-HF-20): members sign up and sign in here, read their own Hermes gate and keep their
/// app settings. The returned token also opens that member's gate.
struct HubClient {
    static let port = 47800
    let address: String  // host:port
    struct SignIn: Equatable { var token: String; var deviceID: String }
    struct Me: Equatable { var account: String; var google: Bool; var gatePort: Int?; var settings: [String: String] }
    enum Failure: Error, Equatable { case rejected(String), unreachable }
    var host: String { String(address.split(separator: ":").first ?? "") }
    /// Where this member's gate answers, seen from this Mac: the hub's host with the gate's port.
    func gateAddress(_ me: Me) -> String? { me.gatePort.map { "\(host):\($0)" } }

    func request(_ method: String, _ path: String, body: [String: Any]? = nil, token: String? = nil) -> URLRequest {
        var request = URLRequest(url: URL(string: "http://\(address)\(path)")!); request.httpMethod = method; request.timeoutInterval = 10
        if let body { request.httpBody = try? JSONSerialization.data(withJSONObject: body); request.setValue("application/json", forHTTPHeaderField: "Content-Type") }
        if let token { request.setValue("Bearer " + token, forHTTPHeaderField: "Authorization") }
        return request
    }
    func send(_ request: URLRequest) async throws -> [String: Any] {
        guard let (data, response) = try? await URLSession.shared.data(for: request), let http = response as? HTTPURLResponse else { throw Failure.unreachable }
        let value = (try? JSONSerialization.jsonObject(with: data) as? [String: Any]) ?? [:]
        guard http.statusCode == 200 else { throw Failure.rejected(value["error"] as? String ?? "unknown") }
        return value
    }
    static func signIn(_ value: [String: Any]) throws -> SignIn {
        guard let token = value["token"] as? String, let device = value["device_id"] as? String else { throw Failure.rejected("unknown") }
        return SignIn(token: token, deviceID: device)
    }
    func info() async -> String?? {
        guard let value = try? await send(request("GET", "/v1/hub")), value["hub"] as? Int == 1 else { return nil }
        return .some(value["google_client_id"] as? String)
    }
    func signup(account: String, password: String, device: String, googleIDToken: String? = nil) async throws -> SignIn {
        var body: [String: Any] = ["account": account, "password": password, "device_name": device]
        if let googleIDToken { body["google_id_token"] = googleIDToken }
        return try Self.signIn(await send(request("POST", "/v1/signup", body: body)))
    }
    func login(account: String, password: String, device: String) async throws -> SignIn {
        try Self.signIn(await send(request("POST", "/v1/login", body: ["account": account, "password": password, "device_name": device])))
    }
    func google(idToken: String, device: String, newPassword: String? = nil, link: (account: String, password: String)? = nil) async throws -> SignIn {
        var body: [String: Any] = ["id_token": idToken, "device_name": device]
        if let newPassword { body["new_password"] = newPassword }
        if let link { body["account"] = link.account; body["password"] = link.password }
        return try Self.signIn(await send(request("POST", "/v1/google", body: body)))
    }
    func me(token: String) async throws -> Me {
        let value = try await send(request("GET", "/v1/me", token: token))
        return Me(account: value["account"] as? String ?? "", google: value["google"] as? Bool == true,
                  gatePort: (value["gate"] as? [String: Any])?["port"] as? Int,
                  settings: (value["settings"] as? [String: Any] ?? [:]).compactMapValues { $0 as? String })
    }
    func save(settings: [String: String], token: String) async throws {
        _ = try await send(request("PUT", "/v1/me/settings", body: ["settings": settings], token: token))
    }
    func state(since: Int? = nil, token: String) async throws -> StateDocument {
        let path = "/v1/me/state" + (since.map { "?since=\($0)" } ?? "")
        return try JSONDecoder().decode(StateDocument.self, from: JSONSerialization.data(withJSONObject: await send(request("GET", path, token: token))))
    }
    func patch(state: [String: StateEntry], token: String) async throws -> StateDocument {
        let items = try JSONSerialization.jsonObject(with: JSONEncoder().encode(state))
        return try JSONDecoder().decode(StateDocument.self, from: JSONSerialization.data(withJSONObject: await send(request("PATCH", "/v1/me/state", body: ["items": items], token: token))))
    }
}
