import Foundation

/// Presentation state; the journal and the member settings remain the only durable sources.
struct PetActivity {
    enum Pose: Equatable { case idle, phone, laptop, wave, failure, doze }
    static let idleDelay: TimeInterval = 180
    static let waveDuration: TimeInterval = 0.7
    private(set) var lastActivity: TimeInterval
    private var waveUntil: TimeInterval = -.infinity
    init(now: TimeInterval) { lastActivity = now }
    mutating func touch(now: TimeInterval) { lastActivity = now }
    mutating func sent(now: TimeInterval) { lastActivity = now; waveUntil = now + Self.waveDuration }
    func pose(now: TimeInterval, asked: Bool, typing: Bool, failed: Bool, paused: Bool) -> Pose {
        if paused { return .idle }
        if failed { return .failure }
        if asked { return .phone }
        if now < waveUntil { return .wave }
        if typing { return .laptop }
        if now - lastActivity >= Self.idleDelay { return .doze }
        return .idle
    }
}
