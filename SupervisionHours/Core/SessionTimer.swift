import Foundation

/// A single running session, persisted in UserDefaults so it survives the app being closed.
struct SessionTimer: Equatable {
    static let startKey = "timer.start"
    static let categoryKey = "timer.category"

    let start: Date
    let category: HourCategory

    static func load(from defaults: UserDefaults = .standard) -> SessionTimer? {
        guard let start = defaults.object(forKey: startKey) as? Date,
              let raw = defaults.string(forKey: categoryKey), let category = HourCategory(rawValue: raw) else { return nil }
        return SessionTimer(start: start, category: category)
    }

    static func begin(_ category: HourCategory, at date: Date = .now, defaults: UserDefaults = .standard) -> SessionTimer {
        defaults.set(date, forKey: startKey)
        defaults.set(category.rawValue, forKey: categoryKey)
        return SessionTimer(start: date, category: category)
    }

    static func clear(defaults: UserDefaults = .standard) {
        defaults.removeObject(forKey: startKey)
        defaults.removeObject(forKey: categoryKey)
    }

    /// Whole minutes since start, never less than 1 so a stopped timer always yields a savable entry.
    func elapsedMinutes(now: Date = .now) -> Int {
        max(1, Int(now.timeIntervalSince(start) / 60))
    }
}
