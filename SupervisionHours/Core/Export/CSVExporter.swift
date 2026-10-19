import Foundation

enum CSVExporter {
    static let header = "date,category,hours,minutes,site,supervisor,clients,verified,notes"

    static func csv(_ entries: [HoursEntry]) -> String {
        let iso = ISO8601DateFormatter()
        var lines = [header]
        for e in entries.sorted(by: { $0.date < $1.date }) {
            var row: [String] = [iso.string(from: e.date), e.category.name]
            row.append(Formatters.plainHours(minutes: e.minutes))
            row.append(String(e.minutes))
            row.append(e.siteName)
            row.append(e.supervisorName)
            row.append(e.clientCount.map { String($0) } ?? "")
            row.append(e.isVerified ? "yes" : "no")
            row.append(e.notes)
            lines.append(row.map(quote).joined(separator: ","))
        }
        return lines.joined(separator: "\n") + "\n"
    }

    static func export(_ entries: [HoursEntry], suffix: String = "hours") throws -> URL {
        let url = ExportFile.temporaryURL(suffix: suffix, extension: "csv")
        try csv(entries).write(to: url, atomically: true, encoding: .utf8)
        return url
    }

    static func quote(_ field: String) -> String {
        "\"" + field.replacingOccurrences(of: "\"", with: "\"\"") + "\""
    }
}

/// A file URL wrapped so it can drive `.sheet(item:)`.
struct ExportFile: Identifiable {
    let url: URL
    var id: String { url.path }

    static func temporaryURL(suffix: String, extension ext: String) -> URL {
        let stamp = DateFormatter.fileStamp.string(from: .now)
        return FileManager.default.temporaryDirectory
            .appendingPathComponent("\(AppConfig.exportFileStem)-\(suffix)-\(stamp)")
            .appendingPathExtension(ext)
    }
}

extension DateFormatter {
    static let fileStamp: DateFormatter = {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd-HHmm"
        return f
    }()
}
