import AppKit

/// Owner sign-in (REQ-HF-20). Airports are found automatically (one Mac may host several users' airports, so the
/// user picks by name when more than one answers). The first sign-up owns an airport; afterwards the owner signs in
/// with an id/password or Google. A forgotten password is reset with Google or on the airport Mac itself.
@MainActor final class LoginWindow: NSWindowController {
    enum Mode: Equatable { case searching, notFound, signup, login, reset }
    static func mode(status: AirportFinder.AuthStatus?, wantsReset: Bool) -> Mode {
        guard let status else { return .notFound }
        if !status.account { return .signup }
        return wantsReset ? .reset : .login
    }
    static func loginFields(account: String, password: String) -> [String: Any] { ["login": ["account": account, "password": password]] }
    static func signupFields(account: String, password: String, googleIDToken: String? = nil) -> [String: Any] {
        var signup = ["account": account, "password": password]; if let googleIDToken { signup["google_id_token"] = googleIDToken }
        return ["signup": signup]
    }
    static func googleFields(idToken: String, newPassword: String? = nil, link: (account: String, password: String)? = nil) -> [String: Any] {
        var google = ["id_token": idToken]
        if let newPassword { google["new_password"] = newPassword }
        if let link { google["account"] = link.account; google["password"] = link.password }
        return ["google": google]
    }
    static func localResetFields(code: String, password: String) -> [String: Any] { ["local": ["code": code, "password": password]] }
    static func message(for reason: String?) -> String {
        switch reason {
        case "bad_login": return "아이디 또는 비밀번호가 맞지 않아요"
        case "locked": return "여러 번 틀려서 10분 동안 잠겼어요 · 잠시 뒤 다시 하거나 비밀번호를 재설정해 주세요"
        case "weak_password": return "비밀번호는 8자 이상으로 정해 주세요"
        case "bad_id": return "아이디는 영문·숫자·. _ - 로 3~64자예요"
        case "exists": return "이 공항에는 이미 주인 계정이 있어요 · 로그인해 주세요"
        case "no_account": return "이 공항에는 아직 계정이 없어요 · 먼저 가입해 주세요"
        case "not_linked": return "Google 계정이 아직 연결되지 않았어요 · 아이디·비밀번호를 넣고 'Google 계정 연결'을 눌러 주세요"
        case "google_failed": return "Google 확인에 실패했어요 · 다시 시도해 주세요"
        case "local_only": return "비밀번호 없이 재설정은 공항 Mac에서만 할 수 있어요"
        default: return "로그인하지 못했어요 · 다시 시도해 주세요"
        }
    }

    let heading = NSTextField(labelWithString: "")
    let airportPicker = NSPopUpButton(frame: .zero, pullsDown: false)
    let account = NSTextField(string: "")
    let password = NSSecureTextField(string: "")
    let confirm = NSSecureTextField(string: "")
    let primary = NSButton(title: "", target: nil, action: nil)
    let google = NSButton(title: "Google로 계속하기", target: nil, action: nil)
    let linkGoogle = NSButton(title: "Google 계정 연결", target: nil, action: nil)
    let forgot = NSButton(title: "비밀번호를 잊었어요", target: nil, action: nil)
    let back = NSButton(title: "로그인으로", target: nil, action: nil)
    let message = NSTextField(wrappingLabelWithString: "")
    let address = NSTextField(string: "")
    let changeAddress = NSButton(title: "주소 직접 입력", target: nil, action: nil)
    private(set) var mode = Mode.searching
    private(set) var airports: [AirportFinder.Airport] = []
    private var wantsReset = false
    private let client: GateClient
    var home = AirportFinder.defaultHome
    var googleClient: GoogleSignIn.Client? = GoogleSignIn.bundled
    var current: AirportFinder.Airport? { airports.indices.contains(airportPicker.indexOfSelectedItem) ? airports[airportPicker.indexOfSelectedItem] : airports.first }
    var status: AirportFinder.AuthStatus? { current?.status }
    var isAirportMac: Bool { current?.local == true && AirportFinder.localPair(home: home) != nil }
    /// Google is offered only when this app's shared client is the one the airport accepts.
    var googleReady: Bool { googleClient != nil && status?.googleClientID == googleClient?.id }

