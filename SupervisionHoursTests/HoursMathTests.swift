import XCTest
import SwiftData
@testable import SupervisionHours

@MainActor
final class HoursMathTests: XCTestCase {
    private var container: ModelContainer!
    private let cal = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        container = try ModelContainer(for: LicenseTrack.self, Supervisor.self, HoursEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    /// Wednesday 2026-09-16 at noon.
    private var now: Date { cal.date(from: DateComponents(year: 2026, month: 9, day: 16, hour: 12))! }
    private func day(_ offset: Int) -> Date { cal.date(byAdding: .day, value: offset, to: now)! }

    private func entry(_ offset: Int, _ category: HourCategory, _ minutes: Int) -> HoursEntry {
        let e = HoursEntry(date: day(offset), category: category, minutes: minutes, siteName: "Riverbend")
        container.mainContext.insert(e)
        return e
    }

    func testTotalsExcludeTraining() {
        let t = HoursMath.totals([entry(0, .direct, 90), entry(0, .indirect, 30), entry(-1, .supervisionIndividual, 60), entry(-1, .supervisionGroup, 90), entry(-2, .training, 180)])
        XCTAssertEqual(t.direct, 1.5, accuracy: 0.001)
        XCTAssertEqual(t.indirect, 0.5, accuracy: 0.001)
        XCTAssertEqual(t.supervision, 2.5, accuracy: 0.001)
        XCTAssertEqual(t.training, 3, accuracy: 0.001)
        XCTAssertEqual(t.total, 4.5, accuracy: 0.001)
    }

    func testWeeksGroupByCalendarWeekNewestFirst() {
        // Wednesday (0), Monday (-2) share a week; the previous Saturday (-4) is the week before.
        let weeks = HoursMath.weeks([entry(0, .direct, 60), entry(-2, .direct, 60), entry(-4, .direct, 60)], calendar: cal)
        XCTAssertEqual(weeks.count, 2)
        XCTAssertEqual(weeks[0].entries.count, 2)
        XCTAssertEqual(weeks[0].totals.total, 2, accuracy: 0.001)
        XCTAssertEqual(weeks[0].start, cal.date(from: DateComponents(year: 2026, month: 9, day: 13)))
        XCTAssertEqual(HoursMath.inWeek([entry(0, .direct, 60), entry(-4, .direct, 60)], of: now, calendar: cal).count, 1)
    }

    func testRequirementsAndFraction() {
        let track = LicenseTrack(licenseType: .lpc, state: "TX")
        track.requiredIndividualSupervisionHours = 50
        var totals = HoursMath.Totals()
        totals.direct = 750; totals.indirect = 200; totals.supervisionIndividual = 30; totals.supervisionGroup = 10
        let reqs = HoursMath.requirements(track: track, totals: totals)
        XCTAssertEqual(reqs.map(\.name), ["Total hours", "Direct client contact", "Supervision", "Individual supervision"])
        XCTAssertEqual(reqs[0].done, 990, accuracy: 0.001)
        XCTAssertEqual(reqs[0].fraction, 0.33, accuracy: 0.001)
        XCTAssertEqual(reqs[1].fraction, 0.5, accuracy: 0.001)
        XCTAssertEqual(reqs[2].remaining, 60, accuracy: 0.001)
        XCTAssertFalse(reqs[3].isMet)
    }

    func testPaceProjectsSlowestRequirement() {
        let track = LicenseTrack(licenseType: .lpc)
        track.requiredTotalHours = 100
        track.requiredDirectHours = 50
        track.requiredSupervisionHours = 10
        // Two weeks sampled: 20 hr direct per week, 1 hr supervision per week.
        var entries: [HoursEntry] = []
        for w in 0..<2 {
            entries.append(entry(-7 * w, .direct, 20 * 60))
            entries.append(entry(-7 * w, .supervisionIndividual, 60))
        }
        let pace = HoursMath.pace(track: track, entries: entries, now: now, calendar: cal)
        XCTAssertEqual(pace.weeksSampled, 2)
        XCTAssertEqual(pace.hoursPerWeek, 21, accuracy: 0.001)
        // Total: 58 remaining at 21/wk ≈ 2.8 wk. Supervision: 8 remaining at 1/wk = 8 wk → limiting.
        XCTAssertEqual(pace.limitingRequirement, "Supervision")
        let weekStart = cal.date(from: DateComponents(year: 2026, month: 9, day: 13))!
        XCTAssertEqual(pace.projectedFinish, cal.date(byAdding: .day, value: 56, to: weekStart))
    }

    func testPaceWithNoEntries() {
        let pace = HoursMath.pace(track: LicenseTrack(), entries: [], now: now, calendar: cal)
        XCTAssertNil(pace.projectedFinish)
        XCTAssertEqual(pace.hoursPerWeek, 0)
    }

    func testRecentSitesAreDistinctNewestFirst() {
        let a = entry(-3, .direct, 60); a.siteName = "Riverbend"
        let b = entry(-1, .direct, 60); b.siteName = "Hope Clinic"
        let c = entry(0, .direct, 60); c.siteName = "Riverbend"
        XCTAssertEqual(HoursMath.recentSites([a, b, c]), ["Riverbend", "Hope Clinic"])
    }

    func testSessionTimerRoundTrip() {
        let defaults = UserDefaults(suiteName: "HoursMathTests")!
        defaults.removePersistentDomain(forName: "HoursMathTests")
        XCTAssertNil(SessionTimer.load(from: defaults))
        let t = SessionTimer.begin(.direct, at: now, defaults: defaults)
        XCTAssertEqual(SessionTimer.load(from: defaults), t)
        XCTAssertEqual(t.elapsedMinutes(now: now.addingTimeInterval(50 * 60 + 30)), 50)
        XCTAssertEqual(t.elapsedMinutes(now: now), 1)
        SessionTimer.clear(defaults: defaults)
        XCTAssertNil(SessionTimer.load(from: defaults))
    }

    func testFormatters() {
        XCTAssertEqual(Formatters.duration(minutes: 90), "1 hr 30 min")
        XCTAssertEqual(Formatters.duration(minutes: 50), "50 min")
        XCTAssertEqual(Formatters.duration(minutes: 120), "2 hr")
        XCTAssertEqual(Formatters.hours(1240), "1,240 hr")
        XCTAssertEqual(Formatters.hours(12.5), "12.5 hr")
        XCTAssertEqual(Formatters.hours(0.25, unit: false), "0.2")
        XCTAssertEqual(Formatters.plainHours(minutes: 90), "1.50")
    }
}
