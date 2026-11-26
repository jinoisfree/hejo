import Foundation

/// The gate owns all settings. This model keeps only the current connection's presentation.
@MainActor final class DiscordState {
    enum Support { case unknown, supported, unsupported }
    private(set) var support = Support.unknown
    private(set) var platformReady = false
    private(set) var paired = false
    private(set) var enabled = false
    private(set) var channelProblem = false
    private(set) var coreOpen = false
    private(set) var code: String?
    private var expires: Date?
    private var requests: [String: String] = [:]
    private var layoutRequests = Set<String>()
    private var lastLayout: SidebarLayout.DiscordLayout?
    private var layoutRejected = false
    private var layoutTask: Task<Void, Never>?
    var layoutSource: (() -> SidebarLayout.DiscordLayout?)?
    private(set) var problem = ""
    var clock: () -> Date = Date.init
    var onChange: (() -> Void)?
    private let send: ([String: Any]) async throws -> Void

    init(send: @escaping ([String: Any]) async throws -> Void) { self.send = send }
    var remaining: Int { max(0, Int(ceil((expires ?? .distantPast).timeIntervalSince(clock())))) }
    var statusText: String {
        if support == .unsupported { return "서버가 지원하지 않음" }
        if support == .unknown { return "서버 연결 전" }
        if !platformReady { return "서버에 디스코드가 연결돼 있지 않음" }
        if coreOpen { return "Hermes 디스코드 허용이 열려 있음" }
        if channelProblem { return "채널 권한 문제" }
        return paired ? "연결됨" : "연결 안 됨"
    }
    func reset() {
        layoutTask?.cancel(); layoutTask = nil
        layoutRequests.removeAll(); lastLayout = nil; layoutRejected = false
        support = .unknown; platformReady = false; paired = false; enabled = false
        coreOpen = false; channelProblem = false; code = nil; expires = nil; requests = [:]; problem = ""; onChange?()
    }
    @discardableResult func receive(_ frame: [String: Any]) -> Bool {
        switch frame["type"] as? String {
        case "discord_status":
            support = .supported; platformReady = frame["platform_ready"] as? Bool == true
            paired = frame["paired"] as? Bool == true; enabled = frame["enabled"] as? Bool == true
            channelProblem = frame["channel_problem"] as? Bool == true
            coreOpen = frame["core_open"] as? Bool == true
            let ref = frame["ref"] as? String
            let layoutReply = ref.flatMap { layoutRequests.remove($0) } != nil
            let kind = ref.flatMap { requests.removeValue(forKey: $0) }
            if paired || kind == "discord_unpair" { code = nil; expires = nil }
            if !layoutReply { problem = "" }
            layoutChanged()
        case "discord_code":
            guard let ref = frame["ref"] as? String, requests.removeValue(forKey: ref) == "discord_pair",
                  let value = frame["code"] as? String, let ttl = frame["expires_in"] as? Int else { return false }
            code = value; expires = clock().addingTimeInterval(TimeInterval(ttl)); problem = ""
        case "error":
            if receiveLayoutError(frame) { return true }
            guard let ref = frame["ref"] as? String, let kind = requests.removeValue(forKey: ref) else { return false }
            if frame["code"] as? String == "unexpected_frame", kind == "discord" { support = .unsupported; code = nil; expires = nil }
            else { problem = "디스코드 설정을 바꾸지 못했어요. 연결 상태를 확인해 주세요." }
        default: return false
        }
        onChange?(); return true
    }
    func receiveLayoutError(_ frame: [String: Any]) -> Bool {
        guard let ref = frame["ref"] as? String, layoutRequests.remove(ref) != nil else { return false }
        layoutRejected = true
        layoutRequests.removeAll()
        return true
    }

    func layoutChanged() {
        guard support == .supported, !layoutRejected, layoutTask == nil, layoutSource != nil else { return }
        layoutTask = Task { [weak self] in
            do { try await Task.sleep(nanoseconds: 100_000_000) }
            catch { return }
            guard let self else { return }
            self.layoutTask = nil
            guard self.support == .supported, !self.layoutRejected,
                  let layout = self.layoutSource?(), layout != self.lastLayout else { return }
            let id = UUID().uuidString.lowercased()
            self.lastLayout = layout
            self.layoutRequests.insert(id)
            let frame = layout.fields.merging(["v": 1, "type": "discord_layout", "id": id]) { _, new in new }
            do { try await self.send(frame) }
            catch {
                // Reset clears pending requests from the previous connection.
                if self.layoutRequests.remove(id) != nil && self.lastLayout == layout { self.lastLayout = nil }
            }
        }
    }

    private func request(_ kind: String, fields: [String: Any] = [:]) async {
        let id = UUID().uuidString.lowercased(); requests[id] = kind
        do { try await send(fields.merging(["v": 1, "type": kind, "id": id]) { _, new in new }) }
        catch { requests.removeValue(forKey: id); problem = "서버에 연결된 뒤 다시 해 주세요."; onChange?() }
    }
    func query() async { await request("discord") }
    func requestCode() async { await request("discord_pair") }
    func unpair() async { await request("discord_unpair") }
    func save(enabled: Bool) async {
        await request("discord_save", fields: ["enabled": enabled])
    }
}
