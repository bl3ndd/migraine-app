import Foundation
import SwiftData

/// Deleting and ending attacks, shared by Home, the calendar and the log form.
enum AttackActions {
    static func delete(_ attacks: [Attack], context: ModelContext, settings: AppSettings) {
        for a in attacks {
            // Remembered so a Health sync never brings the attack back.
            settings.rememberDeleted([a.id] + (a.healthKitID.map { [$0] } ?? []))
            // Our own writes leave Health too, whatever the sync toggle says now;
            // another app's sample stays that app's.
            if a.source == .manual, let id = a.healthKitID {
                Task { await HealthService.delete(healthKitID: id) }
            }
            context.delete(a)
        }
        try? context.save()
    }

    /// An attack started this long ago is more likely forgotten than still
    /// going: "It's over" then asks for the end time instead of using now.
    static let staleAfter: TimeInterval = 72 * 3600

    static func isStale(_ attack: Attack, now: Date = Date()) -> Bool {
        attack.isOngoing && now.timeIntervalSince(attack.start) > staleAfter
    }

    /// Ends an ongoing attack now and, with Health on, writes it there.
    static func end(_ attack: Attack, at date: Date = Date(), context: ModelContext, settings: AppSettings) {
        attack.end = min(max(date, attack.start), attack.start.addingTimeInterval(AttackLimits.maxDuration))
        try? context.save()
        syncToHealth(attack, previousHealthID: nil, context: context, settings: settings)
    }

    /// Mirrors a manual attack to Health after a save. Our previous sample is
    /// always taken out (even with sync off, as delete does), and the attack
    /// forgets its id at once, so a failed re-save leaves it for the next
    /// backfill instead of pointing at a sample that's gone.
    static func syncToHealth(_ attack: Attack, previousHealthID: UUID?, context: ModelContext, settings: AppSettings) {
        guard attack.source == .manual else { return }
        if let previousHealthID {
            attack.healthKitID = nil
            try? context.save()
            Task { await HealthService.delete(healthKitID: previousHealthID) }
        }
        guard settings.healthEnabled, attack.end != nil else { return }
        let value = attack.value
        let meta = HealthMeta(attack)
        let attackID = attack.id
        Task {
            guard let newID = await HealthService.save(value, meta: meta) else { return }
            // The attack may have been deleted while Health was saving: then
            // take the copy back out instead of writing to a deleted model.
            let match = FetchDescriptor<Attack>(predicate: #Predicate { $0.id == attackID })
            if let current = try? context.fetch(match).first {
                current.healthKitID = newID
                try? context.save()
            } else {
                await HealthService.delete(healthKitID: newID)
            }
        }
    }
}
