import Testing
import Foundation
@testable import MigraineLog

struct WidgetBridgeTests {
    let calendar: Calendar = {
        var c = Calendar(identifier: .gregorian)
        c.timeZone = TimeZone(identifier: "UTC")!
        return c
    }()
    /// 2027-01-15 08:00 UTC.
    var now: Date { calendar.date(from: DateComponents(year: 2027, month: 1, day: 15, hour: 8))! }

    private func a(daysAgo: Double, hours: Double? = 3) -> AttackValue {
        let start = now.addingTimeInterval(-daysAgo * 86_400)
        return AttackValue(start: start, end: hours.map { start.addingTimeInterval($0 * 3600) }, intensity: 6)
    }

    @Test func emptyDiary() {
        let s = WidgetBridge.snapshot([], now: now, calendar: calendar)
        #expect(s.ongoingSince == nil && s.lastEnd == nil && s.monthHeadacheDays == 0)
        #expect(s.monthStart == calendar.date(from: DateComponents(year: 2027, month: 1, day: 1)))
    }

    @Test func lastEndAndMonthDays() {
        let attacks = [a(daysAgo: 2), a(daysAgo: 5), a(daysAgo: 20)]  // the last one is in December
        let s = WidgetBridge.snapshot(attacks, now: now, calendar: calendar)
        #expect(s.lastEnd == attacks[0].end)
        #expect(s.ongoingSince == nil)
        #expect(s.monthHeadacheDays == 2)
    }

    @Test func ongoingAttack() {
        let ongoing = a(daysAgo: 0.1, hours: nil)
        let s = WidgetBridge.snapshot([ongoing, a(daysAgo: 4)], now: now, calendar: calendar)
        #expect(s.ongoingSince == ongoing.start)
    }

    @Test func logLink() {
        #expect(WidgetBridge.isLogLink(URL(string: "migrainelog://log")!))
        #expect(!WidgetBridge.isLogLink(URL(string: "migrainelog://other")!))
        #expect(!WidgetBridge.isLogLink(URL(string: "https://log")!))
    }

    @Test func snapshotSurvivesJSON() throws {
        let s = WidgetBridge.snapshot([a(daysAgo: 1)], now: now, calendar: calendar)
        let back = try JSONDecoder().decode(WidgetSnapshot.self, from: JSONEncoder().encode(s))
        #expect(back == s)
    }
}
