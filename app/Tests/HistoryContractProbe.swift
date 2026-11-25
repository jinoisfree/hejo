#if HEJO_HISTORY_CONTRACT_PROBE
import Foundation
#if !HEJO_FROZEN_REFERENCE
import CryptoKit
private final class ContractCredentials: GateCredentialStore {
    var value:String?
    func read(account:String)->String? {value}
    func save(_ token:String,account:String)->Bool {value=token;return true}
    func delete(account:String) {value=nil}
}
#endif
@main enum HistoryContractProbe {
    @MainActor static func main() async throws {
        let args=CommandLine.arguments
        let config=try JSONSerialization.jsonObject(with:Data(contentsOf:URL(fileURLWithPath:args[2]))) as! [String:Any]
        let home=URL(fileURLWithPath:config["home"] as! String)
        try FileManager.default.createDirectory(at:home,withIntermediateDirectories:true)
#if HEJO_FROZEN_REFERENCE
        let rows=config["rows"] as! [[String:Any]],cases=config["cases"] as! [[String:Any]]
        var results=[[String:Any]]()
        for (index,test) in cases.enumerated() {
            let store=try LocalStore(directory:home.appendingPathComponent(String(index)))
            try store.update {$0.stateAccount="fixture-member";$0.stateDevice="fixture-device"}
            for row in rows {try store.append(row)}
            let model=try ConversationModel(store:store)
            try model.apply(["type":"roster","employees":["alpha","beta","gamma"].map{["id":$0,"name":$0,"aliases":[]]}])
            model.noticeClock={Date(timeIntervalSince1970:config["now"] as! Double)}
            var remote=StateDocument(rev:1,items:(test["items"] as! [String:String]).mapValues{StateEntry(v:$0,at:1,dev:"fixture-device")})
            model.memberState.fetch={_ in remote}
            model.memberState.push={values in remote=StateDocument(rev:remote.rev+1,items:MemberState.merge(remote.items,values));return remote}
            await model.memberState.sync()
            let target=test["target"] as! [String:String],key=ConversationKey(employee:target["room"]!,thread:target["thread"]!)
            let scope=test["scope"] as! String
            switch test["action"] as! String {
            case "seed":break // First member fetch invokes the original seed implementation.
            case "enter":model.enterRoom(scope)
            case "mark_all":model.markAllRead(scope)
            case "thread":model.markThreadRead(key)
            case "notice":model.markNoticeRead(key)
            case "all_notices":model.readAllNotices(scope,now:Date(timeIntervalSince1970:config["now"] as! Double))
            default:throw CocoaError(.coderInvalidValue)
            }
            var copies=[[String:Any]]()
            for room in model.rooms {for thread in model.threads(employee:room.id) {
                copies.append(["key":["room":room.id,"thread":thread.key.thread],"text":ThreadTools.copy(model.timeline(thread.key),key:thread.key,name:model.name,group:model.groups[room.id] != nil,zone:.current)])
            }}
            results.append(["id":test["id"]!,"items":model.memberState.items.compactMapValues(\.v),"copies":copies])
        }
        try JSONSerialization.data(withJSONObject:results,options:[.sortedKeys]).write(to:URL(fileURLWithPath:config["output"] as! String))
#else
        if args[1].hasPrefix("cache") {try cache(mode:args[1],home:home);return}
        let store=try LocalStore(directory:home,historyMode:true),client=GateClient(store:store,credentials:ContractCredentials())
        defer {client.stop()}
        try client.pair(address:config["address"] as! String,code:config["pair"] as! String,device:"Contract fixture")
        for _ in 0..<400 {if client.isConnected {break};try await Task.sleep(nanoseconds:20_000_000)}
        guard client.isConnected else {throw GateFailure.notConnected}
        let context=try await client.history.context(["generation":1,"memberRevision":0,"ready":true,"items":[:],"home":["alpha","beta"],"hidden":[],"names":["alpha":"alpha","beta":"beta"],"now":config["now"]!])
        var copies=[[String:Any]]()
        for key in config["keys"] as! [[String:String]] {
            let target=ConversationKey(employee:key["room"]!,thread:key["thread"]!)
            let text=try await HistoryCopy.collect(http:client.history,key:target,context:context,name:{ (config["names"] as? [String:String])?[$0] ?? $0 },group:(config["groups"] as? [String] ?? []).contains(target.employee),check:{},progress:{_,_ in})
            copies.append(["key":key,"text":text])
        }
        try JSONSerialization.data(withJSONObject:copies,options:[.sortedKeys]).write(to:URL(fileURLWithPath:config["output"] as! String))
#endif
    }
#if !HEJO_FROZEN_REFERENCE
    @MainActor private static func cache(mode:String,home:URL) throws {
        func row(_ id:String,_ revision:Int=1)->[String:Any] {["msg_id":id,"revision":revision,"text":"fixture","employee":"alpha","thread":"fixture-thread"]}
        func key(_ id:String)->String {SHA256.hash(data:Data(id.utf8)).map{String(format:"%02x",$0)}.joined()}
        let files=FileManager.default,namespace=home.appendingPathComponent("cache/history-v1/"+key("fixture-a")),index=namespace.appendingPathComponent("index.json")
        if mode=="cache-crash" {
            let cache=try HistoryCache(directory:home,account:"fixture-a")
            try cache.batch {try cache.put(row("unpublished"));_exit(0)}
            fatalError("crash boundary was not reached")
        }
        func require(_ value:Bool)throws {if !value {throw CocoaError(.coderInvalidValue)}}
        let cache=try HistoryCache(directory:home,account:"fixture-a")
        if mode=="cache-reopen" {
            try require(try cache.message("unpublished")==nil && cache.message("isolated")?["revision"] as? Int==1)
            try require(!files.fileExists(atPath:namespace.appendingPathComponent(key("unpublished")+".json").path))
            print("PASS cache process exit leaves prior manifest and removes unpublished body")
            return
        }
        try cache.put(row("original"))
        let original=try Data(contentsOf:index)
        // Fail after body publication, before manifest publication, using a real FS error.
        try files.removeItem(at:index);try files.createDirectory(at:index,withIntermediateDirectories:false)
        var rejected=false;do {try cache.put(row("unpublished"))} catch {rejected=true}
        try require(rejected)
        try files.removeItem(at:index);try original.write(to:index)
        let restarted=try HistoryCache(directory:home,account:"fixture-a")
        try require(try restarted.message("original") != nil && restarted.message("unpublished")==nil)
        // A failed invalidation manifest must not restore a physically removed body.
        let saved=try Data(contentsOf:index)
        try files.removeItem(at:index);try files.createDirectory(at:index,withIntermediateDirectories:false)
        rejected=false;do {try restarted.invalidate(id:"original",through:1)} catch {rejected=true}
        try require(rejected)
        try files.removeItem(at:index);try saved.write(to:index)
        let empty=try HistoryCache(directory:home,account:"fixture-a")
        try require(try empty.message("original")==nil)
        // Eviction followed by body-write failure cannot resurrect the victim on restart.
        let bounded=try HistoryCache(directory:home,account:"fixture-a",messageLimit:1)
        try bounded.put(row("victim"))
        let blocked=namespace.appendingPathComponent(key("blocked")+".json")
        try files.createDirectory(at:blocked,withIntermediateDirectories:false)
        rejected=false;do {try bounded.put(row("blocked"))} catch {rejected=true}
        try require(rejected);try files.removeItem(at:blocked)
        let clean=try HistoryCache(directory:home,account:"fixture-a",messageLimit:1)
        try require(try clean.message("victim")==nil && clean.message("blocked")==nil)
        try clean.put(row("isolated"))
        let other=try HistoryCache(directory:home,account:"fixture-b")
        try require(try other.message("isolated")==nil)
        try other.put(row("isolated",2))
        try require(try clean.message("isolated")?["revision"] as? Int==1)
        // Exercise the product identity mapping, not only arbitrary cache account strings.
        let mappedHome=home.appendingPathComponent("mapped-store")
        let store=try LocalStore(directory:mappedHome,historyMode:true)
        try store.select(address:"fixture-a.invalid",device:"fixture")
        let serverA=try store.historyCache();try serverA.put(row("mapped",1))
        try store.select(address:"fixture-b.invalid",device:"fixture")
        let serverB=try store.historyCache()
        try require(try serverB.message("mapped")==nil)
        try serverB.put(row("mapped",2))
        try store.update {$0.stateAccount="fixture-member"}
        let member=try store.historyCache()
        try require(try member.message("mapped")==nil)
        try member.put(row("mapped",3))
        try require(try serverA.message("mapped")?["revision"] as? Int==1 && serverB.message("mapped")?["revision"] as? Int==2)
        let reopened=try LocalStore(directory:mappedHome,historyMode:true)
        try require(try reopened.historyCache().message("mapped")?["revision"] as? Int==3)
        print("PASS cache body/manifest failure, invalidation, eviction and server/member namespace isolation")
    }
#endif
}
#endif
