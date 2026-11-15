import AppKit

enum ChatMetrics {
    static let avatar: CGFloat = 34
    /// Corner radius of a character picture as a share of its side.
    static let avatarCorner: CGFloat = 0.24
    static let callerAvatar: CGFloat = 24
    static let notificationAvatar: CGFloat = 20
    static let thumbnailPixels = 64
    static let nameFont: CGFloat = 14
    static let auxiliaryFont: CGFloat = 11
    static let bodyFont: CGFloat = 14
    static let avatarNameGap: CGFloat = 8
    static let nameBodyGap: CGFloat = 4
    static let speakerInset: CGFloat = 10
    static let replyInset: CGFloat = 0
    static let horizontalInset: CGFloat = 12
    static let minimumBubbleWidth: CGFloat = 240
    static let bubbleWidthFraction: CGFloat = 0.82
}

struct PaletteRGB: Equatable {
    var r: Double; var g: Double; var b: Double
    static let white = PaletteRGB(r: 1, g: 1, b: 1)
    static let black = PaletteRGB(r: 0, g: 0, b: 0)
    var nsColor: NSColor { NSColor(srgbRed: r, green: g, blue: b, alpha: 1) }
    var hex: String { String(format: "#%02X%02X%02X", Int((r*255).rounded()), Int((g*255).rounded()), Int((b*255).rounded())) }
    var luminance: Double {
        func linear(_ x: Double) -> Double { x <= 0.04045 ? x/12.92 : pow((x+0.055)/1.055, 2.4) }
        return 0.2126*linear(r) + 0.7152*linear(g) + 0.0722*linear(b)
    }
    static func contrast(_ a: PaletteRGB, _ b: PaletteRGB) -> Double {
        (max(a.luminance,b.luminance)+0.05)/(min(a.luminance,b.luminance)+0.05)
    }
    static func hsl(_ hue: Double, _ saturation: Double, _ lightness: Double) -> PaletteRGB {
        let h = (hue.truncatingRemainder(dividingBy: 360)+360).truncatingRemainder(dividingBy: 360)/60
        let c = (1-abs(2*lightness-1))*saturation, x = c*(1-abs(h.truncatingRemainder(dividingBy: 2)-1)), m = lightness-c/2
        let rgb: (Double,Double,Double)
        switch h { case ..<1: rgb=(c,x,0); case ..<2: rgb=(x,c,0); case ..<3: rgb=(0,c,x); case ..<4: rgb=(0,x,c); case ..<5: rgb=(x,0,c); default: rgb=(c,0,x) }
        return PaletteRGB(r:rgb.0+m,g:rgb.1+m,b:rgb.2+m)
    }
}

enum UserBubbleColor: String, CaseIterable {
    case blue, indigo, purple, pink, red, orange, yellow, green, mint, teal, cyan, brown, gray, lightGray
    var title: String {
        switch self {
        case .blue: return "기본"; case .indigo: return "남색"; case .purple: return "보라"
        case .pink: return "분홍"; case .red: return "빨강"; case .orange: return "주황"
        case .yellow: return "노랑"; case .green: return "초록"; case .mint: return "민트"
        case .teal: return "청록"; case .cyan: return "하늘"; case .brown: return "갈색"
        case .gray: return "회색"; case .lightGray: return "밝은 회색"
        }
    }
    private var systemColor: NSColor {
        switch self {
        case .blue: return .systemBlue; case .indigo: return .systemIndigo
        case .purple: return .systemPurple; case .pink: return .systemPink
        case .red: return .systemRed; case .orange: return .systemOrange
        case .yellow: return .systemYellow; case .green: return .systemGreen
        case .mint: return .systemMint; case .teal: return .systemTeal
        case .cyan: return .systemCyan; case .brown: return .systemBrown
        case .gray: return .systemGray
        // A fixed sRGB 82% gray stays visibly distinct from the light conversation surface.
        case .lightGray: return NSColor(srgbRed: 0.82, green: 0.82, blue: 0.82, alpha: 1)
        }
    }
    func resolved(dark: Bool) -> PaletteRGB {
        var rgb = PaletteRGB.black
        NSAppearance(named: dark ? .darkAqua : .aqua)!.performAsCurrentDrawingAppearance {
            let color = systemColor.usingColorSpace(.sRGB)!
            rgb = PaletteRGB(r: Double(color.redComponent), g: Double(color.greenComponent), b: Double(color.blueComponent))
        }
        // Keep systemBlue's hue and saturation; lower HSV brightness only as far
        // as necessary for white text, with a 4.55 margin for 8-bit rounding. Scaling sRGB channels preserves their ratios.
        if self == .blue, PaletteRGB.contrast(rgb, .white) < 4.55 {
            let source = rgb
            var low = 0.0, high = 1.0
            for _ in 0..<64 {
                let scale = (low + high) / 2
                let candidate = PaletteRGB(r: source.r * scale, g: source.g * scale, b: source.b * scale)
                if PaletteRGB.contrast(candidate, .white) >= 4.55 { low = scale } else { high = scale }
            }
            rgb = PaletteRGB(r: source.r * low, g: source.g * low, b: source.b * low)
        }
        return rgb
    }
}

