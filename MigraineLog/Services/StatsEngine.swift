import Foundation

/// Which stretch of history Statistics and the report cover.
nonisolated enum StatsPeriod: String, CaseIterable, Identifiable, Sendable {
    case month = "30D", quarter = "90D", year = "1Y", all = "All"

    var id: String { rawValue }

    var days: Int? {
        switch self {
        case .month: 30
        case .quarter: 90
        case .year: 365
        case .all: nil
        }
    }

    /// Spelled out for sentences ("the previous 30 days").
    var title: String {
        switch self {
        case .month: "30 days"
        case .quarter: "90 days"
        case .year: "year"
        case .all: "all time"
        }
    }

    /// The last `days` calendar days including today, up to `now`; nil for All.
    /// Whole days, so "30 days" never touches a 31st calendar day.
    func interval(now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard let days else { return nil }
        return StatsEngine.lastDays(days, now: now, calendar: calendar)
    }

    /// The same number of calendar days right before `interval(now:)`, for "vs previous" deltas.
    func previousInterval(now: Date, calendar: Calendar = .current) -> DateInterval? {
        guard let days, let current = interval(now: now, calendar: calendar),
              let start = calendar.date(byAdding: .day, value: -days, to: current.start) else { return nil }
        return DateInterval(start: start, end: current.start)
    }
}

