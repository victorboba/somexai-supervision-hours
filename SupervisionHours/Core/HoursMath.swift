import Foundation

/// Pure arithmetic over the entry list: totals per category, weekly grouping, progress and pace.
enum HoursMath {
    struct Totals: Equatable {
        var direct: Double = 0
        var indirect: Double = 0
        var supervisionIndividual: Double = 0
        var supervisionGroup: Double = 0
        var training: Double = 0

        var supervision: Double { supervisionIndividual + supervisionGroup }
        /// Everything the board counts: direct, indirect and supervision. Training is recorded but excluded.
        var total: Double { direct + indirect + supervision }

        func hours(for category: HourCategory) -> Double {
            switch category {
            case .direct: return direct
            case .indirect: return indirect
            case .supervisionIndividual: return supervisionIndividual
            case .supervisionGroup: return supervisionGroup
            case .training: return training
            }
        }
    }

    static func totals(_ entries: [HoursEntry]) -> Totals {
        var t = Totals()
        for e in entries {
            let h = e.hours
            switch e.category {
            case .direct: t.direct += h
            case .indirect: t.indirect += h
            case .supervisionIndividual: t.supervisionIndividual += h
            case .supervisionGroup: t.supervisionGroup += h
            case .training: t.training += h
            }
        }
        return t
    }

    // MARK: Weeks

