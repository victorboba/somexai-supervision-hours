import Foundation
import SwiftData

/// The licensure goal: which license, which board, and the hours it requires. One per user.
/// BACB fieldwork tracks (BCBA, BCaBA) add monthly ratio rules on top of the hour totals.
@Model
final class LicenseTrack {
    var id: UUID = UUID()
    var superviseeName: String = ""
    var licenseTypeRaw: String = LicenseType.lpc.rawValue
    var state: String = ""
    var boardName: String = ""
    var startDate: Date = Date()
    var requiredTotalHours: Double = 3000
    var requiredDirectHours: Double = 1500
    var requiredSupervisionHours: Double = 100
    /// 0 means the board sets no separate individual-supervision minimum.
    var requiredIndividualSupervisionHours: Double = 0
    /// 0 means no weekly cap.
    var maxWeeklyHours: Double = 0
    var notes: String = ""
    var createdAt: Date = Date()

    // MARK: BACB fieldwork rules (used only when licenseType.isFieldwork)
    /// Concentrated Supervised Fieldwork: fewer hours, more supervision.
    var fieldworkConcentrated: Bool = false
    /// Supervision must be at least this percent of each month's fieldwork hours (5, or 10 concentrated).
    var supervisionPercentPerMonth: Double = 5
    /// Unrestricted activities must be at least this percent of all fieldwork hours (60).
    var unrestrictedPercentMin: Double = 60
    /// At least half of supervision must be individual (50).
    var individualSupervisionPercentMin: Double = 50
    /// Supervisor contacts required in each month (4, or 6 concentrated).
    var contactsPerMonth: Int = 4
    /// A supervisor must observe the trainee with a client at least once a month.
    var observationPerMonth: Bool = true
    var minMonthlyHours: Double = 20
    var maxMonthlyHours: Double = 130

    init(licenseType: LicenseType = .lpc, state: String = "") {
        self.id = UUID()
        self.licenseTypeRaw = licenseType.rawValue
        self.state = state
        self.startDate = Calendar.current.startOfDay(for: .now)
        self.createdAt = .now
        if licenseType.isFieldwork { applyFieldworkDefaults() }
    }

    var licenseType: LicenseType {
        get { LicenseType(rawValue: licenseTypeRaw) ?? .other }
        set { licenseTypeRaw = newValue.rawValue }
    }

    var isFieldwork: Bool { licenseType.isFieldwork }

    var title: String {
        let name = licenseType.name
        if isFieldwork { return fieldworkConcentrated ? "\(name) (concentrated)" : name }
        return state.isEmpty ? name : "\(state) \(name)"
    }

    /// BACB numbers as published for the current handbooks. The user can still edit every field.
    func applyFieldworkDefaults() {
        let bcba = licenseType == .bcba
        requiredTotalHours = fieldworkConcentrated ? (bcba ? 1500 : 1000) : (bcba ? 2000 : 1300)
        supervisionPercentPerMonth = fieldworkConcentrated ? 10 : 5
        contactsPerMonth = fieldworkConcentrated ? 6 : 4
        unrestrictedPercentMin = 60
        individualSupervisionPercentMin = 50
        observationPerMonth = true
        minMonthlyHours = 20
        maxMonthlyHours = 130
        requiredDirectHours = 0
        requiredIndividualSupervisionHours = 0
        maxWeeklyHours = 0
        requiredSupervisionHours = (requiredTotalHours * supervisionPercentPerMonth / 100).rounded()
        if boardName.isEmpty { boardName = "Behavior Analyst Certification Board" }
    }
}

enum LicenseType: String, CaseIterable, Identifiable {
    case lpc, lmft, lcsw, psychologist, addiction, bcba, bcaba, other
    var id: String { rawValue }
    var name: String {
        switch self {
        case .lpc: return "LPC / LMHC associate"
        case .lmft: return "LMFT associate"
        case .lcsw: return "LCSW / LMSW"
        case .psychologist: return "Psychology postdoc"
        case .addiction: return "Addiction counselor"
        case .bcba: return "BCBA fieldwork"
        case .bcaba: return "BCaBA fieldwork"
        case .other: return "Other license"
        }
    }
    var short: String {
        switch self {
        case .lpc: return "LPC"
        case .lmft: return "LMFT"
        case .lcsw: return "LCSW"
        case .psychologist: return "Psych"
        case .addiction: return "LCDC"
        case .bcba: return "BCBA"
        case .bcaba: return "BCaBA"
        case .other: return "License"
        }
    }
    /// BACB tracks: restricted/unrestricted categories and monthly ratio rules instead of direct-hour minimums.
    var isFieldwork: Bool { self == .bcba || self == .bcaba }
}