/// Both renderers and the settings preview use these exact resolved colors.
struct UserBubblePalette {
    let background: PaletteRGB
    let foreground: PaletteRGB
    let alpha: Double
    let compositedBackground: PaletteRGB
    var link: PaletteRGB { foreground } // Links also carry an underline.
    var contrast: Double { PaletteRGB.contrast(compositedBackground, foreground) }
    init(color: UserBubbleColor = .blue, dark: Bool, pending: Bool = false) {
        background = color.resolved(dark: dark)
        alpha = pending ? 0.6 : 1
        // Conversation surface reference used by the pending contrast contract.
        let surface = dark ? 0.15 : 0.93
        compositedBackground = PaletteRGB(r: background.r * alpha + surface * (1 - alpha),
            g: background.g * alpha + surface * (1 - alpha), b: background.b * alpha + surface * (1 - alpha))
        if color == .blue && !pending { foreground = .white }
        else {
            foreground = PaletteRGB.contrast(compositedBackground, .black) >= PaletteRGB.contrast(compositedBackground, .white) ? .black : .white
        }
    }
}

/// Shared by native conversation surfaces. Background tint lives below these
/// surfaces, so the opacity slider never fades text, controls or status colours.
enum ThreadAppearance {
    static let inset: CGFloat = 18
    static let radius: CGFloat = 16
    static let statusWidth: CGFloat = 4
    static func surface(dark: Bool) -> NSColor {
        dark ? NSColor(white: 0.15, alpha: 0.55) : NSColor.white.withAlphaComponent(0.38)
    }
    static func replySurface(dark: Bool) -> NSColor {
        (dark ? NSColor.white : NSColor.black).withAlphaComponent(dark ? 0.09 : 0.055)
    }
    /// Reports, lists, quotes, code and long prose keep the full reading width.
    static func isConversational(_ body: String) -> Bool {
        let lines = body.components(separatedBy: "\n")
        return !body.isEmpty && body.count <= 240 && lines.count <= 4 &&
            !lines.contains { line in
                let text = line.trimmingCharacters(in: .whitespaces)
                return ["```", "|", ">", "#", "- ", "* ", "•", "1."].contains { text.hasPrefix($0) }
            }
    }
}

enum LongReply {
    static let lineLimit = 12
    static let characterLimit = 600
    static func needsFolding(_ text: String) -> Bool {
        text.count > characterLimit || text.components(separatedBy: "\n").count > lineLimit
    }
    /// Whole lines whenever possible. A single overlong line is cut at a grapheme boundary.
    /// The UI slices the already-parsed AttributedString at this boundary so emphasis/link spans stay valid.
    static func preview(_ text: String) -> String {
        guard needsFolding(text) else { return text }
        let lines = text.components(separatedBy: "\n")
        var result = ""
        for (index, line) in lines.prefix(lineLimit).enumerated() {
            let candidate = result + (index == 0 ? "" : "\n") + line
            if candidate.count > characterLimit {
                return index == 0 ? String(line.prefix(characterLimit)) : result
            }
            result = candidate
        }
        return result
    }
}
