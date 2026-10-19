import SwiftUI
import SwiftData

/// Every entry grouped by week with per-category totals, the way boards ask for them.
struct LogView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \LicenseTrack.createdAt) private var tracks: [LicenseTrack]
    @Query(sort: \HoursEntry.date, order: .reverse) private var entries: [HoursEntry]

    @State private var filter: HourCategory?
    @State private var editing: HoursEntry?
    @State private var adding = false

    private var filtered: [HoursEntry] { filter.map { c in entries.filter { $0.category == c } } ?? entries }
    private var track: LicenseTrack? { tracks.first }
    private var byMonth: Bool { track?.isFieldwork ?? false }

    /// Fieldwork is verified per month, so the log groups by month there; everyone else gets weeks.
    private var groups: [HoursMath.Week] {
        if byMonth {
            let grouped = Dictionary(grouping: filtered) { HoursMath.monthStart(of: $0.date) }
            return grouped.keys.sorted(by: >).map { HoursMath.Week(start: $0, entries: (grouped[$0] ?? []).sorted { $0.date > $1.date }) }
        }
        return HoursMath.weeks(filtered)
    }

    var body: some View {
        NavigationStack {
            Group {
                if entries.isEmpty {
                    ContentUnavailableView("No hours yet", systemImage: "calendar", description: Text("Logged hours show up here week by week."))
                } else {
                    List {
                        ForEach(groups) { week in
                            let t = week.totals
                            Section {
                                ForEach(week.entries) { e in
                                    Button { editing = e } label: { EntryRow(entry: e) }.buttonStyle(.plain)
                                }
                                .onDelete { offsets in offsets.map { week.entries[$0] }.forEach(context.delete) }
                            } header: {
                                HStack {
                                    Text(byMonth ? Formatters.monthYear.string(from: week.start) : Formatters.week(week.start))
                                    Spacer()
                                    Text("\(Formatters.hours(t.total))").monospacedDigit()
                                }
                            } footer: {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("\(HourCategory.direct.short) \(Formatters.hours(t.direct, unit: false)) · \(HourCategory.indirect.short) \(Formatters.hours(t.indirect, unit: false)) · Supervision \(Formatters.hours(t.supervision, unit: false))\(t.training > 0 ? " · Training \(Formatters.hours(t.training, unit: false))" : "")")
                                    if byMonth, let track, filter == nil {
                                        let checks = HoursMath.monthlyChecks(track: track, entries: entries, month: week.start)
                                        let failed = checks.filter { !$0.passed }
                                        Text(failed.isEmpty ? "All BACB monthly rules met" : "Not met: " + failed.map { $0.name.lowercased() }.joined(separator: ", "))
                                            .foregroundStyle(failed.isEmpty ? .green : .orange)
                                    }
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle("Log")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Picker("Category", selection: $filter) {
                            Text("All categories").tag(HourCategory?.none)
                            ForEach(HourCategory.allCases) { Text($0.name).tag(Optional($0)) }
                        }
                    } label: { Image(systemName: filter == nil ? "line.3.horizontal.decrease.circle" : "line.3.horizontal.decrease.circle.fill") }
                    .accessibilityLabel("Filter by category")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { adding = true } label: { Image(systemName: "plus") }.accessibilityLabel("Log hours")
                }
            }
            .sheet(item: $editing) { EntryEditorView(entry: $0) }
            .sheet(isPresented: $adding) { EntryEditorView(entry: nil, draft: EntryDraft(category: filter ?? .direct)) }
        }
    }
}
