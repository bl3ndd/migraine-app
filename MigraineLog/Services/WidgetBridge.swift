import Foundation
import WidgetKit

/// What the widget shows, written by the app into the shared App Group.
/// The widget target keeps an identical copy (MigraineLogWidget/WidgetSnapshot.swift):
/// change both together. Dates rather than counts, so the widget can work out
/// "days headache-free" itself as days pass without the app running.
nonisolated struct WidgetSnapshot: Codable, Equatable, Sendable {
    /// Start of the attack in progress, if any.
    var ongoingSince: Date?
    /// End of the most recent finished attack.
    var lastEnd: Date?
    /// Headache days so far in the calendar month of `monthStart`.
    var monthHeadacheDays: Int
    var monthStart: Date
}

/// App side of the widget: publishes the snapshot and recognizes its links.
/// The App Group container is local to the device, not iCloud (guideline 5.1.3(ii)).
enum WidgetBridge {
    static let appGroup = "group.white.tea.MigraineLog"
    static let snapshotKey = "widgetSnapshot"

    nonisolated static func snapshot(_ attacks: [AttackValue], now: Date, calendar: Calendar) -> WidgetSnapshot {
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        let inMonth = StatsEngine.attacks(attacks, in: month, now: now)
        return WidgetSnapshot(ongoingSince: attacks.filter { $0.end == nil }.map(\.start).max(),
                              lastEnd: attacks.compactMap(\.end).max(),
                              monthHeadacheDays: StatsEngine.headacheDays(inMonth, now: now, calendar: calendar, within: month).count,
                              monthStart: month.start)
    }

    /// Writes the snapshot and asks widgets to redraw.
    static func publish(_ attacks: [AttackValue]) {
        guard !LaunchMode.isThrowaway, let defaults = UserDefaults(suiteName: appGroup),
              let data = try? JSONEncoder().encode(snapshot(attacks, now: Date(), calendar: .current)) else { return }
        defaults.set(data, forKey: snapshotKey)
        WidgetCenter.shared.reloadAllTimelines()
    }

    /// `migrainelog://log`: open the app straight on the log form.
    nonisolated static func isLogLink(_ url: URL) -> Bool {
        url.scheme == "migrainelog" && url.host == "log"
    }
}
