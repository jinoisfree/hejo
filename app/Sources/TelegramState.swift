import Foundation

/// The gate owns all settings. This model keeps only the current connection's presentation.
@MainActor final class TelegramState {
    enum Support { case unknown, supported, unsupported }
    private(set) var support = Support.unknown
    private(set) var platformReady = false
    private(set) var paired = false
    private(set) var enabled = false
    private(set) var topicProblem = false
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
        if !platformReady { return "서버에 텔레그램이 연결돼 있지 않음" }
        if topicProblem { return "토픽 권한 문제" }
        return paired ? "연결됨" : "연결 안 됨"
    }
    func reset() {
        support = .unknown; platformReady = false; paired = false; enabled = false
        topicProblem = false; code = nil; expires = nil; requests = [:]; problem = ""; onChange?()
    }
    @discardableResult func receive(_ frame: [String: Any]) -> Bool {
        switch frame["type"] as? String {
        case "telegram_status":
            support = .supported; platformReady = frame["platform_ready"] as? Bool == true
            paired = frame["paired"] as? Bool == true; enabled = frame["enabled"] as? Bool == true
            topicProblem = frame["topic_problem"] as? Bool == true
            let kind = (frame["ref"] as? String).flatMap { requests.removeValue(forKey: $0) }
            if paired || kind == "telegram_unpair" { code = nil; expires = nil }
            problem = ""
        case "telegram_code":
            guard let ref = frame["ref"] as? String, requests.removeValue(forKey: ref) == "telegram_pair",
                  let value = frame["code"] as? String, let ttl = frame["expires_in"] as? Int else { return false }
            code = value; expires = clock().addingTimeInterval(TimeInterval(ttl)); problem = ""
        case "error":
            guard let ref = frame["ref"] as? String, let kind = requests.removeValue(forKey: ref) else { return false }
            if frame["code"] as? String == "unexpected_frame", kind == "telegram" { support = .unsupported; code = nil; expires = nil }
            else { problem = "텔레그램 설정을 바꾸지 못했어요. 연결 상태를 확인해 주세요." }
        default: return false
        }
        onChange?(); return true
    }
    private func request(_ kind: String, fields: [String: Any] = [:]) async {
        let id = UUID().uuidString.lowercased(); requests[id] = kind
        do { try await send(fields.merging(["v": 1, "type": kind, "id": id]) { _, new in new }) }
        catch { requests.removeValue(forKey: id); problem = "서버에 연결된 뒤 다시 해 주세요."; onChange?() }
    }
    func query() async { await request("telegram") }
    func requestCode() async { await request("telegram_pair") }
    func unpair() async { await request("telegram_unpair") }
    func save(enabled: Bool) async {
        await request("telegram_save", fields: ["enabled": enabled])
    }
}
