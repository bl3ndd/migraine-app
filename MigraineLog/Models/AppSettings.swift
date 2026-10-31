import Foundation
import Observation

/// User preferences backed by UserDefaults.
@Observable
final class AppSettings {
    @ObservationIgnored private let defaults: UserDefaults

    var hasCompletedOnboarding: Bool { didSet { defaults.set(hasCompletedOnboarding, forKey: Keys.onboarding) } }
    /// The paywall is offered once, after the first saved attack, never again unprompted.
    var hasSeenIntroPaywall: Bool { didSet { defaults.set(hasSeenIntroPaywall, forKey: Keys.introPaywall) } }
    var healthEnabled: Bool { didSet { defaults.set(healthEnabled, forKey: Keys.health) } }
    /// Anonymous usage counts (TelemetryDeck). On by default, as in Mezame; off in Settings.
    var analyticsEnabled: Bool {
        didSet {
            defaults.set(analyticsEnabled, forKey: Keys.analytics)
            Analytics.setEnabled(analyticsEnabled)
        }
    }
    /// Set by a widget's "log" link; Home opens the log form and clears it. Not persisted.
    var pendingLog = false
    /// Health sample ids and attack ids the user deleted, so a Health sync never
    /// brings them back.
    private(set) var deletedIDs: Set<UUID> {
        didSet { defaults.set(deletedIDs.map(\.uuidString), forKey: Keys.deleted) }
    }
    /// Reminder times as minutes since midnight (1260 = 21:00). One evening check-in.
    var reminderMinutes: [Int] { didSet { defaults.set(reminderMinutes, forKey: Keys.reminders) } }
    /// The medicines the person usually takes, offered as one-tap chips when logging.
    var medicationNames: [String] { didSet { defaults.set(medicationNames, forKey: Keys.medications) } }

    func rememberDeleted(_ ids: [UUID]) {
        deletedIDs.formUnion(ids)
    }

    /// Adds a name typed while logging, so it's a chip next time. Case-insensitive, keeps the first spelling.
    func rememberMedication(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty, !medicationNames.contains(where: { $0.caseInsensitiveCompare(clean) == .orderedSame }) else { return }
        medicationNames.append(clean)
    }

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        hasCompletedOnboarding = defaults.bool(forKey: Keys.onboarding)
        hasSeenIntroPaywall = defaults.bool(forKey: Keys.introPaywall)
        healthEnabled = defaults.bool(forKey: Keys.health)
        deletedIDs = Set((defaults.stringArray(forKey: Keys.deleted) ?? []).compactMap(UUID.init(uuidString:)))
        analyticsEnabled = defaults.object(forKey: Keys.analytics) as? Bool ?? true
        reminderMinutes = defaults.array(forKey: Keys.reminders) as? [Int] ?? []
        medicationNames = defaults.stringArray(forKey: Keys.medications) ?? []
    }

    private enum Keys {
        static let onboarding = "hasCompletedOnboarding"
        static let introPaywall = "hasSeenIntroPaywall"
        static let health = "healthEnabled"
        static let deleted = "deletedAttackIDs"
        static let analytics = "analyticsEnabled"
        static let reminders = "reminderMinutes"
        static let medications = "medicationNames"
    }
}
