import AppKit

/// Stub hub for the app's sign-in flow: answers the hub HTTP API from a table the test changes.
final class StubHub: URLProtocol {
    nonisolated(unsafe) static var gatePort: Int?
    nonisolated(unsafe) static var requests: [(String, String, [String: Any])] = []
    override class func canInit(with request: URLRequest) -> Bool { request.url?.host == "hub.test" }
    override class func canonicalRequest(for request: URLRequest) -> URLRequest { request }
    override func startLoading() {
        let path = request.url!.path, method = request.httpMethod ?? "GET"
        var bodyData = request.httpBody
        if bodyData == nil, let stream = request.httpBodyStream {
            stream.open(); var data = Data(); var buffer = [UInt8](repeating: 0, count: 4096)
            while stream.hasBytesAvailable { let n = stream.read(&buffer, maxLength: buffer.count); if n <= 0 { break }; data.append(buffer, count: n) }
            stream.close(); bodyData = data
        }
        let body = bodyData.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] } ?? [:]
        Self.requests.append((method, path, body))
        let (status, value): (Int, [String: Any]) = {
            switch (method, path) {
            case ("GET", "/v1/hub"): return (200, ["hub": 1, "google_client_id": "cid"])
            case ("POST", "/v1/login") where body["password"] as? String == "correct horse": return (200, ["token": "tok", "device_id": "dev"])
            case ("POST", "/v1/login"): return (401, ["error": "bad_login"])
            case ("POST", "/v1/signup"): return (400, ["error": "exists"])
            case ("GET", "/v1/me") where request.value(forHTTPHeaderField: "Authorization") == "Bearer tok":
                return (200, ["account": "moyo", "google": false, "settings": ["petName": "Mochi"], "gate": Self.gatePort.map { ["port": $0] } as Any? ?? NSNull()])
            case ("PUT", "/v1/me/settings"): return (200, ["ok": true])
            default: return (401, ["error": "unknown"])
            }
        }()
        let response = HTTPURLResponse(url: request.url!, statusCode: status, httpVersion: nil, headerFields: ["Content-Type": "application/json"])!
        client?.urlProtocol(self, didReceive: response, cacheStoragePolicy: .notAllowed)
        client?.urlProtocol(self, didLoad: try! JSONSerialization.data(withJSONObject: value))
        client?.urlProtocolDidFinishLoading(self)
    }
    override func stopLoading() {}
}

