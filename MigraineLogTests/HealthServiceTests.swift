import Testing
import Foundation
import HealthKit
@testable import MigraineLog

struct HealthServiceTests {
    static let t0 = Date(timeIntervalSince1970: 1_800_000_000)
    static let own = "white.tea.MigraineLog"

    static func h(_ id: UUID = UUID(), source: String = "com.other.app", severity: HKCategoryValueSeverity = .moderate,
                  meta: HealthMeta = HealthMeta()) -> HealthHeadache {
        HealthHeadache(id: id, start: t0, end: t0.addingTimeInterval(3 * 3600), severity: severity.rawValue, sourceBundleID: source, meta: meta)
    }

    @Test func importSkipsKnownSamples() {
        let known = UUID()
        let other = Self.h()
        #expect(HealthService.newImports([Self.h(known), other], existingHealthIDs: [known], existingAttackIDs: []) == [other])
    }

    @Test func ownWritesComeBackOnAFreshInstall() {
        let mine = Self.h(source: Self.own, meta: HealthMeta(attackID: UUID()))
        #expect(HealthService.newImports([mine], existingHealthIDs: [], existingAttackIDs: []) == [mine])
    }

    @Test func attackRestoredFromBackupIsNotImportedTwice() {
        let attackID = UUID()
        let mine = Self.h(source: Self.own, meta: HealthMeta(attackID: attackID))
        #expect(HealthService.newImports([mine], existingHealthIDs: [], existingAttackIDs: [attackID]).isEmpty)
    }

    @Test func importIsIdempotent() {
        let samples = [Self.h(), Self.h()]
        let first = HealthService.newImports(samples, existingHealthIDs: [], existingAttackIDs: [])
        let second = HealthService.newImports(samples, existingHealthIDs: Set(first.map(\.id)), existingAttackIDs: [])
        #expect(first.count == 2)
        #expect(second.isEmpty)
    }

    @Test func deletedAttacksNeverComeBack() {
        let other = Self.h()
        let mineID = UUID()
        let mine = Self.h(source: Self.own, meta: HealthMeta(attackID: mineID))
        #expect(HealthService.newImports([other, mine], existingHealthIDs: [], existingAttackIDs: [], deletedIDs: [other.id, mineID]).isEmpty)
    }

    @Test func metadataRoundTrip() {
        let meta = HealthMeta(attackID: UUID(), intensity: 7, kind: "migraine", locations: ["left", "behindEyes"], symptoms: ["nausea"],
                              triggers: ["stress", "poorSleep"],
                              medications: [MedicationDose(name: "Sumatriptan", takenAt: Self.t0, effect: .partly)], note: "after work")
        #expect(HealthMeta(metadata: meta.metadata) == meta)
        #expect(HealthMeta(metadata: nil) == HealthMeta())
        #expect(HealthMeta(metadata: HealthMeta().metadata) == HealthMeta())
    }

    @Test func severityMapping() {
        #expect(HealthService.severity(for: 2) == .mild)
        #expect(HealthService.severity(for: 5) == .moderate)
        #expect(HealthService.severity(for: 9) == .severe)
        #expect(HealthService.intensity(for: HKCategoryValueSeverity.mild.rawValue) == 2)
        #expect(HealthService.intensity(for: HKCategoryValueSeverity.severe.rawValue) == 8)
        #expect(HealthService.intensity(for: HKCategoryValueSeverity.unspecified.rawValue) == 5)
        // The round trip stays in the same band.
        for i in 1...10 {
            #expect(IntensityLevel(HealthService.intensity(for: HealthService.severity(for: i).rawValue)) == IntensityLevel(i))
        }
    }

    @MainActor @Test func ownWriteRestoresWithEveryDetail() {
        let attackID = UUID()
        let doses = [MedicationDose(name: "Ibuprofen", takenAt: Self.t0, effect: .helped)]
        let mine = Self.h(source: Self.own, severity: .severe,
                          meta: HealthMeta(attackID: attackID, intensity: 9, kind: "migraine", symptoms: ["aura"], triggers: ["weather"], medications: doses, note: "n"))
        let a = HealthService.makeAttack(mine, ownBundleID: Self.own)
        #expect(a.id == attackID)
        #expect(a.source == .manual)
        #expect(a.healthKitID == mine.id)
        #expect(a.intensity == 9 && a.kind == .migraine)
        #expect(a.symptoms == [.aura] && a.triggers == [.weather])
        #expect(a.medications == doses && a.note == "n")
    }

    @MainActor @Test func otherAppsHeadacheImportsAsPlainHeadache() {
        let other = Self.h(severity: .severe)
        let a = HealthService.makeAttack(other, ownBundleID: Self.own)
        #expect(a.source == .health)
        #expect(a.kind == .headache)
        #expect(a.intensity == 8)
        #expect(a.start == Self.t0 && a.end == Self.t0.addingTimeInterval(3 * 3600))
    }

    @MainActor @Test func deletionsArePersisted() {
        let defaults = UserDefaults(suiteName: "HealthServiceTests-\(UUID())")!
        let id = UUID()
        AppSettings(defaults: defaults).rememberDeleted([id])
        #expect(AppSettings(defaults: defaults).deletedIDs == [id])
    }
}
