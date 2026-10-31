import Testing
import Foundation
@testable import MigraineLog

struct StatsEngineTests {
    /// Fixed UTC Gregorian calendar so day buckets don't depend on the device.
    static let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()

    /// 2026-10-05 is a Monday.
    static func date(day: Int, hour: Int = 9, month: Int = 10) -> Date {
        calendar.date(from: DateComponents(year: 2026, month: month, day: day, hour: hour))!
    }

    static func a(day: Int, hour: Int = 9, hours: Double? = 4, intensity: Int = 6, kind: AttackKind = .migraine, month: Int = 10,
                  triggers: [Trigger] = [], symptoms: [Symptom] = [], meds: [MedicationDose] = []) -> AttackValue {
        let start = date(day: day, hour: hour, month: month)
        return AttackValue(start: start, end: hours.map { start.addingTimeInterval($0 * 3600) }, intensity: intensity, kind: kind,
                           symptoms: symptoms, triggers: triggers, medications: meds)
    }

    let cal = StatsEngineTests.calendar
    let now = StatsEngineTests.date(day: 31, hour: 12)

    @Test func emptyHistory() {
        let s = StatsEngine.summary([], in: nil, now: now, calendar: cal)
        #expect(s == StatsEngine.Summary(attacks: 0, headacheDays: 0, migraineDays: 0, medicationDays: 0, averageIntensity: nil, averageDuration: nil))
        #expect(StatsEngine.headacheFreeDays([], now: now, calendar: cal) == nil)
        #expect(StatsEngine.triggerShares([]).isEmpty)
        #expect(StatsEngine.medicationResults([]).isEmpty)
    }

    @Test func dayCountsOnceWithSeveralAttacks() {
        let attacks = [Self.a(day: 5, hour: 7), Self.a(day: 5, hour: 18, kind: .headache), Self.a(day: 9)]
        #expect(StatsEngine.headacheDays(attacks, now: now, calendar: cal).count == 2)
    }

    @Test func attackPastMidnightCountsBothDays() {
        let overnight = Self.a(day: 5, hour: 22, hours: 6)
        #expect(StatsEngine.days(of: overnight, now: now, calendar: cal) == [cal.startOfDay(for: Self.date(day: 5)), cal.startOfDay(for: Self.date(day: 6))])
        // Ending exactly at midnight doesn't touch the next day.
        let toMidnight = Self.a(day: 5, hour: 22, hours: 2)
        #expect(StatsEngine.days(of: toMidnight, now: now, calendar: cal).count == 1)
    }

    @Test func ongoingAttackCoversUntilNow() {
        let ongoing = Self.a(day: 29, hour: 20, hours: nil)
        #expect(StatsEngine.days(of: ongoing, now: now, calendar: cal).count == 3)  // 29, 30, 31
        #expect(StatsEngine.headacheFreeDays([ongoing, Self.a(day: 2)], now: now, calendar: cal) == 0)
    }

    @Test func daysClipToTheInterval() {
        let monthStart = Self.date(day: 1, hour: 0)
        let october = DateInterval(start: monthStart, end: Self.date(day: 1, hour: 0, month: 11))
        // Sept 30 22:00 → Oct 1 04:00 counts one October day.
        let crossing = AttackValue(start: monthStart.addingTimeInterval(-2 * 3600), end: monthStart.addingTimeInterval(4 * 3600), intensity: 5)
        #expect(StatsEngine.days(of: crossing, now: now, calendar: cal, within: october).count == 1)
        #expect(StatsEngine.attacks([crossing], in: october, now: now).count == 1)
    }

    @Test func summaryNumbers() {
        let meds = [MedicationDose(name: "Ibuprofen", takenAt: Self.date(day: 5, hour: 10))]
        let attacks = [Self.a(day: 5, hours: 2, intensity: 4, kind: .headache, meds: meds),
                       Self.a(day: 12, hours: 6, intensity: 8),
                       Self.a(day: 30, hours: nil, intensity: 6)]
        let s = StatsEngine.summary(attacks, in: nil, now: now, calendar: cal)
        #expect(s.attacks == 3)
        #expect(s.headacheDays == 4)  // 5, 12, 30, 31
        #expect(s.migraineDays == 3)
        #expect(s.medicationDays == 1)
        #expect(s.averageIntensity == 6)
        #expect(abs(s.averageDuration! - 4 * 3600) < 0.01)  // ongoing doesn't count
    }

    @Test func medicationDaysCountDistinctDays() {
        let meds = [MedicationDose(name: "A", takenAt: Self.date(day: 5, hour: 9)),
                    MedicationDose(name: "B", takenAt: Self.date(day: 5, hour: 15)),
                    MedicationDose(name: "A", takenAt: Self.date(day: 6, hour: 1))]
        #expect(StatsEngine.medicationDays([Self.a(day: 5, hours: 20, meds: meds)], calendar: cal).count == 2)
    }

