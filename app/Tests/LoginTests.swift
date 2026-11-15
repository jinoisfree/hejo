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
    typealias S = AirportFinder.AuthStatus
    var probed: [String] = []
    let local = await AirportFinder.findAirports(home: home, status: { probed.append("status"); return status }, probe: { probed.append($0); return S(account: true, google: false, googleClientID: nil, airport: "Owner") })
    try check(local == [.init(address: "127.0.0.1:47999", status: S(account: true, google: false, googleClientID: nil, airport: "Owner"), local: true)] && probed == ["127.0.0.1:47999"],
              "AT58 this Mac's own airport is found without Tailscale")
    try FileManager.default.removeItem(at: file)
    let none = await AirportFinder.findAirports(home: home, status: { nil })
    try check(none.isEmpty, "AT59 nothing found without Tailscale")

    try check(LoginWindow.mode(status: S(account: false, google: false, googleClientID: nil), wantsReset: false) == .signup, "AT58 sign-up open while the airport has no owner")
    try check(LoginWindow.mode(status: S(account: true, google: true, googleClientID: nil), wantsReset: false) == .login, "AT58 login")
    try check(LoginWindow.mode(status: S(account: true, google: true, googleClientID: nil), wantsReset: true) == .reset, "AT58 reset")
    try check(LoginWindow.mode(status: nil, wantsReset: false) == .notFound, "AT58 airport not found")
    let login = LoginWindow.loginFields(account: "owner", password: "secret pass")["login"] as? [String: String]
    try check(login == ["account": "owner", "password": "secret pass"], "AT58 login hello fields")
    let signup = LoginWindow.signupFields(account: "owner", password: "secret pass", googleIDToken: "jwt")["signup"] as? [String: String]
    try check(signup == ["account": "owner", "password": "secret pass", "google_id_token": "jwt"], "AT59 sign-up with Google fields")
    let reset = LoginWindow.googleFields(idToken: "jwt", newPassword: "new secret")["google"] as? [String: String]
    try check(reset == ["id_token": "jwt", "new_password": "new secret"], "AT59 Google reset fields")
    let link = LoginWindow.googleFields(idToken: "jwt", link: ("owner", "secret pass"))["google"] as? [String: String]
    try check(link == ["id_token": "jwt", "account": "owner", "password": "secret pass"], "AT59 Google link fields")
    let localReset = LoginWindow.localResetFields(code: "k", password: "pw123456")["local"] as? [String: String]
    try check(localReset == ["code": "k", "password": "pw123456"], "AT58 airport Mac reset fields")
    try check(LoginWindow.message(for: "bad_login").contains("아이디 또는 비밀번호") && LoginWindow.message(for: "exists").contains("이미 주인"), "AT58 rejection wording")
    let client0 = GoogleSignIn.Client(id: "cid", secret: "s+c")
    let body = String(data: GoogleSignIn.tokenRequest(.init(code: "c/1", verifier: "v", redirect: "http://127.0.0.1:5/"), client: client0).httpBody!, encoding: .utf8)!
    try check(body.contains("client_secret=s%2Bc") && body.contains("grant_type=authorization_code") && body.contains("redirect_uri=http://127.0.0.1:5/"), "AT59 token exchange form encoding")

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
    let window = LoginWindow(client: client); window.home = home; window.googleClient = .init(id: "cid", secret: "s")
    window.apply(.login)
    try check(!window.account.isHidden && !window.password.isHidden && window.confirm.isHidden && !window.forgot.isHidden && window.google.isHidden, "AT58 login form without Google when the airport has none")
    window.apply(.signup)
    try check(!window.account.isHidden && !window.confirm.isHidden && window.forgot.isHidden && window.primary.title == "가입", "AT58 sign-up form")
    window.apply(.reset)
    try check(window.primary.isHidden && window.message.stringValue.contains("공항이 있는 Mac"), "AT59 remote reset without Google points to the airport Mac")
    await window.refresh(find: { [] })
    try check(window.mode == .notFound, "AT58 not found form")
    try Data(#"{"v":1,"port":47999,"code":"Ab-_cdEFgh12"}"#.utf8).write(to: file)
    await window.refresh(find: { [.init(address: "127.0.0.1:47999", status: S(account: true, google: true, googleClientID: "cid", airport: "Owner"), local: true)] })
    try check(window.mode == .login && !window.google.isHidden && window.linkGoogle.isHidden && window.airportPicker.isHidden, "AT59 linked Google offered, single airport has no picker")
    window.apply(.reset)
    try check(!window.primary.isHidden && window.primary.title == "재설정" && window.message.stringValue.contains("공항 Mac이라"), "AT58 airport Mac reset needs no old password")
    try FileManager.default.removeItem(at: file)
    await window.refresh(find: { [.init(address: "100.64.0.2:47820", status: S(account: true, google: false, googleClientID: "cid", airport: "Admin")),
                                  .init(address: "100.64.0.2:47821", status: S(account: false, google: false, googleClientID: "other", airport: "Moyo"))] })
    try check(!window.airportPicker.isHidden && window.airportPicker.itemTitles == ["Admin의 공항", "Moyo의 공항"], "AT59 two airports on one Mac are picked by name")
    try check(window.mode == .login && !window.linkGoogle.isHidden, "AT59 unlinked Google can be linked with id/password")
    window.airportPicker.selectItem(at: 1); window.airportPicker.sendAction(window.airportPicker.action, to: window.airportPicker.target)
    try check(window.mode == .signup && window.google.isHidden, "AT59 picking the other airport shows its sign-up; Google hidden for another client id")
    window.close()
    print("AT-HF-58 APP PASS"); print("AT-HF-59 APP PASS")
}
