import Foundation
import UserNotifications

/// A repeating local notification once a week to log the week's hours. Default: Friday 5 pm.
enum WeeklyReminder {
    static let enabledKey = "reminder.weekly.enabled"
    static let weekdayKey = "reminder.weekly.weekday"   // 1 = Sunday … 7 = Saturday
    static let hourKey = "reminder.weekly.hour"
    static let identifier = "weekly.log"

    static var isEnabled: Bool { UserDefaults.standard.bool(forKey: enabledKey) }
    static var weekday: Int { let v = UserDefaults.standard.integer(forKey: weekdayKey); return (1...7).contains(v) ? v : 6 }
    static var hour: Int { UserDefaults.standard.object(forKey: hourKey) == nil ? 17 : UserDefaults.standard.integer(forKey: hourKey) }

    static func ensurePermission() async -> Bool {
        let center = UNUserNotificationCenter.current()
        switch await center.notificationSettings().authorizationStatus {
        case .notDetermined: return (try? await center.requestAuthorization(options: [.alert, .sound])) ?? false
        case .denied: return false
        default: return true
        }
    }

    static func reschedule() async {
        let center = UNUserNotificationCenter.current()
        center.removePendingNotificationRequests(withIdentifiers: [identifier])
        guard isEnabled, await ensurePermission() else { return }
        var components = DateComponents()
        components.weekday = weekday
        components.hour = hour
        components.minute = 0
        let content = UNMutableNotificationContent()
        content.title = AppConfig.appName
        content.body = "Log this week's hours while they're fresh."
        content.sound = .default
        try? await center.add(UNNotificationRequest(identifier: identifier, content: content,
                                                     trigger: UNCalendarNotificationTrigger(dateMatching: components, repeats: true)))
    }

    static func cancel() {
        UNUserNotificationCenter.current().removePendingNotificationRequests(withIdentifiers: [identifier])
    }
}
