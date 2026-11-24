#if HEJO_PERF_TESTING
import AppKit

/// Test-only observations of production rendering and the actual transition timer.
enum HejoSmoothProbe {
    static var dates=0
    static var memberMerges=0
    static var assessmentInputs:[String:Int]=[:]
    static let profiling=ProcessInfo.processInfo.environment["HEJO_TRANSITION_PROFILE"]=="1"
    static var events:[[String:Any]]=[]
    static func event(_ name:String,_ start:Double,_ end:Double=ProcessInfo.processInfo.systemUptime) {
        if profiling {events.append(["name":name,"start":start,"end":end])}
    }
    static var bodies: [String: Int] = [:]
    static var thinking:[String:Int]=[:],times:[String:Int]=[:]
    static var assessments: [String:Int] = [:]
    static var calendars: [String:Int] = [:]
    static var heights: [String: Int] = [:]
    static var bodyIDs: [ObjectIdentifier: (text: NSAttributedString, id: String)] = [:]
    static var refreshes = 0
    static var scrollStarts = 0
    static var phases: [String: [Double]] = [:]
    static var transitionStart: Double?
    static var transitionSteps: [Double] = []
    static var transitionEnd: Double?
    static var snapshot: (() -> Void)?
    static var started: (() -> Void)?
    static func reset() {
        dates=0;memberMerges=0;assessmentInputs=[:]
        bodies = [:]; heights = [:]; calendars = [:]; assessments = [:]; thinking=[:]; times=[:]; bodyIDs = [:]; refreshes = 0; scrollStarts = 0; phases = [:]
    }
    static func identify(_ text: NSAttributedString, id: String) { bodyIDs[ObjectIdentifier(text)] = (text, id) }
    static func measured(_ text: NSAttributedString) {
        if let id = bodyIDs[ObjectIdentifier(text)] { heights[id.id, default: 0] += 1 }
    }
    static func beginTransition() {
        transitionStart = ProcessInfo.processInfo.systemUptime
        transitionSteps = []; transitionEnd = nil; started?()
    }
}
#endif
