import AppKit

@MainActor final class ConnectWindow: NSWindowController {
    let address = NSTextField(string: "")
    let code = NSSecureTextField(string: "")
    let device = NSTextField(string: AirportFinder.deviceName)
    var onAuto: (() -> Void)?
    let message = NSTextField(wrappingLabelWithString: "Mac의 문에서 발급한 12자 코드를 입력하세요.")
    private let client: GateClient
    init(client: GateClient) {
        self.client = client
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "공항에 연결"; w.isReleasedWhenClosed = false
        super.init(window: w)
        address.stringValue = client.store.settings.address
        if !["", "이 Mac"].contains(client.store.settings.deviceName) { device.stringValue = client.store.settings.deviceName }
        address.placeholderString = "공항 주소:포트"; code.placeholderString = "12자 코드 (기호 포함 그대로)"
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        for (title, field) in [("공항 주소", address), ("페어링 코드", code), ("기기 이름", device)] {
            stack.addArrangedSubview(NSTextField(labelWithString: title)); stack.addArrangedSubview(field)
            field.widthAnchor.constraint(equalToConstant: 440).isActive = true
        }
        let button = NSButton(title: "연결", target: self, action: #selector(connect)); button.keyEquivalent = "\r"
        let auto = NSButton(title: "자동으로 찾기", target: self, action: #selector(findAutomatically))
        let buttons = NSStackView(views: [auto, button]); buttons.spacing = 8
        stack.addArrangedSubview(message); stack.addArrangedSubview(buttons)
        stack.translatesAutoresizingMaskIntoConstraints = false; w.contentView!.addSubview(stack)
        NSLayoutConstraint.activate([stack.leadingAnchor.constraint(equalTo: w.contentView!.leadingAnchor, constant: 40), stack.topAnchor.constraint(equalTo: w.contentView!.topAnchor, constant: 24)])
        message.textColor = .secondaryLabelColor; w.center()
    }
    required init?(coder: NSCoder) { fatalError() }
    func present() { showWindow(nil); window?.makeKeyAndOrderFront(nil); NSApp.activate(ignoringOtherApps: true) }
    func update(_ status: ConnectionStatus) {
        message.stringValue = status.text
        if status == .connected { code.stringValue = ""; close() }
    }
    @objc private func connect() {
        do { try client.pair(address: address.stringValue, code: code.stringValue, device: device.stringValue); code.stringValue = "" }
        catch GateFailure.badCode { message.stringValue = ConnectionStatus.wrongCode.text }
        catch { message.stringValue = "공항 주소를 확인해 주세요 · 주소와 포트를 입력하세요" }
    }
    func searching() { message.stringValue = "공항을 찾는 중…" }
    func notFound() { message.stringValue = "공항을 자동으로 찾지 못했어요 · 공항 Mac과 Tailscale이 켜져 있는지 확인하거나 직접 입력해 주세요"; present() }
    @objc private func findAutomatically() { onAuto?() }
    override func close() { code.stringValue = ""; super.close() }
}
