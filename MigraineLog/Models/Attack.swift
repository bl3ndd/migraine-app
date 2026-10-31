import Foundation
import SwiftData

nonisolated enum AttackKind: String, CaseIterable, Codable, Sendable {
    case migraine, headache

    var title: String {
        switch self {
        case .migraine: "Migraine"
        case .headache: "Headache"
        }
    }
}

nonisolated enum AttackSource: String, Sendable { case manual, health }

/// Where it hurts. Raw values are stored, titles are shown.
nonisolated enum PainLocation: String, CaseIterable, Codable, Sendable {
    case left, right, bothSides, forehead, behindEyes, temples, backOfHead, neck

    var title: String {
        switch self {
        case .left: "Left side"
        case .right: "Right side"
        case .bothSides: "Both sides"
        case .forehead: "Forehead"
        case .behindEyes: "Behind eyes"
        case .temples: "Temples"
        case .backOfHead: "Back of head"
        case .neck: "Neck"
        }
    }
}

nonisolated enum Symptom: String, CaseIterable, Codable, Sendable {
    case aura, nausea, vomiting, lightSensitivity, soundSensitivity, smellSensitivity, dizziness, fatigue, brainFog, neckPain

    var title: String {
        switch self {
        case .aura: "Aura"
        case .nausea: "Nausea"
        case .vomiting: "Vomiting"
        case .lightSensitivity: "Light sensitivity"
        case .soundSensitivity: "Sound sensitivity"
        case .smellSensitivity: "Smell sensitivity"
        case .dizziness: "Dizziness"
        case .fatigue: "Fatigue"
        case .brainFog: "Brain fog"
        case .neckPain: "Neck pain"
        }
    }
}

/// Possible triggers the person suspects. "Suspects" matters: the app counts
/// what was logged, it never claims a cause.
nonisolated enum Trigger: String, CaseIterable, Codable, Sendable {
    case stress, poorSleep, oversleep, skippedMeal, dehydration, alcohol, caffeine, weather, brightLight, screenTime, period, strongSmell, exercise, travel

    var title: String {
        switch self {
        case .stress: "Stress"
        case .poorSleep: "Poor sleep"
        case .oversleep: "Overslept"
        case .skippedMeal: "Skipped meal"
        case .dehydration: "Not enough water"
        case .alcohol: "Alcohol"
        case .caffeine: "Caffeine"
        case .weather: "Weather change"
        case .brightLight: "Bright light"
        case .screenTime: "Screen time"
        case .period: "Period"
        case .strongSmell: "Strong smell"
        case .exercise: "Exercise"
        case .travel: "Travel"
        }
    }
}

nonisolated enum MedicationEffect: String, CaseIterable, Codable, Sendable {
    case unknown, none, partly, helped

    var title: String {
        switch self {
        case .unknown: "Not sure"
        case .none: "No"
        case .partly: "A little"
        case .helped: "Yes"
        }
    }
}

/// One dose taken during an attack. `id` keeps form rows stable while doses
/// are added and removed; files written before it existed get a fresh one.
nonisolated struct MedicationDose: Codable, Equatable, Hashable, Identifiable, Sendable {
    var id = UUID()
    var name: String
    var takenAt: Date
    var effect: MedicationEffect = .unknown

    init(id: UUID = UUID(), name: String, takenAt: Date, effect: MedicationEffect = .unknown) {
        self.id = id
        self.name = name
        self.takenAt = takenAt
        self.effect = effect
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        takenAt = try c.decode(Date.self, forKey: .takenAt)
        effect = try c.decodeIfPresent(MedicationEffect.self, forKey: .effect) ?? .unknown
    }
}

/// One headache or migraine attack, from start to end. `end == nil` means it's
/// still going. Enums are stored as raw strings and every property has a
/// default, so the schema can grow without migrations. Doses live in a JSON
/// blob: they're only ever read whole, never queried.
@Model
final class Attack {
    var id: UUID = UUID()
    var start: Date = Date()
    var end: Date?
    /// Peak pain, 1–10.
    var intensity: Int = 5
    var kindRaw: String = AttackKind.migraine.rawValue
    var locationsRaw: [String] = []
    var symptomsRaw: [String] = []
    var triggersRaw: [String] = []
    var medicationsData: Data = Data()
    var note: String = ""
    var sourceRaw: String = AttackSource.manual.rawValue
    /// The Health headache sample this attack came from or was written to.
    var healthKitID: UUID?

