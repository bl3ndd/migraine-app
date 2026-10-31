import Testing
import Foundation
@testable import MigraineLog

/// Long histories must stay fast: ~2 attacks a week is ~100 a year, so five
/// years is a realistic heavy user. Budgets are generous; durations are printed.
@MainActor
struct PerformanceTests {
    let now = Date()
    let calendar = Calendar.current

    private func time(_ label: String, _ work: () -> Void) -> Duration {
        let elapsed = ContinuousClock().measure(work)
        print("PERF \(label): \(elapsed)")
        return elapsed
    }

    @Test func statisticsOnFiveYears() {
        let attacks = DemoData.attacks(now: now, calendar: calendar, days: 5 * 365)
        #expect(attacks.count > 300)
        let elapsed = time("stats \(attacks.count) attacks") {
            _ = StatsEngine.summary(attacks, in: nil, now: now, calendar: calendar)
            _ = StatsEngine.monthly(attacks, months: 12, now: now, calendar: calendar)
            _ = StatsEngine.triggerShares(attacks)
            _ = StatsEngine.medicationResults(attacks)
            _ = StatsEngine.partOfDayCounts(attacks, calendar: calendar)
            _ = StatsEngine.weekdayCounts(attacks, calendar: calendar)
            _ = StatsEngine.headacheFreeDays(attacks, now: now, calendar: calendar)
            if let month = calendar.dateInterval(of: .month, for: now) {
                _ = StatsEngine.dayPeaks(attacks, now: now, calendar: calendar, within: month)
            }
        }
        #expect(elapsed < .milliseconds(300))
    }

    @Test func doctorReportOnFiveYears() throws {
        let attacks = DemoData.attacks(now: now, calendar: calendar, days: 5 * 365).map { ReportAttack(value: $0, note: "") }
        var url: URL?
        let elapsed = time("PDF \(attacks.count) attacks") {
            url = PDFGenerator.generate(attacks: attacks, interval: nil, patientName: "", now: now)
        }
        let size = try FileManager.default.attributesOfItem(atPath: try #require(url).path)[.size] as? Int ?? 0
        print("PERF PDF size: \(size / 1024) KB")
        #expect(elapsed < .seconds(8))
    }
}
