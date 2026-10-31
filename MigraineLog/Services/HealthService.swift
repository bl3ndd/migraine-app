import Foundation
import HealthKit
import SwiftData

/// A headache sample as read from Health.
nonisolated struct HealthHeadache: Equatable, Sendable {
    var id: UUID
    var start: Date
    var end: Date
    /// `HKCategoryValueSeverity` raw value.
    var severity: Int
    var sourceBundleID: String
    var meta = HealthMeta()
}

/// Everything about an attack beyond time and severity, carried in the
/// sample's metadata. Health syncs it across the user's devices, so a fresh
/// install gets back the details too, not just "a headache happened".
nonisolated struct HealthMeta: Equatable, Sendable {
    var attackID: UUID?
    var intensity: Int?
    var kind: String?
    var locations: [String] = []
    var symptoms: [String] = []
    var triggers: [String] = []
    var medications: [MedicationDose] = []
    var note = ""

    private static let intensityKey = "MigraineLogIntensity"
    private static let kindKey = "MigraineLogKind"
    private static let locationsKey = "MigraineLogLocations"
    private static let symptomsKey = "MigraineLogSymptoms"
    private static let triggersKey = "MigraineLogTriggers"
    private static let medicationsKey = "MigraineLogMedications"
    private static let noteKey = "MigraineLogNote"

    init(attackID: UUID? = nil, intensity: Int? = nil, kind: String? = nil, locations: [String] = [], symptoms: [String] = [],
         triggers: [String] = [], medications: [MedicationDose] = [], note: String = "") {
        self.attackID = attackID
        self.intensity = intensity
        self.kind = kind
        self.locations = locations
        self.symptoms = symptoms
        self.triggers = triggers
        self.medications = medications
        self.note = note
    }

    init(metadata: [String: Any]?) {
        let m = metadata ?? [:]
        attackID = (m[HKMetadataKeyExternalUUID] as? String).flatMap(UUID.init(uuidString:))
        intensity = (m[Self.intensityKey] as? NSNumber)?.intValue
        kind = m[Self.kindKey] as? String
        locations = Self.list(m[Self.locationsKey])
        symptoms = Self.list(m[Self.symptomsKey])
        triggers = Self.list(m[Self.triggersKey])
        medications = (m[Self.medicationsKey] as? String).flatMap { try? JSONDecoder().decode([MedicationDose].self, from: Data($0.utf8)) } ?? []
        note = m[Self.noteKey] as? String ?? ""
    }

    /// Our keys plus `WasUserEntered`. Health metadata takes strings, numbers
    /// and dates only, so lists are newline-joined and doses are JSON text.
    var metadata: [String: Any] {
        var m: [String: Any] = [HKMetadataKeyWasUserEntered: true]
        if let attackID { m[HKMetadataKeyExternalUUID] = attackID.uuidString }
        if let intensity { m[Self.intensityKey] = NSNumber(value: intensity) }
        if let kind { m[Self.kindKey] = kind }
        if !locations.isEmpty { m[Self.locationsKey] = locations.joined(separator: "\n") }
        if !symptoms.isEmpty { m[Self.symptomsKey] = symptoms.joined(separator: "\n") }
        if !triggers.isEmpty { m[Self.triggersKey] = triggers.joined(separator: "\n") }
        if !medications.isEmpty, let data = try? JSONEncoder().encode(medications) { m[Self.medicationsKey] = String(decoding: data, as: UTF8.self) }
        if !note.isEmpty { m[Self.noteKey] = note }
        return m
    }

    private static func list(_ value: Any?) -> [String] {
        (value as? String)?.split(separator: "\n").map(String.init) ?? []
    }
}

extension HealthMeta {
    init(_ a: Attack) {
        self.init(attackID: a.id, intensity: a.intensity, kind: a.kindRaw, locations: a.locationsRaw, symptoms: a.symptomsRaw,
                  triggers: a.triggersRaw, medications: a.medications, note: a.note)
    }
}

/// Opt-in Apple Health bridge: writes finished attacks as headache samples
/// (mild / moderate / severe) and imports headaches other apps logged. Apple
/// Health also syncs across the user's devices, so importing our own writes
/// back is how a new phone gets its history. Health data never leaves the
/// device through us — no analytics, no ads (guideline 5.1.3).
enum HealthService {
    private static let store = HKHealthStore()
    private static let headache = HKCategoryType(.headache)

    static var isAvailable: Bool { HKHealthStore.isHealthDataAvailable() }

    /// Shows the system sheet. `true` means the request went through, not that
    /// the type was granted — HealthKit never reveals read permission.
    static func requestAuthorization() async -> Bool {
        guard isAvailable else { return false }
        do {
            try await store.requestAuthorization(toShare: [headache], read: [headache])
            return true
        } catch {
            return false
        }
    }

    /// 1–3 mild, 4–6 moderate, 7–10 severe.
    nonisolated static func severity(for intensity: Int) -> HKCategoryValueSeverity {
        switch IntensityLevel(intensity) {
        case .mild: .mild
        case .moderate: .moderate
        case .severe: .severe
        }
    }

