import Testing
import Foundation
@testable import MigraineLog

struct AttackTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    @Test(arguments: [(1, IntensityLevel.mild), (3, .mild), (4, .moderate), (6, .moderate), (7, .severe), (10, .severe)])
    func intensityBands(intensity: Int, level: IntensityLevel) {
        #expect(IntensityLevel(intensity) == level)
    }

    @Test func limits() {
        let start = now.addingTimeInterval(-3600)
        #expect(AttackLimits.problem(start: start, end: nil, intensity: 5, now: now) == nil)
        #expect(AttackLimits.problem(start: start, end: now, intensity: 5, now: now) == nil)
        #expect(AttackLimits.problem(start: start, end: nil, intensity: 0, now: now) != nil)
        #expect(AttackLimits.problem(start: start, end: nil, intensity: 11, now: now) != nil)
        #expect(AttackLimits.problem(start: now.addingTimeInterval(600), end: nil, intensity: 5, now: now) == "The start can't be in the future.")
        #expect(AttackLimits.problem(start: start, end: start.addingTimeInterval(-60), intensity: 5, now: now) == "The end is before the start.")
        #expect(AttackLimits.problem(start: now.addingTimeInterval(-8 * 86_400), end: now, intensity: 5, now: now) != nil)
        // A few seconds of picker lag isn't "the future".
        #expect(AttackLimits.problem(start: now.addingTimeInterval(20), end: nil, intensity: 5, now: now) == nil)
    }

    @Test func modelRoundTripsEnumsAndDoses() {
        let doses = [MedicationDose(name: "Sumatriptan 50 mg", takenAt: now, effect: .helped)]
        let a = Attack(start: now, end: now.addingTimeInterval(7200), intensity: 7, kind: .headache, locations: [.left, .behindEyes],
                       symptoms: [.nausea], triggers: [.stress, .poorSleep], medications: doses, note: "work")
        #expect(a.kind == .headache)
        #expect(a.locations == [.left, .behindEyes])
        #expect(a.triggers == [.stress, .poorSleep])
        #expect(a.medications == doses)
        #expect(!a.isOngoing)
        #expect(a.value.duration == 7200)
        a.medications = []
        #expect(a.medicationsData.isEmpty)
        // Unknown raw values from a future version are skipped, not crashing.
        a.triggersRaw = ["stress", "fullMoon"]
        #expect(a.triggers == [.stress])
    }

    @Test func everyCaseHasATitle() {
        #expect(Trigger.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(Symptom.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(PainLocation.allCases.allSatisfy { !$0.title.isEmpty })
        #expect(Set(Trigger.allCases.map(\.title)).count == Trigger.allCases.count)
    }

    @MainActor
    @Test func rememberedMedicinesAreDeduplicated() {
        let settings = AppSettings(defaults: UserDefaults(suiteName: "AttackTests-\(UUID())")!)
        settings.rememberMedication(" Ibuprofen ")
        settings.rememberMedication("ibuprofen")
        settings.rememberMedication("")
        settings.rememberMedication("Sumatriptan")
        #expect(settings.medicationNames == ["Ibuprofen", "Sumatriptan"])
    }
}
