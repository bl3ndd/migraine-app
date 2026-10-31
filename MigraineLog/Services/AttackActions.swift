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
            Analytics.track(.attackDeleted)
        }
        try? context.save()
    }

    /// Ends an ongoing attack now and, with Health on, writes it there.
    static func end(_ attack: Attack, at date: Date = Date(), context: ModelContext, settings: AppSettings) {
        attack.end = max(date, attack.start)
        try? context.save()
        Analytics.track(.attackEnded)
        syncToHealth(attack, previousHealthID: nil, context: context, settings: settings)
    }

    /// Mirrors a finished manual attack to Health; an edit replaces the old sample.
    static func syncToHealth(_ attack: Attack, previousHealthID: UUID?, context: ModelContext, settings: AppSettings) {
        guard settings.healthEnabled, attack.source == .manual, attack.end != nil else { return }
        let value = attack.value
        let meta = HealthMeta(attack)
        let attackID = attack.id
        Task {
            if let previousHealthID { await HealthService.delete(healthKitID: previousHealthID) }
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
