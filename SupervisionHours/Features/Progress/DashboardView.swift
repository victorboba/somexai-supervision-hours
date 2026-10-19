import SwiftUI
import SwiftData

/// A prefilled new entry: which category, and how long if it came from the timer.
struct EntryDraft: Identifiable {
    let category: HourCategory
    var minutes: Int? = nil
    var date: Date = .now
    var id: String { "\(category.rawValue)-\(date.timeIntervalSince1970)" }
}

/// Home: progress against each requirement, this week, pace, the session timer and quick-add buttons.
struct DashboardView: View {
    @Environment(\.modelContext) private var context
    @Environment(\.scenePhase) private var scenePhase
    @Query(sort: \LicenseTrack.createdAt) private var tracks: [LicenseTrack]
    @Query(sort: \HoursEntry.date, order: .reverse) private var entries: [HoursEntry]

    @State private var draft: EntryDraft?
    @State private var editingTrack = false
    @State private var showingSettings = false
    @State private var timer: SessionTimer? = SessionTimer.load()

    private var track: LicenseTrack? { tracks.first }

    var body: some View {
        NavigationStack {
            ScrollView {
                if let track {
                    VStack(spacing: 14) {
                        headerPanel(track)
                        quickAdd
                        if track.isFieldwork { monthPanel(track) }
                        timerPanel
                        requirementsPanel(track)
                        weekPanel(track)
                        pacePanel(track)
                        Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary).frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .padding()
                } else {
                    ContentUnavailableView {
                        Label("Set up your track", systemImage: "flag")
                    } description: {
                        Text("Your license type, state, start date and the hours your board requires.")
                    } actions: {
                        Button("Set Up") { editingTrack = true }.buttonStyle(.borderedProminent)
                    }
                    .padding(.top, 60)
                }
            }
            .background(Color(.systemGroupedBackground))
            .navigationTitle("Progress")
            .toolbar {
                ToolbarItemGroup(placement: .topBarLeading) {
                    Button { showingSettings = true } label: { Image(systemName: "gearshape") }.accessibilityLabel("Settings")
                    NavigationLink { HowToView() } label: { Image(systemName: "questionmark.circle") }.accessibilityLabel("How do I use this app")
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Menu {
                        ForEach(HourCategory.allCases) { c in
                            Button(c.name, systemImage: c.symbol) { draft = EntryDraft(category: c) }
                        }
                        Divider()
                        Button("Edit track", systemImage: "flag") { editingTrack = true }
                    } label: { Image(systemName: "plus") }
                    .accessibilityLabel("More")
                    .disabled(track == nil)
                }
            }
            .sheet(item: $draft) { EntryEditorView(entry: nil, draft: $0) }
            .sheet(isPresented: $editingTrack) { TrackEditorView(track: track) }
            .sheet(isPresented: $showingSettings) { SettingsView() }
        }
        .task {
            #if DEBUG
            if ProcessInfo.processInfo.arguments.contains("-sampleData"), tracks.isEmpty { SampleData.insert(into: context) }
            #endif
        }
        .onChange(of: entries.count, initial: true) { sync() }
        .onChange(of: tracks.count) { sync() }
        .onChange(of: scenePhase, initial: true) { _, phase in
            guard phase == .active else { return }
            timer = SessionTimer.load()
            if WidgetSnapshot.defaults.bool(forKey: LogHoursIntent.pendingKey) {
                WidgetSnapshot.defaults.removeObject(forKey: LogHoursIntent.pendingKey)
                if track == nil { editingTrack = true } else { draft = EntryDraft(category: .direct) }
            }
        }
    }

    private func sync() {
        TrackMode.sync(with: track)
        WidgetSync.update(track: track, entries: entries)
    }

    // MARK: Panels

