import AppKit

struct ConversationDraft {
    var text = ""
    var attachments: [URL] = []
}
@MainActor final class ConversationController {
    let client: GateClient
    let model: ConversationModel
    let files: GateHTTP
    private(set) var drafts: [ConversationKey: ConversationDraft] = [:]
    private var reconnectPending = Set<String>()
    private var pending: [String: (key: ConversationKey, draft: ConversationDraft)] = [:]
    var notice = "" { didSet { onChange?() } }
    var onChange: (() -> Void)?
    var onOpenFile: (URL) -> Void = { NSWorkspace.shared.open($0) }
    private var replicaAddress: String
    private var timer: Timer?
    init(client: GateClient) throws {
        self.client = client; replicaAddress = client.store.settings.address; model = try ConversationModel(store: client.store); files = GateHTTP(client: client)
        model.onChange = { [weak self] in self?.onChange?() }
        client.onFrame = { [weak self] frame in self?.receive(frame) }
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor in self?.model.expireTyping() }
        }
    }
    deinit { timer?.invalidate() }
    func receive(_ frame: [String: Any]) {
        if frame["type"] as? String == "welcome" { reconnectPending = Set(pending.keys) }
        if frame["type"] as? String == "sync_done", frame["more"] as? Bool == false {
            let unconfirmed = reconnectPending.intersection(pending.keys)
            for id in unconfirmed { pending[id] = nil }
            reconnectPending = []
            if !unconfirmed.isEmpty { notice = "전송 확인이 없어요. 내용을 확인하고 다시 보내 주세요." }
        }
        if frame["type"] as? String == "welcome", replicaAddress != client.store.settings.address {
            model.resetReplica(); drafts = [:]; pending = [:]; replicaAddress = client.store.settings.address
        }
        do { try model.apply(frame) } catch { notice = "대화 기록을 읽지 못했어요. 다시 연결해 주세요." }
        if let id = frame["client_msg_id"] as? String, let entry = pending.removeValue(forKey: id) {
            if drafts[entry.key]?.text == entry.draft.text && drafts[entry.key]?.attachments == entry.draft.attachments { drafts[entry.key] = ConversationDraft() }
        }
        if frame["type"] as? String == "error" {
            if let ref = frame["ref"] as? String { pending[ref] = nil }
            switch frame["code"] as? String {
            case "unknown_file": notice = "첨부를 찾지 못했어요. 파일을 다시 첨부해 주세요."
            case "too_large": notice = "너무 큼 · 글이나 첨부 크기를 줄여 주세요."
            case "button_expired": notice = "만료된 버튼이에요. 새 답장을 확인해 주세요."
            default: notice = "요청을 처리하지 못했어요. 다시 시도해 주세요."
            }
        }
        onChange?()
    }
    var draft: ConversationDraft { model.selected.flatMap { drafts[$0] } ?? ConversationDraft() }
    var canSend: Bool { client.isConnected && client.replayComplete }
    var sending: Bool { guard let key = model.selected else { return false }; return pending.values.contains { $0.key == key } }
    func setText(_ text: String, for destination: ConversationKey? = nil) { if let key = destination ?? model.selected { drafts[key, default: ConversationDraft()].text = text } }
    func addAttachments(_ urls: [URL]) {
        guard let key = model.selected else { return }
        let existing = drafts[key]?.attachments ?? []
        let result = ClipboardAttachments.validate(urls.filter { !existing.contains($0) }, available: max(0,10-existing.count))
        drafts[key, default: ConversationDraft()].attachments += result.files
        if let message = result.notice { notice = message }; onChange?()
    }
    func removeAttachment(_ url: URL) { if let key = model.selected { drafts[key]?.attachments.removeAll { $0 == url }; onChange?() } }
    func sendCurrent(for destination: ConversationKey? = nil) async {
        guard let key = destination ?? model.selected, !pending.values.contains(where: { $0.key == key }) else { return }
        let draft = drafts[key] ?? ConversationDraft()
        guard !draft.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || !draft.attachments.isEmpty else { return }
        guard canSend else { notice = "연결이 복구된 뒤 보내 주세요."; return }
        guard draft.text.utf8.count <= 65_536 else { notice = "너무 큼 · 글은 64 KiB까지 보낼 수 있어요."; return }
        let id = UUID().uuidString.lowercased(), address = client.store.settings.address, epoch = client.connectionEpoch
        pending[id] = (key, draft); notice = ""
        do {
            var uploaded: [MessageFile] = []
            for url in draft.attachments { uploaded.append(try await files.upload(url, employee: key.employee)) }
            guard address == client.store.settings.address, epoch == client.connectionEpoch, canSend else { throw GateFailure.notConnected }
            try await client.send(["v":1, "type":"send", "id":id, "employee":key.employee, "thread":key.thread,
                                   "text":draft.text, "client_msg_id":id, "files":uploaded.map(\.fileID)])
        } catch {
            pending[id] = nil; transferFailed(error)
        }
        onChange?()
    }
    func click(_ button: MessageButton, message: ConversationMessage) async {
        guard canSend else { notice = "연결이 복구된 뒤 눌러 주세요."; return }
        do { try await client.send(ConversationModel.click(message: message, button: button)) }
        catch { transferFailed(error) }
    }
    func open(_ file: MessageFile, employee: String) async {
        do { let url = try await files.download(file, employee: employee); onOpenFile(url) }
        catch { transferFailed(error) }
    }
    private func transferFailed(_ error: Error) {
        switch error {
        case FileTransferFailure.tooLarge, GateFailure.tooLarge: notice = "너무 큼 · 첨부는 50 MiB까지 보낼 수 있어요."
        case FileTransferFailure.unauthorized: notice = "출입증을 확인하지 못했어요. 다시 연결해 주세요."
        case FileTransferFailure.changed: notice = "파일이 바뀌었어요. 다시 첨부해 주세요."
        case GateFailure.notConnected: notice = "연결이 복구된 뒤 다시 보내 주세요."
        default: notice = "파일을 처리하지 못했어요. 파일과 연결을 확인해 주세요."
        }
    }
}
