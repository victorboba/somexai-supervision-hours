import AppIntents
import Foundation

/// "Log hours in Supervision Hours" opens the app on the entry form.
struct LogHoursIntent: AppIntent {
    static var title: LocalizedStringResource = "Log Hours"
    static var description = IntentDescription("Opens Supervision Hours ready to record a block of hours.")
    static var openAppWhenRun = true

    static let pendingKey = "intent.openLogHours"

    func perform() async throws -> some IntentResult {
        WidgetSnapshot.defaults.set(true, forKey: Self.pendingKey)
        return .result()
    }
}

struct SupervisionHoursShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: LogHoursIntent(), phrases: ["Log hours in \(.applicationName)", "Add hours in \(.applicationName)"],
                    shortTitle: "Log Hours", systemImageName: "clock.badge.checkmark")
    }
}
