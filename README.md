# Supervision Hours

A private hours log for pre-licensed counselors, therapists and social workers accruing supervised experience: hours by the board's categories, progress against required totals, a pace estimate, and a signature-ready PDF log.

One of a set of niche iPhone apps built from a shared SwiftUI template ([somexai-ios-template](https://github.com/victorboba/somexai-ios-template)). It was never released on the App Store; the code is here for anyone to use. The other apps are collected in [somexai-ios-apps](https://github.com/victorboba/somexai-ios-apps).

## What it does

- **Track**: license type (LPC/LMHC, LMFT, LCSW/LMSW, psychology postdoc, addiction counselor, other), state, board, start date, required total, direct, supervision and individual-supervision hours, and an optional weekly cap. The numbers are user-entered; the app never guesses board rules.
- **BCBA / BCaBA fieldwork mode**: categories become restricted and unrestricted activities, the track editor prefills BACB numbers (editable), a monthly card checks hours range, supervision share, individual share, contacts and client observation, and the PDF adds a monthly verification table. The `-fieldworkSample` launch argument loads a BCBA sample.
- **Supervisors**: name, credentials, license number and contact, printed on the PDF beside the signature line.
- **Log hours**: category (direct, indirect, individual supervision, group supervision, training), duration chips or hours and minutes, site, supervisor, clients seen, a "supervisor has signed off" flag and notes. A session timer prefills an entry.
- **Progress**: counted total, requirement bars with hours to go, this week by category with an optional cap warning, and pace over the last 8 weeks with a projected finish.
- **Log**: entries grouped by calendar week with per-category totals, filtered by category.
- **Report**: all time or one month, hours by category, progress, a PDF log (supervisee, supervisors, totals, by week, every entry, signature lines) and CSV.
- Weekly reminder, widget, and a How do I use this app guide.

## The boundary

Training hours are recorded but excluded from the counted total; every other category counts. Requirements are whatever the user typed, and the PDF footer says the hours are as entered by the supervisee. Your licensing board's rules and your supervisor's records are the authority.

## Privacy

Data stays on the device in SwiftData. There is no account, no analytics and no network access; iCloud sync is off (`iCloudSyncEnabled = false`). CSV and PDF files leave the device only when you share them.

## Build and run

Requirements: Xcode 26 or later, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`), and iOS 17 or later.

```bash
xcodegen generate
open SupervisionHours.xcodeproj
```

Pick the `SupervisionHours` scheme and an iPhone simulator, then Run.

Tests:

```bash
xcodebuild -scheme SupervisionHours -destination 'platform=iOS Simulator,name=iPhone 16 Pro Max' test
```

Paywall: the app has a hard paywall (annual subscription or lifetime purchase). Running from Xcode uses the bundled `Products.storekit` file, so purchases are simulated and free. Debug builds can also skip it with the `-unlock` launch argument or the Debug switch in Settings.

To run on your own device or ship it:

- Set your team in `project.yml` (`DEVELOPMENT_TEAM`).
- Change the `com.example` bundle ID prefix in `project.yml`, both `.entitlements` files and `Products.storekit`.
- Update `supportEmail`, `privacyPolicyURL` and `appStoreID` in `Shared/AppConfig.swift`.

## Notes for developers

- `HoursMath` holds the totals, weekly grouping and pace calculation; `TrackMode` and `LicenseTrack` describe the license tracks.
- Debug launch arguments: `-unlock`, `-sampleData`, `-resetData`, `-skipOnboarding`, `-mockPrices`.

## Project layout

- `SupervisionHours/App/`: app entry point and `RootView`, the single gate (onboarding, paywall, app).
- `SupervisionHours/Core/`: `HoursMath`, session timer, track mode, CSV/PDF export, weekly reminder, StoreKit entitlement store, App Intents, review prompt, sample data.
- `SupervisionHours/Features/`: Entries, Log, Progress, Report, Supervisors, Track, Settings, Help, Onboarding, Paywall.
- `SupervisionHours/Models/`: `HoursEntry`, `Supervisor`, `LicenseTrack`.
- `SupervisionHoursWidget/`: home screen widget reading a snapshot from the App Group.
- `SupervisionHoursTests/`, `SupervisionHoursUITests/`: unit tests and screenshot UI tests.
- `Shared/AppConfig.swift`: everything that changes per app (name, copy, product IDs, links, onboarding, how-to guide).
- App Shortcut: "Log hours in Supervision Hours".

## License

MIT. See [LICENSE](LICENSE).
