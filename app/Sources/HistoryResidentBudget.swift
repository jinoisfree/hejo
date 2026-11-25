import Foundation

/// Serialized resident-body budget, not a measurement of process RSS or AppKit layout memory.
/// Visible/explicitly opened bodies may exceed it; their excess remains observable.
struct HistoryResidentBudget {
    static let maximumBytes = 10 * 512 * 1024
    var countLimit = HistoryCache.maximumMessages
    var byteLimit = maximumBytes
    var pins = Set<String>()
    private var sizes: [String:Int] = [:]
    private var used: [String:UInt64] = [:]
    private var clock: UInt64 = 0
    var ids: Dictionary<String,Int>.Keys {sizes.keys}
    var bytes: Int { sizes.values.reduce(0,+) }
    var pinnedBytes: Int { pins.reduce(0) { $0 + (sizes[$1] ?? 0) } }
    var excessBytes: Int { max(0, bytes-byteLimit) }
    mutating func update(_ id:String, bytes:Int?) {
        sizes[id] = bytes
        if bytes != nil {clock &+= 1;used[id] = clock} else {used[id] = nil}
    }
    mutating func evictions() -> [String] {
        var result=[String]()
        for id in sizes.keys.filter({!pins.contains($0)}).sorted(by:{(used[$0] ?? 0) < (used[$1] ?? 0)}) {
            if sizes.count <= countLimit && bytes <= byteLimit {break}
            result.append(id);sizes[id]=nil;used[id]=nil
        }
        return result
    }
}
