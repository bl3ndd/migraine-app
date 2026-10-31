import Foundation
import SwiftData
import SwiftUI
import UniformTypeIdentifiers

/// Plain-JSON export and import of every attack. Free for everyone: health
/// data can't live in our iCloud (guideline 5.1.3), so a file the user keeps
/// themselves is how they move to a new phone or undo a mistake.
///
/// The archive has its own structs rather than the @Model class, so the file
/// format stays readable by future versions whatever SwiftData stores.
enum BackupService {
    static let formatVersion = 1

    nonisolated struct Archive: Codable, Equatable {
        var version: Int
        var exportedAt: Date
        var attacks: [Item]
    }

    nonisolated struct Item: Codable, Equatable {
        var id: UUID
        var start: Date
        var end: Date?
        var intensity: Int
        var kind: String
        var locations: [String]
        var symptoms: [String]
        var triggers: [String]
        var medications: [MedicationDose]
        var note: String
        var source: String
        var healthKitID: UUID?
    }

    /// What an import actually did, so the UI reports it honestly.
    struct ImportResult: Equatable {
        var added: Int
        var skipped: Int
    }

    static func export(_ attacks: [Attack], now: Date = Date()) throws -> Data {
        let archive = Archive(version: formatVersion, exportedAt: now, attacks: attacks.map(Item.init(from:)))
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        return try encoder.encode(archive)
    }

    /// Additive: an attack already on the device is left alone, so restoring
    /// can never destroy what's there. "Already there" is the same attack id or
    /// the same Health sample — another app's headache imported from Health
    /// gets a new attack id on each install — and deleted ones stay deleted.
    @discardableResult
    static func restore(from data: Data, into context: ModelContext, deletedIDs: Set<UUID> = []) throws -> ImportResult {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        let archive = try decoder.decode(Archive.self, from: data)
        let local = (try? context.fetch(FetchDescriptor<Attack>())) ?? []
        let existing = Set(local.map(\.id)).union(deletedIDs)
        let healthIDs = Set(local.compactMap(\.healthKitID)).union(deletedIDs)
        var result = ImportResult(added: 0, skipped: 0)
        for item in archive.attacks {
            guard !existing.contains(item.id), !(item.healthKitID.map(healthIDs.contains) ?? false) else { result.skipped += 1; continue }
            context.insert(item.makeModel())
            result.added += 1
        }
        try context.save()
        return result
    }

    static func filename(now: Date = Date()) -> String {
        "migraine-log-backup-\(now.formatted(.iso8601.year().month().day()))"
    }
}

private extension BackupService.Item {
    init(from a: Attack) {
        id = a.id
        start = a.start
        end = a.end
        intensity = a.intensity
        kind = a.kindRaw
        locations = a.locationsRaw
        symptoms = a.symptomsRaw
        triggers = a.triggersRaw
        medications = a.medications
        note = a.note
        source = a.sourceRaw
        healthKitID = a.healthKitID
    }

    func makeModel() -> Attack {
        let a = Attack(start: start, end: end, intensity: intensity, medications: medications, note: note, healthKitID: healthKitID)
        a.id = id
        a.kindRaw = kind
        a.locationsRaw = locations
        a.symptomsRaw = symptoms
        a.triggersRaw = triggers
        a.sourceRaw = source
        return a
    }
}

/// Thin wrapper so `fileExporter` can write the archive straight to Files.
struct BackupDocument: FileDocument {
    static var readableContentTypes: [UTType] { [.json] }

    let data: Data

    init(data: Data) {
        self.data = data
    }

    init(configuration: ReadConfiguration) throws {
        data = configuration.file.regularFileContents ?? Data()
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: data)
    }
}
