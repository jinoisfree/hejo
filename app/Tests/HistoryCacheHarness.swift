#if HEJO_HISTORY_CACHE_TEST
import Foundation

@main struct HistoryCacheHarness {
    static func main() throws {
        let home = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
        try FileManager.default.createDirectory(at: home.appendingPathComponent("cache"), withIntermediateDirectories: true)
        defer { try? FileManager.default.removeItem(at: home) }
        let legacy = home.appendingPathComponent("cache/frames.jsonl")
        let original = Data("legacy fixture stays untouched\n".utf8)
        try original.write(to: legacy)
        let cache = try HistoryCache(directory: home, account: "fixture-member", messageLimit: 2, byteLimit: 1024)
        func row(_ id: String, _ revision: Int, _ text: String) -> [String:Any] { ["msg_id": id, "revision": revision, "text": text] }
        try cache.put(row("one", 1, "first")); try cache.put(row("two", 2, "second"))
        _ = try cache.message("one")
        try cache.put(row("three", 3, "third"))
        let missing = try cache.message("two"); assert(missing == nil)
        let first = try cache.message("one"); assert(first?["text"] as? String == "first")
        try cache.put(["msg_id":"one", "revision":4, "deleted":true])
        let stale = try cache.put(row("one", 1, "must not resurrect")); assert(!stale)
        let large = try cache.put(row("large", 5, String(repeating:"x", count:1024))); assert(!large)
        let reopened = try HistoryCache(directory:home, account:"fixture-member", messageLimit:2, byteLimit:1024)
        let deleted = try reopened.message("one"); assert(deleted?["deleted"] as? Bool == true)
        let other = try HistoryCache(directory:home, account:"fixture-other", messageLimit:2, byteLimit:1024)
        assert(other.count == 0 && reopened.count == 2 && reopened.byteCount <= 1024)
        let scoped = try HistoryCache(directory:home, account:"fixture-scoped", messageLimit:4, byteLimit:2048)
        try scoped.batch {
            try scoped.put(["msg_id":"a","revision":1,"room":"alpha","thread":"first","text":"old"])
            try scoped.put(["msg_id":"b","revision":9,"room":"alpha","thread":"first","text":"newer page"])
            try scoped.put(["msg_id":"c","revision":2,"room":"beta","thread":"first","text":"other room"])
            try scoped.put(row("unknown",2,"old manifest without scope"))
        }
        try scoped.invalidate(room:"alpha",thread:"first",through:5)
        let after = try HistoryCache(directory:home,account:"fixture-scoped",messageLimit:4,byteLimit:2048)
        let a = try after.message("a"), b = try after.message("b"), c = try after.message("c"), unknown = try after.message("unknown")
        assert(a == nil && unknown == nil && b != nil && c != nil)
        enum FixtureFailure: Error {case injected}
        do {
            try scoped.batch {try scoped.invalidate(id:"b",through:9);throw FixtureFailure.injected}
        } catch FixtureFailure.injected {}
        let interrupted = try HistoryCache(directory:home,account:"fixture-scoped",messageLimit:4,byteLimit:2048)
        let removed = try interrupted.message("b"), kept = try interrupted.message("c")
        assert(removed == nil && kept != nil)
        var resident = HistoryResidentBudget(countLimit:2,byteLimit:10)
        resident.update("visible",bytes:8);resident.pins=["visible"]
        resident.update("old",bytes:2);resident.update("recent",bytes:4)
        assert(Set(resident.evictions()) == ["old","recent"] && resident.bytes == 8)
        resident.update("visible",bytes:12)
        assert(resident.evictions().isEmpty && resident.excessBytes == 2 && resident.pinnedBytes == 12)
        resident.pins=[]
        assert(resident.evictions() == ["visible"] && resident.bytes == 0)
        resident.update("one",bytes:1);resident.update("two",bytes:1);resident.update("three",bytes:1)
        assert(resident.evictions() == ["one"])
        let preserved = try Data(contentsOf:legacy); assert(preserved == original)
        print("HistoryCache: eviction, revisions, size, restart, account isolation and legacy preservation, scoped invalidation and interrupted batch restart passed")
    }
}
#endif