    init(start: Date = Date(), end: Date? = nil, intensity: Int, kind: AttackKind = .migraine,
         locations: [PainLocation] = [], symptoms: [Symptom] = [], triggers: [Trigger] = [],
         medications: [MedicationDose] = [], note: String = "", source: AttackSource = .manual, healthKitID: UUID? = nil) {
        self.start = start
        self.end = end
        self.intensity = intensity
        self.kindRaw = kind.rawValue
        self.locationsRaw = locations.map(\.rawValue)
        self.symptomsRaw = symptoms.map(\.rawValue)
        self.triggersRaw = triggers.map(\.rawValue)
        self.medicationsData = Self.encode(medications)
        self.note = note
        self.sourceRaw = source.rawValue
        self.healthKitID = healthKitID
    }

    var kind: AttackKind {
        get { AttackKind(rawValue: kindRaw) ?? .migraine }
        set { kindRaw = newValue.rawValue }
    }

    var source: AttackSource {
        get { AttackSource(rawValue: sourceRaw) ?? .manual }
        set { sourceRaw = newValue.rawValue }
    }

    var locations: [PainLocation] {
        get { locationsRaw.compactMap(PainLocation.init(rawValue:)) }
        set { locationsRaw = newValue.map(\.rawValue) }
    }

    var symptoms: [Symptom] {
        get { symptomsRaw.compactMap(Symptom.init(rawValue:)) }
        set { symptomsRaw = newValue.map(\.rawValue) }
    }

    var triggers: [Trigger] {
        get { triggersRaw.compactMap(Trigger.init(rawValue:)) }
        set { triggersRaw = newValue.map(\.rawValue) }
    }

    var medications: [MedicationDose] {
        get { (try? JSONDecoder().decode([MedicationDose].self, from: medicationsData)) ?? [] }
        set { medicationsData = Self.encode(newValue) }
    }

    var isOngoing: Bool { end == nil }

    var value: AttackValue {
        AttackValue(id: id, start: start, end: end, intensity: intensity, kind: kind, locations: locations,
                    symptoms: symptoms, triggers: triggers, medications: medications)
    }

    private static func encode(_ doses: [MedicationDose]) -> Data {
        doses.isEmpty ? Data() : ((try? JSONEncoder().encode(doses)) ?? Data())
    }
}

/// Plain snapshot of an attack for statistics, the widget and exports —
/// testable without SwiftData.
nonisolated struct AttackValue: Equatable, Sendable {
    var id = UUID()
    var start: Date
    var end: Date?
    var intensity: Int
    var kind: AttackKind = .migraine
    var locations: [PainLocation] = []
    var symptoms: [Symptom] = []
    var triggers: [Trigger] = []
    var medications: [MedicationDose] = []

    var level: IntensityLevel { IntensityLevel(intensity) }

    /// How long it lasted, nil while it's still going.
    var duration: TimeInterval? { end.map { $0.timeIntervalSince(start) } }

    /// Until `now` for an ongoing attack: the span it has covered so far.
    func interval(now: Date) -> DateInterval {
        DateInterval(start: start, end: max(start, end ?? now))
    }
}

/// Mild / moderate / severe bands of the 1–10 scale, the same three grades
/// Apple Health uses for headache severity.
nonisolated enum IntensityLevel: Int, CaseIterable, Sendable {
    case mild = 1, moderate, severe

    init(_ intensity: Int) {
        switch intensity {
        case ...3: self = .mild
        case 4...6: self = .moderate
        default: self = .severe
        }
    }

    var title: String {
        switch self {
        case .mild: "Mild"
        case .moderate: "Moderate"
        case .severe: "Severe"
        }
    }
}

/// What a saved attack must satisfy.
nonisolated enum AttackLimits {
    static let intensity = 1...10
    /// Status migrainosus is 72 h; a week leaves room for a long, messy attack
    /// and still catches an end date typed in the wrong month.
    static let maxDuration: TimeInterval = 7 * 86_400

    static func problem(start: Date, end: Date?, intensity: Int, now: Date = Date()) -> String? {
        if !self.intensity.contains(intensity) { return "Pick a pain level from 1 to 10." }
        // A minute of slack: "now" in the picker is a little behind the clock by the time Save is tapped.
        if start > now.addingTimeInterval(60) { return "The start can't be in the future." }
        guard let end else { return nil }
        if end > now.addingTimeInterval(60) { return "The end can't be in the future." }
        if end < start { return "The end is before the start." }
        if end.timeIntervalSince(start) > maxDuration { return "That's longer than a week. Check the start and end dates." }
        return nil
    }
}
