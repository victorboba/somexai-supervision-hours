import Foundation

enum Formatters {
    static let dateTime: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .short
        return f
    }()

    static let date: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    /// "Wed, Sep 16"
    static let weekdayShort: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "EEE, MMM d"
        return f
    }()

    /// "Sep 6"
    static let short: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "MMM d"
        return f
    }()

    /// "September 2026"
    static let monthYear: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "LLLL yyyy"
        return f
    }()

    /// "1 hr 30 min" / "50 min" / "3 hr"
    static func duration(minutes: Int) -> String {
        let h = minutes / 60, m = minutes % 60
        if h == 0 { return "\(m) min" }
        return m == 0 ? "\(h) hr" : "\(h) hr \(m) min"
    }

    /// "12.5 hr" / "1,240 hr": decimal hours, the unit boards total in.
    static func hours(_ hours: Double, unit: Bool = true) -> String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = 1
        n.minimumFractionDigits = 0
        let s = n.string(from: NSNumber(value: hours)) ?? String(format: "%.1f", hours)
        return unit ? "\(s) hr" : s
    }

    /// "5%" / "62.5%"
    static func percent(_ p: Double) -> String {
        p == p.rounded() ? "\(Int(p))%" : String(format: "%.1f%%", p)
    }

    /// Plain "1.50" for CSV cells.
    static func plainHours(minutes: Int) -> String { String(format: "%.2f", Double(minutes) / 60) }

    /// "Week of Sep 6"
    static func week(_ start: Date) -> String { "Week of \(short.string(from: start))" }
}
