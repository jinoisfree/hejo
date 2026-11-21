import Foundation

/// Opt-in timing only. Contact coordinates, device identifiers and conversation data never enter the trace.
enum ThreeTapDiagnostics {
    static let output = traceURL(ProcessInfo.processInfo.environment["HEJO_THREE_TAP_TRACE"])
    static func traceURL(_ path: String?) -> URL? {
        guard let path, !path.isEmpty else { return nil }
        let proposed = URL(fileURLWithPath: path).standardizedFileURL
        // Resolve an existing parent separately: Foundation can leave a symlink unresolved
        // when resolving the whole path of a log file that has not been created yet.
        let parent = proposed.deletingLastPathComponent().resolvingSymlinksInPath()
        var directory: ObjCBool = false
        guard FileManager.default.fileExists(atPath: parent.path, isDirectory: &directory), directory.boolValue,
              parent.pathComponents.contains(".build"),
              (try? FileManager.default.destinationOfSymbolicLink(atPath: proposed.path)) == nil else { return nil }
        return parent.appendingPathComponent(proposed.lastPathComponent)
    }
    static func timestamp() -> Double? { output == nil ? nil : ProcessInfo.processInfo.systemUptime }
    private static var sample: [String: Double]?
    private static let writer = DispatchQueue(label: "hejo.three-tap-diagnostics")
    /// Called on the main thread, after the reader has validated a tap.
    static func begin(frame: Double?, recognized: Double?, main: Double?) {
        guard let frame, let recognized, let main else { return }
        sample = ["frame": frame, "recognized": recognized, "main": main]
    }
    static func discardUnstarted() {
        if sample?["expanded"] == nil { sample = nil }
    }
    static func expanded(_ opening: Bool) {
        guard sample != nil else { return }
        sample?["expanded"] = ProcessInfo.processInfo.systemUptime
        sample?["opening"] = opening ? 1 : 0
    }
    static func mark(_ stage: String) {
        guard sample != nil else { return }
        sample?[stage] = ProcessInfo.processInfo.systemUptime
    }
    static func moved() {
        guard sample != nil, sample?["movement"] == nil else { return }
        sample?["movement"] = ProcessInfo.processInfo.systemUptime
    }
    static func finished() {
        guard var row = sample, row["movement"] != nil, let output else { return }
        row["finished"] = ProcessInfo.processInfo.systemUptime
        sample = nil
        let completed = row
        writer.async {
            do {
                var data = try JSONSerialization.data(withJSONObject: completed, options: [.sortedKeys]); data.append(10)
                if !FileManager.default.fileExists(atPath: output.path) { try Data().write(to: output) }
                let file = try FileHandle(forWritingTo: output); defer { try? file.close() }
                try file.seekToEnd(); try file.write(contentsOf: data)
            } catch { fputs("THREE_TAP_TRACE_WRITE_FAILED\n", stderr) }
        }
    }
}
