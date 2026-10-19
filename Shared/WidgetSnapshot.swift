import Foundation

/// Summary the app writes to the shared App Group so the widget can render without SwiftData.
struct WidgetSnapshot: Codable {
    var hasTrack: Bool = false
    var trackName: String = ""
    var totalHours: Double = 0
    var requiredTotalHours: Double = 0
    var directHours: Double = 0
    var requiredDirectHours: Double = 0
    var supervisionHours: Double = 0
    var requiredSupervisionHours: Double = 0
    var weekHours: Double = 0
    var projectedFinish: Date?
    var updatedAt: Date = .now

    var totalFraction: Double { requiredTotalHours > 0 ? min(totalHours / requiredTotalHours, 1) : 0 }

    static let storageKey = "widget.snapshot"

    static var defaults: UserDefaults {
        UserDefaults(suiteName: AppConfig.appGroupID) ?? .standard
    }

    static func load() -> WidgetSnapshot {
        guard let data = defaults.data(forKey: storageKey),
              let snapshot = try? JSONDecoder().decode(WidgetSnapshot.self, from: data) else { return WidgetSnapshot() }
        return snapshot
    }

    func save() {
        guard let data = try? JSONEncoder().encode(self) else { return }
        Self.defaults.set(data, forKey: Self.storageKey)
    }

    static let placeholder = WidgetSnapshot(hasTrack: true, trackName: "LPC Associate", totalHours: 1240, requiredTotalHours: 3000,
                                            directHours: 690, requiredDirectHours: 1500, supervisionHours: 48, requiredSupervisionHours: 100,
                                            weekHours: 27.5, projectedFinish: Calendar.current.date(byAdding: .month, value: 14, to: .now))
}
