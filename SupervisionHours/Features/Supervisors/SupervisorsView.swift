import SwiftUI
import SwiftData

struct SupervisorsView: View {
    @Environment(\.modelContext) private var context
    @Query(sort: \Supervisor.createdAt) private var supervisors: [Supervisor]
    @Query private var entries: [HoursEntry]

    @State private var editing: Supervisor?
    @State private var adding = false

    var body: some View {
        List {
            ForEach(supervisors) { s in
                let mine = entries.filter { $0.supervisorID == s.id }
                let supervision = HoursMath.totals(mine).supervision
                Button { editing = s } label: {
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(s.title).foregroundStyle(.primary)
                            Text([s.licenseNumber.isEmpty ? nil : "License \(s.licenseNumber)", s.isActive ? nil : "inactive"].compactMap { $0 }.joined(separator: " · "))
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text(Formatters.hours(supervision)).monospacedDigit().foregroundStyle(.primary)
                            Text("supervision").font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .onDelete { offsets in offsets.map { supervisors[$0] }.forEach(context.delete) }
            Button { adding = true } label: { Label("Add Supervisor", systemImage: "plus") }
        }
        .navigationTitle("Supervisors")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $editing) { SupervisorEditorView(supervisor: $0) }
        .sheet(isPresented: $adding) { SupervisorEditorView(supervisor: nil) }
    }
}

struct SupervisorEditorView: View {
    let supervisor: Supervisor?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Query private var entries: [HoursEntry]

    @State private var name = ""
    @State private var credentials = ""
    @State private var licenseNumber = ""
    @State private var email = ""
    @State private var phone = ""
    @State private var notes = ""
    @State private var isActive = true
    @FocusState private var nameFocused: Bool

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Name", text: $name).focused($nameFocused)
                    TextField("Credentials, like LPC-S or LCSW", text: $credentials)
                    TextField("License number", text: $licenseNumber)
                } footer: { Text("Name, credentials and license number print on the PDF log next to the signature line.") }
                Section("Contact") {
                    TextField("Email", text: $email).keyboardType(.emailAddress).textInputAutocapitalization(.never)
                    TextField("Phone", text: $phone).keyboardType(.phonePad)
                }
                Section("Notes") {
                    TextField("Meeting day, rate, what they want on the log…", text: $notes, axis: .vertical).lineLimit(2...5)
                }
                if supervisor != nil {
                    Section { Toggle("Active", isOn: $isActive) } footer: { Text("Inactive supervisors stay on past entries but leave the picker.") }
                }
            }
            .navigationTitle(supervisor == nil ? "New Supervisor" : "Edit Supervisor")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save() }.bold().disabled(name.trimmingCharacters(in: .whitespaces).isEmpty) }
            }
            .onAppear {
                if let supervisor {
                    name = supervisor.name; credentials = supervisor.credentials; licenseNumber = supervisor.licenseNumber
                    email = supervisor.email; phone = supervisor.phone; notes = supervisor.notes; isActive = supervisor.isActive
                } else {
                    nameFocused = true
                }
            }
        }
    }

    private func save() {
        let target = supervisor ?? Supervisor(name: name)
        target.name = name.trimmingCharacters(in: .whitespaces)
        target.credentials = credentials.trimmingCharacters(in: .whitespaces)
        target.licenseNumber = licenseNumber.trimmingCharacters(in: .whitespaces)
        target.email = email
        target.phone = phone
        target.notes = notes
        target.isActive = isActive
        if supervisor == nil { context.insert(target) }
        for e in entries where e.supervisorID == target.id { e.supervisorName = target.title }
        dismiss()
    }
}
