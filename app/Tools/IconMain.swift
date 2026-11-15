import AppKit

@main enum IconMain {
    static func main() throws {
        let folder = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
        try FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let retina = "\u{40}2x"
        for (name, pixels) in [
            ("icon_16x16.png", 16), ("icon_16x16" + retina + ".png", 32),
            ("icon_32x32.png", 32), ("icon_32x32" + retina + ".png", 64),
            ("icon_128x128.png", 128), ("icon_128x128" + retina + ".png", 256),
            ("icon_256x256.png", 256), ("icon_256x256" + retina + ".png", 512),
            ("icon_512x512.png", 512), ("icon_512x512" + retina + ".png", 1024)
        ] {
            guard let image = AppIcon.render(pixels: pixels),
                  let data = image.representation(using: .png, properties: [:]) else {
                throw NSError(domain: "AppIcon", code: pixels)
            }
            try data.write(to: folder.appendingPathComponent(name), options: .atomic)
        }
    }
}
