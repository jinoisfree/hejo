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
        case "not_linked": return "이 Google 계정에 연결된 회원이 없어요"
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
    let switchMode = NSButton(title: "", target: nil, action: nil)
    let forgot = NSButton(title: "비밀번호를 잊었어요", target: nil, action: nil)
    let message = NSTextField(wrappingLabelWithString: "")
    let keepAccount = NSButton(checkboxWithTitle: "아이디 저장", target: nil, action: nil)
    let keepPassword = NSButton(checkboxWithTitle: "비밀번호 저장", target: nil, action: nil)
    let autoLogin = NSButton(checkboxWithTitle: "자동 로그인", target: nil, action: nil)
    /// Saved passwords go to the Keychain under their own entry, never to the settings file.
    var passwords: GateCredentialStore = GateKeychain()
    static let passwordEntry = "saved-login-password"
    var onPasswordSaveFailure:(String)->Void = {text in
        let alert=NSAlert();alert.messageText="hejo";alert.informativeText=text;alert.addButton(withTitle:"확인")
        NSApp.activate(ignoringOtherApps:true);alert.runModal()
    }
    let or = NSTextField(labelWithString: "또는 아이디로")
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
        for (button, action) in [(primary, #selector(submit)), (google, #selector(withGoogle)),
                                 (switchMode, #selector(toggleSignup)), (forgot, #selector(showReset)), (changeAddress, #selector(editAddress))] {
            button.target = self; button.action = action
        }
        primary.keyEquivalent = "\r"
        for link in [switchMode, forgot, changeAddress] { link.isBordered = false; link.contentTintColor = .linkColor }
        // Google first, like other apps' sign-in screens; the id/password form follows.
        or.textColor = .secondaryLabelColor; or.font = .systemFont(ofSize: 11)
        google.bezelStyle = .rounded; google.controlSize = .large
        google.image = NSImage(systemSymbolName: "g.circle.fill", accessibilityDescription: nil); google.imagePosition = .imageLeading
        primary.controlSize = .large
        let options = NSStackView(views: [keepAccount, keepPassword, autoLogin]); options.spacing = 14
        let stack = NSStackView(views: [heading, google, or, account, password, confirm, options, primary, switchMode, forgot, message, changeAddress, address])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        for view in [account, password, confirm, primary, google, address, message] as [NSView] {
            view.widthAnchor.constraint(equalToConstant: 360).isActive = true
        }
        stack.translatesAutoresizingMaskIntoConstraints = false; w.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor, constant: 40),
                                     stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor, constant: 28)])
        loadChoices(); apply(.searching); w.center()
    }
    required init?(coder: NSCoder) { fatalError() }

    /// Checkboxes always mirror the saved choices, from creation on (an unset box must never save "off").
    func loadChoices() {
        let settings = client.store.settings
        keepAccount.state = settings.keepsAccount ? .on : .off
        keepPassword.state = settings.keepsPassword ? .on : .off
        autoLogin.state = settings.signsInAutomatically ? .on : .off
    }
    func present() {
        loadChoices()
        let settings = client.store.settings
        if settings.keepsAccount, let saved = settings.rememberedAccount, account.stringValue.isEmpty { account.stringValue = saved }
        if settings.keepsPassword, password.stringValue.isEmpty, let saved = passwords.read(account: Self.passwordEntry) { password.stringValue = saved }
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
            .reset: ("비밀번호 재설정", hermesHere ? "재설정" : "Google로 확인하고 재설정"), .needsHermes: ("Hermes 연결을 기다리는 중", "")]
        heading.stringValue = titles[next]!.0; primary.title = titles[next]!.1
        account.isHidden = ![.login, .signup].contains(next)
        password.isHidden = ![.login, .signup, .reset].contains(next)
        confirm.isHidden = ![.signup, .reset].contains(next)
        password.placeholderString = next == .reset ? "새 비밀번호 (8자 이상)" : "비밀번호 (8자 이상)"
        primary.isHidden = next == .searching || next == .needsHermes || (next == .reset && !hermesHere && !googleReady)
        google.isHidden = ![.login, .signup].contains(next)  // always on the first screens; explains itself until Google is set up
        or.isHidden = google.isHidden
        google.title = next == .signup ? "Google로 가입하기" : "Google로 계속하기"
        or.stringValue = next == .signup ? "또는 아이디로 가입 (Google로 가입해도 아이디·비밀번호를 함께 정해요)" : "또는 아이디로 로그인"
        for box in [keepAccount, keepPassword, autoLogin] { box.isHidden = ![.login, .signup].contains(next) }
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
            case .needsHermes: return "이 회원의 Hermes가 아직 hejo에 연결되지 않았어요. 맥미니의 내 Mac 계정 터미널에서 \(Self.joinCommand) 을 한 번 실행해 주세요. 연결되면 자동으로 들어가요."
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
        guard let gate = hub.gateAddress(me) else {
            apply(.needsHermes); message.stringValue = "회원 아이디: \(me.account)\n\n" + message.stringValue
            waitForHermes(hub: hub, token: token); return
        }
        try? client.store.update { $0.hubAddress = hub.address }
        rememberChoices()
        do {
            try await client.adopt(address: gate, device: AirportFinder.deviceName, token: token); pendingToken = nil
            onSignedIn?(hub, me)
        }
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
        } else if !id.isEmpty && !password.stringValue.isEmpty {
            // Id and password typed: link this Google account to that existing member.
            let link = (account: id, password: password.stringValue)
            withIDToken { token in { try await $0.google(idToken: token, device: device, link: link) } }
        } else {
            // Plain Google: signs in, or creates the member on first use like other apps.
            withIDToken { token in { try await $0.google(idToken: token, device: device) } }
        }
    }
    private func withIDToken(_ work: @escaping (String) -> (HubClient) async throws -> HubClient.SignIn) {
        guard let googleClient, googleReady else { message.stringValue = "Google 로그인은 아직 준비 중이에요 · hejo의 Google 앱 등록이 끝나면 바로 쓸 수 있어요. 지금은 아이디·비밀번호로 이용해 주세요."; return }
        message.stringValue = "브라우저에서 Google 계정을 선택해 주세요…"
        Task {
            guard let token = await GoogleSignIn.idToken(client: googleClient) else { message.stringValue = Self.message(for: "google_failed"); return }
            NSApp.activate(ignoringOtherApps: true); signIn(work(token))
        }
    }
    /// No "check again" button: while this member's Hermes is not linked yet, look every few seconds and go in.
    var waitInterval: UInt64 = 3_000_000_000
    private var waiting: Task<Void, Never>?
    private func waitForHermes(hub: HubClient, token: String) {
        waiting?.cancel()
        waiting = Task { [weak self] in
            while let self, self.mode == .needsHermes, !Task.isCancelled {
                try? await Task.sleep(nanoseconds: self.waitInterval)
                guard self.mode == .needsHermes, let me = try? await hub.me(token: token), hub.gateAddress(me) != nil else { continue }
                await self.finish(hub: hub, token: token); return
            }
        }
    }
    @objc private func toggleSignup() { apply(mode == .login ? .signup : .login) }
    @objc private func showReset() { apply(.reset) }
    @objc private func editAddress() {
        address.isHidden.toggle()
        if !address.isHidden { window?.makeFirstResponder(address) } else { address.stringValue = ""; Task { await refresh() } }
    }
    /// Keep the sign-in conveniences the member ticked; unticking forgets what was kept.
    func rememberChoices() {
        let keepID = keepAccount.state == .on, keepSecret = keepPassword.state == .on, auto = autoLogin.state == .on
        let id = account.stringValue, secret = password.stringValue
        try? client.store.update {
            $0.rememberAccount = keepID; $0.rememberPassword = keepSecret; $0.autoLogin = auto
            if keepID && !id.isEmpty { $0.rememberedAccount = id } else if !keepID { $0.rememberedAccount = nil }
        }
        if keepSecret && secret.count >= 8, !passwords.save(secret, account: Self.passwordEntry) {
            message.stringValue = "비밀번호를 저장하지 못했어요. 다시 로그인할 때 입력해 주세요."
            onPasswordSaveFailure(message.stringValue)
        }
        else if !keepSecret { passwords.delete(account: Self.passwordEntry) }
    }
    override func close() { password.stringValue = ""; confirm.stringValue = ""; super.close() }
}
