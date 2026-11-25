import AppKit

/// AT-HD-50~53: gate-owned state, native controls and dispatch boundaries.
@MainActor func discordTests() async throws {
    var outgoing: [[String: Any]] = []
    let state = DiscordState { outgoing.append($0) }
    var now = Date(timeIntervalSince1970: 1000)
    state.clock = { now }
    let section = DiscordSettingsSection()
    section.bind(state)
    state.onChange = { section.refresh() }
    try check(section.status.stringValue == "서버 연결 전", "AT-HD-50 initial")
    await state.query()
    state.receive(["type": "error", "ref": outgoing.last!["id"]!, "code": "unexpected_frame"])
    try check(section.status.stringValue == "서버가 지원하지 않음" && !section.pair.isEnabled, "AT-HD-50 legacy gate")
    func status(_ paired: Bool = false, ready: Bool = true, core: Bool = false, problem: Bool = false, enabled: Bool = false) {
        state.receive(["type": "discord_status", "platform_ready": ready, "paired": paired,
                       "enabled": enabled, "channel_problem": problem, "core_open": core])
    }
    status(ready: false)
    try check(section.status.stringValue == "서버에 디스코드가 연결돼 있지 않음" && !section.pair.isEnabled, "AT-HD-50 unavailable")
    status(core: true, problem: true)
    try check(section.status.stringValue == "Hermes 디스코드 허용이 열려 있음", "AT-HD-50 core priority")
    status(problem: true)
    try check(section.status.stringValue == "채널 권한 문제", "AT-HD-50 channels")
    status(true, enabled: true)
    try check(section.status.stringValue == "연결됨" && section.enabled.state == .on, "AT-HD-50 paired")
    status()
    try check(section.status.stringValue == "연결 안 됨" && section.pair.isEnabled && !section.enabled.isEnabled, "AT-HD-50 unpaired")
    section.pair.performClick(nil)
    try await waitFor { outgoing.last?["type"] as? String == "discord_pair" }
    state.receive(["type": "discord_code", "ref": outgoing.last!["id"]!, "code": "ABCDEFGHIJKL", "expires_in": 600])
    try check(section.code.stringValue == "ABCDEFGHIJKL" && !section.code.isHidden && state.remaining == 600, "AT-HD-51 code")
    section.copyPasteboard = NSPasteboard.withUniqueName()
    section.copy.performClick(nil)
    try check(section.copyPasteboard.string(forType: .string) == "ABCDEFGHIJKL", "AT-HD-51 explicit copy")
    now = now.addingTimeInterval(30); section.refresh()
    try check(state.remaining == 570 && section.remaining.stringValue == "570초 남음", "AT-HD-51 expiry")
    status(true, enabled: true)
    try check(state.code == nil && section.code.isHidden, "AT-HD-51 paired clears code")
    section.enabled.performClick(nil)
    try await waitFor { outgoing.last?["type"] as? String == "discord_save" }
    try check(outgoing.last?["enabled"] as? Bool == false && section.enabled.state == .on, "AT-HD-50 waits for save acknowledgement")
    section.unpair.performClick(nil)
    try await waitFor { outgoing.last?["type"] as? String == "discord_unpair" }
    try check(GateClient.features == ["rooms", "discord"], "AT-HD-52 / AT-HTR-20 exact feature list")
    let window = PetSettingsWindow()
    let connectionPage = window.tabs.tabViewItems.first { $0.label == "연결과 동기화" }?.view
    try check(connectionPage.map { window.discordSection.isDescendant(of: $0) } == true,
              "AT-HD-53 / AT-HTR-21 Discord section on connection page")
    let hints = section.subviews.compactMap { ($0 as? NSTextField)?.stringValue }.joined(separator: " ")
    try check(["Message Content", "커뮤니티", "채널 관리", "웹후크 관리"].allSatisfy { hints.contains($0) }, "AT-HD-53 preparation")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let client = GateClient(store: try LocalStore(directory: root), credentials: MemoryCredentials())
    var forwarded: [String] = []
    client.onFrame = { forwarded.append($0["type"] as? String ?? "") }
    _ = try await client.receive(["v": 1, "type": "welcome"])
    _ = try await client.receive(["v": 1, "type": "discord_status", "platform_ready": true, "paired": true, "enabled": true, "core_open": false, "channel_problem": false])
    try check(client.discord.enabled && client.discord.paired && forwarded == ["welcome"], "AT-HD-50 client dispatch")
    client.stop()
    try check(client.discord.support == .unknown && client.discord.code == nil, "AT-HD-50 disconnect reset")
    print("AT-HD-50~53 PASS")
}
