import AppKit

@MainActor private func widthPost(
    _ text: NSAttributedString, mine: Bool = false, id: String = UUID().uuidString,
    streaming: Bool = false, foldTitle: String? = nil
) -> NativeThreadCard.Post {
    .init(id: id, mine: mine, text: text, speaker: mine ? "사장" : "직원", time: "",
          avatar: ProfileAvatar(), nameColor: .labelColor, streaming: streaming,
          foldTitle: foldTitle, openLink: { _ in })
}

@MainActor private func widthContent(
    _ posts: [NativeThreadCard.Post], id: String = UUID().uuidString, inset: CGFloat = 18
) -> NativeThreadCard.Content {
    .init(id: id, top: posts.map(NativeThreadCard.Piece.post), replies: nil, rail: nil, actions: [],
          deleting: nil, style: .init(inset: inset, fill: 0, stroke: nil, lineWidth: 0),
          bell: nil, onBell: {}, clickCard: {},
          quiet: .secondaryLabelColor, expanded: false)
}

private func widthText(_ body: String, size: CGFloat = 14) -> NSAttributedString {
    NSAttributedString(string: body, attributes: [.font: NSFont.systemFont(ofSize: size)])
}

private func richWidthText(_ body: String) -> NSAttributedString {
    let stripped = TextLayout.strip(body)
    let text = NSMutableAttributedString(attributedString: MessageFormat.renderNative(stripped.source, bodySize: 14))
    TextLayout.apply(to: text, lines: stripped.lines, bar: nil, lineSpacing: 2)
    return NSAttributedString(attributedString: text)
}

private func referenceTextSize(_ text: NSAttributedString, width: CGFloat) -> NSSize {
    let storage = NSTextStorage(attributedString: text)
    let manager = NSLayoutManager()
    let container = NSTextContainer(containerSize: .init(width: width, height: .greatestFiniteMagnitude))
    container.lineFragmentPadding = 0
    manager.addTextContainer(container)
    storage.addLayoutManager(manager)
    manager.ensureLayout(for: container)
    return manager.usedRect(for: container).size
}

private func referenceBubbleWidth(_ column: CGFloat) -> CGFloat {
    min(column, max(240, column * 0.75))
}

private func widthNear(_ actual: CGFloat, _ expected: CGFloat, _ label: String) throws {
    try check(abs(actual - expected) <= 1, "\(label): actual \(actual), expected \(expected)")
}

