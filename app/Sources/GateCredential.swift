import Foundation

protocol GateCredentialStore {
    func read(account: String) -> String?
    func save(_ token: String, account: String) -> Bool
    func delete(account: String)
}
/// security receives secrets over stdin, never process arguments or log output.
struct GateKeychain: GateCredentialStore {
    static let service = "io.github.hermes-hejo.hejo.gate-token"
    private func valid(_ value: String) -> Bool {
        !value.isEmpty && value.count <= 512 && value.range(of: "^[A-Za-z0-9_-]+$", options: .regularExpression) != nil
    }
    private func run(_ arguments: [String], input: String? = nil) -> String? {
        let p = Process(); p.executableURL = URL(fileURLWithPath: "/usr/bin/security"); p.arguments = arguments
        let out = Pipe(), pipe = Pipe(); p.standardOutput = out; p.standardInput = pipe; p.standardError = FileHandle.nullDevice
        do { try p.run() } catch { return nil }
        if let input { pipe.fileHandleForWriting.write(Data(input.utf8)) }; try? pipe.fileHandleForWriting.close()
        let data = out.fileHandleForReading.readDataToEndOfFile(); p.waitUntilExit()
        return p.terminationStatus == 0 ? String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines) : nil
    }
    func read(account: String) -> String? {
        guard valid(account), let token = run(["find-generic-password", "-s", Self.service, "-a", account, "-w"]), valid(token) else { return nil }; return token
    }
    func save(_ token: String, account: String) -> Bool {
        guard valid(token), valid(account) else { return false }
        guard run(["-i"], input: "add-generic-password -U -s \"\(Self.service)\" -a \"\(account)\" -w \"\(token)\"\n") != nil else { return false }
        return read(account: account) == token
    }
    func delete(account: String) { if valid(account) { _ = run(["delete-generic-password", "-s", Self.service, "-a", account]) } }
}
