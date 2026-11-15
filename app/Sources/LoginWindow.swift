import AppKit

/// Owner sign-in (REQ-HF-20). The airport is found automatically; the owner signs up once on the airport Mac,
/// then signs in anywhere with an id/password or Google. A forgotten password is reset with Google or on the airport Mac.
@MainActor final class LoginWindow: NSWindowController {
    enum Mode: Equatable { case searching, notFound, signup, needsSignup, login, reset }
    static func mode(isAirport: Bool, status: AirportFinder.AuthStatus?, wantsReset: Bool) -> Mode {
        guard let status else { return .notFound }
        if !status.account { return isAirport ? .signup : .needsSignup }
        return wantsReset ? .reset : .login
    }
    static func loginFields(account: String, password: String) -> [String: Any] { ["login": ["account": account, "password": password]] }
    static func googleFields(_ grant: GoogleSignIn.Grant, newPassword: String? = nil) -> [String: Any] {
        var google = grant.fields; if let newPassword { google["new_password"] = newPassword }; return ["google": google]
    }
    static func localFields(code: String, account: String? = nil, password: String? = nil, google: GoogleSignIn.Grant? = nil) -> [String: Any] {
        var local: [String: Any] = ["code": code]
        if let account { local["account"] = account }; if let password { local["password"] = password }
        if let google { local["google"] = google.fields }
        return ["local": local]
    }
    static func message(for reason: String?) -> String {
        switch reason {
        case "bad_login": return "아이디 또는 비밀번호가 맞지 않아요"
        case "locked": return "여러 번 틀려서 10분 동안 잠겼어요 · 잠시 뒤 다시 시도하거나 비밀번호를 재설정해 주세요"
        case "weak_password": return "비밀번호는 8자 이상으로 정해 주세요"
        case "bad_id": return "아이디는 영문·숫자·. _ - 로 3~64자예요"
        case "no_account": return "아직 사장 계정이 없어요 · 공항 Mac(맥미니)의 hejo에서 먼저 만들어 주세요"
        case "not_linked": return "Google 계정이 아직 연결되지 않았어요 · 공항 Mac에서 연결해 주세요"
        case "google_failed": return "Google 확인에 실패했어요 · 다시 시도해 주세요"
        case "local_only": return "이 작업은 공항 Mac(맥미니)에서만 할 수 있어요"
        default: return "로그인하지 못했어요 · 다시 시도해 주세요"
        }
    }

    let heading = NSTextField(labelWithString: "")
    let account = NSTextField(string: "")
    let password = NSSecureTextField(string: "")
    let confirm = NSSecureTextField(string: "")
    let primary = NSButton(title: "", target: nil, action: nil)
    let google = NSButton(title: "Google로 계속하기", target: nil, action: nil)
    let forgot = NSButton(title: "비밀번호를 잊었어요", target: nil, action: nil)
    let back = NSButton(title: "로그인으로", target: nil, action: nil)
    let message = NSTextField(wrappingLabelWithString: "")
    let addressLabel = NSTextField(labelWithString: "")
    let address = NSTextField(string: "")
    let changeAddress = NSButton(title: "주소 바꾸기", target: nil, action: nil)
    private(set) var mode = Mode.searching
    private(set) var status: AirportFinder.AuthStatus?
    private var wantsReset = false
    private let client: GateClient
    var home = AirportFinder.defaultHome
    var isAirport: Bool { AirportFinder.localPair(home: home) != nil }

