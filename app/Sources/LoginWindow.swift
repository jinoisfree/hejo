import AppKit

/// Member sign-in at the Mac's hejo hub (REQ-HF-20). The hub is found automatically. Anyone can sign up as a member;
/// each member signs in with an id/password or Google and reaches only their own Hermes. A forgotten password is
/// reset with Google, or without the old password on the Mac that runs that member's Hermes.
@MainActor final class LoginWindow: NSWindowController {
    enum Mode: Equatable { case searching, notFound, login, signup, reset, needsHermes }
    /// The member's one-time join command in the Mac's shared folder (next to the user folders).
    static var joinCommand: String {
        URL(fileURLWithPath: NSHomeDirectory()).deletingLastPathComponent().appendingPathComponent("Shared/hejo/install/hejo-join").path
    }
    static func message(for reason: String?) -> String {
        switch reason {
        case "bad_login": return "아이디 또는 비밀번호가 맞지 않아요"
        case "locked": return "여러 번 틀려서 10분 동안 잠겼어요 · 잠시 뒤 다시 하거나 비밀번호를 재설정해 주세요"
        case "weak_password": return "비밀번호는 8자 이상으로 정해 주세요"
        case "bad_id": return "아이디는 영문·숫자·. _ - 로 3~64자예요"
        case "exists": return "이미 있는 아이디예요 · 다른 아이디를 쓰거나 로그인해 주세요"
        case "not_linked": return "이 Google 계정에 연결된 회원이 없어요 · 아이디·비밀번호를 넣고 'Google 계정 연결'을 눌러 주세요"
        case "google_in_use": return "이 Google 계정은 이미 다른 회원에 연결돼 있어요"
        case "google_failed": return "Google 확인에 실패했어요 · 다시 시도해 주세요"
        case "local_only": return "기존 비밀번호 없이 재설정은 내 Hermes가 있는 Mac에서만 할 수 있어요"
        case "hub_unavailable", "unreachable": return "hejo 서버에 연결하지 못했어요 · 잠시 뒤 다시 시도해 주세요"
        default: return "로그인하지 못했어요 · 다시 시도해 주세요"
        }
    }

    let heading = NSTextField(labelWithString: "")
    let account = NSTextField(string: "")
    let password = NSSecureTextField(string: "")
    let confirm = NSSecureTextField(string: "")
    let primary = NSButton(title: "", target: nil, action: nil)
    let google = NSButton(title: "Google로 계속하기", target: nil, action: nil)
    let linkGoogle = NSButton(title: "Google 계정 연결", target: nil, action: nil)
    let switchMode = NSButton(title: "", target: nil, action: nil)
    let forgot = NSButton(title: "비밀번호를 잊었어요", target: nil, action: nil)
    let message = NSTextField(wrappingLabelWithString: "")
    let address = NSTextField(string: "")
    let changeAddress = NSButton(title: "서버 주소 직접 입력", target: nil, action: nil)
    private(set) var mode = Mode.searching
    private(set) var hub: HubClient?
    private(set) var hubGoogleClientID: String?
    private var pendingToken: String?
    private let client: GateClient
    var home = AirportFinder.defaultHome
    var googleClient: GoogleSignIn.Client? = GoogleSignIn.bundled
    var onSignedIn: ((HubClient, HubClient.Me) -> Void)?
    /// This Mac runs the signing-in member's Hermes (its 0600 proof file is readable only by that Mac account).
    var hermesHere: Bool { AirportFinder.localPair(home: home) != nil }
    var googleReady: Bool { googleClient != nil && hubGoogleClientID == googleClient?.id }

