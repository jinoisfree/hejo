#if HEJO_HISTORY_BASELINE
import AppKit

@MainActor final class HistorySemantics {
    let controller: ConversationController
    var snapshots = [[String: Any]]()
    init(_ controller: ConversationController) { self.controller = controller }
    func snapshot(_ label: String) {
        let m = controller.model
        let roomIDs = m.rooms.map(\.id)
        let threads = roomIDs.flatMap { m.threads(employee: $0) }
        let threadValues: [[String: Any]] = threads.map { thread in
            let key = thread.key, a = m.assessment(key), lines = m.timeline(key)
            return ["room": key.employee, "thread": key.thread, "title": thread.title,
                "preview": thread.preview, "latestSeq": thread.latestSeq,
                "messages": lines.map(\.id), "unread": m.unread(key),
                "working": a.working, "settled": a.settled, "approved": a.approved,
                "pending": a.pending?.id ?? "", "bell": m.bell(key).map { $0 as Any } ?? NSNull(),
                "read": m.memberState.read("thread:" + key.employee + "/" + key.thread),
                "copy": ThreadTools.copy(lines, key: key, name: m.name, group: m.groups[key.employee] != nil, zone: TimeZone(secondsFromGMT: 0)!),
                "linkRoundTrip": ThreadTools.destination(ThreadTools.link(key)) == key]
        }
        let messages: [[String: Any]] = m.messages.values.sorted { $0.seq < $1.seq }.map { line in
            ["id": line.id, "seq": line.seq, "text": line.text, "role": line.role,
             "room": line.key.employee, "thread": line.key.thread, "replyState": line.replyState ?? "",
             "streaming": line.streaming, "confirmed": m.confirmed(line.id),
             "check": m.check(line.id, line: 0, original: false), "files": line.files.map(\.name)]
        }
        let notices = (roomIDs + [HomeRoom.id]).map { room -> [String: Any] in
            ["room": room, "groups": m.notices(room).map { ["id": $0.id, "questions": $0.questions, "messages": $0.messages] as [String: Any] }]
        }
        let searches = ["한글", "ALPHA", "  Alpha  ", "fixture.txt", "없는 글"].map { query -> [String: Any] in
            ["query": query, "threads": roomIDs.flatMap { m.threads(employee: $0, query: query).map(\.id) },
             "sidebar": WorkspaceSearch.sidebar(query, messages: Array(m.messages.values), names: Dictionary(uniqueKeysWithValues: m.employees.map { ($0.id, $0.name) }), hidden: m.hidden).map(\.id),
             "groups": WorkspaceSearch.groups(query, messages: Array(m.messages.values), names: Dictionary(uniqueKeysWithValues: m.employees.map { ($0.id, $0.name) }), hidden: m.hidden).map { ["thread": $0.key.thread, "matches": $0.matches.map(\.id), "root": $0.root.id] as [String: Any] }]
        }
        snapshots.append(["label": label, "applied": m.applied, "memberFetched": m.memberState.hasFetched,
            "messages": messages, "threads": threadValues, "roomOrder": roomIDs,
            "sidebarOrder": m.sidebar.items.map(\.id), "homeOrder": m.homeThreads.map(\.id),
            "muted": m.muted.sorted(), "notices": notices, "searches": searches,
            "roomRead": Dictionary(uniqueKeysWithValues: roomIDs.map { ($0, m.memberState.read("read:" + $0)) })])
    }
    func finish(view: ConversationView) async throws -> [[String: Any]] {
        let m = controller.model
        snapshot("before-member-fetch")
        var remote = StateDocument(rev: 1, items: ["read:beta": StateEntry(v: "4", at: 1767225600, dev: "fixture-device")])
        m.memberState.fetch = { _ in remote }
        m.memberState.push = { changes in
            remote = StateDocument(rev: remote.rev + 1, items: MemberState.merge(remote.items, changes)); return remote
        }
        await m.memberState.sync(); snapshot("after-member-fetch")
        m.toggleMute("beta"); snapshot("mute")
        if let thread = m.threads(employee: "alpha").first { m.toggleBell(thread.key); snapshot("bell-off") }
        if let message = m.messages.values.sorted(by: { $0.seq < $1.seq }).first { m.confirm(message); snapshot("confirmed") }
        if let message = m.messages.values.first(where: { $0.text == "- [ ] 확인 항목" }) {
            m.toggleCheck(message.id, line: 0, original: false); snapshot("checked")
        }
        view.chooseEmployee("beta"); snapshot("enter-beta")
        m.selectHome(); snapshot("home")
        if let key = m.homeThreads.first?.key, let destination = ThreadTools.destination(ThreadTools.link(key)) {
            view.openFromBubble(destination)
            guard m.selected == destination else { throw GateFailure.protocolError }
            snapshot("link-opened")
        } else { throw GateFailure.protocolError }
        await withCheckedContinuation { (done: CheckedContinuation<Void, Never>) in
            DispatchQueue.main.async {
                view.editor.editor.insertText("격리 입력", replacementRange: NSRange(location: 0, length: (view.editor.editor.string as NSString).length))
                done.resume()
            }
        }
        guard view.editor.editor.string == "격리 입력" else { throw GateFailure.protocolError }
        snapshot("appkit-input")
        controller.clock = { Date(timeIntervalSince1970: 1767312000) }; snapshot("24-hour-boundary")
        return snapshots
    }
}
#endif