    init(client: GateClient) {
        self.client = client
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 440, height: 420), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "hejo"; w.isReleasedWhenClosed = false
        super.init(window: w)
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        account.placeholderString = "아이디"; password.placeholderString = "비밀번호 (8자 이상)"; confirm.placeholderString = "비밀번호 확인"
        address.placeholderString = "공항 주소:포트"; address.isHidden = true
        addressLabel.textColor = .secondaryLabelColor; message.textColor = .secondaryLabelColor
        for (button, action) in [(primary, #selector(submit)), (google, #selector(withGoogle)), (forgot, #selector(showReset)),
                                 (back, #selector(showLogin)), (changeAddress, #selector(editAddress))] {
            button.target = self; button.action = action
        }
        primary.keyEquivalent = "\r"; primary.bezelColor = .controlAccentColor
        for link in [forgot, back, changeAddress] { link.isBordered = false; link.contentTintColor = .linkColor }
        let addressRow = NSStackView(views: [addressLabel, changeAddress]); addressRow.spacing = 6
        let stack = NSStackView(views: [heading, account, password, confirm, primary, google, forgot, back, message, addressRow, address])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        for field in [account, password, confirm, primary, google, address] { field.widthAnchor.constraint(equalToConstant: 360).isActive = true }
        message.widthAnchor.constraint(equalToConstant: 360).isActive = true
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
    /// Find the airport and the sign-in methods it offers, then show the matching form.
    func refresh(find: () async -> String? = { await AirportFinder.findAddress() }) async {
        apply(.searching)
        let found = !address.isHidden && !address.stringValue.isEmpty ? address.stringValue : await find()
        if let found { address.stringValue = found }
        status = found == nil ? nil : await AirportFinder.authStatus(address: found!)
        apply(Self.mode(isAirport: isAirport, status: status, wantsReset: wantsReset))
    }
    func apply(_ next: Mode) {
        mode = next
        let titles: [Mode: (String, String)] = [.searching: ("공항을 찾는 중…", ""), .notFound: ("공항을 찾지 못했어요", "다시 찾기"),
            .signup: ("사장 계정 만들기", "계정 만들기"), .needsSignup: ("사장 계정이 아직 없어요", "다시 확인"),
            .login: ("hejo 로그인", "로그인"), .reset: ("비밀번호 재설정", isAirport ? "재설정" : "Google로 확인하고 재설정")]
        heading.stringValue = titles[next]!.0; primary.title = titles[next]!.1
        let googleReady = status?.googleClientID != nil
        account.isHidden = ![.signup, .login].contains(next)
        password.isHidden = ![.signup, .login, .reset].contains(next)
        confirm.isHidden = ![.signup, .reset].contains(next)
        password.placeholderString = next == .reset ? "새 비밀번호 (8자 이상)" : "비밀번호 (8자 이상)"
        primary.isHidden = next == .searching || (next == .reset && !isAirport && status?.google != true)
        google.isHidden = !(googleReady && ((next == .login && (status?.google == true || isAirport)) || next == .signup))
        google.title = next == .signup ? "Google 계정도 연결하며 만들기" : status?.google == true ? "Google로 계속하기" : "Google 계정 연결"
        forgot.isHidden = next != .login
        back.isHidden = next != .reset
        addressLabel.stringValue = address.stringValue.isEmpty ? "공항 주소를 직접 입력할 수 있어요" : "공항: \(address.stringValue)"
        message.stringValue = {
            switch next {
            case .notFound: return "공항 Mac과 Tailscale이 켜져 있는지 확인하거나 주소를 직접 입력해 주세요."
            case .needsSignup: return Self.message(for: "no_account")
            case .signup: return "이 Mac이 공항이라 여기서만 사장 계정을 만들 수 있어요."
            case .reset where isAirport: return "공항 Mac이라 지금 비밀번호 없이 새로 정할 수 있어요. 다른 기기는 모두 로그아웃돼요."
            case .reset where status?.google == true: return "새 비밀번호를 정하고 Google로 본인 확인을 해 주세요. 다른 기기는 모두 로그아웃돼요."
            case .reset: return "공항 Mac(맥미니)의 hejo에서 재설정할 수 있어요. Google 계정을 연결해 두면 어디서든 재설정할 수 있어요."
            default: return ""
            }
        }()
    }
    func update(_ connection: ConnectionStatus) {
        if connection == .connected { password.stringValue = ""; confirm.stringValue = ""; wantsReset = false; close() }
        else if connection == .wrongCode { message.stringValue = Self.message(for: client.rejection); Task { await refresh() } }
    }
    private var device: String { AirportFinder.deviceName }
    private func newPassword() -> String? {
        guard password.stringValue.count >= 8 else { message.stringValue = Self.message(for: "weak_password"); return nil }
        guard confirm.isHidden || confirm.stringValue == password.stringValue else { message.stringValue = "비밀번호 확인이 달라요"; return nil }
        return password.stringValue
    }
    private func start(_ fields: [String: Any]) {
        do { try client.signIn(address: address.stringValue, device: device, fields: fields); message.stringValue = "확인하는 중…" }
        catch { message.stringValue = "공항 주소를 확인해 주세요" }
    }
    @objc private func submit() {
        switch mode {
        case .notFound, .needsSignup, .searching: Task { await refresh() }
        case .login: start(Self.loginFields(account: account.stringValue, password: password.stringValue))
        case .signup:
            guard let code = AirportFinder.localPair(home: home)?.code, let secret = newPassword() else { return }
            start(Self.localFields(code: code, account: account.stringValue, password: secret))
        case .reset:
            guard let secret = newPassword() else { return }
            if let code = AirportFinder.localPair(home: home)?.code { start(Self.localFields(code: code, password: secret)) }
            else { Task { await googleThen { Self.googleFields($0, newPassword: secret) } } }
        }
    }
    @objc private func withGoogle() {
        switch mode {
        case .signup:
            guard let secret = newPassword() else { return }
            let id = account.stringValue
            Task { await googleThen { grant in AirportFinder.localPair(home: self.home).map { Self.localFields(code: $0.code, account: id, password: secret, google: grant) } ?? [:] } }
        case .login where status?.google != true && isAirport:
            Task { await googleThen { grant in AirportFinder.localPair(home: self.home).map { Self.localFields(code: $0.code, google: grant) } ?? [:] } }
        default: Task { await googleThen { Self.googleFields($0) } }
        }
    }
    private func googleThen(_ fields: @escaping (GoogleSignIn.Grant) -> [String: Any]) async {
        guard let clientID = status?.googleClientID else { message.stringValue = "Google 로그인이 아직 설정되지 않았어요"; return }
        message.stringValue = "브라우저에서 Google 계정을 선택해 주세요…"
        guard let grant = await GoogleSignIn.run(clientID: clientID) else { message.stringValue = Self.message(for: "google_failed"); return }
        let value = fields(grant); guard !value.isEmpty else { message.stringValue = Self.message(for: "local_only"); return }
        NSApp.activate(ignoringOtherApps: true); start(value)
    }
    @objc private func showReset() { wantsReset = true; apply(.reset) }
    @objc private func showLogin() { wantsReset = false; apply(Self.mode(isAirport: isAirport, status: status, wantsReset: false)) }
    @objc private func editAddress() { address.isHidden.toggle(); if !address.isHidden { window?.makeFirstResponder(address) } else { Task { await refresh() } } }
    override func close() { password.stringValue = ""; confirm.stringValue = ""; super.close() }
}