    private func headerPanel(_ track: LicenseTrack) -> some View {
        let totals = HoursMath.totals(entries)
        return Panel {
            Text(track.title).font(.headline)
            if !track.superviseeName.isEmpty { Text(track.superviseeName).font(.subheadline).foregroundStyle(.secondary) }
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                Text(Formatters.hours(totals.total, unit: false)).font(.system(size: 40, weight: .bold, design: .rounded)).monospacedDigit()
                Text("of \(Formatters.hours(track.requiredTotalHours)) counted").font(.subheadline).foregroundStyle(.secondary)
            }
            Text("Since \(Formatters.date.string(from: track.startDate))").font(.caption).foregroundStyle(.secondary)
        }
    }

    private var quickAdd: some View {
        HStack(spacing: 10) {
            quickButton(.direct, title: HourCategory.direct.short)
            quickButton(.indirect, title: HourCategory.indirect.short)
            quickButton(.supervisionIndividual, title: "Supervision")
        }
    }

    private func quickButton(_ category: HourCategory, title: String) -> some View {
        Button { draft = EntryDraft(category: category) } label: {
            VStack(spacing: 4) {
                Image(systemName: category.symbol).font(.title3).frame(height: 26)
                Text(title).font(.subheadline.weight(.semibold)).lineLimit(1).minimumScaleFactor(0.7)
            }
            .frame(maxWidth: .infinity).frame(height: 56)
        }
        .buttonStyle(.borderedProminent).buttonBorderShape(.roundedRectangle(radius: 14)).tint(category.color)
        .accessibilityLabel("Log \(category.name)")
    }

    private var timerPanel: some View {
        Panel(title: "Session timer") {
            if let timer {
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(timerInterval: timer.start...Date.distantFuture, countsDown: false)
                            .font(.system(size: 32, weight: .semibold, design: .rounded)).monospacedDigit()
                        Text("\(timer.category.name) · started \(timer.start.formatted(date: .omitted, time: .shortened))").font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button("Stop") { stopTimer() }.buttonStyle(.borderedProminent).tint(.red)
                }
            } else {
                HStack {
                    Text("Start before a session; the entry is prefilled when you stop.").font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                    Menu {
                        ForEach(HourCategory.allCases) { c in Button(c.name, systemImage: c.symbol) { timer = SessionTimer.begin(c) } }
                    } label: { Label("Start Timer", systemImage: "play.fill") }
                    .buttonStyle(.bordered)
                }
            }
        }
    }

    private func stopTimer() {
        guard let timer else { return }
        let minutes = timer.elapsedMinutes()
        SessionTimer.clear()
        self.timer = nil
        draft = EntryDraft(category: timer.category, minutes: minutes, date: timer.start)
    }

    private func requirementsPanel(_ track: LicenseTrack) -> some View {
        let reqs = HoursMath.requirements(track: track, totals: HoursMath.totals(entries))
        return Panel(title: "Requirements") {
            if reqs.isEmpty {
                Text("Enter the hours your board requires in Settings → Track.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 14) { ForEach(reqs) { RequirementBar(requirement: $0) } }
            }
            let ratios = HoursMath.ratioRequirements(track: track, totals: HoursMath.totals(entries))
            if !ratios.isEmpty {
                Divider()
                ForEach(ratios) { CheckRow(check: $0) }
            }
        }
    }

    private func monthPanel(_ track: LicenseTrack) -> some View {
        let checks = HoursMath.monthlyChecks(track: track, entries: entries, month: .now)
        return Panel(title: "\(Formatters.monthYear.string(from: .now)) · BACB monthly rules") {
            if checks.isEmpty {
                Text("Log hours this month and each rule shows as met or not.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                VStack(spacing: 8) { ForEach(checks) { CheckRow(check: $0) } }
                Text("Checked against what is logged so far this month. A month that misses a rule may not count; check the current BACB handbook.").font(.caption).foregroundStyle(.secondary)
            }
        }
    }

    private func weekPanel(_ track: LicenseTrack) -> some View {
        let week = HoursMath.totals(HoursMath.inWeek(entries, of: .now))
        let overCap = track.maxWeeklyHours > 0 && week.total > track.maxWeeklyHours
        return Panel(title: Formatters.week(HoursMath.weekStart(of: .now))) {
            HStack(spacing: 0) {
                stat(HourCategory.direct.short, week.direct)
                stat(HourCategory.indirect.short, week.indirect)
                stat("Supervision", week.supervision)
                stat("Total", week.total, bold: true)
            }
            if track.maxWeeklyHours > 0 {
                Text(overCap ? "Over your board's weekly cap of \(Formatters.hours(track.maxWeeklyHours))." : "Weekly cap \(Formatters.hours(track.maxWeeklyHours)).")
                    .font(.caption).foregroundStyle(overCap ? .red : .secondary)
            }
        }
    }

    private func pacePanel(_ track: LicenseTrack) -> some View {
        let pace = HoursMath.pace(track: track, entries: entries)
        return Panel(title: "Pace") {
            if pace.weeksSampled == 0 {
                Text("Log a few weeks and the app estimates when you will finish.").font(.subheadline).foregroundStyle(.secondary)
            } else {
                LabeledContent("Average per week", value: "\(Formatters.hours(pace.hoursPerWeek)) over \(pace.weeksSampled) wk")
                if let finish = pace.projectedFinish {
                    LabeledContent("Projected finish", value: finish.formatted(.dateTime.month(.abbreviated).year()))
                    if let limiting = pace.limitingRequirement {
                        Text("Set by \(limiting.lowercased()), the slowest requirement at this pace.").font(.caption).foregroundStyle(.secondary)
                    }
                } else {
                    Text("Every requirement with a rate is met.").font(.caption).foregroundStyle(.green)
                }
            }
        }
    }

    private func stat(_ label: String, _ hours: Double, bold: Bool = false) -> some View {
        VStack(spacing: 2) {
            Text(Formatters.hours(hours, unit: false)).font(bold ? .headline : .body).monospacedDigit()
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
