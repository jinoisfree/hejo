import AppKit

/// Retains the existing controls and actions while laying out each settings category independently.
final class SettingsDocument: NSView {
    override var isFlipped: Bool { true }
    func resized(_ child: NSView, by delta: CGFloat) {
        for view in subviews where view !== child && view.frame.minY > child.frame.minY { view.frame.origin.y += delta }
        frame.size.height += delta
    }
}

enum SettingsPages {
    static func make(blocks: [[NSView]]) -> NSScrollView {
        let spacing: CGFloat = 22
        let heights = blocks.map { block in
            (block.map { $0.frame.maxY }.max() ?? 0) - (block.map { $0.frame.minY }.min() ?? 0)
        }
        let height = max(540, heights.reduce(0, +) + spacing * CGFloat(blocks.count + 1))
        let document = SettingsDocument(frame: NSRect(x: 0, y: 0, width: 580, height: height))
        var top = spacing
        for (block, blockHeight) in zip(blocks, heights) {
            let originalTop = block.map { $0.frame.maxY }.max() ?? 0
            for view in block {
                view.removeFromSuperview()
                view.frame.origin.x += 110
                view.frame.origin.y = top + originalTop - view.frame.maxY
                document.addSubview(view)
            }
            top += blockHeight + spacing
        }
        let scroll = NSScrollView(frame: NSRect(x: 0, y: 0, width: 580, height: 580))
        scroll.hasVerticalScroller = true; scroll.autohidesScrollers = true
        scroll.scrollerStyle = .overlay
        scroll.autoresizingMask = [.width, .height]
        scroll.documentView = document
        document.scroll(.zero)
        return scroll
    }
}

/// Native settings present the gate-owned forum connection state.
@MainActor final class TelegramSettingsSection: NSView {
    override var isFlipped: Bool { true }
    let status = NSTextField(labelWithString: "서버 연결 전")
    let code = NSTextField(labelWithString: "")
    let remaining = NSTextField(labelWithString: "")
    let problem = NSTextField(wrappingLabelWithString: "")
    let pair = NSButton(title: "연결 코드 받기", target: nil, action: nil)
    let copy = NSButton(title: "복사", target: nil, action: nil)
    var copyPasteboard: NSPasteboard = .general
    let unpair = NSButton(title: "연결 해제", target: nil, action: nil)
    let enabled = NSButton(checkboxWithTitle: "텔레그램 연결 켜기", target: nil, action: nil)
    private weak var model: TelegramState?
    private var timer: Timer?
    init() {
        super.init(frame: NSRect(x: 24, y: 0, width: 340, height: 300))
        let title = NSTextField(labelWithString: "텔레그램")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        let hint = NSTextField(wrappingLabelWithString: "텔레그램에서 포럼(토픽)을 켠 그룹을 만들고 봇을 토픽 관리 권한이 있는 관리자로 넣은 뒤, 이 코드를 그 그룹에 보내세요. 연결을 켜면 hejo의 방마다 토픽이 생깁니다.")
        hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor
        let views: [(NSView, NSRect)] = [
            (title, NSRect(x: 0, y: 0, width: 320, height: 22)),
            (status, NSRect(x: 0, y: 30, width: 330, height: 22)),
            (pair, NSRect(x: 0, y: 58, width: 140, height: 30)),
            (unpair, NSRect(x: 150, y: 58, width: 110, height: 30)),
            (code, NSRect(x: 0, y: 94, width: 160, height: 24)),
            (remaining, NSRect(x: 170, y: 94, width: 95, height: 24)),
            (copy, NSRect(x: 270, y: 90, width: 60, height: 30)),
            (enabled, NSRect(x: 0, y: 126, width: 330, height: 26)),
            (hint, NSRect(x: 0, y: 164, width: 330, height: 90)),
            (problem, NSRect(x: 0, y: 258, width: 330, height: 40))]
        for (view, rect) in views { view.frame = rect; addSubview(view) }
        code.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        copy.target = self; copy.action = #selector(copyCode)
        pair.target = self; pair.action = #selector(pairPhone)
        unpair.target = self; unpair.action = #selector(unpairPhone)
        enabled.target = self; enabled.action = #selector(changeEnabled)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCode() }
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }
    func bind(_ model: TelegramState) {
        self.model = model; refresh()
    }
    func refresh() {
        status.stringValue = model?.statusText ?? "서버 연결 전"
        let supported = model?.support == .supported
        pair.isEnabled = supported && model?.platformReady == true
        unpair.isEnabled = supported && model?.paired == true
        enabled.isEnabled = supported && model?.paired == true
        enabled.state = model?.enabled == true ? .on : .off
        problem.stringValue = model?.problem ?? ""
        refreshCode()
    }
    private func refreshCode() {
        let seconds = model?.remaining ?? 0
        code.isHidden = seconds == 0 || model?.code == nil
        remaining.isHidden = code.isHidden; copy.isHidden = code.isHidden; copy.isEnabled = !code.isHidden
        code.stringValue = code.isHidden ? "" : model?.code ?? ""
        remaining.stringValue = "\(seconds)초 남음"
    }
    @objc private func copyCode() {
        guard let model, model.remaining > 0, let code = model.code else { return }
        copyPasteboard.clearContents(); copyPasteboard.setString(code, forType: .string)
    }
    @objc private func pairPhone() { Task { await model?.requestCode() } }
    @objc private func unpairPhone() { Task { await model?.unpair() } }
    @objc private func changeEnabled() {
        guard let model else { return }
        let value = enabled.state == .on
        refresh() // Wait for the gate's acknowledgement before displaying a changed setting.
        Task { await model.save(enabled: value) }
    }
}

