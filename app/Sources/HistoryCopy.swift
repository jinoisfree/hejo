import Foundation

/// Explicit export only. Rows never enter the resident body cache or live cursor.
@MainActor enum HistoryCopy {
    static func collect(http: HistoryHTTP, key: ConversationKey, context: String,
                        name:(String)->String, ownerName:String, group:Bool, check: () throws -> Void, progress: (Int,Int) -> Void) async throws -> String {
        let target = ["room":key.employee,"thread":key.thread]
        var fields: [String:Any] = ["target":target]
        let directory=FileManager.default.temporaryDirectory.appendingPathComponent("history-copy-"+UUID().uuidString,isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true,attributes:[.posixPermissions:0o700])
        defer {try? FileManager.default.removeItem(at:directory)}
        var chunks:[URL]=[],ids=Set<String>(),cursors=Set<String>(),collected=0,visible=0
        var reference: String?, revision: Int?, total: Int?, upperSequence: Int?
        repeat {
            try check()
            let page = try await http.query(context:context,kind:"copy",scope:key.employee,fields:fields)
            try check()
            guard let ref = page["copyRef"] as? String, let root = page["root"] as? [String:Any],
                  let currentRevision = HistoryHTTP.integer(root["revision"]), let count = HistoryHTTP.integer(root["messageCount"]),
                  reference == nil || reference == ref, revision == nil || revision == currentRevision,
                  total == nil || total == count else { throw HistoryFailure.invalidResponse }
            reference = ref; revision = currentRevision; total = count
            let file=directory.appendingPathComponent(String(chunks.count))
            guard FileManager.default.createFile(atPath:file.path,contents:nil,attributes:[.posixPermissions:0o600]) else {throw GateFailure.storage}
            let handle=try FileHandle(forWritingTo:file)
            defer {try? handle.close()}
            var pageVisible=0,firstSequence:Int?,lastSequence:Int?
            for value in page["items"] as! [[String:Any]] {
                var row = value
                if let contentRef = row["contentRef"] as? String {
                    row = try await http.content(reference:contentRef,id:row["msg_id"] as! String,revision:row["revision"] as! Int,retry:false)
                    try check()
                }
                let message = try HistoryHTTP.message(row)
                guard message.key == key, ids.insert(message.id).inserted,
                      lastSequence == nil || message.seq > lastSequence!,
                      upperSequence == nil || message.seq < upperSequence! else { throw HistoryFailure.invalidResponse }
                if firstSequence == nil {firstSequence=message.seq};lastSequence=message.seq
                collected += 1
                if let section=ThreadTools.copySections([message],name:name,ownerName:ownerName).first {
                    if pageVisible>0 {try handle.write(contentsOf:Data("\n\n".utf8))}
                    try handle.write(contentsOf:Data(section.utf8));pageVisible += 1;visible += 1
                }
            }
            if let firstSequence {upperSequence=firstSequence}
            if pageVisible>0 {chunks.append(file)}
            progress(collected,count)
            try check()
            if let next = page["next"] as? String {
                guard cursors.insert(next).inserted else { throw HistoryFailure.invalidResponse }
                fields["cursor"] = next
            } else { break }
        } while true
        guard collected == total, let reference else { throw HistoryFailure.invalidResponse }
        // Pages arrive newest first. Keep only one decoded body at a time; the final
        // clipboard string is necessarily proportional to the explicit export size.
        var text=ThreadTools.copyHeader(count:visible,key:key,name:name,group:group)
        for file in chunks.reversed() {
            await Task.yield();try check()
            text += "\n\n" + (try String(contentsOf:file,encoding:.utf8))
        }
        let end = try await http.query(context:context,kind:"copy",scope:key.employee,
            fields:["target":target,"action":"finalize","copyRef":reference])
        try check()
        guard HistoryHTTP.integer(end["revision"]) == revision else { throw HistoryFailure.invalidResponse }
        return text
    }
}

extension HistoryHTTP {
    static func message(_ row: [String:Any]) throws -> ConversationMessage {
        try validate(row,kind:"messages")
        guard boolean(row["missing"]) != true, boolean(row["deleted"]) != true, row["contentRef"] == nil,
              row["type"] as? String == "message", let id = row["msg_id"] as? String,
              let room = (row["room"] ?? row["employee"]) as? String else { throw HistoryFailure.invalidResponse }
        func decode<T:Decodable>(_ value:Any, as type:T.Type) throws -> T {
            try JSONDecoder().decode(type,from:JSONSerialization.data(withJSONObject:value))
        }
        var message = ConversationMessage(id:id,key:.init(employee:room,thread:row["thread"] as! String),
            role:row["role"] as! String,text:row["text"] as! String,
            files:try decode(row["files"]!,as:[MessageFile].self),buttons:try decode(row["buttons"]!,as:[MessageButton].self),
            replyState:row["reply_state"] as? String,seq:row["seq"] as! Int,latestSeq:row["revision"] as! Int,
            timestamp:row["ts"] as! String,clientMessageID:row["client_msg_id"] as? String)
        message.employee = row["employee"] as? String; message.answerTo = row["answer_to"] as? String
        message.isQuestion = row["answer"] != nil
        message.branch = row["branch"] as? String
        if let answer=row["answer"] as? [String:Any] { message.answer=try decode(answer,as:QuestionAnswer.self) }
        message.branchFrom = (row["branch_from"] as? [String:Any])?["thread"] as? String
        if let checklist = row["checklist"] { message.checklist = try decode(checklist,as:ReplyChecklist.self) }
        message.streaming = row["final"] as? Bool == false; message.finalized = row["final"] as? Bool == true
        return message
    }
}
