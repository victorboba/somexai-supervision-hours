import Foundation
import WidgetKit

enum WidgetSync {
    static func update(track: LicenseTrack?, entries: [HoursEntry], now: Date = .now) {
        var snapshot = WidgetSnapshot()
        if let track {
            let totals = HoursMath.totals(entries)
            snapshot.hasTrack = true
            snapshot.trackName = track.title
            snapshot.totalHours = totals.total
            snapshot.requiredTotalHours = track.requiredTotalHours
            snapshot.directHours = totals.direct
            snapshot.requiredDirectHours = track.requiredDirectHours
            snapshot.supervisionHours = totals.supervision
            snapshot.requiredSupervisionHours = track.requiredSupervisionHours
            snapshot.weekHours = HoursMath.totals(HoursMath.inWeek(entries, of: now)).total
            snapshot.projectedFinish = HoursMath.pace(track: track, entries: entries, now: now).projectedFinish
        }
        snapshot.save()
        WidgetCenter.shared.reloadAllTimelines()
    }
}
