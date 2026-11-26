import AppKit
import os

enum StaleCopies {
    static func schedule() {
        let bundle = Bundle.main
        let folders = LoginLaunch.applicationFolders
        guard LoginLaunch.isInstalled(bundle: bundle.bundleURL, folders: folders),
              let identifier = bundle.bundleIdentifier, !identifier.isEmpty,
              let version = bundle.infoDictionary?["CFBundleVersion"] as? String,
              let build = Int(version) else { return }

        func runningBundles() -> [URL] {
            NSWorkspace.shared.runningApplications.compactMap(\.bundleURL)
        }
        let atLaunch = runningBundles()
        let logger = Logger(subsystem: identifier, category: "stale-copies")
        DispatchQueue.global(qos: .utility).async {
            clean(bundle: bundle.bundleURL, identifier: identifier, build: build, folders: folders,
                  running: { atLaunch + runningBundles() }, trash: { url in
                var destination: NSURL?
                try FileManager.default.trashItem(at: url, resultingItemURL: &destination)
                guard let destination else { throw CocoaError(.fileNoSuchFile) }
                return destination as URL
            }, log: { logger.notice("\($0, privacy: .public)") })
        }
    }

    static func clean(bundle: URL, identifier: String, build: Int, folders: [URL],
                      running: () -> [URL], trash: (URL) throws -> URL, log: (String) -> Void) {
        guard LoginLaunch.isInstalled(bundle: bundle, folders: folders) else { return }
        let ownPath = bundle.resolvingSymlinksInPath().path
        let keys: Set<URLResourceKey> = [.isDirectoryKey, .isSymbolicLinkKey]
        for folder in folders {
            guard let entries = try? FileManager.default.contentsOfDirectory(
                at: folder, includingPropertiesForKeys: Array(keys)
            ) else { continue }
            for entry in entries where entry.pathExtension == "app" {
                let path = entry.resolvingSymlinksInPath().path
                guard path != ownPath, let properties = try? entry.resourceValues(forKeys: keys),
                      properties.isDirectory == true, properties.isSymbolicLink == false,
                      let data = try? Data(contentsOf: entry.appendingPathComponent("Contents/Info.plist")),
                      let info = (try? PropertyListSerialization.propertyList(from: data, format: nil)) as? [String: Any],
                      info["CFBundleIdentifier"] as? String == identifier,
                      let version = info["CFBundleVersion"] as? String, let older = Int(version), older < build,
                      !running().contains(where: { $0.resolvingSymlinksInPath().path == path }) else { continue }
                let source = "path=\(entry.path) build=\(older)"
                do {
                    let destination = try trash(entry)
                    log("\(source) trash=\(destination.path)")
                } catch {
                    let failure = error as NSError
                    log("\(source) error=\(failure.domain)/\(failure.code)")
                }
            }
        }
    }
}
