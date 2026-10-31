import StoreKit
import UIKit

/// Asks for an App Store rating once the app has proven useful — three logged
/// attacks — at most once per version, and only on a good day: never while an
/// attack is going or on the day one ended. Someone in pain isn't asked to rate.
enum ReviewService {
    /// Swappable for tests, which must not touch the real counters or show a prompt.
    static var defaults: UserDefaults = .standard
    static var prompt: () -> Void = { promptNow() }

    static let threshold = 3
    private static let countKey = "savedAttackCount"
    private static let promptedVersionKey = "reviewPromptedVersion"

    private static var currentVersion: String {
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0"
    }

    /// Screenshot runs drive real flows; a system rating alert must never land in one.
    private static var isSnapshot: Bool {
        ProcessInfo.processInfo.arguments.contains { $0.hasPrefix("-SNAPSHOT") }
    }

    /// Call when a new attack is saved (not on edits).
    static func recordAttack() {
        guard !isSnapshot else { return }
        defaults.set(defaults.integer(forKey: countKey) + 1, forKey: countKey)
    }

    /// Call when Home appears. `headacheFreeDays` is nil with no history, 0 while
    /// an attack is going or one ended today.
    static func considerPrompt(headacheFreeDays: Int?) {
        guard !isSnapshot, let days = headacheFreeDays, days >= 1,
              defaults.integer(forKey: countKey) >= threshold,
              defaults.string(forKey: promptedVersionKey) != currentVersion else { return }
        defaults.set(currentVersion, forKey: promptedVersionKey)
        prompt()
    }

    /// Wait for Home to settle: asking mid-transition gets the alert dropped.
    private static func promptNow() {
        Task { @MainActor in
            try? await Task.sleep(for: .seconds(1.5))
            guard let scene = UIApplication.shared.connectedScenes
                .compactMap({ $0 as? UIWindowScene })
                .first(where: { $0.activationState == .foregroundActive })
            else { return }
            AppStore.requestReview(in: scene)
        }
    }
}
