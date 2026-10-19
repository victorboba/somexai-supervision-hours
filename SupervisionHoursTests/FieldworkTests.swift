import XCTest
import SwiftData
@testable import SupervisionHours

@MainActor
final class FieldworkTests: XCTestCase {
    private var container: ModelContainer!
    private let cal = Calendar(identifier: .gregorian)

    override func setUpWithError() throws {
        container = try ModelContainer(for: LicenseTrack.self, Supervisor.self, HoursEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private var month: Date { cal.date(from: DateComponents(year: 2026, month: 9, day: 1))! }
    private func entry(day: Int, _ category: HourCategory, _ minutes: Int, observed: Bool = false) -> HoursEntry {
        let e = HoursEntry(date: cal.date(from: DateComponents(year: 2026, month: 9, day: day, hour: 10))!, category: category, minutes: minutes)
        e.hasObservation = observed
        container.mainContext.insert(e)
        return e
    }

    func testBCBADefaults() {
        let t = LicenseTrack(licenseType: .bcba)
        XCTAssertEqual(t.requiredTotalHours, 2000)
        XCTAssertEqual(t.supervisionPercentPerMonth, 5)
        XCTAssertEqual(t.contactsPerMonth, 4)
        XCTAssertEqual(t.requiredSupervisionHours, 100)
        XCTAssertEqual(t.requiredDirectHours, 0)
        XCTAssertTrue(t.isFieldwork)
        t.fieldworkConcentrated = true
        t.applyFieldworkDefaults()
        XCTAssertEqual(t.requiredTotalHours, 1500)
        XCTAssertEqual(t.supervisionPercentPerMonth, 10)
        XCTAssertEqual(t.contactsPerMonth, 6)
        XCTAssertEqual(t.requiredSupervisionHours, 150)
        XCTAssertEqual(LicenseTrack(licenseType: .bcaba).requiredTotalHours, 1300)
        XCTAssertTrue(LicenseTrack(licenseType: .lpc).requiredDirectHours > 0)
        XCTAssertTrue(HoursMath.monthlyChecks(track: LicenseTrack(licenseType: .lpc), entries: [entry(day: 1, .direct, 60)], month: month, calendar: cal).isEmpty)
    }

    func testMonthMeetsEveryRule() {
        let t = LicenseTrack(licenseType: .bcba)
        // 100 hours: 30 restricted, 64 unrestricted, 6 supervision (4 individual contacts + 1 group), one observation.
        var e: [HoursEntry] = [entry(day: 1, .direct, 30 * 60), entry(day: 2, .indirect, 64 * 60)]
        for d in [5, 12, 19, 26] { e.append(entry(day: d, .supervisionIndividual, 60, observed: d == 12)) }
        e.append(entry(day: 15, .supervisionGroup, 120))
        let checks = HoursMath.monthlyChecks(track: t, entries: e, month: month, calendar: cal)
        XCTAssertEqual(checks.map(\.name), ["Hours this month", "Supervision share", "Individual share of supervision", "Supervisor contacts", "Client observation"])
        XCTAssertTrue(checks.allSatisfy(\.passed), checks.filter { !$0.passed }.map(\.value).joined(separator: "; "))
        XCTAssertEqual(checks[1].value, "6% (min 5%)")
        XCTAssertEqual(checks[3].value, "5 (min 4)")
        let ratios = HoursMath.ratioRequirements(track: t, totals: HoursMath.totals(e))
        XCTAssertEqual(ratios.count, 2)
        XCTAssertTrue(ratios[0].passed)   // 64% unrestricted
    }

    func testMonthFailsSupervisionShareContactsAndObservation() {
        let t = LicenseTrack(licenseType: .bcba)
        // 100 hours with only 3 hours of supervision in 3 contacts, no observation, too much restricted work.
        var e: [HoursEntry] = [entry(day: 1, .direct, 60 * 60), entry(day: 2, .indirect, 37 * 60)]
        for d in [5, 12, 19] { e.append(entry(day: d, .supervisionIndividual, 60)) }
        let checks = HoursMath.monthlyChecks(track: t, entries: e, month: month, calendar: cal)
        let failed = Set(checks.filter { !$0.passed }.map(\.name))
        XCTAssertEqual(failed, ["Supervision share", "Supervisor contacts", "Client observation"])
        let ratios = HoursMath.ratioRequirements(track: t, totals: HoursMath.totals(e))
        XCTAssertFalse(ratios[0].passed)  // 37% unrestricted
    }

    func testMonthlyHoursOutsideRangeFails() {
        let t = LicenseTrack(licenseType: .bcba)
        let checks = HoursMath.monthlyChecks(track: t, entries: [entry(day: 1, .indirect, 10 * 60), entry(day: 3, .supervisionIndividual, 60)], month: month, calendar: cal)
        XCTAssertFalse(checks[0].passed)
        XCTAssertEqual(checks[0].value, "11 hr (20–130 hr)")
    }

    func testCategoryLabelsFollowTrackMode() {
        TrackMode.isFieldwork = true
        XCTAssertEqual(HourCategory.direct.name, "Restricted activities")
        XCTAssertEqual(HourCategory.indirect.short, "Unrestricted")
        XCTAssertNotNil(HourCategory.indirect.hint)
        TrackMode.isFieldwork = false
        XCTAssertEqual(HourCategory.direct.name, "Direct client contact")
        XCTAssertNil(HourCategory.direct.hint)
        XCTAssertEqual(HourCategory.direct.name(fieldwork: true), "Restricted activities")
    }
}
