import Foundation

/// The one file to edit when starting a new app from this template.
enum AppConfig {
    // MARK: Identity
    static let appName = "Supervision Hours"
    static let bundleID = "com.example.supervision-hours"
    static let appGroupID = "group.com.example.supervision-hours"
    static let appStoreID = ""

    // MARK: Sync
    static let iCloudSyncEnabled = false

    // MARK: StoreKit
    static let productPrefix = bundleID.replacingOccurrences(of: "-", with: "")
    static let annualProductID = "\(productPrefix).pro.annual"
    static let lifetimeProductID = "\(productPrefix).pro.lifetime"

    // MARK: Links
    static let supportEmail = "support@somexai.com"
    static let privacyPolicyURL = URL(string: "https://somexai.com/privacy/supervision-hours/")!
    static let termsURL = URL(string: "https://www.apple.com/legal/internet-services/itunes/dev/stdeula/")!

    // MARK: Copy
    static let entryNoun = "Entry"
    static let entryNounPlural = "Entries"
    static let exportFileStem = "supervision-hours"

    static let disclaimer = "Supervision Hours keeps the log you fill in. Required hours and categories are whatever you typed in Settings; your licensing board's rules and your supervisor's records are the authority."

    static let onboarding: [OnboardingPage] = [
        OnboardingPage(symbol: "list.clipboard", title: "Every hour, in your board's categories",
                       body: "Direct and indirect hours for LPC, LMFT and LCSW tracks; restricted and unrestricted for BCBA fieldwork. Individual and group supervision. Log in seconds or run a timer."),
        OnboardingPage(symbol: "chart.bar.xaxis", title: "See exactly how far you are",
                       body: "Progress toward the total, the direct hours and the supervision hours you need, plus a finish date at your current pace."),
        OnboardingPage(symbol: "signature", title: "A log your supervisor can sign",
                       body: "Weekly totals, every entry, and signature lines in one PDF. CSV too. Everything stays on your phone."),
    ]

    static let paywallSymbol = "checkmark.seal.fill"
    static let paywallHeadline = "Unlock \(appName)"
    static let paywallBenefits = [
        "Hours by category with progress toward your board's numbers",
        "BCBA fieldwork mode with the BACB's monthly rules checked for you",
        "Weekly log, session timer, pace and projected finish",
        "Signature-ready PDF log and CSV export",
        "Widget, Siri Shortcut, no ads, no account",
    ]

    // MARK: How-to guide
    static let howToIntro = "Set up once, then each session takes ten seconds to log. Here is the order a new associate goes through."
    static let howTo: [HowToStep] = [
        HowToStep(symbol: "flag", title: "Set up your track",
                  body: "On first launch tap Set Up (later: Settings → Track). Enter your license type, state, start date, and the hours your board requires: total, direct client contact, supervision, and individual supervision if there is a minimum. Pick BCBA or BCaBA fieldwork and the form switches to the BACB rules: total hours, supervision percent per month, contacts per month, unrestricted minimum.",
                  tip: "Copy the numbers from your board's rules page or the BACB handbook. The app never guesses them."),
        HowToStep(symbol: "person.badge.shield.checkmark", title: "Add your supervisor",
                  body: "Settings → Supervisors → Add. Name, credentials and license number go onto the PDF log."),
        HowToStep(symbol: "plus.circle.fill", title: "Log hours",
                  body: "On Progress tap Direct, Indirect or Supervision, pick the duration, site and supervisor, and save. Or tap Start Timer before a session and Stop after; the entry is prefilled.",
                  tip: "Say \"Log hours in \(appName)\" to Siri to open the form from anywhere."),
        HowToStep(symbol: "chart.bar", title: "Check progress and pace",
                  body: "The bars show hours done against each requirement. The Pace card uses your last eight weeks to estimate when you will finish. On a fieldwork track a monthly card shows each BACB rule (hours, supervision share, contacts, observation) as met or not."),
        HowToStep(symbol: "calendar", title: "Review the week",
                  body: "The Log tab groups entries by week with totals per category, the way most boards want them. Tap an entry to edit, swipe to delete."),
        HowToStep(symbol: "signature", title: "Export the log for signatures",
                  body: "Report → choose a month or All time → PDF. It has the totals, every entry, and signature lines for you and each supervisor."),
        HowToStep(symbol: "bell", title: "Weekly reminder and widget",
                  body: "Settings → Weekly reminder picks a day and time to nudge you to log the week. For the widget, long-press the Home Screen, tap +, search \"\(appName)\"."),
    ]

    static let mockPrices = (annual: "$14.99", lifetime: "$34.99")

    // MARK: Behaviour
    static let reviewAfterSuccesses = 3
}

struct HowToStep: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
    var tip: String? = nil
}

struct OnboardingPage: Identifiable, Hashable {
    var id: String { title }
    let symbol: String
    let title: String
    let body: String
}
