import Foundation

/// Whether the current track is BACB fieldwork, mirrored into UserDefaults so category labels can be
/// resolved anywhere (rows, pickers, PDF) without threading the track through every view.
enum TrackMode {
    static let fieldworkKey = "track.isFieldwork"

    static var isFieldwork: Bool {
        get { UserDefaults.standard.bool(forKey: fieldworkKey) }
        set { UserDefaults.standard.set(newValue, forKey: fieldworkKey) }
    }

    static func sync(with track: LicenseTrack?) {
        isFieldwork = track?.isFieldwork ?? false
    }
}
