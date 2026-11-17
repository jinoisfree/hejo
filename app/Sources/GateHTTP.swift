import Foundation
import UniformTypeIdentifiers

struct DownloadFileStore {
    var root: URL

    /// `home` supplies an isolated user's Downloads folder for checks; normal runs use FileManager's user directory.
    static func standard(home: URL? = nil) -> URL {
        if let home { return home.appendingPathComponent("Downloads") }
        return FileManager.default.urls(for: .downloadsDirectory, in: .userDomainMask).first
            ?? FileManager.default.homeDirectoryForCurrentUser.appendingPathComponent("Downloads")
    }

    private static func cleaned(_ name: String) -> String {
        let cleaned = String(name.map { "/:\\\0\n\r".contains($0) ? "_" : $0 }).trimmingCharacters(in: .whitespaces)
        return cleaned.hasPrefix(".") ? "_" + cleaned.dropFirst() : cleaned
    }
    /// A name that is safe as one path component, whatever the room or file was called.
    static func safe(_ name: String) -> String {
        let trimmed = cleaned(name)
        return trimmed.isEmpty ? "이름 없음" : String(trimmed.prefix(120))
    }
    /// How long a file's name may get, in bytes, leaving room for the stamp in front of it.
    static let nameBytes = 200
    /// A file's name with the file ID for the file in it, so two files of one name sent in the same minute stay two files.
    /// The extension is kept however long the name was. Without an ID the name is as `safe` makes it.
    static func named(_ name: String, id: String) -> String {
        let tag = id.filter { $0.isASCII && ($0.isLetter || $0.isNumber) }
        guard !tag.isEmpty else { return safe(name) }
        let whole = cleaned(name).isEmpty ? "이름 없음" : cleaned(name)
        var base = whole, ending = ""
        // A dot at the very start, or a long tail after the last one, is not an extension.
        if let dot = whole.lastIndex(of: "."), dot != whole.startIndex, whole[dot...].utf8.count <= 16 { base = String(whole[..<dot]); ending = String(whole[dot...]) }
        let tail = " (\(tag))" + ending
        while base.utf8.count + tail.utf8.count > nameBytes, !base.isEmpty { base.removeLast() }
        return base + tail
    }

    private static let stamp: DateFormatter = {
        let formatter = DateFormatter(); formatter.locale = Locale(identifier: "en_US_POSIX"); formatter.dateFormat = "yyyy-MM-dd HHmm"; return formatter
    }()

    /// The same message's file always lands on the same path, so opening it twice does not fetch it twice.
    /// `id` is the file ID for the file; a file saved before names carried it is still where `id: ""` says.
    func destination(room: String, name: String, date: Date, id: String = "") -> URL {
        root.appendingPathComponent(Self.stamp.string(from: date) + " " + Self.named(name, id: id))
    }

    func save(_ data: Data, room: String, name: String, date: Date, id: String = "") throws -> URL {
        let target = destination(room: room, name: name, date: date, id: id)
        try FileManager.default.createDirectory(at: target.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: target, options: .atomic)
        return target
    }

    /// Keeps a copy of a file that was sent. A file already inside the store is left where it is,
    /// and a different file that already has the name is not written over: the copy gets a number after its name.
    func keep(copyOf source: URL, room: String, date: Date) throws -> URL {
        if source.standardizedFileURL.path.hasPrefix(root.standardizedFileURL.path + "/") { return source }
        let data = try Data(contentsOf: source)
        let first = destination(room: room, name: source.lastPathComponent, date: date)
        try FileManager.default.createDirectory(at: first.deletingLastPathComponent(), withIntermediateDirectories: true)
        let ending = first.pathExtension.isEmpty ? "" : "." + first.pathExtension
        let base = first.deletingPathExtension().lastPathComponent
        for number in 1...99 {
            let target = number == 1 ? first : first.deletingLastPathComponent().appendingPathComponent("\(base) \(number)\(ending)")
            if FileManager.default.fileExists(atPath: target.path) {
                let size = ((try? FileManager.default.attributesOfItem(atPath: target.path))?[.size] as? NSNumber)?.intValue
                if size == data.count, (try? Data(contentsOf: target)) == data { return target }
                continue
            }
            try data.write(to: target, options: .atomic)
            return target
        }
        throw CocoaError(.fileWriteFileExists)
    }

}

