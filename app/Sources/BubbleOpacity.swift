import Foundation

/// A tint laid over the glass so text stays readable on bright or busy wallpapers.
enum BubbleOpacity {
    static let defaultPercent = 65.0
    /// Below 55% the worst case (white wallpaper behind white text) drops under a 4.5:1 contrast ratio.
    static let range = 55.0...100.0
    static let collapsed = 0.35

    static func clamped(_ value: Double) -> Double {
        value.isFinite ? min(range.upperBound, max(range.lowerBound, value.rounded())) : defaultPercent
    }

    /// Progress 0 is the status bubble, 1 the full conversation, so the tint deepens while the glass grows.
    static func alpha(progress: Double, percent: Double, reduceTransparency: Bool) -> Double {
        if reduceTransparency { return 1 }
        let fraction = min(1, max(0, progress.isFinite ? progress : 0))
        return collapsed + (clamped(percent) / 100 - collapsed) * fraction
    }
}
