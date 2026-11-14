import AppKit

@MainActor final class ConnectWindow: NSWindowController {
    let address = NSTextField(string: "")
    let code = NSSecureTextField(string: "")
    let device = NSTextField(string: "이 Mac")
    let message = NSTextField(wrappingLabelWithString: "Mac의 문에서 발급한 12자 코드를 입력하세요.")
    private let client: GateClient
    init(client: GateClient) {
        self.client = client
        let w = NSWindow(contentRect: CGRect(x: 0, y: 0, width: 520, height: 360), styleMask: [.titled, .closable], backing: .buffered, defer: false)
        w.title = "공항에 연결"; w.isReleasedWhenClosed = false
        super.init(window: w)
        address.stringValue = client.store.settings.address; device.stringValue = client.store.settings.deviceName
        address.placeholderString = "공항 주소:포트"; code.placeholderString = "12자 코드 (기호 포함 그대로)"
        let stack = NSStackView(); stack.orientation = .vertical; stack.alignment = .leading; stack.spacing = 10
        for (title, field) in [("공항 주소", address), ("페어링 코드", code), ("기기 이름", device)] {
            stack.addArrangedSubview(NSTextField(labelWithString: title)); stack.addArrangedSubview(field)
            field.widthAnchor.constraint(equalToConstant: 440).isActive = true
        }
        let button = NSButton(title: "연결", target: self, action: #selector(connect)); button.keyEquivalent = "\r"
        stack.addArrangedSubview(message); stack.addArrangedSubview(button)
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
    override func close() { code.stringValue = ""; super.close() }
}
