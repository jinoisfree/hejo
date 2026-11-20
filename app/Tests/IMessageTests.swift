import AppKit

/// AT-HI-35~37: native settings/menu values and outgoing contracts follow one server model.
@MainActor func imessageTests() async throws {
    var outgoing: [[String: Any]] = []
    let state = IMessageState { outgoing.append($0) }
    var now = Date(timeIntervalSince1970: 1000)
    state.clock = { now }
    let section = IMessageSettingsSection()
    let choices = [IMessageRoom(id: "alpha", title: "Alpha"), IMessageRoom(id: "group", title: "Team")]
    section.bind(state, rooms: { choices })
    state.onChange = { section.refresh() }
    func status(_ paired: Bool, enabled: Bool = false, room: String? = nil, reports: [String] = [], ready: Bool = true) {
        state.receive(["type": "imessage_status", "platform_ready": ready, "paired": paired, "enabled": enabled,
                       "room": room as Any? ?? NSNull(), "reports": reports])
    }
    status(false)
    try check(section.status.stringValue == "연결 안 됨" && section.pair.isEnabled && !section.enabled.isEnabled, "AT-HI-35 unpaired native controls")
    await state.requestCode()
    let request = outgoing.last!
    state.receive(["type": "imessage_code", "ref": request["id"]!, "code": "ABCDEFGHIJKL", "expires_in": 600])
    try check(section.code.stringValue == "ABCDEFGHIJKL" && !section.code.isHidden && section.remaining.stringValue == "600초 남음", "AT-HI-35 private code and expiry")
    section.copyPasteboard = NSPasteboard.withUniqueName(); section.copy.performClick(nil)
    try check(section.copyPasteboard.string(forType: .string) == "ABCDEFGHIJKL", "AT-HI-35 copy private code on user action")
    now = now.addingTimeInterval(12); section.refresh()
    try check(section.remaining.stringValue == "588초 남음", "AT-HI-35 countdown")
    status(true, enabled: true, room: "alpha", reports: ["group"])
    try check(section.status.stringValue == "연결됨" && section.code.isHidden && section.enabled.state == .on && section.rooms.titleOfSelectedItem == "Alpha", "AT-HI-35 paired hides code and applies server values")
    status(true, enabled: false, room: "group")
    try check(section.enabled.state == .off && section.rooms.titleOfSelectedItem == "Team", "AT-HI-35 remote room change")
    for room in ["alpha", "group"] {
        status(true, enabled: true, room: room, reports: [room])
        let menu = NSMenu()
        IMessageMenus.append(to: menu, room: room, state: state)
        let connect = menu.items.first { $0.title == "아이메시지 연결 방으로" } as! RoomActionItem
        let report = menu.items.first { $0.title == "폰으로 보고 받기" } as! RoomActionItem
        try check(connect.state == .on && report.state == .on, "AT-HI-36 direct/group menu checks")
        let before = outgoing.count
        connect.trigger(); try await waitFor { outgoing.count == before + 1 }
        try check(outgoing.last?["type"] as? String == "imessage_save" && outgoing.last?["room"] is NSNull, "AT-HI-36 disconnect selected room")
        report.trigger(); try await waitFor { outgoing.count == before + 2 }
        try check(outgoing.last?["reports"] as? [String] == [], "AT-HI-36 remove report room")
        status(true, enabled: true)
        let off = NSMenu(); IMessageMenus.append(to: off, room: room, state: state)
        (off.items.first { $0.title == connect.title } as! RoomActionItem).trigger()
        try await waitFor { outgoing.count == before + 3 }
        try check(outgoing.last?["room"] as? String == room, "AT-HI-36 select direct/group room")
        (off.items.first { $0.title == report.title } as! RoomActionItem).trigger()
        try await waitFor { outgoing.count == before + 4 }
        try check(outgoing.last?["reports"] as? [String] == [room], "AT-HI-36 add report room")
    }
    await state.query()
    state.receive(["type": "error", "ref": outgoing.last!["id"]!, "code": "unexpected_frame"])
    let old = NSMenu(); IMessageMenus.append(to: old, room: "alpha", state: state)
    try check(section.status.stringValue == "서버가 지원하지 않음" && old.items.isEmpty, "AT-HI-37 old gate hides both menu items")
    status(false, ready: false)
    try check(section.status.stringValue == "서버에 아이메시지가 연결돼 있지 않음" && !section.pair.isEnabled, "AT-HI-37 missing phone transport disables code")
    try check(GateClient.features.contains("imessage"), "AT-HI-37 hello advertises feature")
    await state.unpair()
    try check(outgoing.last?["type"] as? String == "imessage_unpair", "AT-HI-35 unpair frame")
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let client = GateClient(store: try LocalStore(directory: root), credentials: MemoryCredentials())
    var forwarded: [String] = []
    client.onFrame = { frame in forwarded.append(frame["type"] as? String ?? "") }
    _ = try await client.receive(["v": 1, "type": "welcome"])
    _ = try await client.receive(["v": 1, "type": "imessage_status", "platform_ready": true, "paired": true, "enabled": true, "room": "alpha", "reports": []])
    try check(client.imessage.room == "alpha" && client.imessage.enabled, "AT-HI-35 GateClient dispatches status to its model")
    try check(forwarded == ["welcome"], "AT-HI-35 feature frames stay out of conversation handling")
    client.stop()
    try check(client.imessage.code == nil && client.imessage.support == .unknown, "AT-HI-35 stop clears connection state")
    print("AT-HI-35~37 PASS")
}