// A redirect must never carry a gateway credential to a different endpoint.
private final class GateRedirectPolicy: NSObject, URLSessionTaskDelegate {
    func urlSession(_ session: URLSession, task: URLSessionTask, willPerformHTTPRedirection response: HTTPURLResponse,
                    newRequest request: URLRequest, completionHandler: @escaping (URLRequest?) -> Void) { completionHandler(nil) }
}
enum FileTransferFailure: Error { case tooLarge, invalidFile, unauthorized, unavailable, changed }
enum OutgoingFileProblem:Error,Equatable {
    case missing(String),tooLarge(String),unreadable(String),changed(String)
    var message:String {switch self {
    case .missing(let name):return "파일을 찾지 못했어요: \(name)"
    case .tooLarge(let name):return "50MiB보다 큰 파일은 보낼 수 없어요: \(name)"
    case .unreadable(let name):return "파일을 읽지 못했어요: \(name)"
    case .changed(let name):return "보내는 사이 파일이 바뀌었어요. 다시 보내 주세요: \(name)"
    }}
}
@MainActor final class GateHTTP {
    nonisolated static let maxFileBytes = 50 * 1024 * 1024
    let client: GateClient
    private let session: URLSession
    private let copies=DispatchQueue(label:"hejo.sent-files")
    let downloads: DownloadFileStore
    init(client: GateClient, downloads: URL? = nil) {
        self.downloads=DownloadFileStore(root:downloads ?? DownloadFileStore.standard())
        self.client = client
        session = URLSession(configuration: .ephemeral, delegate: GateRedirectPolicy(), delegateQueue: nil)
    }
    private static func validate(_ file: MessageFile) throws {
        guard UUID(uuidString: file.fileID) != nil, (1...255).contains(file.name.count), !file.name.contains(where: { "/\\\0".contains($0) }),
              file.name != ".", file.name != "..", (0...maxFileBytes).contains(file.size) else { throw FileTransferFailure.invalidFile }
    }
    private func check(_ response: URLResponse) throws {
        guard let http = response as? HTTPURLResponse else { throw FileTransferFailure.unavailable }
        switch http.statusCode { case 200..<300: return; case 401: throw FileTransferFailure.unauthorized; case 413: throw FileTransferFailure.tooLarge; case 415: throw FileTransferFailure.invalidFile; default: throw FileTransferFailure.unavailable }
    }
    func picture(_ path:String) async throws -> Data {
        guard let uri=URLComponents(string:path),uri.scheme==nil,uri.host==nil,uri.fragment==nil else { throw FileTransferFailure.invalidFile }
        let segments=uri.path.split(separator:"/").map(String.init)
        guard segments.count==4,segments[0]=="v1",segments[1]=="pictures",["employee","room"].contains(segments[2]) else { throw FileTransferFailure.invalidFile }
        let request=try client.authorizedRequest(components:segments,query:uri.queryItems ?? [])
        let (data,response)=try await session.data(for:request);try check(response)
        return data // The 512 KiB limit is for PUT; existing profile photos may be larger.
    }
    @discardableResult func setPicture(kind:String,id:String,data:Data?) async throws -> String? {
        if let data,data.count>PictureCodec.maximum { throw FileTransferFailure.tooLarge }
        var request=try client.authorizedRequest(components:["v1","pictures",kind,id])
        request.httpMethod=data==nil ? "DELETE" : "PUT";request.httpBody=data
        request.setValue("image/png",forHTTPHeaderField:"Content-Type")
        let (result,response)=try await session.data(for:request);try check(response)
        return (try JSONSerialization.jsonObject(with:result) as? [String:Any])?["picture"] as? String
    }
    nonisolated static func prepareUploads(_ urls:[URL]) throws ->[Int] {
        try urls.map {url in
            guard let values=try? url.resourceValues(forKeys:[.isRegularFileKey,.fileSizeKey]),values.isRegularFile==true,let size=values.fileSize else {throw OutgoingFileProblem.missing(url.lastPathComponent)}
            guard size<=maxFileBytes else {throw OutgoingFileProblem.tooLarge(url.lastPathComponent)}
            return size
        }
    }
    func upload(_ url: URL, employee: String, expectedSize:Int?=nil) async throws -> MessageFile {
        let size=try expectedSize ?? Self.prepareUploads([url])[0]
        let data = try await Task.detached { () throws -> Data in
            let data:Data
            do {let handle=try FileHandle(forReadingFrom:url);defer{try? handle.close()};data=try handle.read(upToCount:Self.maxFileBytes+1) ?? Data()}
            catch {throw OutgoingFileProblem.unreadable(url.lastPathComponent)}
            guard data.count==size else {throw OutgoingFileProblem.changed(url.lastPathComponent)}
            return data
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
        guard file.size == data.count else { throw OutgoingFileProblem.changed(name) }; return file
    }
    /// User-requested open only. Thumbnail reads still use the disposable cache below.
    func openedFile(_ file:MessageFile, employee:String, date:Date) async throws -> (url:URL, problem:String?) {
        try Self.validate(file)
        // Construct the authenticated request before consulting a saved copy. A different employee's copy is never reused.
        _ = try client.authorizedRequest(components:["v1","files",employee,file.fileID])
        let target=downloads.destination(room:employee,name:file.name,date:date,id:file.fileID)
        let deleted=Set(client.store.records.filter{$0["type"] as? String=="delete"}.compactMap{$0["msg_id"] as? String})
        let registered=client.store.records.contains { row in
            row["type"] as? String=="message" && !deleted.contains(row["msg_id"] as? String ?? "") && row["employee"] as? String == employee && (row["files"] as? [[String:Any]] ?? []).contains {
                $0["file_id"] as? String==file.fileID && $0["name"] as? String==file.name && $0["size"] as? Int==file.size
            }
        }
        if registered,FileManager.default.fileExists(atPath:target.path) {return (target,nil)}
        let wasRegistered=client.store.hasFile(file.fileID)
        let cached=try await download(file,employee:employee)
        let data=try await Task.detached {try Data(contentsOf:cached)}.value
        if wasRegistered && !client.store.hasFile(file.fileID) {throw FileTransferFailure.unavailable}
        do {return (try downloads.save(data,room:employee,name:file.name,date:date,id:file.fileID),nil)
        } catch {return (cached,"파일을 저장하지 못했어요. \(error.localizedDescription)")}
    }
    func keepSent(_ urls:[URL], date:Date) async {
        let downloads=self.downloads
        // Like the original send completion, a local copy failure does not turn an accepted message into a failed send.
        await withCheckedContinuation { continuation in
            copies.async {for url in urls {_ = try? downloads.keep(copyOf:url,room:"",date:date)};continuation.resume()}
        }
    }
    func download(_ file: MessageFile, employee: String) async throws -> URL {
        try Self.validate(file)
        let wasRegistered=client.store.hasFile(file.fileID)
        let request = try client.authorizedRequest(components: ["v1", "files", employee, file.fileID])
        let (temporary, response) = try await session.download(for: request)
        defer { try? FileManager.default.removeItem(at: temporary) }
        try check(response)
        let values = try temporary.resourceValues(forKeys: [.fileSizeKey])
        guard values.fileSize == file.size else { throw FileTransferFailure.changed }
        let cache = client.store.directory
        let data=try await Task.detached {try Data(contentsOf:temporary)}.value
        // Serialize cache publication with scope redaction on the main actor, including an in-flight download.
        if wasRegistered && !client.store.hasFile(file.fileID) {throw FileTransferFailure.unavailable}
            let destination = cache.appendingPathComponent("cache/files/" + file.fileID, isDirectory: true)
            try FileManager.default.createDirectory(at: destination, withIntermediateDirectories: true, attributes: [.posixPermissions: 0o700])
            let target = destination.appendingPathComponent(file.name)
            try data.write(to: target, options: .atomic)
            try FileManager.default.setAttributes([.posixPermissions: 0o600], ofItemAtPath: target.path)
            return target
    }
}
