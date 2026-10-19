import UIKit

/// The supervised-experience log: header, totals against requirements, weekly table, every entry, signature lines.
/// Boring on purpose; it is what gets stapled to the licensure application.
@MainActor
enum ReportExporter {
    static func export(track: LicenseTrack, supervisors: [Supervisor], entries all: [HoursEntry], from start: Date, to end: Date, periodLabel: String) throws -> URL {
        let calendar = Calendar.current
        let entries = HoursMath.between(all, from: start, to: end).sorted { $0.date < $1.date }
        let periodTotals = HoursMath.totals(entries)
        let overall = HoursMath.totals(all)
        let weeks = HoursMath.weeks(entries).reversed()
        let usedSupervisors = supervisors.filter { s in entries.contains { $0.supervisorID == s.id } }
        let signers = usedSupervisors.isEmpty ? supervisors.filter(\.isActive) : usedSupervisors

        let footer = "\(AppConfig.appName) · hours as entered by the supervisee · verify against the board's requirements"
        return try PDFCanvas.render(footer: footer) { pdf in
            pdf.title(track.isFieldwork ? "Fieldwork experience log" : "Supervised experience log")
            pdf.subtitle("\(periodLabel) · \(Formatters.date.string(from: start)) to \(Formatters.date.string(from: end)) · generated \(Formatters.dateTime.string(from: .now))")

            pdf.heading(track.isFieldwork ? "Trainee" : "Supervisee")
            var pairs: [(String, String)] = [
                ("Name", track.superviseeName.isEmpty ? "—" : track.superviseeName),
                ("License track", track.title),
                (track.isFieldwork ? "Fieldwork began" : "Supervised experience began", Formatters.date.string(from: track.startDate)),
            ]
            if !track.boardName.isEmpty { pairs.append(("Board", track.boardName)) }
            for s in signers {
                var line = s.title
                if !s.licenseNumber.isEmpty { line += " · License \(s.licenseNumber)" }
                pairs.append(("Supervisor", line))
            }
            pdf.keyValues(pairs)

            pdf.heading("Hours in this period")
            pdf.table(headers: ["Category", "Hours"], widths: [0.7, 0.3], rows: HourCategory.allCases.map { [$0.name(fieldwork: track.isFieldwork), Formatters.hours(periodTotals.hours(for: $0), unit: false)] }
                      + [["Total counted (excludes training)", Formatters.hours(periodTotals.total, unit: false)]])

            pdf.heading("Progress toward requirements (all time)")
            pdf.table(headers: ["Requirement", "Required", "Completed", "Remaining"], widths: [0.4, 0.2, 0.2, 0.2],
                      rows: HoursMath.requirements(track: track, totals: overall).map {
                          [$0.name, Formatters.hours($0.required, unit: false), Formatters.hours($0.done, unit: false), Formatters.hours($0.remaining, unit: false)]
                      })

            if track.isFieldwork {
                pdf.heading("Monthly verification")
                let months = Dictionary(grouping: entries) { HoursMath.monthStart(of: $0.date, calendar: calendar) }.keys.sorted()
                pdf.table(headers: ["Month", "Hours", "Restricted", "Unrestricted", "Supervision", "Contacts", "Observed", "Rules"],
                          widths: [0.16, 0.10, 0.12, 0.13, 0.13, 0.11, 0.11, 0.14],
                          rows: months.map { m in
                              let mine = HoursMath.inMonth(entries, of: m, calendar: calendar)
                              let t = HoursMath.totals(mine)
                              let checks = HoursMath.monthlyChecks(track: track, entries: entries, month: m, calendar: calendar)
                              let failed = checks.filter { !$0.passed }
                              return [Formatters.monthYear.string(from: m), Formatters.hours(t.total, unit: false),
                                      Formatters.hours(t.direct, unit: false), "\(Formatters.hours(t.indirect, unit: false)) (\(Formatters.percent(t.total > 0 ? t.indirect / t.total * 100 : 0)))",
                                      "\(Formatters.hours(t.supervision, unit: false)) (\(Formatters.percent(t.total > 0 ? t.supervision / t.total * 100 : 0)))",
                                      "\(mine.filter { $0.category.isSupervision }.count)", mine.contains { $0.hasObservation } ? "Yes" : "No",
                                      failed.isEmpty ? "All met" : "Not met: " + failed.map(\.name).joined(separator: "; ")]
                          })
                let ratios = HoursMath.ratioRequirements(track: track, totals: overall)
                if !ratios.isEmpty { pdf.keyValues(ratios.map { ($0.name, $0.value + ($0.passed ? "" : "  — not met")) }) }
            }

            pdf.heading("By week")
            pdf.table(headers: ["Week of", HourCategory.direct.short(fieldwork: track.isFieldwork), HourCategory.indirect.short(fieldwork: track.isFieldwork), "Indiv. sup.", "Group sup.", "Training", "Total"],
                      widths: [0.22, 0.13, 0.13, 0.13, 0.13, 0.13, 0.13],
                      rows: weeks.map { w in
                          let t = w.totals
                          return [Formatters.short.string(from: w.start)] + [t.direct, t.indirect, t.supervisionIndividual, t.supervisionGroup, t.training, t.total].map { Formatters.hours($0, unit: false) }
                      })

            pdf.heading("Every entry")
            pdf.table(headers: ["Date", "Category", "Hours", "Site", "Supervisor", "Clients", "Sig.", "Notes"],
                      widths: [0.12, 0.17, 0.08, 0.15, 0.15, 0.07, 0.06, 0.20],
                      rows: entries.map { e in
                          [Formatters.date.string(from: e.date), e.category.name(fieldwork: track.isFieldwork), Formatters.hours(e.hours, unit: false), e.siteName, e.supervisorName,
                           e.clientCount.map(String.init) ?? "", e.isVerified ? "✓" : "", (e.hasObservation ? "Client observation. " : "") + e.notes]
                      })

            pdf.heading("Signatures")
            pdf.paragraph("I attest that the hours above are accurate.", color: .darkGray)
            pdf.spacer(6)
            var lines: [(String, String)] = [("Supervisee", track.superviseeName)]
            for s in signers { lines.append(("Supervisor", s.title)) }
            if signers.isEmpty { lines.append(("Supervisor", "")) }
            for (role, name) in lines {
                pdf.spacer(18)
                pdf.keyValues([("\(role) signature", "________________________________________      Date: ________________")])
                if !name.isEmpty { pdf.paragraph(name, color: .darkGray) }
            }

            pdf.spacer(10)
            pdf.paragraph(AppConfig.disclaimer, color: .darkGray)
        }
    }
}
