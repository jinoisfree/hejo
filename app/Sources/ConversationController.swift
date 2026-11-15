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
    private(set) var transferFailure: IslandFailure? { didSet { onChange?() } }
    private(set) var uploads: [ConversationKey: IslandUpload] = [:] { didSet { onChange?() } }
    var islandInput: IslandModel.Input {
        IslandModel.Input(messages:Array(model.messages.values),typing:model.typing,
            names:Dictionary(uniqueKeysWithValues:model.employees.map { ($0.id,$0.name) }),
            unread:model.visibleUnreadTotal,selected:model.selected,
            status:client.status,failure:transferFailure,uploads:uploads,muted:model.muted)
    }
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
            reconnectPending = []
            if let id=unconfirmed.sorted().first, let entry=pending[id] {
                transferFailure=IslandFailure(message:"전송 확인이 없어요. 내용을 확인하고 다시 보내 주세요.",firstWords:IslandModel.firstLine(entry.draft.text),retryKey:entry.key,isSend:true)
            }
            for id in unconfirmed { pending[id] = nil }
        }
        if frame["type"] as? String == "welcome", replicaAddress != client.store.settings.address {
            model.resetReplica(); drafts = [:]; pending = [:]; transferFailure=nil; uploads=[:]; replicaAddress = client.store.settings.address
        }
        do { try model.apply(frame) } catch { notice = "대화 기록을 읽지 못했어요. 다시 연결해 주세요." }
        if let id = frame["client_msg_id"] as? String, let entry = pending.removeValue(forKey: id) {
            transferFailure=nil
            if drafts[entry.key]?.text == entry.draft.text && drafts[entry.key]?.attachments == entry.draft.attachments { drafts[entry.key] = ConversationDraft() }
        }
        if frame["type"] as? String == "error" {
            let entry=(frame["ref"] as? String).flatMap { pending.removeValue(forKey:$0) }
            let message:String
            switch frame["code"] as? String {
            case "unknown_file": message = "첨부를 찾지 못했어요. 파일을 다시 첨부해 주세요."
            case "too_large": message = "너무 큼 · 글이나 첨부 크기를 줄여 주세요."
            case "button_expired": message = "만료된 버튼이에요. 새 답장을 확인해 주세요."
            default: message = "요청을 처리하지 못했어요. 다시 시도해 주세요."
            }
            let repair=["unknown_file","too_large","button_expired"].contains(frame["code"] as? String ?? "")
            transferFailure=IslandFailure(message:message,firstWords:entry.map { IslandModel.firstLine($0.draft.text) } ?? "",retryKey:repair ? nil : entry?.key,isSend:entry != nil)
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
        guard canSend else { transferFailed(GateFailure.notConnected,for:key); return }
        guard draft.text.utf8.count <= 65_536 else { transferFailure=IslandFailure(message:"너무 큼 · 글은 64 KiB까지 보낼 수 있어요.",firstWords:IslandModel.firstLine(draft.text),isSend:true); return }
        let id = UUID().uuidString.lowercased(), address = client.store.settings.address, epoch = client.connectionEpoch
        pending[id] = (key, draft); notice = ""
        if !draft.attachments.isEmpty { uploads[key]=IslandUpload(completed:0,total:draft.attachments.count) }
        defer { uploads[key]=nil }
        do {
            var uploaded: [MessageFile] = []
            for url in draft.attachments {
                uploaded.append(try await files.upload(url, employee: key.employee))
                uploads[key]=IslandUpload(completed:uploaded.count,total:draft.attachments.count)
            }
            guard address == client.store.settings.address, epoch == client.connectionEpoch, canSend else { throw GateFailure.notConnected }
            try await client.send(["v":1, "type":"send", "id":id, "employee":key.employee, "thread":key.thread,
                                   "text":draft.text.trimmingCharacters(in:.whitespacesAndNewlines), "client_msg_id":id, "files":uploaded.map(\.fileID)])
        } catch {
            pending[id] = nil; transferFailed(error,for:key)
        }
        onChange?()
    }
    func click(_ button: MessageButton, message: ConversationMessage) async {
        guard canSend else { transferFailed(GateFailure.notConnected); return }
        do { try await client.send(ConversationModel.click(message: message, button: button)); transferFailure=nil }
        catch { transferFailed(error) }
    }
    func open(_ file: MessageFile, employee: String) async {
        do { let url = try await files.download(file, employee: employee); onOpenFile(url); transferFailure=nil }
        catch { transferFailed(error) }
    }
    private func transferFailed(_ error: Error, for key: ConversationKey? = nil) {
        let message:String, retryable:Bool
        switch error {
        case FileTransferFailure.tooLarge, GateFailure.tooLarge: message = "너무 큼 · 첨부는 50 MiB까지 보낼 수 있어요."; retryable=false
        case FileTransferFailure.unauthorized: message = "출입증을 확인하지 못했어요. 다시 연결해 주세요."; retryable=false
        case FileTransferFailure.changed: message = "파일이 바뀌었어요. 다시 첨부해 주세요."; retryable=false
        case GateFailure.notConnected: message = "연결이 복구된 뒤 다시 보내 주세요."; retryable=true
        default: message = "파일을 처리하지 못했어요. 파일과 연결을 확인해 주세요."; retryable=true
        }
        transferFailure=IslandFailure(message:message,firstWords:key.map { IslandModel.firstLine(drafts[$0]?.text ?? "") } ?? "",retryKey:retryable ? key : nil,isSend:key != nil)
    }
}
