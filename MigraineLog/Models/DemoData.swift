import Foundation

/// Believable history for `-DEMO`: about two attacks a week, mostly migraines
/// with some lighter headaches, a few long ones running past midnight, triggers
/// that cluster (poor sleep, stress, period, weather), and two medicines with
/// different results. Deterministic, so a demo looks the same every launch.
/// The most recent attack is at least a few days back, so Home shows a streak.
nonisolated enum DemoData {
    static let triptan = "Sumatriptan 50 mg"
    static let ibuprofen = "Ibuprofen 400 mg"

    static func attacks(now: Date, calendar: Calendar, days: Int = 90) -> [AttackValue] {
        var rng = SplitMix64(seed: 2026)
        var out: [AttackValue] = []
        let today = calendar.startOfDay(for: now)
        let cycleStart = calendar.date(byAdding: .day, value: -days, to: today) ?? today
        // Skip the last few days so the demo opens on a headache-free streak.
        for dayOffset in stride(from: days - 1, through: 4, by: -1) {
            guard let day = calendar.date(byAdding: .day, value: -dayOffset, to: today) else { continue }
            let dayInCycle = (calendar.dateComponents([.day], from: cycleStart, to: day).day ?? 0) % 28
            let periodDay = dayInCycle < 3
            // ~2 a week, more around the period.
            guard rng.next(100) < (periodDay ? 45 : 22) else { continue }

            let isMigraine = rng.next(100) < 70
            let hour = [6, 7, 9, 13, 15, 17, 19, 21][Int(rng.next(8))]
            guard let start = calendar.date(byAdding: .minute, value: hour * 60 + Int(rng.next(50)), to: day) else { continue }
            let intensity = isMigraine ? 5 + Int(rng.next(5)) : 2 + Int(rng.next(4))
            let hours = isMigraine ? 4 + Double(rng.next(26)) : 1 + Double(rng.next(5))
            let end = start.addingTimeInterval(hours * 3600 + Double(rng.next(50)) * 60)

            var triggers: [Trigger] = []
            if periodDay { triggers.append(.period) }
            if rng.next(100) < 40 { triggers.append(.poorSleep) }
            if rng.next(100) < 35 { triggers.append(.stress) }
            if rng.next(100) < 20 { triggers.append(.weather) }
            if rng.next(100) < 15 { triggers.append(.skippedMeal) }
            if rng.next(100) < 12 { triggers.append(.screenTime) }
            if rng.next(100) < 8 { triggers.append(.alcohol) }

            var symptoms: [Symptom] = []
            if isMigraine {
                symptoms.append(.lightSensitivity)
                if rng.next(100) < 60 { symptoms.append(.nausea) }
                if rng.next(100) < 50 { symptoms.append(.soundSensitivity) }
                if rng.next(100) < 25 { symptoms.append(.aura) }
                if rng.next(100) < 10 { symptoms.append(.vomiting) }
            } else if rng.next(100) < 40 {
                symptoms.append(.neckPain)
            }
            if rng.next(100) < 30 { symptoms.append(.fatigue) }

            let side: PainLocation = [.left, .left, .right, .bothSides][Int(rng.next(4))]
            let locations: [PainLocation] = isMigraine ? [side, .behindEyes].prefix(rng.next(100) < 50 ? 2 : 1).map { $0 } : [.forehead, .temples]

            var meds: [MedicationDose] = []
            if isMigraine, rng.next(100) < 80 {
                let effect: MedicationEffect = [.helped, .helped, .helped, .partly, .none][Int(rng.next(5))]
                meds.append(MedicationDose(name: triptan, takenAt: start.addingTimeInterval(1800), effect: effect))
            } else if rng.next(100) < 60 {
                let effect: MedicationEffect = [.partly, .partly, .helped, .none][Int(rng.next(4))]
                meds.append(MedicationDose(name: ibuprofen, takenAt: start.addingTimeInterval(1200), effect: effect))
            }

            out.append(AttackValue(start: start, end: min(end, now), intensity: intensity, kind: isMigraine ? .migraine : .headache,
                                   locations: locations, symptoms: symptoms, triggers: triggers, medications: meds))
        }
        return out
    }
}

/// Tiny deterministic generator; `SystemRandomNumberGenerator` can't be seeded.
nonisolated struct SplitMix64 {
    private var state: UInt64
    init(seed: UInt64) { state = seed }

    mutating func next(_ upperBound: UInt64) -> UInt64 {
        state &+= 0x9E37_79B9_7F4A_7C15
        var z = state
        z = (z ^ (z >> 30)) &* 0xBF58_476D_1CE4_E5B9
        z = (z ^ (z >> 27)) &* 0x94D0_49BB_1331_11EB
        return (z ^ (z >> 31)) % upperBound
    }
}