    static func weekStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .weekOfYear, for: date)?.start ?? calendar.startOfDay(for: date)
    }

    struct Week: Identifiable {
        let start: Date
        var entries: [HoursEntry]
        var id: Date { start }
        var totals: Totals { HoursMath.totals(entries) }
    }

    /// Entries grouped by calendar week, newest week first, entries within a week newest first.
    static func weeks(_ entries: [HoursEntry], calendar: Calendar = .current) -> [Week] {
        let grouped = Dictionary(grouping: entries) { weekStart(of: $0.date, calendar: calendar) }
        return grouped.keys.sorted(by: >).map { Week(start: $0, entries: (grouped[$0] ?? []).sorted { $0.date > $1.date }) }
    }

    static func inWeek(_ entries: [HoursEntry], of date: Date, calendar: Calendar = .current) -> [HoursEntry] {
        guard let interval = calendar.dateInterval(of: .weekOfYear, for: date) else { return [] }
        return entries.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    static func monthStart(of date: Date, calendar: Calendar = .current) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    static func inMonth(_ entries: [HoursEntry], of date: Date, calendar: Calendar = .current) -> [HoursEntry] {
        guard let interval = calendar.dateInterval(of: .month, for: date) else { return [] }
        return entries.filter { $0.date >= interval.start && $0.date < interval.end }
    }

    static func between(_ entries: [HoursEntry], from start: Date, to end: Date) -> [HoursEntry] {
        entries.filter { $0.date >= start && $0.date <= end }
    }

    /// Months that have entries, newest first.
    static func months(_ entries: [HoursEntry], calendar: Calendar = .current) -> [Date] {
        Set(entries.compactMap { calendar.date(from: calendar.dateComponents([.year, .month], from: $0.date)) }).sorted(by: >)
    }

    // MARK: Progress

    struct Requirement: Identifiable {
        let name: String
        let done: Double
        let required: Double
        var id: String { name }
        var remaining: Double { max(0, required - done) }
        var fraction: Double { required > 0 ? min(done / required, 1) : 0 }
        var isMet: Bool { required > 0 && done >= required }
    }

    static func requirements(track: LicenseTrack, totals: Totals) -> [Requirement] {
        var list = [
            Requirement(name: "Total hours", done: totals.total, required: track.requiredTotalHours),
            Requirement(name: "Direct client contact", done: totals.direct, required: track.requiredDirectHours),
            Requirement(name: "Supervision", done: totals.supervision, required: track.requiredSupervisionHours),
        ]
        if track.requiredIndividualSupervisionHours > 0 {
            list.append(Requirement(name: "Individual supervision", done: totals.supervisionIndividual, required: track.requiredIndividualSupervisionHours))
        }
        return list.filter { $0.required > 0 }
    }

    // MARK: Pace

    struct Pace {
        /// Counted hours per week averaged over the recent window.
        var hoursPerWeek: Double
        var weeksSampled: Int
        /// When the slowest requirement is projected to be met at this pace; nil when nothing is logged or all met.
        var projectedFinish: Date?
        var limitingRequirement: String?
    }

    /// Averages the last `windowWeeks` calendar weeks (including the current one) and projects each requirement forward.
    static func pace(track: LicenseTrack, entries: [HoursEntry], now: Date = .now, windowWeeks: Int = 8, calendar: Calendar = .current) -> Pace {
        let currentWeek = weekStart(of: now, calendar: calendar)
        guard let windowStart = calendar.date(byAdding: .weekOfYear, value: -(windowWeeks - 1), to: currentWeek) else {
            return Pace(hoursPerWeek: 0, weeksSampled: 0, projectedFinish: nil, limitingRequirement: nil)
        }
        let firstEntry = entries.map(\.date).min().map { weekStart(of: $0, calendar: calendar) } ?? currentWeek
        let sampleStart = max(windowStart, firstEntry)
        let sampled = entries.filter { $0.date >= sampleStart }
        let weeksSampled = max(1, (calendar.dateComponents([.weekOfYear], from: sampleStart, to: currentWeek).weekOfYear ?? 0) + 1)
        let window = totals(sampled)
        let perWeek = window.total / Double(weeksSampled)

        var finish: Date?
        var limiting: String?
        guard !entries.isEmpty else { return Pace(hoursPerWeek: 0, weeksSampled: 0, projectedFinish: nil, limitingRequirement: nil) }
        let all = totals(entries)
        let rates: [(String, Double, Double)] = [
            ("Total hours", all.total, track.requiredTotalHours > 0 ? window.total / Double(weeksSampled) : 0),
            ("Direct client contact", all.direct, window.direct / Double(weeksSampled)),
            ("Supervision", all.supervision, window.supervision / Double(weeksSampled)),
        ]
        let required = [track.requiredTotalHours, track.requiredDirectHours, track.requiredSupervisionHours]
        for ((name, done, rate), need) in zip(rates, required) where need > 0 && done < need {
            guard rate > 0 else { continue }
            let weeks = (need - done) / rate
            if let date = calendar.date(byAdding: .day, value: Int((weeks * 7).rounded(.up)), to: currentWeek) {
                if finish == nil || date > finish! { finish = date; limiting = name }
            }
        }
        return Pace(hoursPerWeek: perWeek, weeksSampled: weeksSampled, projectedFinish: finish, limitingRequirement: limiting)
    }

    // MARK: BACB fieldwork

    struct Check: Identifiable {
        let name: String
        let value: String
        let passed: Bool
        var id: String { name }
    }

    /// The BACB's per-month rules applied to one month's entries. Empty when the track is not fieldwork.
    static func monthlyChecks(track: LicenseTrack, entries: [HoursEntry], month: Date, calendar: Calendar = .current) -> [Check] {
        guard track.isFieldwork else { return [] }
        let mine = inMonth(entries, of: month, calendar: calendar)
        let t = totals(mine)
        guard t.total > 0 else { return [] }
        var checks: [Check] = []
        if track.minMonthlyHours > 0 || track.maxMonthlyHours > 0 {
            let lo = track.minMonthlyHours, hi = track.maxMonthlyHours
            let ok = (lo == 0 || t.total >= lo) && (hi == 0 || t.total <= hi)
            let range = hi > 0 ? "\(Formatters.hours(lo, unit: false))–\(Formatters.hours(hi))" : "at least \(Formatters.hours(lo))"
            checks.append(Check(name: "Hours this month", value: "\(Formatters.hours(t.total)) (\(range))", passed: ok))
        }
        if track.supervisionPercentPerMonth > 0 {
            let pct = t.supervision / t.total * 100
            checks.append(Check(name: "Supervision share", value: "\(Formatters.percent(pct)) (min \(Formatters.percent(track.supervisionPercentPerMonth)))", passed: pct + 0.0001 >= track.supervisionPercentPerMonth))
        }
        if track.individualSupervisionPercentMin > 0, t.supervision > 0 {
            let pct = t.supervisionIndividual / t.supervision * 100
            checks.append(Check(name: "Individual share of supervision", value: "\(Formatters.percent(pct)) (min \(Formatters.percent(track.individualSupervisionPercentMin)))", passed: pct + 0.0001 >= track.individualSupervisionPercentMin))
        }
        if track.contactsPerMonth > 0 {
            let contacts = mine.filter { $0.category.isSupervision }.count
            checks.append(Check(name: "Supervisor contacts", value: "\(contacts) (min \(track.contactsPerMonth))", passed: contacts >= track.contactsPerMonth))
        }
        if track.observationPerMonth {
            let observed = mine.contains { $0.category.isSupervision && $0.hasObservation }
            checks.append(Check(name: "Client observation", value: observed ? "Yes" : "None logged", passed: observed))
        }
        return checks
    }

    /// Overall ratio requirements for fieldwork: unrestricted share of all hours, supervision share of all hours.
    static func ratioRequirements(track: LicenseTrack, totals: Totals) -> [Check] {
        guard track.isFieldwork, totals.total > 0 else { return [] }
        var checks: [Check] = []
        if track.unrestrictedPercentMin > 0 {
            let pct = totals.indirect / totals.total * 100
            checks.append(Check(name: "Unrestricted share of all hours", value: "\(Formatters.percent(pct)) (min \(Formatters.percent(track.unrestrictedPercentMin)))", passed: pct + 0.0001 >= track.unrestrictedPercentMin))
        }
        if track.supervisionPercentPerMonth > 0 {
            let pct = totals.supervision / totals.total * 100
            checks.append(Check(name: "Supervision share of all hours", value: "\(Formatters.percent(pct)) (min \(Formatters.percent(track.supervisionPercentPerMonth)))", passed: pct + 0.0001 >= track.supervisionPercentPerMonth))
        }
        return checks
    }

    /// Distinct site names, most recently used first.
    static func recentSites(_ entries: [HoursEntry]) -> [String] {
        var seen = Set<String>()
        return entries.sorted { $0.date > $1.date }.compactMap { e in
            let s = e.siteName.trimmingCharacters(in: .whitespaces)
            guard !s.isEmpty, !seen.contains(s) else { return nil }
            seen.insert(s)
            return s
        }
    }
}