/// Native settings present the gate-owned forum connection state.
@MainActor final class DiscordSettingsSection: NSView {
    override var isFlipped: Bool { true }
    let status = NSTextField(labelWithString: "서버 연결 전")
    let code = NSTextField(labelWithString: "")
    let remaining = NSTextField(labelWithString: "")
    let problem = NSTextField(wrappingLabelWithString: "")
    let pair = NSButton(title: "연결 코드 받기", target: nil, action: nil)
    let copy = NSButton(title: "복사", target: nil, action: nil)
    var copyPasteboard: NSPasteboard = .general
    let unpair = NSButton(title: "연결 해제", target: nil, action: nil)
    let enabled = NSButton(checkboxWithTitle: "디스코드 연결 켜기", target: nil, action: nil)
    private weak var model: DiscordState?
    private var timer: Timer?
    init() {
        super.init(frame: NSRect(x: 24, y: 0, width: 340, height: 390))
        let title = NSTextField(labelWithString: "디스코드")
        title.font = .systemFont(ofSize: 14, weight: .semibold)
        let hint = NSTextField(wrappingLabelWithString: "디스코드 개발자 포털에서 봇을 만들고 Message Content Intent를 켜세요. 서버를 만든 뒤 커뮤니티를 켜고, 봇을 채널 보기·메시지 보내기·공개 스레드에서 메시지 보내기·메시지 기록 보기·첨부·채널 관리·웹후크 관리 권한으로 초대하세요. 이 코드를 서버의 일반 채널에 입력한 뒤 연결을 켜면 방마다 포럼 채널이 생깁니다.")
        hint.font = .systemFont(ofSize: 12); hint.textColor = .secondaryLabelColor
        let views: [(NSView, NSRect)] = [
            (title, NSRect(x: 0, y: 0, width: 320, height: 22)),
            (status, NSRect(x: 0, y: 30, width: 330, height: 22)),
            (pair, NSRect(x: 0, y: 58, width: 140, height: 30)),
            (unpair, NSRect(x: 150, y: 58, width: 110, height: 30)),
            (code, NSRect(x: 0, y: 94, width: 160, height: 24)),
            (remaining, NSRect(x: 170, y: 94, width: 95, height: 24)),
            (copy, NSRect(x: 270, y: 90, width: 60, height: 30)),
            (enabled, NSRect(x: 0, y: 126, width: 330, height: 26)),
            (hint, NSRect(x: 0, y: 164, width: 330, height: 170)),
            (problem, NSRect(x: 0, y: 338, width: 330, height: 40))]
        for (view, rect) in views { view.frame = rect; addSubview(view) }
        code.font = .monospacedSystemFont(ofSize: 18, weight: .medium)
        copy.target = self; copy.action = #selector(copyCode)
        pair.target = self; pair.action = #selector(pairPhone)
        unpair.target = self; unpair.action = #selector(unpairPhone)
        enabled.target = self; enabled.action = #selector(changeEnabled)
        refresh()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.refreshCode() }
        }
    }
    required init?(coder: NSCoder) { fatalError() }
    deinit { timer?.invalidate() }
    func bind(_ model: DiscordState) {
        self.model = model; refresh()
    }
    func refresh() {
        status.stringValue = model?.statusText ?? "서버 연결 전"
        let supported = model?.support == .supported
        pair.isEnabled = supported && model?.platformReady == true
        unpair.isEnabled = supported && model?.paired == true
        enabled.isEnabled = supported && model?.paired == true
        enabled.state = model?.enabled == true ? .on : .off
        problem.stringValue = model?.problem ?? ""
        refreshCode()
    }
    private func refreshCode() {
        let seconds = model?.remaining ?? 0
        code.isHidden = seconds == 0 || model?.code == nil
        remaining.isHidden = code.isHidden; copy.isHidden = code.isHidden; copy.isEnabled = !code.isHidden
        code.stringValue = code.isHidden ? "" : model?.code ?? ""
        remaining.stringValue = "\(seconds)초 남음"
    }
    @objc private func copyCode() {
        guard let model, model.remaining > 0, let code = model.code else { return }
        copyPasteboard.clearContents(); copyPasteboard.setString(code, forType: .string)
    }
    @objc private func pairPhone() { Task { await model?.requestCode() } }
    @objc private func unpairPhone() { Task { await model?.unpair() } }
    @objc private func changeEnabled() {
        guard let model else { return }
        let value = enabled.state == .on
        refresh() // Wait for the gate's acknowledgement before displaying a changed setting.
        Task { await model.save(enabled: value) }
    }
}
