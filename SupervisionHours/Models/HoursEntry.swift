import Foundation
import SwiftData

/// One block of logged time. Minutes are stored; hours are derived everywhere else.
@Model
final class HoursEntry {
    var id: UUID = UUID()
    var date: Date = Date()
    var categoryRaw: String = HourCategory.direct.rawValue
    var minutes: Int = 60
    var siteName: String = ""
    var supervisorID: UUID? = nil
    /// Copied at save time so exports survive a deleted supervisor.
    var supervisorName: String = ""
    var clientCount: Int? = nil
    /// Set when the supervisor has initialed or signed off this block.
    var isVerified: Bool = false
    /// Fieldwork: the supervisor observed the trainee working with a client during this supervision.
    var hasObservation: Bool = false
    var notes: String = ""
    var createdAt: Date = Date()

    init(date: Date = .now, category: HourCategory, minutes: Int, siteName: String = "", supervisor: Supervisor? = nil) {
        self.id = UUID()
        self.date = date
        self.categoryRaw = category.rawValue
        self.minutes = minutes
        self.siteName = siteName
        self.supervisorID = supervisor?.id
        self.supervisorName = supervisor?.title ?? ""
        self.createdAt = .now
    }

    var category: HourCategory {
        get { HourCategory(rawValue: categoryRaw) ?? .direct }
        set { categoryRaw = newValue.rawValue }
    }

    var hours: Double { Double(minutes) / 60 }
    var day: Date { Calendar.current.startOfDay(for: date) }
}

/// The categories licensing boards ask for. Training is kept for the record but not counted toward the total.
/// On BACB fieldwork tracks the first two read as restricted and unrestricted activities.
enum HourCategory: String, CaseIterable, Identifiable {
    case direct, indirect, supervisionIndividual, supervisionGroup, training
    var id: String { rawValue }

    var name: String { name(fieldwork: TrackMode.isFieldwork) }
    var short: String { short(fieldwork: TrackMode.isFieldwork) }

    func name(fieldwork: Bool) -> String {
        switch self {
        case .direct: return fieldwork ? "Restricted activities" : "Direct client contact"
        case .indirect: return fieldwork ? "Unrestricted activities" : "Indirect / other clinical"
        case .supervisionIndividual: return "Individual supervision"
        case .supervisionGroup: return "Group supervision"
        case .training: return "Training / CE"
        }
    }

    func short(fieldwork: Bool) -> String {
        switch self {
        case .direct: return fieldwork ? "Restricted" : "Direct"
        case .indirect: return fieldwork ? "Unrestricted" : "Indirect"
        case .supervisionIndividual: return "Indiv. sup."
        case .supervisionGroup: return "Group sup."
        case .training: return "Training"
        }
    }

    /// What the category covers, shown under the picker so a trainee files things the way the BACB does.
    var hint: String? {
        guard TrackMode.isFieldwork else { return nil }
        switch self {
        case .direct: return "Delivering therapeutic or instructional procedures directly to clients."
        case .indirect: return "Assessment, program design, data analysis, training others, meetings, research."
        default: return nil
        }
    }

    var symbol: String {
        switch self {
        case .direct: return "person.2"
        case .indirect: return "doc.text"
        case .supervisionIndividual: return "person.badge.shield.checkmark"
        case .supervisionGroup: return "person.3"
        case .training: return "graduationcap"
        }
    }

    var isSupervision: Bool { self == .supervisionIndividual || self == .supervisionGroup }
    var countsTowardTotal: Bool { self != .training }
    /// Default block when tapping the quick-add button, in minutes.
    var defaultMinutes: Int {
        switch self {
        case .direct: return 50
        case .indirect: return 30
        case .supervisionIndividual: return 60
        case .supervisionGroup: return 90
        case .training: return 60
        }
    }
}