@MainActor func bubbleWidthTests() throws {
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let priorStore = ChatAppearance.store
    let store = try LocalStore(directory: root)
    ChatAppearance.bind(store)
    defer { ChatAppearance.bind(priorStore) }

    var failures: [String] = []
    func observe(_ name: String, _ body: () throws -> Void) {
        do {
            try body()
            print("\(name) PASS")
        } catch {
            failures.append(name)
            print("\(name) FAIL \(error)")
        }
    }

    let long = widthText(String(repeating: "여러 문장이 이어지는 긴 글입니다. ", count: 15))
    let longPosts = [widthPost(long, mine: true), widthPost(long)]
    func pair(_ width: CGFloat) -> [NativeThreadCard.Placed] {
        NativeThreadCard.layout(widthContent(longPosts), width: width).placed
    }
    let wide = pair(900)
    observe("AT-BW-01") {
        try widthNear(wide[0].bubble.maxX, 839, "owner edge")
        try widthNear(wide[1].bubble.minX, 61, "employee edge")
        try widthNear(wide[0].bubble.minX - 18, 882 - wide[1].bubble.maxX, "matching opposite margins")
        for item in wide { try widthNear(item.bubble.width, 615.75, "long post width") }
        try widthNear(wide[0].bubble.minX - 18, 205.25, "opposite margin")
    }
    observe("AT-BW-02") {
        for item in pair(600) { try widthNear(item.bubble.width, 390.75, "resized post width") }
    }
    for (width, expected): (CGFloat, CGFloat) in [(360, 240), (250, 171)] {
        observe("AT-BW-03 W=\(Int(width))") {
            for item in pair(width) { try widthNear(item.bubble.width, expected, "narrow post width") }
        }
    }

    let lines = ["첫 줄", "가장 길게 쓴 두 번째 줄", "세 번째 줄", "끝"]
    let lineWidth = lines.map { referenceTextSize(widthText($0), width: 2000).width }.max()!
    let multiline = widthText(lines.joined(separator: "\n"))
    for mine in [true, false] {
        let role = mine ? "owner" : "employee"
        observe("AT-BW-04a \(role)") {
            let item = NativeThreadCard.layout(widthContent([widthPost(multiline, mine: mine)]), width: 900).placed[0]
            try widthNear(item.text.height, ceil(referenceTextSize(multiline, width: 591.75).height), "unwrapped height")
            try widthNear(mine ? item.bubble.maxX : item.bubble.minX, mine ? 839 : 61, "aligned edge")
            try widthNear(item.bubble.width, ceil(lineWidth) + 24, "longest explicit line")
            try check(item.bubble.width < 615.75, "multiline bubble uses less than the maximum")
        }
        observe("AT-BW-04b \(role)") {
            let single = widthText(lines[1])
            let item = NativeThreadCard.layout(widthContent([widthPost(single, mine: mine)]), width: 900).placed[0]
            try widthNear(item.bubble.width, ceil(lineWidth) + 24, "single line")
        }
    }

    let centered = NSMutableAttributedString(attributedString: widthText("가운데\n왼쪽"))
    let paragraph = NSMutableParagraphStyle()
    paragraph.alignment = .center
    centered.addAttribute(.paragraphStyle, value: paragraph, range: NSRange(location: 0, length: 4))
    let foldTitle = "더 보기"
    let foldTextWidth = (foldTitle as NSString).size(withAttributes: [.font: NSFont.systemFont(ofSize: 11)]).width
    let mixed = widthText("첫 줄\n둘째 줄\n" + long.string)
    let cases: [(String, NativeThreadCard.Post)] = [
        ("a", widthPost(mixed)),
        ("b", widthPost(richWidthText(richBody))),
        ("c", widthPost(richWidthText("첫 줄\n둘째 줄\n```\nx\n```"))),
        ("d", widthPost(long, foldTitle: foldTitle)),
        ("e", widthPost(widthText(Array(repeating: "가", count: 40).joined(separator: "\n")), foldTitle: foldTitle)),
        ("f", widthPost(centered))
    ]
    for width: CGFloat in [900, 600] {
        let maximum = referenceBubbleWidth(width - 79)
        for (name, post) in cases {
            let layout = NativeThreadCard.layout(widthContent([post]), width: width)
            let item = layout.placed[0]
            if name == "b" {
                observe("AT-BW-05b TextKit W=\(Int(width))") { try assertRichBody(layout) }
            }
            if post.foldTitle != nil {
                observe("AT-BW-05\(name) fold W=\(Int(width))") {
                    try check(!item.fold.isEmpty && item.bubble.contains(item.fold) && item.fold.width >= foldTextWidth,
                              "fold title fits inside bubble")
                }
            }
            observe("AT-BW-05\(name) W=\(Int(width))") {
                if name == "e" {
                    let minimum = foldTextWidth + 24
                    try check((minimum...(minimum + 3)).contains(item.bubble.width) && item.bubble.width < maximum
                              && item.bubble.width > referenceTextSize(widthText("가"), width: 2000).width + 24,
                              "fold controls bubble width: actual \(item.bubble.width), expected \(minimum)...\(minimum + 3)")
                } else {
                    try widthNear(item.bubble.width, maximum, "full-width post")
                }
            }
        }
    }

    func stream(_ text: NSAttributedString, id: String, width: CGFloat = 900, active: Bool = true) -> CGFloat {
        let post = widthPost(text, id: id, streaming: active)
        return NativeThreadCard.layout(widthContent([post], id: "bubble-stream"), width: width).placed[0].bubble.width
    }
    let broad = widthText(String(repeating: "넓은 줄 ", count: 9).trimmingCharacters(in: .whitespaces))
    let short = widthText("짧은 글")
    let shortWidth = ceil(referenceTextSize(short, width: 2000).width) + 24
    let initial = stream(broad, id: "stream-complete")
    observe("AT-BW-06 ②") {
        let next = stream(short, id: "stream-complete")
        try check(next >= initial, "stream width decreased from \(initial) to \(next)")
    }
    observe("AT-BW-06 ③") {
        let final = stream(short, id: "stream-complete", active: false)
        try widthNear(final, shortWidth, "final width")
        try check(final < initial, "final post drops streamed width")
    }
    observe("AT-BW-06 ④") {
        _ = stream(broad, id: "stream-resize")
        try widthNear(stream(short, id: "stream-resize", width: 600), shortWidth, "stream width after resize")
    }
    observe("AT-BW-06 ⑤") {
        try ChatAppearance.change(fontSize: 18)
        defer { try? ChatAppearance.change(fontSize: 14) }
        let large = stream(widthText(broad.string, size: 18), id: "stream-font")
        try ChatAppearance.change(fontSize: 12)
        let smallText = widthText(broad.string, size: 12)
        let small = stream(smallText, id: "stream-font")
        try widthNear(small, ceil(referenceTextSize(smallText, width: 2000).width) + 24, "stream width after font change")
        try check(small < large, "smaller font drops streamed width")
    }

    let list = NativeThreadList(frame: NSRect(x: 0, y: 0, width: 700, height: 700))
    let window = NSWindow(contentRect: list.frame, styleMask: [], backing: .buffered, defer: false)
    window.contentView = list
    window.orderFrontRegardless()
    defer { window.orderOut(nil) }
    list.automaticallyTicks = false
    list.reduceMotion = { true }
    list.show(longPosts.map { widthContent([$0], inset: 12) }, identity: "width-list")

    var observed: [CGFloat] = []
    for width: CGFloat in [700, 1000, 520] {
        observe("AT-BW-10 W=\(Int(width))") {
            window.setContentSize(.init(width: width, height: 700))
            list.frame.size.width = width
            list.layoutSubtreeIfNeeded()
            let table = try homeRequire(list.documentView as? NSTableView, "list table")
            let cardWidth = list.contentSize.width - 24
            let expected = referenceBubbleWidth(cardWidth - 24 - 43)
            var frames: [NSRect] = []
            for row in 0..<2 {
                let card = try homeRequire(table.view(atColumn: 0, row: row, makeIfNecessary: false) as? NativeThreadCard,
                                           "visible card in row \(row)")
                try check(card.visibleRect.height > 0, "card is on screen")
                let body = try homeRequire(homeDescendants(card, NSTextView.self).first, "card text view")
                try check(body.attributedString().string == long.string, "same post after resize")
                frames.append(body.frame.offsetBy(dx: -12, dy: 0))
            }
            observed.append(frames[0].width + 24)
            try widthNear(frames[0].maxX, cardWidth - 12 - 43 - 12, "owner text edge")
            try widthNear(frames[1].minX, 12 + 43 + 12, "employee text edge")
            print("AT-BW-10 observed widths \(frames.map { $0.width + 24 }) expected \(expected)")
            for frame in frames { try widthNear(frame.width + 24, expected, "visible bubble width") }
        }
    }
    observe("AT-BW-10 distinct widths") {
        try check(observed.count == 3 && Set(observed).count == 3, "observed widths \(observed)")
    }

    try check(failures.isEmpty, "failed bubble width cases: \(failures.joined(separator: ", "))")
}

