import SwiftUI

extension HourCategory {
    var color: Color {
        switch self {
        case .direct: return .accentColor
        case .indirect: return .teal
        case .supervisionIndividual: return .purple
        case .supervisionGroup: return .indigo
        case .training: return .gray
        }
    }
}

/// A rounded, grouped-background panel used on the Progress and Report screens.
struct Panel<Content: View>: View {
    var title: String? = nil
    @ViewBuilder let content: () -> Content

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let title { Text(title).font(.headline) }
            content()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .background(Color(.secondarySystemGroupedBackground), in: RoundedRectangle(cornerRadius: 14))
    }
}

/// One requirement: label, done of required, thin bar, remaining.
struct RequirementBar: View {
    let requirement: HoursMath.Requirement

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline) {
                Text(requirement.name).font(.subheadline.weight(.semibold))
                Spacer()
                Text("\(Formatters.hours(requirement.done, unit: false)) of \(Formatters.hours(requirement.required))").font(.subheadline).monospacedDigit()
            }
            ProgressView(value: requirement.fraction).tint(requirement.isMet ? .green : .accentColor)
            Text(requirement.isMet ? "Requirement met" : "\(Formatters.hours(requirement.remaining)) to go · \(Int((requirement.fraction * 100).rounded()))%")
                .font(.caption).foregroundStyle(requirement.isMet ? .green : .secondary)
        }
        .accessibilityElement(children: .combine)
    }
}

/// A rule with a pass/fail mark, for BACB monthly checks and ratio requirements.
struct CheckRow: View {
    let check: HoursMath.Check

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 8) {
            Image(systemName: check.passed ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                .foregroundStyle(check.passed ? Color.green : Color.orange)
            Text(check.name).font(.subheadline)
            Spacer()
            Text(check.value).font(.subheadline).foregroundStyle(check.passed ? Color.secondary : Color.orange).monospacedDigit().multilineTextAlignment(.trailing)
        }
        .accessibilityElement(children: .combine)
    }
}

/// One line of the log: category, duration, site, supervisor.
struct EntryRow: View {
    let entry: HoursEntry

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: entry.category.symbol).foregroundStyle(entry.category.color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(entry.category.name).font(.subheadline.weight(.semibold))
                    if entry.isVerified { Image(systemName: "checkmark.seal.fill").font(.caption).foregroundStyle(.green).accessibilityLabel("Verified") }
                    if entry.hasObservation { Image(systemName: "eye.fill").font(.caption).foregroundStyle(.purple).accessibilityLabel("Client observation") }
                }
                Text(subtitle).font(.caption).foregroundStyle(.secondary).lineLimit(1)
            }
            Spacer()
            VStack(alignment: .trailing, spacing: 2) {
                Text(Formatters.duration(minutes: entry.minutes)).font(.body.weight(.semibold)).monospacedDigit()
                Text(Formatters.weekdayShort.string(from: entry.date)).font(.caption).foregroundStyle(.secondary)
            }
        }
        .contentShape(Rectangle())
    }

    private var subtitle: String {
        var parts: [String] = []
        if !entry.siteName.isEmpty { parts.append(entry.siteName) }
        if let n = entry.clientCount, entry.category == .direct { parts.append("\(n) client\(n == 1 ? "" : "s")") }
        if entry.category.isSupervision, !entry.supervisorName.isEmpty { parts.append(entry.supervisorName) }
        if parts.isEmpty, !entry.notes.isEmpty { parts.append(entry.notes) }
        return parts.joined(separator: " · ")
    }
}