/// Pure statistics over attacks. No SwiftData, no clock: callers pass the
/// attacks, the calendar and "now", so every number is reproducible in tests.
///
/// Headache days are the number neurologists ask for: a day counts once however
/// many attacks it had, and an attack running past midnight counts on every
/// day it touched.
nonisolated enum StatsEngine {
    struct Summary: Equatable, Sendable {
        var attacks: Int
        var headacheDays: Int
        var migraineDays: Int
        var medicationDays: Int
        /// Mean peak pain, nil with no attacks.
        var averageIntensity: Double?
        /// Mean length of attacks that have ended.
        var averageDuration: TimeInterval?
    }

    struct MonthCount: Equatable, Sendable {
        var month: Date
        var headacheDays: Int
        var migraineDays: Int
    }

    struct Share<Item: Hashable & Sendable>: Equatable, Sendable {
        var item: Item
        var count: Int
        /// count / attacks considered, 0…1.
        var share: Double
    }

    struct MedicationResult: Equatable, Sendable {
        var name: String
        var doses: Int
        /// Doses with a yes / a little / no answer; "not sure" doesn't count either way.
        var rated: Int
        var helped: Int
        var partly: Int

        /// Share of rated doses that helped at least a little, nil before any rating.
        var helpedShare: Double? { rated == 0 ? nil : Double(helped + partly) / Double(rated) }
    }

    enum PartOfDay: Int, CaseIterable, Sendable {
        case night, morning, afternoon, evening

        var title: String {
            switch self {
            case .night: "Night"
            case .morning: "Morning"
            case .afternoon: "Afternoon"
            case .evening: "Evening"
            }
        }

        /// Night 0–6, morning 6–12, afternoon 12–18, evening 18–24.
        init(hour: Int) {
            self = PartOfDay(rawValue: min(max(hour, 0), 23) / 6) ?? .night
        }
    }

    /// Doctors look closer when acute headache medicine is taken on 10 or more
    /// days a month (the lower medication-overuse threshold in ICHD-3). The app
    /// only points it out and suggests asking — it never advises dosing.
    static let medicationDaysNotice = 10

    /// The last `days` calendar days including today, from midnight to `now`.
    static func lastDays(_ days: Int, now: Date, calendar: Calendar) -> DateInterval {
        let start = calendar.date(byAdding: .day, value: -(days - 1), to: calendar.startOfDay(for: now)) ?? now
        return DateInterval(start: start, end: max(start, now))
    }

    /// Attacks that overlap the interval at all.
    static func attacks(_ attacks: [AttackValue], in interval: DateInterval, now: Date) -> [AttackValue] {
        attacks.filter { $0.interval(now: now).intersects(interval) || interval.contains($0.start) }
    }

    /// Calendar days an attack touched, clipped to `interval` when given.
    static func days(of attack: AttackValue, now: Date, calendar: Calendar, within interval: DateInterval? = nil) -> Set<Date> {
        var span = attack.interval(now: now)
        if let interval {
            guard let clipped = span.intersection(with: interval) ?? (interval.contains(span.start) ? DateInterval(start: span.start, duration: 0) : nil)
            else { return [] }
            span = clipped
        }
        var result: Set<Date> = []
        var day = calendar.startOfDay(for: span.start)
        // An attack that ends exactly at midnight didn't touch the next day.
        let last = span.end > span.start ? span.end.addingTimeInterval(-1) : span.end
        let lastDay = calendar.startOfDay(for: last)
        while day <= lastDay {
            result.insert(day)
            guard let next = calendar.date(byAdding: .day, value: 1, to: day) else { break }
            day = next
        }
        return result
    }

    static func headacheDays(_ attacks: [AttackValue], now: Date, calendar: Calendar, within interval: DateInterval? = nil) -> Set<Date> {
        attacks.reduce(into: Set<Date>()) { $0.formUnion(days(of: $1, now: now, calendar: calendar, within: interval)) }
    }

    static func medicationDays(_ attacks: [AttackValue], calendar: Calendar, within interval: DateInterval? = nil) -> Set<Date> {
        Set(attacks.flatMap(\.medications)
            .filter { interval?.contains($0.takenAt) ?? true }
            .map { calendar.startOfDay(for: $0.takenAt) })
    }

    static func summary(_ all: [AttackValue], in interval: DateInterval?, now: Date, calendar: Calendar) -> Summary {
        let list = interval.map { attacks(all, in: $0, now: now) } ?? all
        let durations = list.compactMap(\.duration)
        return Summary(
            attacks: list.count,
            headacheDays: headacheDays(list, now: now, calendar: calendar, within: interval).count,
            migraineDays: headacheDays(list.filter { $0.kind == .migraine }, now: now, calendar: calendar, within: interval).count,
            medicationDays: medicationDays(list, calendar: calendar, within: interval).count,
            averageIntensity: mean(list.map { Double($0.intensity) }),
            averageDuration: mean(durations)
        )
    }

    /// Headache and migraine days per calendar month, oldest first, ending with
    /// the month of `now`. Months without attacks are included as zeros.
    static func monthly(_ all: [AttackValue], months: Int, now: Date, calendar: Calendar) -> [MonthCount] {
        guard months > 0, let thisMonth = calendar.dateInterval(of: .month, for: now)?.start else { return [] }
        return (0..<months).reversed().compactMap { back in
            guard let start = calendar.date(byAdding: .month, value: -back, to: thisMonth),
                  let interval = calendar.dateInterval(of: .month, for: start) else { return nil }
            let inMonth = attacks(all, in: interval, now: now)
            return MonthCount(month: start,
                              headacheDays: headacheDays(inMonth, now: now, calendar: calendar, within: interval).count,
                              migraineDays: headacheDays(inMonth.filter { $0.kind == .migraine }, now: now, calendar: calendar, within: interval).count)
        }
    }

    /// Peak pain per day for the calendar grid.
    static func dayPeaks(_ all: [AttackValue], now: Date, calendar: Calendar, within interval: DateInterval) -> [Date: Int] {
        var peaks: [Date: Int] = [:]
        for a in attacks(all, in: interval, now: now) {
            for day in days(of: a, now: now, calendar: calendar, within: interval) {
                peaks[day] = max(peaks[day] ?? 0, a.intensity)
            }
        }
        return peaks
    }

    static func triggerShares(_ attacks: [AttackValue]) -> [Share<Trigger>] {
        shares(attacks, \.triggers)
    }

    static func symptomShares(_ attacks: [AttackValue]) -> [Share<Symptom>] {
        shares(attacks, \.symptoms)
    }

    static func locationShares(_ attacks: [AttackValue]) -> [Share<PainLocation>] {
        shares(attacks, \.locations)
    }

    /// Per medication name (case-insensitive, first spelling wins), most used first.
    static func medicationResults(_ attacks: [AttackValue]) -> [MedicationResult] {
        var results: [String: MedicationResult] = [:]
        var order: [String] = []
        for dose in attacks.flatMap(\.medications) {
            let key = dose.name.trimmingCharacters(in: .whitespaces).lowercased()
            guard !key.isEmpty else { continue }
            if results[key] == nil {
                results[key] = MedicationResult(name: dose.name.trimmingCharacters(in: .whitespaces), doses: 0, rated: 0, helped: 0, partly: 0)
                order.append(key)
            }
            results[key]!.doses += 1
            switch dose.effect {
            case .helped: results[key]!.rated += 1; results[key]!.helped += 1
            case .partly: results[key]!.rated += 1; results[key]!.partly += 1
            case .none: results[key]!.rated += 1
            case .unknown: break
            }
        }
        return order.compactMap { results[$0] }.enumerated()
            .sorted { $0.element.doses != $1.element.doses ? $0.element.doses > $1.element.doses : $0.offset < $1.offset }
            .map(\.element)
    }

    /// Attack starts by part of day.
    static func partOfDayCounts(_ attacks: [AttackValue], calendar: Calendar) -> [PartOfDay: Int] {
        Dictionary(grouping: attacks) { PartOfDay(hour: calendar.component(.hour, from: $0.start)) }.mapValues(\.count)
    }

    /// Attack starts by `Calendar` weekday (1 = Sunday … 7 = Saturday).
    static func weekdayCounts(_ attacks: [AttackValue], calendar: Calendar) -> [Int: Int] {
        Dictionary(grouping: attacks) { calendar.component(.weekday, from: $0.start) }.mapValues(\.count)
    }

    static func intensityCounts(_ attacks: [AttackValue]) -> [IntensityLevel: Int] {
        Dictionary(grouping: attacks, by: \.level).mapValues(\.count)
    }

    /// Whole days since the last attack ended; 0 while one is going or one ended
    /// today, nil with no attacks at all.
    static func headacheFreeDays(_ attacks: [AttackValue], now: Date, calendar: Calendar) -> Int? {
        guard !attacks.isEmpty else { return nil }
        if attacks.contains(where: { $0.end == nil }) { return 0 }
        guard let lastEnd = attacks.compactMap(\.end).max() else { return nil }
        let days = calendar.dateComponents([.day], from: calendar.startOfDay(for: lastEnd), to: calendar.startOfDay(for: now)).day ?? 0
        return max(0, days)
    }

    /// Headache days in the current period minus the previous one.
    static func headacheDayChange(_ all: [AttackValue], period: StatsPeriod, now: Date, calendar: Calendar) -> Int? {
        guard let current = period.interval(now: now, calendar: calendar),
              let previous = period.previousInterval(now: now, calendar: calendar) else { return nil }
        let before = attacks(all, in: previous, now: now)
        guard !before.isEmpty || all.contains(where: { $0.start < previous.start }) else { return nil }
        return headacheDays(attacks(all, in: current, now: now), now: now, calendar: calendar, within: current).count
            - headacheDays(before, now: now, calendar: calendar, within: previous).count
    }

    private static func shares<Item: Hashable & Sendable>(_ attacks: [AttackValue], _ path: KeyPath<AttackValue, [Item]>) -> [Share<Item>] {
        guard !attacks.isEmpty else { return [] }
        var counts: [Item: Int] = [:]
        var order: [Item] = []
        for a in attacks {
            for item in Set(a[keyPath: path]) {
                if counts[item] == nil { order.append(item) }
                counts[item, default: 0] += 1
            }
        }
        let total = Double(attacks.count)
        return order.enumerated()
            .sorted { counts[$0.element]! != counts[$1.element]! ? counts[$0.element]! > counts[$1.element]! : $0.offset < $1.offset }
            .map { Share(item: $0.element, count: counts[$0.element]!, share: Double(counts[$0.element]!) / total) }
    }

    private static func mean(_ values: [Double]) -> Double? {
        values.isEmpty ? nil : values.reduce(0, +) / Double(values.count)
    }
}

/// "3 h 20 min", "45 min", "2 d 4 h".
nonisolated enum DurationText {
    static func format(_ seconds: TimeInterval) -> String {
        let minutes = Int((seconds / 60).rounded())
        if minutes < 60 { return "\(max(minutes, 0)) min" }
        let hours = minutes / 60
        if hours < 48 {
            let rest = minutes % 60
            return rest == 0 ? "\(hours) h" : "\(hours) h \(rest) min"
        }
        let restHours = hours % 24
        return restHours == 0 ? "\(hours / 24) d" : "\(hours / 24) d \(restHours) h"
    }
}
