import UserNotifications

/// One daily evening check-in. A diary is only as good as its gaps: headaches
/// that weren't logged are the ones that skew the monthly count.
enum NotificationService {
    nonisolated static let idPrefix = "checkin-reminder-"
    static let defaultEvening = 21 * 60

    static func requestPermission() async -> Bool {
        (try? await UNUserNotificationCenter.current().requestAuthorization(options: [.alert, .sound])) ?? false
    }

    /// Replaces every pending reminder with one per time in `minutes`.
    /// Reminders are the only notifications this app schedules.
    static func schedule(minutes: [Int]) {
        let center = UNUserNotificationCenter.current()
        center.removeAllPendingNotificationRequests()
        requests(minutes: minutes).forEach { center.add($0) }
    }

    // MARK: Request builders (pure, unit-tested)

    nonisolated static func requests(minutes: [Int]) -> [UNNotificationRequest] {
        Set(minutes).sorted().map { m in
            let content = UNMutableNotificationContent()
            content.title = "Migraine Log"
            content.body = "Any headache today? Log it while you remember, so your monthly count stays right."
            content.sound = .default
            let trigger = UNCalendarNotificationTrigger(dateMatching: DateComponents(hour: m / 60, minute: m % 60), repeats: true)
            return UNNotificationRequest(identifier: "\(idPrefix)\(m)", content: content, trigger: trigger)
        }
    }
}
