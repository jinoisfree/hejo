import Foundation
import UniformTypeIdentifiers

// A redirect must never carry a gateway credential to a different endpoint.
private final class GateRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
enum FileTransferFailure: Error { case tooLarge, invalidFile, unauthorized, unavailable, changed }
@MainActor final class GateHTTP {
    nonisolated static let maxFileBytes = 50 * 1024 * 1024
    let client: GateClient
    private let session: URLSession
    init(client: GateClient) {
        self.client = client
        session = URLSession(configuration: .ephemeral, delegate: GateRedirectPolicy(), delegateQueue: nil)
    }
    private static func validate(_ file: MessageFile) throws {
        guard UUID(uuidString: file.fileID) != nil, (1...255).contains(file.name.count), !file.name.contains(where: { "/\\\0".contains($0) }),
              file.name != ".", file.name != "..", (0...maxFileBytes).contains(file.size) else { throw FileTransferFailure.invalidFile }
    }
    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw FileTransferFailure.unavailable }
        switch http.statusCode { case 200..<300: return; case 401: throw FileTransferFailure.unauthorized; case 413: throw FileTransferFailure.tooLarge; default: throw FileTransferFailure.unavailable }
    }
    func upload(_ url: URL, employee: String) async throws -> MessageFile {
        let data = try await Task.detached { () throws -> Data in
            let values = try url.resourceValues(forKeys: [.isRegularFileKey, .fileSizeKey])
            guard values.isRegularFile == true, let size = values.fileSize else { throw FileTransferFailure.invalidFile }
            guard size <= Self.maxFileBytes else { throw FileTransferFailure.tooLarge }
            let handle = try FileHandle(forReadingFrom: url); defer { try? handle.close() }
            let data = try handle.read(upToCount: Self.maxFileBytes + 1) ?? Data()
            guard data.count == size else { throw FileTransferFailure.changed }; return data
        }.value
        let name = url.lastPathComponent
        guard (1...255).contains(name.count), !name.contains(where: { "\"\\\r\n".contains($0) }) else { throw FileTransferFailure.invalidFile }
        let mime = UTType(filenameExtension: url.pathExtension)?.preferredMIMEType ?? "application/octet-stream"
        let boundary = "hejo-" + UUID().uuidString
        let body = await Task.detached {
            var body = Data("--\(boundary)\r\nContent-Disposition: form-data; name=\"file\"; filename=\"\(name)\"\r\nContent-Type: \(mime)\r\n\r\n".utf8)
            body.append(data); body.append(Data("\r\n--\(boundary)--\r\n".utf8)); return body
        }.value
        var request = try client.authorizedRequest(components: ["v1", "files"], query: [URLQueryItem(name: "employee", value: employee)])
        request.httpMethod = "POST"; request.setValue("multipart/form-data; boundary=\(boundary)", forHTTPHeaderField: "Content-Type")
        let (responseData, response) = try await session.upload(for: request, from: body)
        try check(response)
        let file = try JSONDecoder().decode(MessageFile.self, from: responseData); try Self.validate(file)
        guard file.size == data.count else { throw FileTransferFailure.changed }; return file
    }
    func download(_ file: MessageFile, employee: String) async throws -> URL {
        try Self.validate(file)
        let request = try client.authorizedRequest(components: ["v1", "files", employee, file.fileID])
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try check(response)
        let values = try temporary.resourceValues(forKeys: [.fileSizeKey])
        guard values.fileSize == file.size else { throw FileTransferFailure.changed }
        let cache = client.store.directory
        return try await Task.detached {
            let destination = cache.appendingPathComponent("cache/files/" + file.fileID, isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let target = destination.appendingPathComponent(file.name)
            let data = try Data(contentsOf: temporary); try data.write(to: target, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            return target
        }.value
    }
}