/// AT-HF-58/59/60 app side: find the hub, sign in as a member, open that member's own gate, carry settings.
@MainActor func loginTests() async throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(at: home.appendingPathComponent("hejo"), withIntermediateDirectories: true)
    let file = home.appendingPathComponent("hejo/local-pair.json")
    try check(AirportFinder.localPair(home: home) == nil, "AT60 no proof file")
    try Data(#"{"v":1,"port":70000,"code":"short"}"#.utf8).write(to: file)
    try check(AirportFinder.localPair(home: home) == nil, "AT60 malformed proof file ignored")
    try Data(#"{"v":1,"port":47821,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    try check(AirportFinder.localPair(home: home) == .init(port: 47821, code: "Ab-_cdEFgh12"), "AT60 proof file parsed")
    try FileManager.default.removeItem(at: file)
    let status = Data(#"{"Self":{"UserID":1},"Peer":{"a":{"Online":true,"OS":"iOS","HostName":"phone","TailscaleIPs":["100.64.0.3","fd7a::3"]},"b":{"Online":false,"OS":"macOS","HostName":"old","TailscaleIPs":["100.64.0.4"]},"c":{"Online":true,"OS":"macOS","HostName":"mini","TailscaleIPs":["fd7a::2","100.64.0.2"]}}}"#.utf8)
    try check(AirportFinder.peers(statusJSON: status) == ["100.64.0.2", "100.64.0.3"], "AT58 online peers, Macs first, IPv4 only")
    var probed: [String] = []
    let local = await AirportFinder.findHub(status: { probed.append("status"); return status }, reach: { _ in true }, probe: { probed.append($0); return $0 == "127.0.0.1:47800" })
    try check(local == "127.0.0.1:47800" && probed == ["127.0.0.1:47800"], "AT58 hub on this Mac found first")
    probed = []
    let remote = await AirportFinder.findHub(status: { status }, reach: { $0 == "100.64.0.2" }, probe: { probed.append($0); return $0 != "127.0.0.1:47800" })
    try check(remote == "100.64.0.2:47800" && probed == ["127.0.0.1:47800", "100.64.0.2:47800"], "AT58 hub found over Tailscale")
    let none = await AirportFinder.findHub(status: { nil }, reach: { _ in true }, probe: { _ in false })
    try check(none == nil, "AT58 no hub without Tailscale")

    let hub = HubClient(address: "100.64.0.2:47800")
    try check(hub.gateAddress(.init(account: "moyo", google: false, gatePort: 47821, settings: [:])) == "100.64.0.2:47821"
              && hub.gateAddress(.init(account: "moyo", google: false, gatePort: nil, settings: [:])) == nil, "AT60 member gate is the hub host with the gate port")
    let request = hub.request("PUT", "/v1/me/settings", body: ["settings": ["petName": "Mochi"]], token: "tok")
    try check(request.url?.absoluteString == "http://100.64.0.2:47800/v1/me/settings" && request.value(forHTTPHeaderField: "Authorization") == "Bearer tok", "AT58 settings request")
    try check(LoginWindow.message(for: "bad_login").contains("아이디 또는 비밀번호") && LoginWindow.message(for: "exists").contains("이미 있는 아이디"), "AT58 rejection wording")

    // Google pieces (independent PKCE reference: Python hashlib + urlsafe base64).
    try check(GoogleSignIn.challenge("dBjftJeZ4CVP-mJ92K27uhbUJU1p1r_wW1gFWFOEjXk") == "ngF5GsXcbwljx6u133FFr3Xht9xooA_DuaX_3QwODtc", "AT59 PKCE S256")
    let url = URLComponents(url: GoogleSignIn.authURL(clientID: "cid", redirect: "http://127.0.0.1:5/", challenge: "ch", state: "st"), resolvingAgainstBaseURL: false)!
    let items = Dictionary(uniqueKeysWithValues: url.queryItems!.map { ($0.name, $0.value!) })
    try check(url.host == "accounts.google.com" && items["client_id"] == "cid" && items["code_challenge_method"] == "S256" && items["scope"] == "openid email", "AT59 Google auth URL")
    try check(GoogleSignIn.callback("GET /?state=st&code=abc HTTP/1.1\r\nHost: x\r\n\r\n", state: "st") == "abc", "AT59 redirect code")
    try check(GoogleSignIn.callback("GET /?state=other&code=abc HTTP/1.1\r\n", state: "st") == nil && GoogleSignIn.callback("GET /?state=st&error=denied HTTP/1.1\r\n", state: "st") == nil, "AT59 redirect state/error rejected")
    let body = String(data: GoogleSignIn.tokenRequest(.init(code: "c/1", verifier: "v", redirect: "http://127.0.0.1:5/"), client: .init(id: "cid", secret: "s+c")).httpBody!, encoding: .utf8)!
    try check(body.contains("client_secret=s%2Bc") && body.contains("grant_type=authorization_code"), "AT59 token exchange form encoding")

    // The whole sign-in against the stub hub.
    URLProtocol.registerClass(StubHub.self); defer { URLProtocol.unregisterClass(StubHub.self) }
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: directory) }
    let client = GateClient(store: try LocalStore(directory: directory), credentials: MemoryCredentials())
    let window = LoginWindow(client: client); window.home = home; window.googleClient = .init(id: "cid", secret: "s")
    var signedIn: [String: String] = [:]; window.onSignedIn = { _, me in signedIn = me.settings }
    await window.refresh(find: { nil })
    try check(window.mode == .notFound, "AT58 hub not found form")
    await window.refresh(find: { "hub.test:47800" })
    try check(window.mode == .login && !window.google.isHidden && !window.linkGoogle.isHidden && window.confirm.isHidden && !window.forgot.isHidden, "AT58 login form with Google from the hub's client")
    window.switchMode.performClick(nil)
    try check(window.mode == .signup && !window.confirm.isHidden && window.forgot.isHidden, "AT58 anyone can open sign-up")
    window.switchMode.performClick(nil)
    window.account.stringValue = "moyo"; window.password.stringValue = "wrong horse"; window.primary.performClick(nil)
    for _ in 0..<50 where !window.message.stringValue.contains("맞지 않아요") { try await Task.sleep(nanoseconds: 20_000_000) }
    try check(window.message.stringValue.contains("아이디 또는 비밀번호"), "AT58 bad login shown")
    StubHub.gatePort = nil
    window.password.stringValue = "correct horse"; window.primary.performClick(nil)
    for _ in 0..<50 where window.mode != .needsHermes { try await Task.sleep(nanoseconds: 20_000_000) }
    try check(window.mode == .needsHermes && window.message.stringValue.contains("hejo-join"), "AT60 signed in but Hermes not linked yet")
    StubHub.gatePort = 47821
    window.primary.performClick(nil)
    for _ in 0..<50 where client.store.settings.address.isEmpty { try await Task.sleep(nanoseconds: 20_000_000) }
    try check(client.store.settings.address == "hub.test:47821" && client.store.settings.hubAddress == "hub.test:47800", "AT60 opens this member's own gate and remembers the hub")
    try check(signedIn["petName"] == "Mochi", "AT58 member settings delivered on sign-in")
    window.apply(.reset)
    try check(window.primary.title == "Google로 확인하고 재설정" && window.message.stringValue.contains("Google"), "AT59 reset away from the member's Mac uses Google")
    try Data(#"{"v":1,"port":47821,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    window.apply(.reset)
    try check(window.primary.title == "재설정" && window.message.stringValue.contains("기존 비밀번호 없이"), "AT60 reset on the member's own Mac needs no old password")
    client.stop(); window.close()
    try await client.receive(["v": 1, "type": "pair_rejected", "reason": "local_only"])
    try check(client.rejection == "local_only" && client.status == .wrongCode, "AT60 rejection reason kept for the form")
    print("AT-HF-58 APP PASS"); print("AT-HF-59 APP PASS"); print("AT-HF-60 APP PASS")
}