    @Test func monthlyIncludesEmptyMonthsOldestFirst() {
        let attacks = [Self.a(day: 3, month: 8), Self.a(day: 4, kind: .headache, month: 8), Self.a(day: 20)]
        let months = StatsEngine.monthly(attacks, months: 4, now: now, calendar: cal)
        #expect(months.map(\.headacheDays) == [0, 2, 0, 1])
        #expect(months.map(\.migraineDays) == [0, 1, 0, 1])
        #expect(months.last?.month == Self.date(day: 1, hour: 0))
    }

    @Test func dayPeaksKeepTheWorst() {
        let october = DateInterval(start: Self.date(day: 1, hour: 0), end: Self.date(day: 1, hour: 0, month: 11))
        let peaks = StatsEngine.dayPeaks([Self.a(day: 5, intensity: 3), Self.a(day: 5, hour: 18, intensity: 8)], now: now, calendar: cal, within: october)
        #expect(peaks == [cal.startOfDay(for: Self.date(day: 5)): 8])
    }

    @Test func triggerSharesSortedByCountThenOrderSeen() {
        let attacks = [Self.a(day: 1, triggers: [.stress, .poorSleep]), Self.a(day: 2, triggers: [.poorSleep]),
                       Self.a(day: 3, triggers: [.weather]), Self.a(day: 4)]
        let shares = StatsEngine.triggerShares(attacks)
        #expect(shares.map(\.item) == [.poorSleep, .stress, .weather])
        #expect(shares[0].count == 2)
        #expect(shares[0].share == 0.5)
    }

    @Test func medicationResultsGroupByNameIgnoringCase() {
        let t = Self.date(day: 1)
        let attacks = [Self.a(day: 1, meds: [MedicationDose(name: "Sumatriptan", takenAt: t, effect: .helped)]),
                       Self.a(day: 2, meds: [MedicationDose(name: "sumatriptan ", takenAt: t, effect: .none)]),
                       Self.a(day: 3, meds: [MedicationDose(name: "Sumatriptan", takenAt: t, effect: .unknown),
                                              MedicationDose(name: "Ibuprofen", takenAt: t, effect: .partly)])]
        let results = StatsEngine.medicationResults(attacks)
        #expect(results.map(\.name) == ["Sumatriptan", "Ibuprofen"])
        #expect(results[0].doses == 3)
        #expect(results[0].rated == 2)
        #expect(results[0].helpedShare == 0.5)
        #expect(results[1].helpedShare == 1)
    }

    @Test func partOfDayAndWeekday() {
        let attacks = [Self.a(day: 5, hour: 2), Self.a(day: 5, hour: 7), Self.a(day: 6, hour: 11), Self.a(day: 12, hour: 19)]
        let parts = StatsEngine.partOfDayCounts(attacks, calendar: cal)
        #expect(parts[.night] == 1 && parts[.morning] == 2 && parts[.evening] == 1 && parts[.afternoon] == nil)
        let weekdays = StatsEngine.weekdayCounts(attacks, calendar: cal)
        #expect(weekdays[2] == 3)  // Mondays
        #expect(weekdays[3] == 1)
    }

    @Test func headacheFreeDaysCountFromLastEnd() {
        #expect(StatsEngine.headacheFreeDays([Self.a(day: 27, hours: 3), Self.a(day: 10)], now: now, calendar: cal) == 4)
        #expect(StatsEngine.headacheFreeDays([Self.a(day: 31, hour: 6, hours: 2)], now: now, calendar: cal) == 0)
    }

    @Test func headacheDayChangeVsPreviousPeriod() {
        // Last 30 days: 2 headache days; the 30 before: 3.
        let attacks = [Self.a(day: 20), Self.a(day: 25), Self.a(day: 10, month: 9), Self.a(day: 12, month: 9), Self.a(day: 15, month: 9)]
        #expect(StatsEngine.headacheDayChange(attacks, period: .month, now: now, calendar: cal) == -1)
        // Nothing logged before the period: no comparison.
        #expect(StatsEngine.headacheDayChange([Self.a(day: 20)], period: .month, now: now, calendar: cal) == nil)
        #expect(StatsEngine.headacheDayChange(attacks, period: .all, now: now, calendar: cal) == nil)
    }

    @Test func periodIntervals() {
        let week = StatsPeriod.month.interval(now: now)!
        #expect(week.end == now)
        #expect(week.duration == 30 * 86_400)
        #expect(StatsPeriod.month.previousInterval(now: now)!.end == week.start)
        #expect(StatsPeriod.all.interval(now: now) == nil)
    }

    @Test func durationText() {
        #expect(DurationText.format(45 * 60) == "45 min")
        #expect(DurationText.format(3 * 3600) == "3 h")
        #expect(DurationText.format(3 * 3600 + 20 * 60) == "3 h 20 min")
        #expect(DurationText.format(52 * 3600) == "2 d 4 h")
        #expect(DurationText.format(72 * 3600) == "3 d")
    }
}
