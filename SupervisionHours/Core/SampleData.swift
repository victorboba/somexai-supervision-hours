import Foundation
import SwiftData

#if DEBUG
/// Debug-only sample data: sixteen weeks of an LPC associate at a community clinic, one supervisor,
/// four client days a week plus Friday supervision. Fictional.
@MainActor
enum SampleData {
    static func insert(into context: ModelContext, fieldwork: Bool = ProcessInfo.processInfo.arguments.contains("-fieldworkSample")) {
        let hasEntries = !((try? context.fetch(FetchDescriptor<HoursEntry>()))?.isEmpty ?? true)
        guard !hasEntries else { return }
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: .now)

        let track = (try? context.fetch(FetchDescriptor<LicenseTrack>()))?.first ?? {
            let t: LicenseTrack
            if fieldwork {
                t = LicenseTrack(licenseType: .bcba)
                t.superviseeName = "Sam Okafor"
            } else {
                t = LicenseTrack(licenseType: .lpc, state: "Texas")
                t.superviseeName = "Jordan Alvarez"
                t.boardName = "Texas State Board of Examiners of Professional Counselors"
                t.requiredTotalHours = 3000
                t.requiredDirectHours = 1500
                t.requiredSupervisionHours = 100
                t.requiredIndividualSupervisionHours = 50
            }
            t.startDate = calendar.date(byAdding: .weekOfYear, value: -16, to: today) ?? today
            context.insert(t)
            return t
        }()
        TrackMode.sync(with: track)

        let supervisors = (try? context.fetch(FetchDescriptor<Supervisor>())) ?? []
        let elena = supervisors.first ?? {
            let s = fieldwork ? Supervisor(name: "Priya Natarajan", credentials: "BCBA-D", licenseNumber: "1-19-41287")
                              : Supervisor(name: "Elena Ruiz", credentials: "LPC-S", licenseNumber: "TX 71234")
            s.email = fieldwork ? "pnatarajan@brightpathaba.org" : "eruiz@riverbendcounseling.org"
            context.insert(s)
            return s
        }()

        let site = fieldwork ? "BrightPath ABA" : "Riverbend Counseling"
        for week in stride(from: 16, through: 0, by: -1) {
            guard let weekStart = calendar.date(byAdding: .weekOfYear, value: -week, to: HoursMath.weekStart(of: today)) else { continue }
            for weekday in 1...5 {   // Monday..Friday relative to the week start (Sunday)
                guard let day = calendar.date(byAdding: .day, value: weekday, to: weekStart), day <= today else { continue }
                let nine = calendar.date(bySettingHour: 9, minute: 0, second: 0, of: day) ?? day
                if weekday <= 4 {
                    let clients = [5, 6, 4, 5][(week + weekday) % 4]
                    // Fieldwork trainees spend most of the day on unrestricted work, so the big block flips category.
                    let direct = HoursEntry(date: nine, category: fieldwork ? .indirect : .direct, minutes: clients * 50, siteName: site, supervisor: elena)
                    direct.clientCount = fieldwork ? nil : clients
                    direct.isVerified = week >= 2
                    if week == 5 && weekday == 2 { direct.notes = fieldwork ? "Skill acquisition programming, parent training." : "Two intakes, one no-show." }
                    context.insert(direct)
                    let indirect = HoursEntry(date: nine.addingTimeInterval(6 * 3600), category: fieldwork ? .direct : .indirect, minutes: [60, 90, 75, 60][(week + weekday) % 4], siteName: site, supervisor: elena)
                    indirect.isVerified = week >= 2
                    if fieldwork { indirect.clientCount = 1 }
                    if weekday == 1 { indirect.notes = fieldwork ? "1:1 session, DTT." : "Notes, treatment plans, case consult." }
                    context.insert(indirect)
                } else {
                    let individual = HoursEntry(date: nine.addingTimeInterval(4 * 3600), category: .supervisionIndividual, minutes: 60, siteName: site, supervisor: elena)
                    individual.isVerified = week >= 2
                    individual.hasObservation = fieldwork && week % 3 == 0
                    if individual.hasObservation { individual.notes = "Observed a session with a client." }
                    context.insert(individual)
                    if week % 2 == 0 {
                        let group = HoursEntry(date: nine.addingTimeInterval(5.5 * 3600), category: .supervisionGroup, minutes: 90, siteName: site, supervisor: elena)
                        group.isVerified = week >= 2
                        group.notes = "Group of four associates."
                        context.insert(group)
                    }
                }
            }
            if week % 4 == 2, let day = calendar.date(byAdding: .day, value: 6, to: weekStart), day <= today {
                let training = HoursEntry(date: calendar.date(bySettingHour: 10, minute: 0, second: 0, of: day) ?? day, category: .training, minutes: 180, siteName: "Online")
                training.notes = "Ethics CE webinar."
                context.insert(training)
            }
        }
        try? context.save()
    }
}
#endif