    init(client: GateClient) {
        self.client = client
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 440, height: 430), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "hejo"; w.isReleasedWhenClosed = false
        super.init(window: w)
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        account.placeholderString = "아이디"; confirm.placeholderString = "비밀번호 확인"
        address.placeholderString = "hejo 서버 주소 (예: 맥미니 Tailscale 주소)"; address.isHidden = true
        message.textColor = .secondaryLabelColor
        for (button, action) in [(primary, #selector(submit)), (google, #selector(withGoogle)), (linkGoogle, #selector(withGoogleLink)),
                                 (switchMode, #selector(toggleSignup)), (forgot, #selector(showReset)), (changeAddress, #selector(editAddress))] {
            button.target = self; button.action = action
        }
        primary.keyEquivalent = "\r"
        for link in [switchMode, forgot, changeAddress] { link.isBordered = false; link.contentTintColor = .linkColor }
        let stack = NSStackView(views: [heading, account, password, confirm, primary, google, linkGoogle, switchMode, forgot, message, changeAddress, address])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        for view in [account, password, confirm, primary, google, linkGoogle, address, message] as [NSView] {
            view.widthAnchor.constraint(equalToConstant: 360).isActive = true
        }
        stack.translatesAutoresizingMaskIntoConstraints = false; w.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor, constant: 40),
                                     stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor, constant: 28)])
        apply(.searching); w.center()
    }
    required init?(coder: NSCoder) { fatalError() }

    func present() {
        showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true)
        Task { await refresh() }
    }
    func refresh(find: () async -> String? = { await AirportFinder.findHub() }) async {
        apply(.searching)
        let typed = address.isHidden ? nil : address.stringValue.trimmingCharacters(in: .whitespaces)
        var found = typed.map { $0.contains(":") ? $0 : "\($0):\(HubClient.port)" }
        if found == nil { found = await find() }
        guard let found, let info = await HubClient(address: found).info() else { hub = nil; apply(.notFound); return }
        hub = HubClient(address: found); hubGoogleClientID = info
        apply(mode == .signup ? .signup : .login)
    }
    func apply(_ next: Mode) {
        mode = next
        let titles: [Mode: (String, String)] = [.searching: ("hejo 서버를 찾는 중…", ""), .notFound: ("hejo 서버를 찾지 못했어요", "다시 찾기"),
            .login: ("hejo 로그인", "로그인"), .signup: ("가입하기", "가입"),
            .reset: ("비밀번호 재설정", hermesHere ? "재설정" : "Google로 확인하고 재설정"), .needsHermes: ("Hermes 연결이 필요해요", "다시 확인")]
        heading.stringValue = titles[next]!.0; primary.title = titles[next]!.1
        account.isHidden = ![.login, .signup].contains(next)
        password.isHidden = ![.login, .signup, .reset].contains(next)
        confirm.isHidden = ![.signup, .reset].contains(next)
        password.placeholderString = next == .reset ? "새 비밀번호 (8자 이상)" : "비밀번호 (8자 이상)"
        primary.isHidden = next == .searching || (next == .reset && !hermesHere && !googleReady)
        google.isHidden = !googleReady || ![.login, .signup].contains(next)
        google.title = next == .signup ? "Google 계정도 연결해서 가입" : "Google로 계속하기"
        linkGoogle.isHidden = !(googleReady && next == .login)
        switchMode.isHidden = ![.login, .signup, .reset].contains(next)
        switchMode.title = next == .login ? "처음이에요 · 가입하기" : "로그인으로"
        forgot.isHidden = next != .login
        changeAddress.isHidden = next == .searching
        message.stringValue = {
            switch next {
            case .notFound: return "맥미니(hejo 서버)와 Tailscale이 켜져 있는지 확인하거나 서버 주소를 직접 입력해 주세요."
            case .signup: return "회원마다 자기 Hermes 직원들과 대화해요. 가입한 뒤 내 Hermes가 있는 Mac 계정에서 한 번 연결하면 돼요."
            case .reset where hermesHere: return "내 Hermes가 있는 Mac이라 기존 비밀번호 없이 새로 정할 수 있어요. 다른 기기는 모두 로그아웃돼요."
            case .reset where googleReady: return "새 비밀번호를 정하고 Google로 본인 확인을 해 주세요. 다른 기기는 모두 로그아웃돼요."
            case .reset: return "내 Hermes가 있는 Mac(맥미니의 내 계정)의 hejo에서 재설정할 수 있어요. Google 계정을 연결해 두면 어디서든 재설정할 수 있어요."
            case .needsHermes: return "이 회원의 Hermes가 아직 hejo에 연결되지 않았어요. 맥미니의 내 Mac 계정 터미널에서 \(Self.joinCommand) 을 한 번 실행한 뒤 '다시 확인'을 눌러 주세요."
            default: return ""
            }
        }()
    }
    func update(_ connection: ConnectionStatus) {
        if connection == .connected { password.stringValue = ""; confirm.stringValue = ""; close() }
        else if connection == .wrongCode { message.stringValue = Self.message(for: client.rejection) }
    }
    private func newPassword() -> String? {
        guard password.stringValue.count >= 8 else { message.stringValue = Self.message(for: "weak_password"); return nil }
        guard confirm.isHidden || confirm.stringValue == password.stringValue else { message.stringValue = "비밀번호 확인이 달라요"; return nil }
        return password.stringValue
    }
    /// Run a hub sign-in, then open this member's own gate with the issued token.
    private func signIn(_ work: @escaping (HubClient) async throws -> HubClient.SignIn) {
        guard let hub else { Task { await refresh() }; return }
        message.stringValue = "확인하는 중…"
        Task {
            do { let result = try await work(hub); pendingToken = result.token; await finish(hub: hub, token: result.token) }
            catch HubClient.Failure.rejected(let reason) { message.stringValue = Self.message(for: reason) }
            catch { message.stringValue = Self.message(for: "unreachable") }
        }
    }
    func finish(hub: HubClient, token: String) async {
        guard let me = try? await hub.me(token: token) else { message.stringValue = Self.message(for: "unreachable"); return }
        guard let gate = hub.gateAddress(me) else { apply(.needsHermes); return }
        try? client.store.update { $0.hubAddress = hub.address }
        onSignedIn?(hub, me)
        do { try await client.adopt(address: gate, device: AirportFinder.deviceName, token: token); pendingToken = nil }
        catch { message.stringValue = "로그인 정보를 저장하지 못했어요 · 다시 시도해 주세요" }
    }
    @objc private func submit() {
        let device = AirportFinder.deviceName, id = account.stringValue
        switch mode {
        case .searching: return
        case .notFound: Task { await refresh() }
        case .needsHermes: if let hub, let pendingToken { Task { await finish(hub: hub, token: pendingToken) } } else { apply(.login) }
        case .login: let secret = password.stringValue; signIn { try await $0.login(account: id, password: secret, device: device) }
        case .signup: if let secret = newPassword() { signIn { try await $0.signup(account: id, password: secret, device: device) } }
        case .reset:
            guard let secret = newPassword() else { return }
            if let local = AirportFinder.localPair(home: home) {
                // The member's own gate checks the proof file and asks the hub to reset; its welcome carries a new token.
                try? client.store.update { $0.hubAddress = hub?.address }
                do { try client.signIn(address: "127.0.0.1:\(local.port)", device: device, fields: ["local": ["code": local.code, "password": secret]]); message.stringValue = "확인하는 중…" }
                catch { message.stringValue = Self.message(for: "unreachable") }
            } else { withIDToken { token in { try await $0.google(idToken: token, device: device, newPassword: secret) } } }
        }
    }
    @objc private func withGoogle() {
        let device = AirportFinder.deviceName, id = account.stringValue
        if mode == .signup {
            guard let secret = newPassword() else { return }
            withIDToken { token in { try await $0.signup(account: id, password: secret, device: device, googleIDToken: token) } }
        } else { withIDToken { token in { try await $0.google(idToken: token, device: device) } } }
    }
    @objc private func withGoogleLink() {
        let link = (account: account.stringValue, password: password.stringValue), device = AirportFinder.deviceName
        guard !link.account.isEmpty, !link.password.isEmpty else { message.stringValue = "아이디와 비밀번호를 넣고 눌러 주세요"; return }
        withIDToken { token in { try await $0.google(idToken: token, device: device, link: link) } }
    }
    private func withIDToken(_ work: @escaping (String) -> (HubClient) async throws -> HubClient.SignIn) {
        guard let googleClient, googleReady else { message.stringValue = "이 서버에서는 Google 로그인을 쓸 수 없어요"; return }
        message.stringValue = "브라우저에서 Google 계정을 선택해 주세요…"
        Task {
            guard let token = await GoogleSignIn.idToken(client: googleClient) else { message.stringValue = Self.message(for: "google_failed"); return }
            NSApp.activate(ignoringOtherApps: true); signIn(work(token))
        }
    }
    @objc private func toggleSignup() { apply(mode == .login ? .signup : .login) }
    @objc private func showReset() { apply(.reset) }
    @objc private func editAddress() {
        address.isHidden.toggle()
        if !address.isHidden { window?.makeFirstResponder(address) } else { address.stringValue = ""; Task { await refresh() } }
    }
    override func close() { password.stringValue = ""; confirm.stringValue = ""; super.close() }
}