@MainActor func captureBubbleWidths(to output: URL) throws {
    let samples = [
        """
        2026년 송년회 안내

        • 일자: 2026년 12월 16일(수)
        • 시간: 15:00
        • 장소: 회사 2층 사무실

        일정 등록
        """,
        """
        송년회 일정 등록했습니다
        12/16(수) 15:00~16:00, 회사 캘린더에 1건 들어갔습니다.
        같은 날 다른 일정은 없어서 겹치는 일정도 없습니다.
        따로 하실 일은 없습니다.
        """,
        "그날 참석 인원이 스무 명쯤 될 것 같은데 근처에 단체로 저녁 먹을 만한 곳을 몇 군데 찾아서 가격대랑 예약 가능 여부까지 같이 정리해 줄 수 있을까? 주차가 되는 곳이면 더 좋겠고 너무 시끄럽지 않은 곳으로 부탁해.",
        "네, 스무 명이 한 번에 앉을 수 있고 주차가 되는 조용한 곳을 기준으로 찾아보겠습니다. 가격대와 예약 가능 시간, 단체석 유무를 표로 정리해서 오늘 안에 드리겠습니다. 후보는 세 군데 정도로 추리고 각 장소의 장단점을 한 줄씩 붙이겠습니다."
    ]
    let posts = samples.enumerated().map { index, sample in
        let mine = index.isMultiple(of: 2)
        let text = NSAttributedString(string: sample, attributes: [.font: NSFont.systemFont(ofSize: 14),
                                                                  .foregroundColor: NSColor.white])
        var post = widthPost(text, mine: mine)
        post.nameColor = .white
        post.time = "오후 3:0\(index + 2)"
        return post
    }
    var content = widthContent(posts, inset: 12)
    content.style.background = NSColor(white: 0.11, alpha: 1)
    let layout = NativeThreadCard.layout(content, width: 687)
    let card = NativeThreadCard(frame: NSRect(x: 0, y: 0, width: layout.width + 24, height: layout.height))
    card.appearance = NSAppearance(named: .darkAqua)
    card.configure(layout)
    card.layoutSubtreeIfNeeded()
    let image = try homeRequire(card.bitmapImageRepForCachingDisplay(in: card.bounds), "AT-BW-09 bitmap")
    card.cacheDisplay(in: card.bounds, to: image)
    let data = try homeRequire(image.representation(using: .png, properties: [:]), "AT-BW-09 PNG")
    try data.write(to: output)
    print("AT-BW-09 captured bubble widths \(layout.placed.map { $0.bubble.width })")
}