    /// The middle of each band; an unspecified severity reads as moderate.
    nonisolated static func intensity(for severity: Int) -> Int {
        switch HKCategoryValueSeverity(rawValue: severity) {
        case .mild: 2
        case .severe: 8
        default: 5
        }
    }

    /// Writes a finished attack and returns the sample UUID to store in `Attack.healthKitID`.
    /// Ongoing attacks aren't written: a Health sample needs an end.
    static func save(_ attack: AttackValue, meta: HealthMeta) async -> UUID? {
        guard isAvailable, let end = attack.end, store.authorizationStatus(for: headache) == .sharingAuthorized else { return nil }
        let sample = HKCategorySample(type: headache, value: severity(for: attack.intensity).rawValue,
                                      start: attack.start, end: max(end, attack.start), metadata: meta.metadata)
        do {
            try await store.save(sample)
            return sample.uuid
        } catch {
            return nil
        }
    }

    /// Deletes our own write.
    static func delete(healthKitID: UUID) async {
        guard isAvailable else { return }
        let own = HKQuery.predicateForObjects(from: .default())
        let byID = HKQuery.predicateForObject(with: healthKitID)
        _ = try? await store.deleteObjects(of: headache, predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [own, byID]))
    }

    /// Every headache sample since `since`, from any source. "Not present"
    /// samples (a symptom app logging "no headache today") are skipped.
    static func fetchHeadaches(since: Date) async -> [HealthHeadache] {
        guard isAvailable else { return [] }
        let range = HKQuery.predicateForSamples(withStart: since, end: nil)
        let query = HKSampleQueryDescriptor(predicates: [.categorySample(type: headache, predicate: range)], sortDescriptors: [])
        guard let samples = try? await query.result(for: store) else { return [] }
        return samples
            .filter { $0.value != HKCategoryValueSeverity.notPresent.rawValue }
            .map { s in
                HealthHeadache(id: s.uuid, start: s.startDate, end: s.endDate, severity: s.value,
                               sourceBundleID: s.sourceRevision.source.bundleIdentifier, meta: HealthMeta(metadata: s.metadata))
            }
    }

    /// Imports headaches we don't have yet — from other apps, and our own
    /// writes synced from another device or left from a previous install.
    /// Returns how many were added.
    @discardableResult
    static func importNew(into context: ModelContext, deletedIDs: Set<UUID>) async -> Int {
        let since = Calendar.current.date(byAdding: .year, value: -5, to: Date()) ?? .distantPast
        let health = await fetchHeadaches(since: since)
        let local = (try? context.fetch(FetchDescriptor<Attack>())) ?? []
        let fresh = newImports(health, existingHealthIDs: Set(local.compactMap(\.healthKitID)),
                               existingAttackIDs: Set(local.map(\.id)), deletedIDs: deletedIDs)
        let ownBundleID = Bundle.main.bundleIdentifier ?? ""
        for h in fresh {
            context.insert(makeAttack(h, ownBundleID: ownBundleID))
        }
        if !fresh.isEmpty { try? context.save() }
        return fresh.count
    }

    /// Writes finished attacks logged here that never reached Health (logged
    /// before Health was turned on, or ended since). Returns how many were saved.
    @discardableResult
    static func backfill(_ context: ModelContext) async -> Int {
        let pending = ((try? context.fetch(FetchDescriptor<Attack>())) ?? [])
            .filter { $0.source == .manual && $0.healthKitID == nil && $0.end != nil }
        var saved = 0
        for a in pending {
            if let id = await save(a.value, meta: HealthMeta(a)) {
                a.healthKitID = id
                saved += 1
            }
        }
        if saved > 0 { try? context.save() }
        return saved
    }

    /// Skips what we already hold, matched both on the Health sample and on our
    /// own attack id — an attack restored from a JSON backup and its Health copy
    /// are one attack — and anything the user deleted here.
    nonisolated static func newImports(_ health: [HealthHeadache], existingHealthIDs: Set<UUID>, existingAttackIDs: Set<UUID>,
                                       deletedIDs: Set<UUID> = []) -> [HealthHeadache] {
        let known = existingHealthIDs.union(deletedIDs)
        return health.filter { h in
            let attackKnown = h.meta.attackID.map { existingAttackIDs.contains($0) || deletedIDs.contains($0) } ?? false
            return !known.contains(h.id) && !attackKnown
        }
    }

    /// Our own writes come back with every detail and their original id;
    /// anything else is a plain headache with the severity's middle intensity.
    static func makeAttack(_ h: HealthHeadache, ownBundleID: String) -> Attack {
        let own = h.sourceBundleID == ownBundleID
        let kind = h.meta.kind.flatMap(AttackKind.init(rawValue:)) ?? .headache
        let a = Attack(start: h.start, end: h.end, intensity: h.meta.intensity ?? intensity(for: h.severity), kind: kind,
                       medications: h.meta.medications, note: h.meta.note,
                       source: own ? .manual : .health, healthKitID: h.id)
        a.locationsRaw = h.meta.locations
        a.symptomsRaw = h.meta.symptoms
        a.triggersRaw = h.meta.triggers
        if own, let id = h.meta.attackID { a.id = id }
        return a
    }
}