    init(client: GateClient) {
        self.client = client
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 440, height: 470), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "hejo"; w.isReleasedWhenClosed = false
        super.init(window: w)
        heading.font = .systemFont(ofSize: 20, weight: .semibold)
        account.placeholderString = "아이디"; password.placeholderString = "비밀번호 (8자 이상)"; confirm.placeholderString = "비밀번호 확인"
        address.placeholderString = "공항 주소:포트"; address.isHidden = true
        message.textColor = .secondaryLabelColor
        airportPicker.target = self; airportPicker.action = #selector(pickAirport)
        for (button, action) in [(primary, #selector(submit)), (google, #selector(withGoogle)), (linkGoogle, #selector(withGoogleLink)),
                                 (forgot, #selector(showReset)), (back, #selector(showLogin)), (changeAddress, #selector(editAddress))] {
            button.target = self; button.action = action
        }
        primary.keyEquivalent = "\r"
        for link in [forgot, back, changeAddress] { link.isBordered = false; link.contentTintColor = .linkColor }
        let stack = NSStackView(views: [heading, airportPicker, account, password, confirm, primary, google, linkGoogle, forgot, back, message, changeAddress, address])
        stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        for view in [airportPicker, account, password, confirm, primary, google, linkGoogle, address, message] as [NSView] {
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
    /// Find airports (or use the typed address), then show the form for the selected one.
    func refresh(find: () async -> [AirportFinder.Airport] = { await AirportFinder.findAirports() }) async {
        apply(.searching)
        if !address.isHidden, !address.stringValue.isEmpty {
            let typed = address.stringValue
            airports = await AirportFinder.authStatus(address: typed).map { [AirportFinder.Airport(address: typed, status: $0)] } ?? []
        } else { airports = await find() }
        let saved = client.store.settings.address
        airportPicker.removeAllItems()
        for airport in airports {
            let name = airport.status.airport.isEmpty ? airport.address : "\(airport.status.airport)의 공항"
            airportPicker.addItem(withTitle: airport.local ? "\(name) · 이 Mac" : name)
        }
        if let index = airports.firstIndex(where: { $0.address == saved }) { airportPicker.selectItem(at: index) }
        apply(Self.mode(status: status, wantsReset: wantsReset))
    }
    func apply(_ next: Mode) {
        mode = next
        let titles: [Mode: (String, String)] = [.searching: ("공항을 찾는 중…", ""), .notFound: ("공항을 찾지 못했어요", "다시 찾기"),
            .signup: ("가입하기", "가입"), .login: ("hejo 로그인", "로그인"),
            .reset: ("비밀번호 재설정", isAirportMac ? "재설정" : "Google로 확인하고 재설정")]
        heading.stringValue = titles[next]!.0; primary.title = titles[next]!.1
        airportPicker.isHidden = airports.count < 2 || next == .searching
        account.isHidden = ![.signup, .login].contains(next)
        password.isHidden = ![.signup, .login, .reset].contains(next)
        confirm.isHidden = ![.signup, .reset].contains(next)
        password.placeholderString = next == .reset ? "새 비밀번호 (8자 이상)" : "비밀번호 (8자 이상)"
        primary.isHidden = next == .searching || (next == .reset && !isAirportMac && !(googleReady && status?.google == true))
        google.isHidden = !googleReady || !((next == .login && status?.google == true) || next == .signup)
        google.title = next == .signup ? "Google 계정도 연결해서 가입" : "Google로 계속하기"
        linkGoogle.isHidden = !(googleReady && next == .login && status?.google == false)
        forgot.isHidden = next != .login
        back.isHidden = next != .reset
        changeAddress.isHidden = next == .searching
        message.stringValue = {
            switch next {
            case .notFound: return "공항 Mac과 Tailscale이 켜져 있는지 확인하거나 주소를 직접 입력해 주세요."
            case .signup: return "이 공항의 주인 계정을 만들어요. 처음 가입한 사람이 주인이 되고, 그 뒤에는 가입이 닫혀요."
            case .reset where isAirportMac: return "공항 Mac이라 기존 비밀번호 없이 새로 정할 수 있어요. 다른 기기는 모두 로그아웃돼요."
            case .reset where googleReady && status?.google == true: return "새 비밀번호를 정하고 Google로 본인 확인을 해 주세요. 다른 기기는 모두 로그아웃돼요."
            case .reset: return "이 공항이 있는 Mac의 hejo에서 재설정할 수 있어요. Google 계정을 연결해 두면 어디서든 재설정할 수 있어요."
            default: return ""
            }
        }()
    }
    func update(_ connection: ConnectionStatus) {
        if connection == .connected { password.stringValue = ""; confirm.stringValue = ""; wantsReset = false; close() }
        else if connection == .wrongCode { let reason = client.rejection; Task { await refresh(); message.stringValue = Self.message(for: reason) } }
    }
    private func newPassword() -> String? {
        guard password.stringValue.count >= 8 else { message.stringValue = Self.message(for: "weak_password"); return nil }
        guard confirm.isHidden || confirm.stringValue == password.stringValue else { message.stringValue = "비밀번호 확인이 달라요"; return nil }
        return password.stringValue
    }
    private func start(_ fields: [String: Any]) {
        guard let current else { message.stringValue = "공항을 먼저 찾아 주세요"; return }
        do { try client.signIn(address: current.address, device: AirportFinder.deviceName, fields: fields); message.stringValue = "확인하는 중…" }
        catch { message.stringValue = "공항 주소를 확인해 주세요" }
    }
    @objc private func submit() {
        switch mode {
        case .notFound, .searching: Task { await refresh() }
        case .login: start(Self.loginFields(account: account.stringValue, password: password.stringValue))
        case .signup: if let secret = newPassword() { start(Self.signupFields(account: account.stringValue, password: secret)) }
        case .reset:
            guard let secret = newPassword() else { return }
            if isAirportMac, let code = AirportFinder.localPair(home: home)?.code { start(Self.localResetFields(code: code, password: secret)) }
            else { withIDToken { Self.googleFields(idToken: $0, newPassword: secret) } }
        }
    }
    @objc private func withGoogle() {
        if mode == .signup {
            guard let secret = newPassword() else { return }
            let id = account.stringValue
            withIDToken { Self.signupFields(account: id, password: secret, googleIDToken: $0) }
        } else { withIDToken { Self.googleFields(idToken: $0) } }
    }
    @objc private func withGoogleLink() {
        let link = (account: account.stringValue, password: password.stringValue)
        guard !link.account.isEmpty, !link.password.isEmpty else { message.stringValue = "아이디와 비밀번호를 넣고 눌러 주세요"; return }
        withIDToken { Self.googleFields(idToken: $0, link: link) }
    }
    private func withIDToken(_ fields: @escaping (String) -> [String: Any]) {
        guard let googleClient, googleReady else { message.stringValue = "이 공항에서는 Google 로그인을 쓸 수 없어요"; return }
        message.stringValue = "브라우저에서 Google 계정을 선택해 주세요…"
        Task {
            guard let token = await GoogleSignIn.idToken(client: googleClient) else { message.stringValue = Self.message(for: "google_failed"); return }
            NSApp.activate(ignoringOtherApps: true); start(fields(token))
        }
    }
    @objc private func pickAirport() { apply(Self.mode(status: status, wantsReset: wantsReset)) }
    @objc private func showReset() { wantsReset = true; apply(.reset) }
    @objc private func showLogin() { wantsReset = false; apply(Self.mode(status: status, wantsReset: false)) }
    @objc private func editAddress() {
        address.isHidden.toggle()
        if !address.isHidden { window?.makeFirstResponder(address) } else { address.stringValue = ""; Task { await refresh() } }
    }
    override func close() { password.stringValue = ""; confirm.stringValue = ""; super.close() }
}
