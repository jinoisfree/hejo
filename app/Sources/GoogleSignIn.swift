import AppKit
import CryptoKit
import Network

/// Google sign-in for the desktop app (REQ-HF-20): PKCE and a one-shot loopback redirect in the browser, then the code
/// is redeemed with hejo's shared desktop client (Google treats installed-app secrets as non-confidential). The gate
/// verifies the resulting ID token with Google and checks the audience.
enum GoogleSignIn {
    struct Grant: Equatable { var code: String; var verifier: String; var redirect: String
        var fields: [String: Any] { ["code": code, "verifier": verifier, "redirect_uri": redirect] }
    }
    /// hejo's shared desktop OAuth client, baked into Info.plist at build time (absent → Google is hidden).
    struct Client: Equatable { var id: String; var secret: String }
    static var bundled: Client? {
        guard let id = Bundle.main.object(forInfoDictionaryKey: "HejoGoogleClientID") as? String, !id.isEmpty,
              let secret = Bundle.main.object(forInfoDictionaryKey: "HejoGoogleClientSecret") as? String, !secret.isEmpty else { return nil }
        return Client(id: id, secret: secret)
    }
    static func tokenRequest(_ grant: Grant, client: Client) -> URLRequest {
        var request = URLRequest(url: URL(string: "https://oauth2.googleapis.com/token")!)
        request.httpMethod = "POST"; request.timeoutInterval = 15
        request.setValue("application/x-www-form-urlencoded", forHTTPHeaderField: "Content-Type")
        var form = URLComponents()
        form.queryItems = [.init(name: "code", value: grant.code), .init(name: "code_verifier", value: grant.verifier),
                           .init(name: "redirect_uri", value: grant.redirect), .init(name: "client_id", value: client.id),
                           .init(name: "client_secret", value: client.secret), .init(name: "grant_type", value: "authorization_code")]
        request.httpBody = Data((form.percentEncodedQuery ?? "").replacingOccurrences(of: "+", with: "%2B").utf8)
        return request
    }
    /// Browser sign-in, then the code is redeemed for an ID token that the gate verifies with Google.
    static func idToken(client: Client) async -> String? {
        guard let grant = await run(clientID: client.id),
              let (data, response) = try? await URLSession.shared.data(for: tokenRequest(grant, client: client)),
              (response as? HTTPURLResponse)?.statusCode == 200,
              let value = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return nil }
        return value["id_token"] as? String
    }
    static func base64URL(_ data: Data) -> String {
        data.base64EncodedString().replacingOccurrences(of: "+", with: "-").replacingOccurrences(of: "/", with: "_").replacingOccurrences(of: "=", with: "")
    }
    static func random() -> String {
        var bytes = [UInt8](repeating: 0, count: 32)
        _ = SecRandomCopyBytes(kSecRandomDefault, bytes.count, &bytes)
        return base64URL(Data(bytes))
    }
    static func challenge(_ verifier: String) -> String { base64URL(Data(SHA256.hash(data: Data(verifier.utf8)))) }
    static func authURL(clientID: String, redirect: String, challenge: String, state: String) -> URL {
        var parts = URLComponents(string: "https://accounts.google.com/o/oauth2/v2/auth")!
        parts.queryItems = [.init(name: "client_id", value: clientID), .init(name: "redirect_uri", value: redirect),
                            .init(name: "response_type", value: "code"), .init(name: "scope", value: "openid email"),
                            .init(name: "code_challenge", value: challenge), .init(name: "code_challenge_method", value: "S256"),
                            .init(name: "state", value: state), .init(name: "prompt", value: "select_account")]
        return parts.url!
    }
    /// The authorization code from the browser's redirect request line, only when `state` matches.
    static func callback(_ request: String, state: String) -> String? {
        guard let line = request.split(separator: "\r\n").first, line.hasPrefix("GET "),
              let target = line.split(separator: " ").dropFirst().first,
              let parts = URLComponents(string: "http://127.0.0.1" + target) else { return nil }
        let items = Dictionary((parts.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { first, _ in first })
        guard items["state"] == state, let code = items["code"], !code.isEmpty else { return nil }
        return code
    }
    /// Opens Google in the browser and waits (up to 3 minutes) for the redirect. Nil when cancelled or failed.
    static func run(clientID: String, open: @escaping (URL) -> Void = { NSWorkspace.shared.open($0) }) async -> Grant? {
        let verifier = random(), state = random()
        let parameters = NWParameters.tcp
        parameters.requiredLocalEndpoint = .hostPort(host: "127.0.0.1", port: .any)
        guard let listener = try? NWListener(using: parameters) else { return nil }
        let box = Once<Grant?>()
        return await withCheckedContinuation { continuation in
            box.resume = { continuation.resume(returning: $0); listener.cancel() }
            listener.stateUpdateHandler = { state0 in
                switch state0 {
                case .ready:
                    guard let port = listener.port?.rawValue else { box.finish(nil); return }
                    let redirect = "http://127.0.0.1:\(port)/"
                    box.redirect = redirect
                    DispatchQueue.main.async { open(authURL(clientID: clientID, redirect: redirect, challenge: challenge(verifier), state: state)) }
                case .failed, .cancelled: box.finish(nil)
                default: break
                }
            }
            listener.newConnectionHandler = { connection in
                connection.start(queue: .global())
                connection.receive(minimumIncompleteLength: 1, maximumLength: 8192) { data, _, _, _ in
                    let code = data.flatMap { String(data: $0, encoding: .utf8) }.flatMap { callback($0, state: state) }
                    let page = code == nil ? "Google 로그인이 완료되지 않았어요. hejo에서 다시 시도해 주세요." : "로그인했어요. hejo로 돌아가세요."
                    let body = Data("<!doctype html><meta charset=utf-8><title>hejo</title><p style=\"font:16px -apple-system;margin:40px\">\(page)</p>".utf8)
                    let head = Data("HTTP/1.1 200 OK\r\nContent-Type: text/html; charset=utf-8\r\nContent-Length: \(body.count)\r\nConnection: close\r\n\r\n".utf8)
                    connection.send(content: head + body, completion: .contentProcessed { _ in connection.cancel() })
                    if let code, let redirect = box.redirect { box.finish(Grant(code: code, verifier: verifier, redirect: redirect)) }
                }
            }
            listener.start(queue: .global())
            DispatchQueue.global().asyncAfter(deadline: .now() + 180) { box.finish(nil) }
        }
    }
    private final class Once<T>: @unchecked Sendable {
        private let lock = NSLock(); private var done = false
        var resume: ((T) -> Void)?; var redirect: String?
        func finish(_ value: T) {
            lock.lock(); guard !done else { lock.unlock(); return }; done = true; let resume = self.resume; lock.unlock()
            resume?(value)
        }
    }
}
