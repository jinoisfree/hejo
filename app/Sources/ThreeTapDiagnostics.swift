import Foundation
import CoreFoundation

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
        idleStart = nil
        _ = waitObserver
    }
    private static var idleStart: Double?
    // Diagnose run-loop sleep separately from synchronous work after timer registration.
    // This observer is installed only when an enabled trace begins a real sample.
    private static let waitObserver: CFRunLoopObserver? = {
        let activities = CFRunLoopActivity.beforeWaiting.rawValue | CFRunLoopActivity.afterWaiting.rawValue
        let observer = CFRunLoopObserverCreateWithHandler(nil, activities, true, 0) { _, activity in
            guard sample?["timer_start"] != nil, sample?["first_tick"] == nil else { return }
            let now = ProcessInfo.processInfo.systemUptime
            if activity == .beforeWaiting { idleStart = now }
            else if let start = idleStart {
                let slept = (sample?["timer_sleep_seconds"] ?? 0) + now - start
                sample?["timer_sleep_seconds"] = slept
                idleStart = nil
            }
        }
        if let observer { CFRunLoopAddObserver(CFRunLoopGetMain(), observer, .commonModes) }
        return observer
    }()
    static func firstTick() {
        guard sample != nil, sample?["first_tick"] == nil else { return }
        sample?["first_tick"] = ProcessInfo.processInfo.systemUptime
        if sample?["timer_sleep_seconds"] == nil { sample?["timer_sleep_seconds"] = 0 }
    }
    static func markFirst(_ stage: String) {
        guard sample?[stage] == nil else { return }
        mark(stage)
    }
    static func startBeforeFirstTickSpan() -> Double? {
        sample?["first_tick"] == nil ? startSpan() : nil
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
    /// Main-thread spans include nested work; only fixed stage names and numeric costs are recorded.
    static func startSpan() -> Double? {
        sample == nil ? nil : ProcessInfo.processInfo.systemUptime
    }
    static func endSpan(_ stage: String, _ start: Double?) {
        guard let start, sample != nil else { return }
        let count = Int(sample?[stage + "_count"] ?? 0) + 1
        sample?[stage + "_count"] = Double(count)
        sample?[stage + "_seconds_" + String(count)] = ProcessInfo.processInfo.systemUptime - start
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
