import Testing
import Foundation
import SwiftData
@testable import MigraineLog

@MainActor
struct BackupServiceTests {
    private func makeContext() throws -> ModelContext {
        let container = try ModelContainer(for: Attack.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
        return ModelContext(container)
    }

    private func sample() -> Attack {
        let t = Date(timeIntervalSince1970: 1_800_000_000)
        return Attack(start: t, end: t.addingTimeInterval(5400), intensity: 7, kind: .migraine, locations: [.right],
                      symptoms: [.nausea, .aura], triggers: [.period], medications: [MedicationDose(name: "Rizatriptan", takenAt: t, effect: .helped)],
                      note: "after work", source: .health, healthKitID: UUID())
    }

    @Test func roundTripKeepsEveryField() throws {
        let original = sample()
        let data = try BackupService.export([original])
        let context = try makeContext()
        let result = try BackupService.restore(from: data, into: context)
        #expect(result == BackupService.ImportResult(added: 1, skipped: 0))
        let restored = try #require(try context.fetch(FetchDescriptor<Attack>()).first)
        #expect(restored.id == original.id)
        #expect(restored.value == original.value)
        #expect(restored.note == "after work")
        #expect(restored.source == .health)
        #expect(restored.healthKitID == original.healthKitID)
    }

    @Test func ongoingAttackKeepsNoEnd() throws {
        let ongoing = Attack(start: Date(timeIntervalSince1970: 1_800_000_000), intensity: 4)
        let context = try makeContext()
        try BackupService.restore(from: try BackupService.export([ongoing]), into: context)
        #expect(try context.fetch(FetchDescriptor<Attack>()).first?.end == nil)
    }

    @Test func restoreIsAdditive() throws {
        let original = sample()
        let data = try BackupService.export([original])
        let context = try makeContext()
        try BackupService.restore(from: data, into: context)
        let second = try BackupService.restore(from: data, into: context)
        #expect(second == BackupService.ImportResult(added: 0, skipped: 1))
        #expect(try context.fetchCount(FetchDescriptor<Attack>()) == 1)
    }

    @Test func otherAppsHealthImportIsNotDuplicated() throws {
        // On a new phone, Health already imported another app's headache under a new attack id.
        let original = sample()
        let data = try BackupService.export([original])
        let context = try makeContext()
        let imported = Attack(start: original.start, end: original.end, intensity: 8, source: .health, healthKitID: original.healthKitID)
        context.insert(imported)
        let result = try BackupService.restore(from: data, into: context)
        #expect(result == BackupService.ImportResult(added: 0, skipped: 1))
    }

    @Test func deletedAttacksStayDeleted() throws {
        let original = sample()
        let context = try makeContext()
        let result = try BackupService.restore(from: try BackupService.export([original]), into: context, deletedIDs: [original.id])
        #expect(result.added == 0)
    }

    @Test func dosesWithoutIdsStillDecode() throws {
        let json = #"[{"name":"Ibuprofen","takenAt":0,"effect":"helped"}]"#
        let doses = try JSONDecoder().decode([MedicationDose].self, from: Data(json.utf8))
        #expect(doses.first?.name == "Ibuprofen" && doses.first?.effect == .helped)
    }

    @Test func rejectsForeignFiles() throws {
        let context = try makeContext()
        #expect(throws: (any Error).self) { try BackupService.restore(from: Data("{\"hello\": 1}".utf8), into: context) }
    }

    @Test func filenameHasTheDate() {
        #expect(BackupService.filename(now: Date(timeIntervalSince1970: 1_800_000_000)).hasPrefix("migraine-log-backup-2027-"))
    }
}
