import AppKit

/// What the composer sends: plain words stay plain (ddots passes the composer size as the base), only real formatting
/// becomes markup, and surrounding whitespace is trimmed before sending.
@MainActor func composerTests() throws {
    let plain = MessageFormat.editor("안녕 /stop", bodySize: ChatMetrics.bodyFont)
    try check(MessageFormat.serialize(plain, baseSize: ChatMetrics.bodyFont) == "안녕 /stop", "plain composer text is sent without markup")
    let bold = NSMutableAttributedString(attributedString: plain)
    bold.addAttribute(.font, value: NSFont.boldSystemFont(ofSize: ChatMetrics.bodyFont), range: NSRange(location: 0, length: 2))
    try check(MessageFormat.serialize(bold, baseSize: ChatMetrics.bodyFont).contains("<b>"), "real formatting still serializes")
    print("COMPOSER_PLAIN_PASS")
}
