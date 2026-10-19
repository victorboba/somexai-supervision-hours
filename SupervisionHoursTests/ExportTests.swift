import XCTest
import SwiftData
import PDFKit
@testable import SupervisionHours

@MainActor
final class ExportTests: XCTestCase {
    private var container: ModelContainer!

    override func setUpWithError() throws {
        container = try ModelContainer(for: LicenseTrack.self, Supervisor.self, HoursEntry.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
    }

    private func sample() -> (LicenseTrack, Supervisor, [HoursEntry]) {
        let track = LicenseTrack(licenseType: .lpc, state: "Texas")
        track.superviseeName = "Jordan Alvarez"
        let sup = Supervisor(name: "Elena Ruiz", credentials: "LPC-S", licenseNumber: "TX 71234")
        container.mainContext.insert(track)
        container.mainContext.insert(sup)
        let a = HoursEntry(date: Date(timeIntervalSince1970: 1_760_000_000), category: .direct, minutes: 250, siteName: "Riverbend Counseling", supervisor: sup)
        a.clientCount = 5
        a.isVerified = true
        a.notes = "Two intakes, \"one no-show\""
        let b = HoursEntry(date: Date(timeIntervalSince1970: 1_760_300_000), category: .supervisionIndividual, minutes: 60, siteName: "Riverbend Counseling", supervisor: sup)
        let c = HoursEntry(date: Date(timeIntervalSince1970: 1_760_400_000), category: .training, minutes: 180, siteName: "Online")
        [a, b, c].forEach { container.mainContext.insert($0) }
        return (track, sup, [a, b, c])
    }

    func testCSVHasHeaderAndOneRowPerEntry() {
        let (_, _, entries) = sample()
        let lines = CSVExporter.csv(entries).split(separator: "\n")
        XCTAssertEqual(lines.count, 4)
        XCTAssertEqual(lines[0], "date,category,hours,minutes,site,supervisor,clients,verified,notes")
        XCTAssertTrue(lines[1].contains("\"Direct client contact\",\"4.17\",\"250\",\"Riverbend Counseling\",\"Elena Ruiz, LPC-S\",\"5\",\"yes\",\"Two intakes, \"\"one no-show\"\"\""))
        XCTAssertTrue(lines[3].contains("\"Training / CE\",\"3.00\",\"180\",\"Online\",\"\",\"\",\"no\""))
    }

    func testPDFLogRendersTablesAndSignatures() throws {
        let (track, sup, entries) = sample()
        let url = try ReportExporter.export(track: track, supervisors: [sup], entries: entries, from: .distantPast, to: .now, periodLabel: "All time")
        let document = try XCTUnwrap(PDFDocument(url: url))
        let text = (0..<document.pageCount).compactMap { document.page(at: $0)?.string }.joined()
        XCTAssertTrue(text.contains("Supervised experience log"))
        XCTAssertTrue(text.contains("Jordan Alvarez"))
        XCTAssertTrue(text.contains("Elena Ruiz, LPC-S"))
        XCTAssertTrue(text.contains("TX 71234"))
        XCTAssertTrue(text.contains("excludes training"))
        XCTAssertTrue(text.contains("Supervisor signature"))
        XCTAssertTrue(text.contains("Riverbend"))
    }
}
