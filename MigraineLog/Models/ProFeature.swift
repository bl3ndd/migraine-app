import Foundation

/// Everything behind the one-time Pro unlock. Logging, the calendar, history,
/// Apple Health, backup, reminders and the widget are never gated: the data is
/// the user's.
nonisolated enum ProFeature: Sendable {
    case pdfReport, fullStats

    /// The single gating predicate every view goes through.
    static func isLocked(_ feature: ProFeature, isPro: Bool) -> Bool {
        !isPro
    }
}
