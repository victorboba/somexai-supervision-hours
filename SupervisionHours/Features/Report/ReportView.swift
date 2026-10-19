import SwiftUI
import SwiftData

struct ReportView: View {
    @Query(sort: \LicenseTrack.createdAt) private var tracks: [LicenseTrack]
    @Query(sort: \Supervisor.createdAt) private var supervisors: [Supervisor]
    @Query(sort: \HoursEntry.date, order: .reverse) private var entries: [HoursEntry]

    @State private var month: Date? = nil       // nil = all time
    @State private var exportFile: ExportFile?
    @State private var exportError: String?

    private var track: LicenseTrack? { tracks.first }
    private var months: [Date] { HoursMath.months(entries) }
    private var range: (start: Date, end: Date, label: String) {
        if let month, let interval = Calendar.current.dateInterval(of: .month, for: month) {
            return (interval.start, min(interval.end.addingTimeInterval(-1), .now), Formatters.monthYear.string(from: month))
        }
        let start = track?.startDate ?? entries.last?.date ?? .now
        return (min(start, entries.last?.date ?? start), .now, "All time")
    }
    private var selected: [HoursEntry] { HoursMath.between(entries, from: range.start, to: range.end) }

    var body: some View {
        NavigationStack {
            Group {
                if let track {
                    List {
                        Section {
                            Picker("Period", selection: $month) {
                                Text("All time").tag(Date?.none)
                                ForEach(months, id: \.self) { Text(Formatters.monthYear.string(from: $0)).tag(Optional($0)) }
                            }
                        }
                        let t = HoursMath.totals(selected)
                        Section("\(range.label) · \(selected.count) entr\(selected.count == 1 ? "y" : "ies")") {
                            ForEach(HourCategory.allCases) { c in
                                LabeledContent(c.name, value: Formatters.hours(t.hours(for: c))).monospacedDigit()
                            }
                            LabeledContent("Total counted", value: Formatters.hours(t.total)).font(.headline).monospacedDigit()
                        }
                        Section("Progress (all time)") {
                            ForEach(HoursMath.requirements(track: track, totals: HoursMath.totals(entries))) { r in
                                LabeledContent(r.name, value: "\(Formatters.hours(r.done, unit: false)) of \(Formatters.hours(r.required))").monospacedDigit()
                            }
                        }
                        Section("Export") {
                            Button {
                                export { try ReportExporter.export(track: track, supervisors: supervisors, entries: entries, from: range.start, to: range.end, periodLabel: range.label) }
                            } label: { Label("PDF log with signature lines", systemImage: "signature") }
                            Button { export { try CSVExporter.export(selected, suffix: month == nil ? "all" : Formatters.monthYear.string(from: month!).replacingOccurrences(of: " ", with: "-").lowercased()) } } label: {
                                Label("CSV of these entries", systemImage: "tablecells")
                            }
                            .disabled(selected.isEmpty)
                        }
                        Section { Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary) }
                    }
                } else {
                    ContentUnavailableView("No track set up yet", systemImage: "signature", description: Text("Set it up on Progress to start a report."))
                }
            }
            .navigationTitle("Report")
            .sheet(item: $exportFile) { ShareSheet(url: $0.url) }
            .alert("Export failed", isPresented: Binding(get: { exportError != nil }, set: { if !$0 { exportError = nil } })) {
                Button("OK") { exportError = nil }
            } message: { Text(exportError ?? "") }
        }
    }

    private func export(_ make: () throws -> URL) {
        do { exportFile = ExportFile(url: try make()) } catch { exportError = error.localizedDescription }
    }
}
