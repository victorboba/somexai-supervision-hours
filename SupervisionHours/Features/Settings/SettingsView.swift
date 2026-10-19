import SwiftUI
import SwiftData

struct SettingsView: View {
    @Environment(EntitlementStore.self) private var store
    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @Query(sort: \LicenseTrack.createdAt) private var tracks: [LicenseTrack]
    @Query private var supervisors: [Supervisor]

    @AppStorage(WeeklyReminder.enabledKey) private var reminderEnabled = false
    @AppStorage(WeeklyReminder.weekdayKey) private var reminderWeekday = 6
    @AppStorage(WeeklyReminder.hourKey) private var reminderHour = 17

    @State private var editingTrack = false
    @State private var confirmingDeleteAll = false
    #if DEBUG
    @State private var sampleDataImported = false
    @AppStorage(DebugFlags.unlockKey) private var debugUnlock = false
    @AppStorage("onboarding.completed") private var onboardingCompleted = true
    #endif

    private var version: String {
        let short = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "?"
        let build = Bundle.main.infoDictionary?["CFBundleVersion"] as? String ?? "?"
        return "\(short) (\(build))"
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Button { editingTrack = true } label: {
                        if let track = tracks.first {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(track.title).foregroundStyle(.primary)
                                Text(track.isFieldwork
                                     ? "\(Formatters.hours(track.requiredTotalHours)) total · \(Formatters.percent(track.supervisionPercentPerMonth)) supervision · \(track.contactsPerMonth) contacts a month"
                                     : "\(Formatters.hours(track.requiredTotalHours)) total · \(Formatters.hours(track.requiredDirectHours)) direct · \(Formatters.hours(track.requiredSupervisionHours)) supervision")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else {
                            Text("Set up your track").foregroundStyle(.primary)
                        }
                    }
                    NavigationLink { SupervisorsView() } label: {
                        LabeledContent("Supervisors", value: supervisors.isEmpty ? "None yet" : supervisors.filter(\.isActive).map(\.name).joined(separator: ", "))
                    }
                    .accessibilityIdentifier("Supervisors")
                } header: { Text("Track") }

                Section {
                    Toggle("Weekly reminder to log hours", isOn: $reminderEnabled)
                    if reminderEnabled {
                        Picker("Day", selection: $reminderWeekday) {
                            ForEach(1...7, id: \.self) { Text(Calendar.current.weekdaySymbols[$0 - 1]).tag($0) }
                        }
                        Picker("Time", selection: $reminderHour) {
                            ForEach([7, 8, 9, 12, 15, 16, 17, 18, 19, 20], id: \.self) { h in
                                Text(Calendar.current.date(bySettingHour: h, minute: 0, second: 0, of: .now)!.formatted(date: .omitted, time: .shortened)).tag(h)
                            }
                        }
                    }
                } header: { Text("Reminder") } footer: { Text("One notification a week. Nothing else.") }
                .onChange(of: [reminderEnabled ? 1 : 0, reminderWeekday, reminderHour]) { Task { await WeeklyReminder.reschedule() } }

                Section("Help") {
                    NavigationLink { HowToView() } label: { Label("How do I use \(AppConfig.appName)?", systemImage: "questionmark.circle") }
                }

                Section("Your plan") {
                    LabeledContent("Status", value: planDescription)
                    if store.isEntitled && !store.isLifetime {
                        Button("Manage Subscription") { openURL(URL(string: "https://apps.apple.com/account/subscriptions")!) }
                    }
                    Button("Restore Purchases") { Task { await store.restore() } }
                    if let error = store.lastError { Text(error).font(.footnote).foregroundStyle(.red) }
                }

                Section("Your data") {
                    Text("Everything you record stays on this device\(AppConfig.iCloudSyncEnabled ? " and in your private iCloud" : ""). Nothing is sent to us.")
                        .font(.footnote).foregroundStyle(.secondary)
                    Button("Delete All Data", role: .destructive) { confirmingDeleteAll = true }
                }

                Section("About") {
                    Text(AppConfig.disclaimer).font(.footnote).foregroundStyle(.secondary)
                    if !AppConfig.appStoreID.isEmpty {
                        Button("Rate \(AppConfig.appName)") { openURL(URL(string: "https://apps.apple.com/app/id\(AppConfig.appStoreID)?action=write-review")!) }
                    }
                    Button("Contact Support") {
                        let subject = "\(AppConfig.appName) \(version)".addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? ""
                        openURL(URL(string: "mailto:\(AppConfig.supportEmail)?subject=\(subject)")!)
                    }
                    NavigationLink("Privacy Policy") { PrivacyPolicyView() }
                    Link("Terms of Use", destination: AppConfig.termsURL)
                    LabeledContent("Version", value: version)
                }

                #if DEBUG
                Section("Debug (not in release builds)") {
                    Toggle("Unlock without purchase", isOn: $debugUnlock)
                        .onChange(of: debugUnlock) { Task { await store.refreshEntitlements() } }
                    Button("Show onboarding again") { onboardingCompleted = false; dismiss() }
                    Button(sampleDataImported ? "Imported ✓" : "Insert sample data (16 weeks)") {
                        SampleData.insert(into: context)
                        sampleDataImported = true
                        Task { try? await Task.sleep(for: .seconds(2)); sampleDataImported = false }
                    }
                    .disabled(sampleDataImported)
                }
                #endif
            }
            .navigationTitle("Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } } }
            .sheet(isPresented: $editingTrack) { TrackEditorView(track: tracks.first) }
            .confirmationDialog("Delete the track, every supervisor and every logged hour on this device?", isPresented: $confirmingDeleteAll, titleVisibility: .visible) {
                Button("Delete All", role: .destructive) {
                    try? context.delete(model: HoursEntry.self)
                    try? context.delete(model: Supervisor.self)
                    try? context.delete(model: LicenseTrack.self)
                    SessionTimer.clear()
                    TrackMode.sync(with: nil)
                    WeeklyReminder.cancel()
                    WidgetSync.update(track: nil, entries: [])
                }
                Button("Cancel", role: .cancel) {}
            } message: { Text("This cannot be undone. Export the PDF log first if you want a copy.") }
        }
    }

    private var planDescription: String {
        guard store.isEntitled else { return "Not active" }
        if store.isLifetime { return "Lifetime" }
        if let expiry = store.expiresAt { return "Annual, renews \(expiry.formatted(date: .abbreviated, time: .omitted))" }
        return "Active"
    }
}
