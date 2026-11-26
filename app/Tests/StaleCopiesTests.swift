import Foundation

func staleCopiesTests() throws {
    let manager = FileManager.default
    let root = manager.temporaryDirectory.resolvingSymlinksInPath().appendingPathComponent(UUID().uuidString)
    defer { try? manager.removeItem(at: root) }
    let folders = ["system", "user"].map { root.appendingPathComponent($0) }
    let trash = root.appendingPathComponent("trash")
    try manager.createDirectory(at: trash, withIntermediateDirectories: true)
    let id = "invalid.example.fixture"

    func bundle(_ folder: URL, _ name: String, _ build: String?, identifier: String) throws -> URL {
        let url = folder.appendingPathComponent(name + ".app")
        let contents = url.appendingPathComponent("Contents")
        try manager.createDirectory(at: contents, withIntermediateDirectories: true)
        if let build {
            let plist = ["CFBundleIdentifier": identifier, "CFBundleVersion": build]
            let data = try PropertyListSerialization.data(fromPropertyList: plist, format: .xml, options: 0)
            try data.write(to: contents.appendingPathComponent("Info.plist"))
        }
        return url
    }

    let own = try folders.map { try bundle($0, "current", "10", identifier: id) }
    let running = try bundle(folders[1], "running", "8", identifier: id)
    let nested = try bundle(folders[0].appendingPathComponent("nested"), "old", "7", identifier: id)
    let outside = try bundle(root, "outside", "10", identifier: id)
    let kept = try [own[0], own[1], running, nested, outside,
                    bundle(folders[1], "future", "11", identifier: id),
                    bundle(folders[0], "other", "1", identifier: "invalid.example.other"),
                    bundle(folders[0], "missing", nil, identifier: id),
                    bundle(folders[0], "invalid", "abc", identifier: id)]
    func canonicalPath(_ url: URL) -> String {
        url.deletingLastPathComponent().resolvingSymlinksInPath().appendingPathComponent(url.lastPathComponent).path
    }
    var attempted = [URL]()
    var lines = [String]()
    var denied: URL?
    func run(_ current: URL) {
        attempted.removeAll()
        lines.removeAll()
        StaleCopies.clean(bundle: current, identifier: id, build: 10, folders: folders,
                          running: { [running] }, trash: { url in
            attempted.append(url)
            if canonicalPath(url) == denied.map(canonicalPath) { throw CocoaError(.fileWriteNoPermission) }
            let result = trash.appendingPathComponent(UUID().uuidString)
            try manager.moveItem(at: url, to: result)
            return result
        }, log: { lines.append($0) })
    }

    run(own[0])
    try check(attempted.isEmpty && lines.isEmpty, "AT-TIDY-05 ineligible copies are silent")
    for (index, current) in own.enumerated() {
        let old = try folders.enumerated().map { number, folder in
            try bundle(folder, "previous-\(index)-\(number)", "9", identifier: id)
        }
        run(outside)
        try check(attempted.isEmpty && lines.isEmpty, "AT-TIDY-06 uninstalled launch")
        run(current)
        try check(Set(attempted.map(canonicalPath)) == Set(old.map(canonicalPath)) && attempted.count == 2,
                  "AT-TIDY-04/04b both application folders")
        try check(lines.count == 2 && attempted.allSatisfy { url in
            !manager.fileExists(atPath: url.path) && lines.contains { $0.contains(url.path) && $0.contains("build=9") && $0.contains(trash.path) }
        }, "AT-TIDY-08b one move record per copy")
        try check(kept.allSatisfy { manager.fileExists(atPath: $0.path) }, "AT-TIDY-05/07 preserve excluded bundles")
    }
    let first = try bundle(folders[0], "denied", "8", identifier: id)
    let second = try bundle(folders[1], "movable", "7", identifier: id)
    denied = first
    run(own[1])
    try check(attempted.map(canonicalPath) == [first, second].map(canonicalPath) && manager.fileExists(atPath: first.path)
              && !manager.fileExists(atPath: second.path), "AT-TIDY-08 continue after failure")
    try check(lines.count == 2 && lines[0].contains(attempted[0].path) && lines[0].contains("build=8")
              && lines[0].contains("error=") && lines[1].contains(trash.path), "AT-TIDY-08b failure record")
}
