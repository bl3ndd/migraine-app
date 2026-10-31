import Testing
import Foundation
@testable import MigraineLog

struct DemoDataTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)
    let calendar = Calendar(identifier: .gregorian)

    @Test func deterministicAndPlausible() {
        let a = DemoData.attacks(now: now, calendar: calendar)
        let again = DemoData.attacks(now: now, calendar: calendar)
        #expect(a.map(\.start) == again.map(\.start))
        #expect(a.map(\.intensity) == again.map(\.intensity))
        #expect(a.map(\.triggers) == again.map(\.triggers))
        // ~2 a week over 90 days.
        #expect((15...45).contains(a.count))
        #expect(a.allSatisfy { AttackLimits.problem(start: $0.start, end: $0.end, intensity: $0.intensity, now: now) == nil })
        #expect(a.contains { $0.kind == .headache } && a.contains { $0.kind == .migraine })
        #expect(Set(a.flatMap(\.medications).map(\.name)) == [DemoData.triptan, DemoData.ibuprofen])
    }

    @Test func endsOnAHeadacheFreeStreak() {
        let a = DemoData.attacks(now: now, calendar: calendar)
        #expect(a.allSatisfy { $0.end != nil })
        #expect((StatsEngine.headacheFreeDays(a, now: now, calendar: calendar) ?? 0) >= 3)
    }
}
