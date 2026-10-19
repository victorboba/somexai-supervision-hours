import WidgetKit
import SwiftUI

struct SnapshotEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

struct SnapshotProvider: TimelineProvider {
    func placeholder(in context: Context) -> SnapshotEntry { SnapshotEntry(date: .now, snapshot: .placeholder) }

    func getSnapshot(in context: Context, completion: @escaping (SnapshotEntry) -> Void) {
        completion(SnapshotEntry(date: .now, snapshot: context.isPreview ? .placeholder : WidgetSnapshot.load()))
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<SnapshotEntry>) -> Void) {
        let calendar = Calendar.current
        let midnight = calendar.startOfDay(for: calendar.date(byAdding: .day, value: 1, to: .now) ?? .now)
        completion(Timeline(entries: [SnapshotEntry(date: .now, snapshot: WidgetSnapshot.load())], policy: .after(midnight)))
    }
}

struct SupervisionHoursWidgetView: View {
    @Environment(\.widgetFamily) private var family
    let entry: SnapshotEntry
    private var s: WidgetSnapshot { entry.snapshot }

    private func hours(_ h: Double) -> String {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.maximumFractionDigits = h == h.rounded() ? 0 : 1
        return n.string(from: NSNumber(value: h)) ?? "\(Int(h))"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 5) {
            Text(s.hasTrack ? s.trackName : AppConfig.appName).font(.caption.weight(.semibold)).foregroundStyle(.secondary).lineLimit(1)
            if !s.hasTrack {
                Text("Set up your track").font(.headline)
            } else {
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text(hours(s.totalHours)).font(.system(size: family == .systemSmall ? 26 : 30, weight: .bold, design: .rounded)).monospacedDigit()
                    Text("of \(hours(s.requiredTotalHours)) hr").font(.caption).foregroundStyle(.secondary)
                }
                ProgressView(value: s.totalFraction).tint(s.totalFraction >= 1 ? .green : .accentColor)
                if family != .systemSmall {
                    Text("Direct \(hours(s.directHours)) of \(hours(s.requiredDirectHours)) · Supervision \(hours(s.supervisionHours)) of \(hours(s.requiredSupervisionHours))")
                        .font(.caption2).foregroundStyle(.secondary).lineLimit(1)
                }
                Spacer(minLength: 0)
                Text("\(hours(s.weekHours)) hr this week").font(.caption)
                if let finish = s.projectedFinish {
                    Text("On pace for \(finish.formatted(.dateTime.month(.abbreviated).year()))").font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
        .containerBackground(.fill.tertiary, for: .widget)
    }
}

struct SupervisionHoursWidget: Widget {
    let kind = "SupervisionHoursWidget"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: SnapshotProvider()) { SupervisionHoursWidgetView(entry: $0) }
            .configurationDisplayName(AppConfig.appName)
            .description("Hours toward licensure, this week, and your projected finish.")
            .supportedFamilies([.systemSmall, .systemMedium])
    }
}

@main
struct SupervisionHoursWidgetBundle: WidgetBundle {
    var body: some Widget { SupervisionHoursWidget() }
}
