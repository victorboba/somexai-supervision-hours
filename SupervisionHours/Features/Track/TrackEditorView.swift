import SwiftUI
import SwiftData

/// The licensure goal: who, which license, and the numbers the board requires.
/// Picking a BACB fieldwork type swaps the hour minimums for the monthly ratio rules.
struct TrackEditorView: View {
    let track: LicenseTrack?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss

    @State private var superviseeName = ""
    @State private var licenseType: LicenseType = .lpc
    @State private var state = ""
    @State private var boardName = ""
    @State private var startDate: Date = .now
    @State private var total: Double? = 3000
    @State private var direct: Double? = 1500
    @State private var supervision: Double? = 100
    @State private var individual: Double? = nil
    @State private var weeklyMax: Double? = nil
    @State private var notes = ""
    // Fieldwork
    @State private var concentrated = false
    @State private var supervisionPercent: Double? = 5
    @State private var unrestrictedPercent: Double? = 60
    @State private var individualPercent: Double? = 50
    @State private var contacts: Int = 4
    @State private var observation = true
    @State private var minMonthly: Double? = 20
    @State private var maxMonthly: Double? = 130

    private var isFieldwork: Bool { licenseType.isFieldwork }

    var body: some View {
        NavigationStack {
            Form {
                Section("You") {
                    TextField("Your name (as on the application)", text: $superviseeName)
                    Picker("License", selection: $licenseType) { ForEach(LicenseType.allCases) { Text($0.name).tag($0) } }
                    if isFieldwork {
                        Toggle("Concentrated Supervised Fieldwork", isOn: $concentrated)
                    } else {
                        TextField("State or province", text: $state)
                    }
                    TextField("Board (optional)", text: $boardName)
                    DatePicker(isFieldwork ? "Fieldwork began" : "Supervised experience began", selection: $startDate, displayedComponents: .date)
                }
                if isFieldwork {
                    Section {
                        hoursRow("Total fieldwork hours", $total, unit: "hr")
                        hoursRow("Supervision, percent of each month", $supervisionPercent, unit: "%")
                        hoursRow("Unrestricted activities, minimum", $unrestrictedPercent, unit: "%")
                        hoursRow("Individual share of supervision", $individualPercent, unit: "%")
                        Stepper("Supervisor contacts per month: \(contacts)", value: $contacts, in: 0...20)
                        Toggle("One client observation per month", isOn: $observation)
                        hoursRow("Minimum hours per month", $minMonthly, unit: "hr")
                        hoursRow("Maximum hours per month", $maxMonthly, unit: "hr")
                    } header: { Text("BACB fieldwork rules") } footer: {
                        Text("Prefilled from the BACB handbook (2,000 hours at 5% supervision and 4 contacts a month; concentrated is 1,500 at 10% and 6). Check the current handbook and edit anything that differs.")
                    }
                } else {
                    Section {
                        hoursRow("Total hours", $total, unit: "hr")
                        hoursRow("Direct client contact", $direct, unit: "hr")
                        hoursRow("Supervision (all)", $supervision, unit: "hr")
                        hoursRow("Individual supervision minimum", $individual, unit: "hr")
                        hoursRow("Weekly cap (optional)", $weeklyMax, unit: "hr")
                    } header: { Text("Required by your board") } footer: {
                        Text("Copy these from your board's rules; they differ by state and license and change over time. Leave a field empty if your board has no such number.")
                    }
                }
                Section("Notes") {
                    TextField("Ratio rules, minimum months, anything to remember", text: $notes, axis: .vertical).lineLimit(2...5)
                }
            }
            .navigationTitle(track == nil ? "Set Up Track" : "Edit Track")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold() }
            }
            .onAppear(perform: load)
            .onChange(of: licenseType) { _, new in if new.isFieldwork { applyPresets() } }
            .onChange(of: concentrated) { if isFieldwork { applyPresets() } }
        }
    }

    private func hoursRow(_ label: String, _ value: Binding<Double?>, unit: String) -> some View {
        LabeledContent(label) {
            HStack(spacing: 4) {
                TextField("—", value: value, format: .number.precision(.fractionLength(0...1))).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(width: 64)
                    .accessibilityLabel(label)
                Text(unit).foregroundStyle(.secondary).frame(width: 20, alignment: .leading)
            }
        }
    }

    private func applyPresets() {
        let preset = LicenseTrack(licenseType: licenseType)
        preset.fieldworkConcentrated = concentrated
        preset.applyFieldworkDefaults()
        total = preset.requiredTotalHours
        supervisionPercent = preset.supervisionPercentPerMonth
        unrestrictedPercent = preset.unrestrictedPercentMin
        individualPercent = preset.individualSupervisionPercentMin
        contacts = preset.contactsPerMonth
        observation = preset.observationPerMonth
        minMonthly = preset.minMonthlyHours
        maxMonthly = preset.maxMonthlyHours
        if boardName.isEmpty { boardName = preset.boardName }
    }

    private func load() {
        guard let track else { return }
        superviseeName = track.superviseeName; licenseType = track.licenseType; state = track.state; boardName = track.boardName
        startDate = track.startDate
        total = track.requiredTotalHours == 0 ? nil : track.requiredTotalHours
        direct = track.requiredDirectHours == 0 ? nil : track.requiredDirectHours
        supervision = track.requiredSupervisionHours == 0 ? nil : track.requiredSupervisionHours
        individual = track.requiredIndividualSupervisionHours == 0 ? nil : track.requiredIndividualSupervisionHours
        weeklyMax = track.maxWeeklyHours == 0 ? nil : track.maxWeeklyHours
        notes = track.notes
        concentrated = track.fieldworkConcentrated
        supervisionPercent = track.supervisionPercentPerMonth
        unrestrictedPercent = track.unrestrictedPercentMin
        individualPercent = track.individualSupervisionPercentMin
        contacts = track.contactsPerMonth
        observation = track.observationPerMonth
        minMonthly = track.minMonthlyHours == 0 ? nil : track.minMonthlyHours
        maxMonthly = track.maxMonthlyHours == 0 ? nil : track.maxMonthlyHours
    }

    private func save() {
        let target = track ?? LicenseTrack(licenseType: licenseType, state: state)
        target.superviseeName = superviseeName.trimmingCharacters(in: .whitespaces)
        target.licenseType = licenseType
        target.state = isFieldwork ? "" : state.trimmingCharacters(in: .whitespaces)
        target.boardName = boardName
        target.startDate = Calendar.current.startOfDay(for: startDate)
        target.requiredTotalHours = total ?? 0
        target.notes = notes
        if isFieldwork {
            target.fieldworkConcentrated = concentrated
            target.supervisionPercentPerMonth = supervisionPercent ?? 0
            target.unrestrictedPercentMin = unrestrictedPercent ?? 0
            target.individualSupervisionPercentMin = individualPercent ?? 0
            target.contactsPerMonth = contacts
            target.observationPerMonth = observation
            target.minMonthlyHours = minMonthly ?? 0
            target.maxMonthlyHours = maxMonthly ?? 0
            target.requiredDirectHours = 0
            target.requiredIndividualSupervisionHours = 0
            target.maxWeeklyHours = 0
            // Overall supervision requirement follows from the monthly percentage.
            target.requiredSupervisionHours = ((total ?? 0) * (supervisionPercent ?? 0) / 100).rounded()
        } else {
            target.requiredDirectHours = direct ?? 0
            target.requiredSupervisionHours = supervision ?? 0
            target.requiredIndividualSupervisionHours = individual ?? 0
            target.maxWeeklyHours = weeklyMax ?? 0
        }
        if track == nil { context.insert(target) }
        TrackMode.sync(with: target)
        dismiss()
    }
}
