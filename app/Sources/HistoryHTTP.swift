import Foundation
import CoreFoundation
import CryptoKit

enum HistoryFailure: Error, Equatable {
    case updateRequired, invalidResponse, changed, tooLarge
    case server(String, retryable: Bool)
}

/// Bounded HTTP transport for the current authenticated WebSocket session.
/// HTTP snapshots never advance GateClient's live sequence.
@MainActor final class HistoryHTTP {
    private unowned let client: GateClient
    private let session = URLSession(configuration: .ephemeral, delegate: GateRedirectPolicy(), delegateQueue: nil)
    static let pageBytes = 512 * 1024
    init(client: GateClient) { self.client = client }
    deinit { session.invalidateAndCancel() }

    static func integer(_ value: Any?) -> Int? {
        guard let n = value as? NSNumber, CFGetTypeID(n) != CFBooleanGetTypeID(),
              n.doubleValue.isFinite, n.doubleValue >= 0, n.doubleValue <= 9_007_199_254_740_991,
              n.doubleValue.rounded(.towardZero) == n.doubleValue else { return nil }
        return n.intValue
    }
    static func boolean(_ value: Any?) -> Bool? {
        guard let n = value as? NSNumber, CFGetTypeID(n) == CFBooleanGetTypeID() else { return nil }
        return n.boolValue
    }
    private func data(_ request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (bytes, response) = try await session.bytes(for: request)
        guard let response = response as? HTTPURLResponse else { throw HistoryFailure.invalidResponse }
        guard response.expectedContentLength <= Int64(Self.pageBytes) else { throw HistoryFailure.tooLarge }
        var body = Data()
        for try await byte in bytes {
            try Task.checkCancellation()
            guard body.count < Self.pageBytes else { throw HistoryFailure.tooLarge }
            body.append(byte)
        }
        return (body, response)
    }
    func preflight(address: String) async throws {
        var parts = URLComponents(url: try GateClient.endpoint(address), resolvingAgainstBaseURL: false)!
        parts.scheme = parts.scheme == "wss" ? "https" : "http"; parts.path = "/v1/history/capabilities"
        var request = URLRequest(url: parts.url!); request.timeoutInterval = 10
        let (body, response) = try await data(request)
        if response.statusCode == 404 { throw HistoryFailure.updateRequired }
        guard response.statusCode == 200 else { throw HistoryFailure.server("unavailable", retryable: response.statusCode == 503) }
        guard let value = try JSONSerialization.jsonObject(with: body) as? [String:Any],
              Self.integer(value["version"]) == 1, value["mode"] as? String == "history-v1" else { throw HistoryFailure.updateRequired }
        guard let limits = value["limits"] as? [String:Any], Self.integer(limits["page_items"]) == 50,
              Self.integer(limits["page_bytes"]) == Self.pageBytes,
              Self.integer(limits["content_chunk_bytes"]) == 256 * 1024 else { throw HistoryFailure.invalidResponse }
    }
    private func post(_ path: String, _ fields: [String:Any], retry: Bool = true) async throws -> [String:Any] {
        guard let history = client.historySession, client.isConnected else { throw GateFailure.notConnected }
        let epoch = client.connectionEpoch
        var payload = fields; payload["session"] = history
        var request = try client.authorizedRequest(components: ["v1","history",path]); request.timeoutInterval = 10
        request.httpMethod = "POST"; request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(withJSONObject: payload, options: .sortedKeys)
        guard request.httpBody!.count <= (path == "context" ? 2 * 1024 * 1024 : 64 * 1024) else { throw HistoryFailure.tooLarge }
        // Only reads are retried, once. Authentication/protocol/stale-context errors
        // are actionable failures, never empty results or a legacy replay request.
        for attempt in 0...1 {
            do {
                let (body, response) = try await data(request)
                try Task.checkCancellation()
                guard client.connectionEpoch == epoch, client.historySession == history, client.isConnected else { throw HistoryFailure.changed }
                guard let value = try JSONSerialization.jsonObject(with: body) as? [String:Any] else { throw HistoryFailure.invalidResponse }
                if response.statusCode == 503 && attempt == 0 && retry { continue }
                guard response.statusCode == 200 else {
                    guard let code = value["code"] as? String, let retryable = Self.boolean(value["retryable"]) else { throw HistoryFailure.invalidResponse }
                    throw HistoryFailure.server(code, retryable: retryable)
                }
                return value
            } catch let error as URLError where retry && attempt == 0 && [.timedOut,.networkConnectionLost,.cannotConnectToHost].contains(error.code) {
                try Task.checkCancellation()
                guard client.connectionEpoch == epoch, client.historySession == history else { throw HistoryFailure.changed }
            }
        }
        throw HistoryFailure.server("unavailable", retryable: true)
    }
    func context(_ fields: [String:Any]) async throws -> String {
        let response = try await post("context", fields)
        guard let token = response["context"] as? String, !token.isEmpty,
              Self.integer(response["generation"]) == Self.integer(fields["generation"]),
              Self.integer(response["memberRevision"]) == Self.integer(fields["memberRevision"]) else { throw HistoryFailure.invalidResponse }
        return token
    }
    func query(context: String, kind: String, scope: String, fields: [String:Any] = [:], retry: Bool = true) async throws -> [String:Any] {
        let reference = UUID().uuidString.lowercased()
        var request = fields; request["context"] = context; request["kind"] = kind
        request["scope"] = scope; request["request"] = reference
        let response = try await post("query", request, retry: retry && kind != "copy")
        guard response["session"] as? String == client.historySession,
              response["context"] as? String == context, response["request"] as? String == reference,
              Self.integer(response["through"]) != nil, let complete = Self.boolean(response["complete"]),
              response["next"] is NSNull || response["next"] is String,
              complete == (response["next"] is NSNull) else { throw HistoryFailure.invalidResponse }
        if kind == "read_plan" {
            guard let changes = response["changes"] as? [String:String], changes.count <= 50,
                  response["action"] as? String == fields["action"] as? String,
                  changes.allSatisfy({ key, value in ["read:","thread:","bell:"].contains(where:key.hasPrefix) && Int(value).map{$0 >= 0} == true }) else { throw HistoryFailure.invalidResponse }
        } else {
            guard let rows = response["items"] as? [[String:Any]], rows.count <= 50 else { throw HistoryFailure.invalidResponse }
            for row in rows { try Self.validate(row, kind: kind) }
        }
        if let root = response["root"] as? [String:Any] { try Self.validate(root, kind:"threads") }
        if let totals = response["totals"] as? [String:Any] {
            guard ["unread","questions","alerts"].allSatisfy({Self.integer(totals[$0]) != nil}) else { throw HistoryFailure.invalidResponse }
        }
        return response
    }
    /// Only called for a displayed/explicitly opened body; never prefetch all refs.
    func content(reference: String, id: String, revision: Int, retry: Bool = true) async throws -> [String:Any] {
        let file = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        guard FileManager.default.createFile(atPath: file.path, contents: nil, attributes: [.posixPermissions:0o600]) else { throw GateFailure.storage }
        defer { try? FileManager.default.removeItem(at: file) }
        let handle = try FileHandle(forWritingTo: file)
        defer { try? handle.close() }
        var cursor: String?, total: Int?, digest: String?, offset = 0, hasher = SHA256()
        repeat {
            var request: [String:Any] = ["ref":reference]
            if let cursor { request["cursor"] = cursor }
            let chunk = try await post("content", request, retry: retry)
            guard Self.integer(chunk["revision"]) == revision, Self.integer(chunk["offset"]) == offset,
                  let size = Self.integer(chunk["totalBytes"]), size > offset,
                  let hash = chunk["sha256"] as? String, hash.count == 64,
                  let encoded = chunk["data"] as? String, let data = Data(base64Encoded: encoded),
                  !data.isEmpty, data.count <= 256*1024, offset + data.count <= size,
                  chunk["next"] is NSNull || chunk["next"] is String else { throw HistoryFailure.invalidResponse }
            if let total, total != size { throw HistoryFailure.changed }
            if let digest, digest != hash { throw HistoryFailure.changed }
            total = size; digest = hash
            try handle.write(contentsOf: data); hasher.update(data: data); offset += data.count
            cursor = chunk["next"] as? String
            guard (cursor == nil) == (offset == size) else { throw HistoryFailure.invalidResponse }
        } while cursor != nil
        let actual = hasher.finalize().map { String(format:"%02x", $0) }.joined()
        guard actual == digest else { throw HistoryFailure.invalidResponse }
        try handle.synchronize()
        let data = try Data(contentsOf:file, options:.mappedIfSafe)
        guard let value = try JSONSerialization.jsonObject(with:data) as? [String:Any],
              value["msg_id"] as? String == id, Self.integer(value["revision"]) == revision,
              value["type"] as? String == "message", value["text"] is String else { throw HistoryFailure.invalidResponse }
        try Self.validate(value, kind:"messages")
        return value
    }
    static func validate(_ row: [String:Any], kind: String) throws {
        if boolean(row["removed"]) == true {
            guard row["id"] is String, integer(row["revision"]) != nil else { throw HistoryFailure.invalidResponse }; return
        }
        if kind == "messages" || kind == "copy" || kind == "resolve" {
            guard row["msg_id"] is String else { throw HistoryFailure.invalidResponse }
            if boolean(row["missing"]) == true { return }
            guard integer(row["revision"]) != nil else { throw HistoryFailure.invalidResponse }
            if boolean(row["deleted"]) == true || row["contentRef"] is String { return }
            guard row["type"] as? String == "message", let seq = integer(row["seq"]), seq > 0,
                  let revision = integer(row["revision"]), revision >= seq,
                  row["thread"] is String, row["employee"] is String, row["text"] is String, row["ts"] is String,
                  row["room"] == nil || row["room"] is String,
                  ["owner","employee"].contains(row["role"] as? String ?? ""),
                  let files = row["files"] as? [[String:Any]], let buttons = row["buttons"] as? [[String:Any]] else { throw HistoryFailure.invalidResponse }
            _ = try JSONDecoder().decode([MessageFile].self, from: JSONSerialization.data(withJSONObject: files))
            _ = try JSONDecoder().decode([MessageButton].self, from: JSONSerialization.data(withJSONObject: buttons))
        } else if kind == "asks" {
            guard let id=row["id"] as? String, id == row["msg_id"] as? String else { throw HistoryFailure.invalidResponse }
            _ = try JSONDecoder().decode(QuestionRow.self, from: JSONSerialization.data(withJSONObject:row))
        } else if kind == "threads" || row["rootID"] != nil {
            guard let key = row["key"] as? [String:String], key["room"] != nil, key["thread"] != nil,
                  row["title"] is String, row["preview"] is String, row["rootID"] is String,
                  ["owner","employee"].contains(row["rootRole"] as? String ?? ""),
                  ["rootSeq","latestSeq","originalMaxSeq","messageCount","unread","revision"].allSatisfy({integer(row[$0]) != nil}),
                  let activity = row["activity"] as? [String:Any],
                  boolean(activity["working"]) != nil,
                  activity["lastSpeaker"] is String || activity["lastSpeaker"] is NSNull,
                  activity["latestEmployeeTime"] is NSNull || (activity["latestEmployeeTime"] as? NSNumber).map({CFGetTypeID($0) != CFBooleanGetTypeID() && $0.doubleValue.isFinite}) == true,
                  let assessment = row["assessment"] as? [String:Any],
                  ["working","settled","approved"].allSatisfy({boolean(assessment[$0]) != nil}) else { throw HistoryFailure.invalidResponse }
        } else if kind == "message_state" {
            guard row["id"] is String,let status=row["status"] as? String,["present","deleted","missing"].contains(status) else {throw HistoryFailure.invalidResponse}
            if status == "present" {
                guard let seq=integer(row["seq"]),seq>0,let revision=integer(row["revision"]),revision>=seq,
                      boolean(row["read"]) != nil,boolean(row["eligible"]) != nil,
                      let key=row["key"] as? [String:String],key["room"] != nil,key["thread"] != nil else {throw HistoryFailure.invalidResponse}
            } else {
                guard row["key"] == nil,row["seq"] == nil,row["read"] == nil,row["eligible"] == nil else {throw HistoryFailure.invalidResponse}
                if status == "deleted",integer(row["revision"]) == nil {throw HistoryFailure.invalidResponse}
                if status == "missing",row["revision"] != nil {throw HistoryFailure.invalidResponse}
            }
            _ = try JSONDecoder().decode(HistoryMessageState.self,from:JSONSerialization.data(withJSONObject:row))
        } else if kind == "questions" {
            guard let seq=integer(row["seq"]),seq>0,let revision=integer(row["revision"]),revision>=seq else {throw HistoryFailure.invalidResponse}
            _ = try JSONDecoder().decode(HistoryQuestion.self,from:JSONSerialization.data(withJSONObject:row))
        } else if kind == "receipt" {
            guard row["client_msg_id"] is String, ["accepted","deleted","not_found"].contains(row["status"] as? String ?? "") else { throw HistoryFailure.invalidResponse }
            if row["status"] as? String != "not_found" {
                guard row["msg_id"] is String, integer(row["seq"]) != nil,
                      let key = row["key"] as? [String:String], key["room"] != nil, key["thread"] != nil else { throw HistoryFailure.invalidResponse }
            }
        } else if kind == "overview" {
            guard row["id"] is String, let activity = row["latestActivity"] as? NSNumber, CFGetTypeID(activity) != CFBooleanGetTypeID(), activity.doubleValue.isFinite, ["unread","questions","alerts","latestSeq"].allSatisfy({integer(row[$0]) != nil}) else { throw HistoryFailure.invalidResponse }
        } else if kind == "notices" || kind == "search" {
            guard let key = row["key"] as? [String:String], key["room"] != nil, key["thread"] != nil else { throw HistoryFailure.invalidResponse }
            if kind == "notices" {
                guard row["id"] is String, row["group"] is String, row["title"] is String,
                      row["speaker"] is String, row["timestamp"] is String, row["preview"] is String,
                      boolean(row["questions"]) != nil, integer(row["revision"]) != nil else { throw HistoryFailure.invalidResponse }
            } else if let matches = row["matches"] as? [[String:Any]] {
                guard matches.count <= 200, let root = row["root"] as? [String:Any], boolean(row["exact"]) != nil,
                      row["latest"] is String, row["rootSnippet"] is String, root["key"] as? [String:String] == key else { throw HistoryFailure.invalidResponse }
                try validate(root, kind:"threads")
                for match in matches {
                    try validateSearchHit(match)
                    guard let matchKey = match["key"] as? [String:String], matchKey == key else { throw HistoryFailure.invalidResponse }
                }
            } else {
                try validateSearchHit(row)
            }
        } else { throw HistoryFailure.invalidResponse }
    }
}
