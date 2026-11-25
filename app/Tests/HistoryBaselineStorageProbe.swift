#if HEJO_HISTORY_BASELINE && HEJO_HISTORY_STORAGE_PROBE
import Foundation
@main private enum HistoryStorageProbe {
    static func main() throws {
        let root = URL(fileURLWithPath: CommandLine.arguments[1])
        let dir = root.appendingPathComponent("app", isDirectory: true)
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        let file = dir.appendingPathComponent("probe")
        do { let replacement = try FileManager.default.url(for: .itemReplacementDirectory, in: .userDomainMask, appropriateFor: file, create: true); defer { try? FileManager.default.removeItem(at: replacement) }; print("replacement-created=true") }
        catch { print("replacement-error=\(error)") }
        let created = FileManager.default.createFile(atPath: file.path, contents: Data("probe".utf8), attributes: [.posixPermissions: 0o600])
        print("createFile=\(created)")
        do { try Data("probe".utf8).write(to: dir.appendingPathComponent("data-probe")); print("dataWrite=true") }
        catch { print("dataWrite=false \(error)") }
        let plain = dir.appendingPathComponent("plain-probe")
        print("plainCreate=\(FileManager.default.createFile(atPath: plain.path, contents: Data()))")
        do { try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: plain.path); print("chmod=true") }
        catch { print("chmod=false \(error)") }
        let fd = open(dir.appendingPathComponent("posix-probe").path, O_CREAT | O_WRONLY, 0o600)
        print("posixOpen=\(fd >= 0) errno=\(errno)")
        if fd >= 0 { close(fd) }
    }
}
#endif
