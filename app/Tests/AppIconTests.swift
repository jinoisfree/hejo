import AppKit

func appIconTests() throws {
    guard let large = AppIcon.render(pixels: 1024) else { throw TestFailure.assertion("AT-HF-66 1024 icon") }
    for (x, y) in [(0, 0), (1023, 0), (0, 1023), (1023, 1023), (100, 100)] {
        try check((large.colorAt(x: x, y: y)?.alphaComponent ?? 1) == 0, "AT-HF-66 rounded transparent corner")
    }
    var blue = false, dark = false
    for y in 410...610 {
        for x in 0..<1024 {
            guard let pixel = large.colorAt(x: x, y: y), pixel.alphaComponent > 0.5 else { continue }
            let red = pixel.redComponent, green = pixel.greenComponent, b = pixel.blueComponent
            let isBlue = b > red + 0.18 && b > green + 0.03
            let isDark = max(red, green, b) < 0.3
            if x < 512 && isBlue { blue = true }
            if x > 512 && isDark { dark = true }
            if x < 102 || x > 921 { try check(!isBlue && !isDark, "AT-HF-66 text margin") }
        }
    }
    try check(blue && dark, "AT-HF-66 blue H and dark EJO.")
    guard let small = AppIcon.render(pixels: 16) else { throw TestFailure.assertion("AT-HF-66 16 icon") }
    for y in 0..<16 {
        for x in 0..<16 {
            guard let p = small.colorAt(x: x, y: y), p.alphaComponent > 0.5 else { continue }
            if p.blueComponent > p.redComponent + 0.18 || max(p.redComponent, p.greenComponent, p.blueComponent) < 0.3 {
                try check(x >= 1 && x <= 14, "AT-HF-66 small text is not clipped")
            }
        }
    }
    print("AT-HF-66 PASS")
}
