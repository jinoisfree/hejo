import AppKit

/// AT-HF-58/59 app side: find the airport, choose the sign-in form, and build the hello fields.
@MainActor func loginTests() async throws {
    let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: home) }
    try FileManager.default.createDirectory(at: home.appendingPathComponent("hejo"), withIntermediateDirectories: true)
    let file = home.appendingPathComponent("hejo/local-pair.json")
    try check(AirportFinder.localPair(home: home) == nil, "AT58 no local file")
    try Data(#"{"v":1,"port":70000,"code":"short"}"#.utf8).write(to: file)
    try check(AirportFinder.localPair(home: home) == nil, "AT58 malformed local file ignored")
    try Data(#"{"v":1,"port":47999,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    try check(AirportFinder.localPair(home: home) == .init(port: 47999, code: "Ab-_cdEFgh12"), "AT58 local file parsed")
    let status = Data(#"{"Self":{"UserID":1},"Peer":{"a":{"Online":true,"OS":"iOS","HostName":"phone","TailscaleIPs":["100.64.0.3","fd7a::3"]},"b":{"Online":false,"OS":"macOS","HostName":"old","TailscaleIPs":["100.64.0.4"]},"c":{"Online":true,"OS":"macOS","HostName":"airport","TailscaleIPs":["fd7a::2","100.64.0.2"]}}}"#.utf8)
    try check(AirportFinder.peers(statusJSON: status) == ["100.64.0.2", "100.64.0.3"], "AT59 online peers, Macs first, IPv4 only")
    var probed: [String] = []
    let local = await AirportFinder.findAddress(home: home, status: { probed.append("status"); return status }, reach: { probed.append($0); return true })
    try check(local == "127.0.0.1:47999" && probed.isEmpty, "AT58 airport Mac finds its own gate without probing")
    try FileManager.default.removeItem(at: file)
    let remote = await AirportFinder.findAddress(home: home, status: { status }, reach: { probed.append($0); return $0 == "100.64.0.3" })
    try check(remote == "100.64.0.3:47820" && probed == ["100.64.0.2", "100.64.0.3"], "AT59 probes Tailscale peers in order")
    let none = await AirportFinder.findAddress(home: home, status: { nil }, reach: { _ in true })
    try check(none == nil, "AT59 nothing found without Tailscale")

    typealias S = AirportFinder.AuthStatus
    try check(LoginWindow.mode(isAirport: true, status: S(account: false, google: false), wantsReset: false) == .signup, "AT58 sign-up only on airport Mac")
    try check(LoginWindow.mode(isAirport: false, status: S(account: false, google: false), wantsReset: false) == .needsSignup, "AT58 other Macs ask for airport sign-up")
    try check(LoginWindow.mode(isAirport: false, status: S(account: true, google: true), wantsReset: false) == .login, "AT58 login")
    try check(LoginWindow.mode(isAirport: false, status: S(account: true, google: true), wantsReset: true) == .reset, "AT58 reset")
    try check(LoginWindow.mode(isAirport: false, status: nil, wantsReset: false) == .notFound, "AT58 airport not found")
    let login = LoginWindow.loginFields(account: "owner", password: "secret pass")["login"] as? [String: String]
    try check(login == ["account": "owner", "password": "secret pass"], "AT58 login hello fields")
    let grant = GoogleSignIn.Grant(code: "c", verifier: "v", redirect: "http://127.0.0.1:5/")
    let google = LoginWindow.googleFields(grant, newPassword: "new secret")["google"] as? [String: String]
    try check(google == ["code": "c", "verifier": "v", "redirect_uri": "http://127.0.0.1:5/", "new_password": "new secret"], "AT59 Google reset fields")
    let setup = LoginWindow.localFields(code: "k", account: "owner", password: "pw123456", google: grant)["local"] as? [String: Any]
    try check(setup?["code"] as? String == "k" && setup?["account"] as? String == "owner" && (setup?["google"] as? [String: String])?["code"] == "c", "AT58 local setup fields")
    try check(LoginWindow.message(for: "bad_login").contains("아이디 또는 비밀번호") && LoginWindow.message(for: "local_only").contains("공항 Mac"), "AT58 rejection wording")

    // Reference value from an independent implementation (Python hashlib + urlsafe base64).
    try check(GoogleSignIn.challenge("dBjftJeZ4CVP-mJ92K27uhbUJU1p1r_wW1gFWFOEjXk") == "ngF5GsXcbwljx6u133FFr3Xht9xooA_DuaX_3QwODtc", "AT59 PKCE S256")
    let url = URLComponents(url: GoogleSignIn.authURL(clientID: "cid", redirect: "http://127.0.0.1:5/", challenge: "ch", state: "st"), resolvingAgainstBaseURL: false)!
    let items = Dictionary(uniqueKeysWithValues: url.queryItems!.map { ($0.name, $0.value!) })
    try check(url.host == "accounts.google.com" && items["client_id"] == "cid" && items["code_challenge_method"] == "S256" && items["scope"] == "openid email", "AT59 Google auth URL")
    try check(GoogleSignIn.callback("GET /?state=st&code=abc HTTP/1.1\r\nHost: x\r\n\r\n", state: "st") == "abc", "AT59 redirect code")
    try check(GoogleSignIn.callback("GET /?state=other&code=abc HTTP/1.1\r\n", state: "st") == nil && GoogleSignIn.callback("GET /?state=st&error=denied HTTP/1.1\r\n", state: "st") == nil, "AT59 redirect state/error rejected")

    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString); defer { try? FileManager.default.removeItem(at: directory) }
    let client = GateClient(store: try LocalStore(directory: directory), credentials: MemoryCredentials())
    try await client.receive(["v": 1, "type": "pair_rejected", "reason": "bad_login"])
    try check(client.rejection == "bad_login" && client.status == .wrongCode, "AT58 rejection reason kept for the form")
    let window = LoginWindow(client: client); window.home = home
    window.apply(.login)
    try check(!window.account.isHidden && !window.password.isHidden && window.confirm.isHidden && !window.forgot.isHidden, "AT58 login form")
    try Data(#"{"v":1,"port":47999,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    window.apply(.signup)
    func capture(_ name: String) throws {
        let view = window.window!.contentView!; view.layoutSubtreeIfNeeded()
        let image = view.bitmapImageRepForCachingDisplay(in: view.bounds)!; view.cacheDisplay(in: view.bounds, to: image)
        try image.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: FileManager.default.currentDirectoryPath).appendingPathComponent(".build/" + name))
    }
    try capture("task14-signup-automatic.png")
    try check(!window.account.isHidden && !window.confirm.isHidden && window.forgot.isHidden && window.primary.title == "계정 만들기", "AT58 sign-up form")
    window.apply(.reset)
    try check(window.account.isHidden && !window.confirm.isHidden && !window.primary.isHidden && window.message.stringValue.contains("공항 Mac이라"), "AT58 airport reset needs no old password")
    try FileManager.default.removeItem(at: file)
    window.apply(.login); try capture("task14-login-automatic.png")
    window.apply(.reset)
    try check(window.primary.isHidden && window.message.stringValue.contains("공항 Mac"), "AT59 remote reset without Google points to airport Mac")
    await window.refresh(find: { nil })
    try check(window.mode == .notFound, "AT58 not found form")
    window.close()
    print("AT-HF-58 APP PASS"); print("AT-HF-59 APP PASS")
}
