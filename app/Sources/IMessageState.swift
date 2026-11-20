import Foundation

struct IMessageRoom {
    let id: String
    let title: String
}

/// The gate owns all settings. This model keeps only the current connection's presentation.
@MainActor final class IMessageState {
    enum Support { case unknown, supported, unsupported }
    private(set) var support = Support.unknown
    private(set) var platformReady = false
    private(set) var paired = false
    private(set) var enabled = false
    private(set) var room: String?
    private(set) var reports: [String] = []
    private(set) var code: String?
    private var expires: Date?
    private var requests: [String: String] = [:]
    private(set) var problem = ""
    var clock: () -> Date = Date.init
    var onChange: (() -> Void)?
    private let send: ([String: Any]) async throws -> Void

    init(send: @escaping ([String: Any]) async throws -> Void) { self.send = send }
    var remaining: Int { max(0, Int(ceil((expires ?? .distantPast).timeIntervalSince(clock())))) }
    var statusText: String {
        if support == .unsupported { return "서버가 지원하지 않음" }
        if support == .unknown { return "서버 연결 전" }
        if !platformReady { return "서버에 아이메시지가 연결돼 있지 않음" }
        return paired ? "연결됨" : "연결 안 됨"
    }
    func reset() {
        support = .unknown; platformReady = false; paired = false; enabled = false
        room = nil; reports = []; code = nil; expires = nil; requests = [:]; problem = ""; onChange?()
    }
    @discardableResult func receive(_ frame: [String: Any]) -> Bool {
        switch frame["type"] as? String {
        case "imessage_status":
            support = .supported; platformReady = frame["platform_ready"] as? Bool == true
            paired = frame["paired"] as? Bool == true; enabled = frame["enabled"] as? Bool == true
            room = frame["room"] as? String; reports = frame["reports"] as? [String] ?? []
            let kind = (frame["ref"] as? String).flatMap { requests.removeValue(forKey: $0) }
            if paired || kind == "imessage_unpair" { code = nil; expires = nil }
            problem = ""
        case "imessage_code":
            guard let ref = frame["ref"] as? String, requests.removeValue(forKey: ref) == "imessage_pair",
                  let value = frame["code"] as? String, let ttl = frame["expires_in"] as? Int else { return false }
            code = value; expires = clock().addingTimeInterval(TimeInterval(ttl)); problem = ""
        case "error":
            guard let ref = frame["ref"] as? String, let kind = requests.removeValue(forKey: ref) else { return false }
            if frame["code"] as? String == "unexpected_frame", kind == "imessage" { support = .unsupported; code = nil; expires = nil }
            else { problem = "아이메시지 설정을 바꾸지 못했어요. 연결 상태를 확인해 주세요." }
        default: return false
        }
        onChange?(); return true
    }
    private func request(_ kind: String, fields: [String: Any] = [:]) async {
        let id = UUID().uuidString.lowercased(); requests[id] = kind
        do { try await send(fields.merging(["v": 1, "type": kind, "id": id]) { _, new in new }) }
        catch { requests.removeValue(forKey: id); problem = "서버에 연결된 뒤 다시 해 주세요."; onChange?() }
    }
    func query() async { await request("imessage") }
    func requestCode() async { await request("imessage_pair") }
    func unpair() async { await request("imessage_unpair") }
    func save(enabled: Bool, room: String?, reports: [String]) async {
        await request("imessage_save", fields: ["enabled": enabled, "room": room as Any? ?? NSNull(), "reports": reports])
    }
    func toggleRoom(_ id: String) async { await save(enabled: enabled, room: room == id ? nil : id, reports: reports) }
    func toggleReport(_ id: String) async {
        await save(enabled: enabled, room: room, reports: reports.contains(id) ? reports.filter { $0 != id } : reports + [id])
    }
}
