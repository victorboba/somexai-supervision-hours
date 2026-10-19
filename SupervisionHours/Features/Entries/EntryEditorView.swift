import SwiftUI
import SwiftData

/// Log or edit one block of hours. Duration via chips or typed hours and minutes.
struct EntryEditorView: View {
    let entry: HoursEntry?
    var draft: EntryDraft? = nil

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(\.requestReview) private var requestReview
    @Query(sort: \Supervisor.createdAt) private var supervisors: [Supervisor]
    @Query(sort: \HoursEntry.date, order: .reverse) private var entries: [HoursEntry]

    @State private var category: HourCategory = .direct
    @State private var date: Date = .now
    @State private var hours: Int = 0
    @State private var minutes: Int = 50
    @State private var site = ""
    @State private var supervisorID: UUID?
    @State private var clients: Int? = nil
    @State private var verified = false
    @State private var observation = false
    @State private var notes = ""

    private let chips = [30, 45, 50, 60, 90, 120]
    private var totalMinutes: Int { hours * 60 + minutes }
    private var canSave: Bool { totalMinutes > 0 }
    private var activeSupervisors: [Supervisor] { supervisors.filter { $0.isActive || $0.id == supervisorID } }
    private var recentSites: [String] { HoursMath.recentSites(entries) }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Picker("Category", selection: $category) {
                        ForEach(HourCategory.allCases) { Label($0.name, systemImage: $0.symbol).tag($0) }
                    }
                    if let hint = category.hint { Text(hint).font(.footnote).foregroundStyle(.secondary) }
                    DatePicker("When", selection: $date)
                }

                Section("Duration") {
                    ScrollView(.horizontal, showsIndicators: false) {
                        HStack(spacing: 8) {
                            ForEach(chips, id: \.self) { m in
                                let on = totalMinutes == m
                                Button(Formatters.duration(minutes: m)) { hours = m / 60; minutes = m % 60 }
                                    .buttonStyle(.bordered).tint(on ? .accentColor : .secondary)
                                    .accessibilityAddTraits(on ? .isSelected : [])
                            }
                        }
                    }
                    .listRowInsets(EdgeInsets(top: 8, leading: 16, bottom: 8, trailing: 16))
                    HStack {
                        Picker("Hours", selection: $hours) { ForEach(0..<13, id: \.self) { Text("\($0) hr").tag($0) } }
                            .pickerStyle(.menu).labelsHidden().accessibilityLabel("Hours")
                        Picker("Minutes", selection: $minutes) { ForEach(Array(stride(from: 0, through: 55, by: 5)), id: \.self) { Text("\($0) min").tag($0) } }
                            .pickerStyle(.menu).labelsHidden().accessibilityLabel("Minutes")
                        Spacer()
                        Text(Formatters.hours(Double(totalMinutes) / 60)).foregroundStyle(.secondary).monospacedDigit()
                    }
                }

                Section("Where and with whom") {
                    HStack {
                        TextField("Site or practice", text: $site)
                        if !recentSites.isEmpty {
                            Menu {
                                ForEach(recentSites, id: \.self) { s in Button(s) { site = s } }
                            } label: { Image(systemName: "clock.arrow.circlepath") }
                            .accessibilityLabel("Recent sites")
                        }
                    }
                    Picker("Supervisor", selection: $supervisorID) {
                        Text("None").tag(UUID?.none)
                        ForEach(activeSupervisors) { Text($0.title).tag(Optional($0.id)) }
                    }
                    if category == .direct {
                        LabeledContent("Clients seen") {
                            TextField("—", value: $clients, format: .number).keyboardType(.numberPad).multilineTextAlignment(.trailing).frame(width: 60)
                                .accessibilityLabel("Clients seen")
                        }
                    }
                    if category.isSupervision, TrackMode.isFieldwork {
                        Toggle("Supervisor observed me with a client", isOn: $observation)
                    }
                    Toggle("Supervisor has signed off", isOn: $verified)
                }

                Section("Notes") {
                    TextField("Modality, presenting concerns, what supervision covered…", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                if category == .training {
                    Section { Text("Training is kept for your records and shown on the log, but not counted toward the total.").font(.footnote).foregroundStyle(.secondary) }
                }
            }
            .navigationTitle(entry == nil ? "Log Hours" : "Edit Hours")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold().disabled(!canSave) }
            }
            .onAppear(perform: load)
        }
    }

    private func load() {
        if let entry {
            category = entry.category
            date = entry.date
            hours = entry.minutes / 60
            minutes = entry.minutes % 60
            site = entry.siteName
            supervisorID = entry.supervisorID
            clients = entry.clientCount
            verified = entry.isVerified
            observation = entry.hasObservation
            notes = entry.notes
        } else {
            category = draft?.category ?? .direct
            date = draft?.date ?? .now
            let m = draft?.minutes ?? category.defaultMinutes
            hours = m / 60
            minutes = m % 60
            let last = entries.first
            site = last?.siteName ?? ""
            supervisorID = last?.supervisorID ?? activeSupervisors.first?.id
        }
    }

    private func save() {
        let supervisor = supervisors.first { $0.id == supervisorID }
        let target = entry ?? HoursEntry(date: date, category: category, minutes: totalMinutes)
        target.date = date
        target.category = category
        target.minutes = totalMinutes
        target.siteName = site.trimmingCharacters(in: .whitespaces)
        target.supervisorID = supervisorID
        target.supervisorName = supervisor?.title ?? ""
        target.clientCount = category == .direct ? clients : nil
        target.isVerified = verified
        target.hasObservation = category.isSupervision && observation
        target.notes = notes
        if entry == nil { context.insert(target) }
        ReviewPrompter.recordSuccess(request: requestReview)
        dismiss()
    }
}
