import Testing
import Foundation
import UserNotifications
@testable import MigraineLog

struct RemindersTests {
    @Test func oneRepeatingRequestPerTime() throws {
        let requests = NotificationService.requests(minutes: [1260, 1260])
        #expect(requests.map(\.identifier) == ["checkin-reminder-1260"])
        let trigger = try #require(requests[0].trigger as? UNCalendarNotificationTrigger)
        #expect(trigger.repeats)
        #expect(trigger.dateComponents.hour == 21 && trigger.dateComponents.minute == 0)
        #expect(requests[0].content.body.contains("headache"))
        #expect(NotificationService.requests(minutes: []).isEmpty)
    }

    @Test func timeConversionRoundTrips() {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/New_York")!
        let day = Date(timeIntervalSince1970: 1_800_000_000)
        for minutes in [0, 480, 755, 1260, 1439] {
            let date = ReminderTime.date(fromMinutes: minutes, calendar: calendar, on: day)
            #expect(ReminderTime.minutes(from: date, calendar: calendar) == minutes)
        }
    }
}

@MainActor
@Suite(.serialized)
struct ReviewServiceTests {
    /// Saves `attacks`, then opens Home with `freeDays`; returns how many prompts fired.
    private func run(attacks: Int, freeDays: [Int?]) -> Int {
        let defaults = UserDefaults(suiteName: "ReviewServiceTests-\(UUID())")!
        var prompts = 0
        let (savedDefaults, savedPrompt) = (ReviewService.defaults, ReviewService.prompt)
        ReviewService.defaults = defaults
        ReviewService.prompt = { prompts += 1 }
        defer { ReviewService.defaults = savedDefaults; ReviewService.prompt = savedPrompt }
        for _ in 0..<attacks { ReviewService.recordAttack() }
        freeDays.forEach(ReviewService.considerPrompt)
        return prompts
    }

    @Test func promptsOnceAfterThresholdOnAGoodDay() {
        #expect(run(attacks: ReviewService.threshold - 1, freeDays: [5]) == 0)
        #expect(run(attacks: ReviewService.threshold, freeDays: [2, 3, 4]) == 1)
    }

    @Test func neverDuringOrRightAfterAnAttack() {
        #expect(run(attacks: 10, freeDays: [0, nil]) == 0)
        #expect(run(attacks: 10, freeDays: [0, 1]) == 1)
    }
}
