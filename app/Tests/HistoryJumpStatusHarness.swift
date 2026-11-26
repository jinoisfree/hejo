#if HEJO_HISTORY_TRANSPORT_TEST
import AppKit

@MainActor enum HistoryJumpStatusHarness {
    static func labels(in view:NSView) -> [String] {
        guard !view.isHiddenOrHasHiddenAncestor else { return [] }
        return [view.accessibilityLabel(),(view as? NSTextField)?.stringValue].compactMap { $0 }
            + view.subviews.flatMap { labels(in:$0) }
    }

    static func saveScreenshot(of view:NSView,named name:String) throws {
        guard ProcessInfo.processInfo.environment["JUMP_ONCE_CAPTURE_PNG"] == "1" else { return }
        view.layoutSubtreeIfNeeded()
        guard let bitmap = view.bitmapImageRepForCachingDisplay(in:view.bounds) else {
            throw HistoryFailure.server("AT-JO-15 missing view bitmap",retryable:false)
        }
        view.cacheDisplay(in:view.bounds,to:bitmap)
        guard let png = bitmap.representation(using:.png,properties:[:]) else {
            throw HistoryFailure.server("AT-JO-15 PNG encoding failed",retryable:false)
        }
        let directory = URL(fileURLWithPath:".build/jump-once",isDirectory:true)
        try FileManager.default.createDirectory(at:directory,withIntermediateDirectories:true)
        try png.write(to:directory.appendingPathComponent(name+".png"),options:.atomic)
    }

    static func cardOrigin(in drawer:TodoDrawerView) -> CGFloat? {
        guard let card = drawer.cardViews.first else { return nil }
        return card.convert(card.bounds,to:nil).minY
    }
}
#endif
