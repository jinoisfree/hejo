import Foundation

/// A calendar-day pause, never a skipped version or consent to install.
struct UpdateReminder {
    static let key = "updateReminderHiddenUntil"
    var defaults: UserDefaults = .standard
    var calendar: Calendar = .current
    func allowsCheck(manual: Bool, now: Date = Date()) -> Bool {
        manual || now >= (defaults.object(forKey: Self.key) as? Date ?? .distantPast)
    }
    func hideToday(now: Date = Date()) {
        defaults.set(calendar.date(byAdding: .day, value: 1, to: calendar.startOfDay(for: now))!, forKey: Self.key)
    }
}
enum UpdateNoticePolicy {
    static func allows(manual: Bool, enabled: Bool, reminderAllows: Bool) -> Bool { manual || (enabled && reminderAllows) }
}
struct UpdateNoticeSettings {
    static let key = "updateNotices"
    var defaults: UserDefaults = .standard
    var enabled: Bool { defaults.object(forKey: Self.key) as? Bool ?? true }
    func setEnabled(_ enabled: Bool) { defaults.set(enabled, forKey: Self.key) }
}
/// Only launching the expected installed build consumes the marker.
struct UpdateInstallation {
    var defaults: UserDefaults = .standard
    func preparing(version: String, build: String) {
        defaults.set(version, forKey: "updatePendingVersion"); defaults.set(build, forKey: "updatePendingBuild")
    }
    func cancelled() {
        defaults.removeObject(forKey: "updatePendingVersion"); defaults.removeObject(forKey: "updatePendingBuild")
    }
    func installed(version: String, build: String) -> Bool {
        guard defaults.string(forKey: "updatePendingVersion") == version,
              defaults.string(forKey: "updatePendingBuild") == build else { return false }
        cancelled(); return true
    }
}
