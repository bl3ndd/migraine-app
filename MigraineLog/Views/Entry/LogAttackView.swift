import SwiftUI
import SwiftData

/// New attack, or edit of an existing one. Built to be filled in with a
/// headache: everything is a tap, only pain level is needed to save, and the
/// rest can be added later. Attacks imported from Health keep their times
/// read-only — the app that logged them owns those.
struct LogAttackView: View {
    var editing: Attack?
    /// Open with "It's over" already on and the end at now ("Pick the End Time").
    var endingNow = false
    /// Called after a new attack (not an edit) is saved.
    var onSavedNew: (() -> Void)?

    @Environment(\.modelContext) private var context
    @Environment(\.dismiss) private var dismiss
    @Environment(AppSettings.self) private var settings

    @State private var start = Date()
    @State private var hasEnded = false
    @State private var end = Date()
    @State private var intensity = 5
    @State private var kind = AttackKind.migraine
    @State private var locations: Set<PainLocation> = []
    @State private var symptoms: Set<Symptom> = []
    @State private var triggers: Set<Trigger> = []
    @State private var doses: [MedicationDose] = []
    @State private var newMedication = ""
    @State private var note = ""
    @State private var saved = false
    @State private var confirmingDelete = false
    @State private var loaded = false
    @FocusState private var focus: Field?

    private enum Field { case medication, note }

    private var isImported: Bool { editing?.source == .health }
    /// Imported times can't be edited here, so they're never what blocks Save.
    private var problem: String? {
        isImported ? AttackLimits.problem(start: Date(), end: nil, intensity: intensity)
            : AttackLimits.problem(start: start, end: hasEnded ? end : nil, intensity: intensity)
    }

    /// Doses happen during the attack: from its start to its end (or now).
    private var doseRange: ClosedRange<Date> {
        let upper = max(start, hasEnded ? end : Date())
        return start...upper
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    SectionLabel("How bad is it at its worst?")
                    CardView { IntensityPicker(value: $intensity) }
                    if intensity >= 9 { EmergencyNote() }

                    SectionLabel("Type")
                    SegmentedChips(options: AttackKind.allCases, selection: $kind) { $0.title }

                    SectionLabel("When")
                    timeCard
                    if let problem {
                        Text(problem)
                            .font(.body.weight(.semibold))
                            .foregroundStyle(AppColors.danger)
                            .padding(.horizontal, 4)
                    }

                    SectionLabel("Medication")
                    medicationCard

                    SectionLabel("Where it hurts")
                    CardView { ChipGroup(items: PainLocation.allCases, selection: $locations) { $0.title } }

                    SectionLabel("Symptoms")
                    CardView { ChipGroup(items: Symptom.allCases, selection: $symptoms) { $0.title } }

                    SectionLabel("Possible triggers")
                    CardView { ChipGroup(items: Trigger.allCases, selection: $triggers) { $0.title } }

                    SectionLabel("Note")
                    CardView {
                        TextField("Anything worth remembering", text: $note, axis: .vertical)
                            .font(.body)
                            .focused($focus, equals: .note)
                    }

                    if editing != nil {
                        Button(role: .destructive) {
                            confirmingDelete = true
                        } label: {
                            Label("Delete Entry", systemImage: "trash")
                                .font(.body.weight(.semibold))
                                .frame(maxWidth: .infinity, minHeight: 50)
                        }
                        .buttonStyle(.bordered)
                        .tint(AppColors.danger)
                        .padding(.top, 8)
                    }
                }
                .padding()
            }
            .scrollDismissesKeyboard(.interactively)
            .background(AppColors.bgApp)
            .navigationTitle(editing == nil ? "Log Headache" : "Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
            .safeAreaInset(edge: .bottom) {
                Button("Save", action: save)
                    .buttonStyle(PrimaryButtonStyle())
                    .disabled(problem != nil)
                    .padding(.horizontal)
                    .padding(.vertical, 10)
                    .background(AppColors.bgApp)
            }
            .sensoryFeedback(.success, trigger: saved)
            .confirmationDialog("Delete this entry?", isPresented: $confirmingDelete, titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive) {
                    if let editing { AttackActions.delete([editing], context: context, settings: settings) }
                    dismiss()
                }
            } message: {
                Text("It will be removed from your diary. This can't be undone.")
            }
            .onAppear(perform: load)
        }
    }

    // MARK: Sections

    private var timeCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                DatePicker("Started", selection: $start, in: ...Date())
                    .font(.body.weight(.medium))
                Divider()
                Toggle("It's over", isOn: $hasEnded.animation())
                    .font(.body.weight(.medium))
                    .tint(AppColors.accent)
                if hasEnded {
                    DatePicker("Ended", selection: $end, in: min(start, Date())...max(start, Date()))
                        .font(.body.weight(.medium))
                    if end > start {
                        Text("Lasted \(DurationText.format(end.timeIntervalSince(start)))")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                } else {
                    Text("Still going. End it from Home when it's over.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .disabled(isImported)
        }
        .overlay(alignment: .bottomLeading) {
            if isImported {
                Text("From Apple Health. Times are kept as recorded.")
                    .font(.caption)
                    .foregroundStyle(AppColors.textSecondary)
                    .padding([.leading, .bottom], 20)
                    .offset(y: 22)
            }
        }
        .padding(.bottom, isImported ? 18 : 0)
    }

    private var medicationCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                ForEach($doses) { $dose in
                    doseRow($dose)
                    Divider()
                }
                let suggestions = settings.medicationNames.filter { name in
                    !doses.contains { $0.name.caseInsensitiveCompare(name) == .orderedSame }
                }
                if !suggestions.isEmpty {
                    FlowLayout(spacing: 8) {
                        ForEach(suggestions, id: \.self) { name in
                            Button {
                                addDose(name)
                            } label: {
                                Label(name, systemImage: "plus")
                                    .font(.body.weight(.medium))
                                    .padding(.horizontal, 14)
                                    .padding(.vertical, 10)
                                    .foregroundStyle(AppColors.accent)
                                    .background(Capsule().fill(AppColors.accentTint))
                            }
                            .buttonStyle(.plain)
                            .accessibilityLabel("Add \(name)")
                        }
                    }
                }
                HStack {
                    TextField(doses.isEmpty && suggestions.isEmpty ? "What did you take? (optional)" : "Something else", text: $newMedication)
                        .focused($focus, equals: .medication)
                        .submitLabel(.done)
                        .onSubmit { addDose(newMedication) }
                    Button("Add") { addDose(newMedication) }
                        .font(.body.weight(.semibold))
                        .disabled(newMedication.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }

    private func doseRow(_ dose: Binding<MedicationDose>) -> some View {
        let id = dose.wrappedValue.id
        return VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(dose.wrappedValue.name).font(.headline).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Button {
                    doses.removeAll { $0.id == id }
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title2)
                        .foregroundStyle(AppColors.textSecondary)
                }
                .buttonStyle(.plain)
                .accessibilityLabel("Remove \(dose.wrappedValue.name)")
            }
            // Date and time: a dose at 2 AM in an attack that began at 10 PM belongs to the next day.
            DatePicker("Taken", selection: dose.takenAt, in: doseRange)
                .font(.subheadline)
            Text("Did it help?").font(.subheadline).foregroundStyle(AppColors.textSecondary)
            SegmentedChips(options: [MedicationEffect.none, .partly, .helped, .unknown], selection: dose.effect) { $0.title }
        }
    }

    // MARK: Actions

    private func addDose(_ name: String) {
        let clean = name.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        // Still going: taken now. Logged afterwards from memory: at the start.
        let takenAt = hasEnded ? start : max(start, Date())
        doses.append(MedicationDose(name: clean, takenAt: takenAt))
        newMedication = ""
    }

    private func load() {
        guard !loaded else { return }
        loaded = true
        guard let a = editing else { return }
        start = a.start
        hasEnded = a.end != nil || endingNow
        end = a.end ?? min(Date(), a.start.addingTimeInterval(AttackLimits.maxDuration))
        intensity = a.intensity
        kind = a.kind
        locations = Set(a.locations)
        symptoms = Set(a.symptoms)
        triggers = Set(a.triggers)
        doses = a.medications
        note = a.note
    }

    private func save() {
        guard problem == nil else { return }
        let attack: Attack
        let previousHealthID = editing?.healthKitID
        if let editing {
            attack = editing
        } else {
            attack = Attack(start: start, intensity: intensity)
            context.insert(attack)
            ReviewService.recordAttack()
            Analytics.track(.attackAdded)
        }
        if !isImported {
            attack.start = start
            attack.end = hasEnded ? max(end, start) : nil
        }
        attack.intensity = intensity
        attack.kind = kind
        // Stored in the order the chips show, whatever order they were tapped in.
        attack.locations = PainLocation.allCases.filter(locations.contains)
        attack.symptoms = Symptom.allCases.filter(symptoms.contains)
        attack.triggers = Trigger.allCases.filter(triggers.contains)
        attack.medications = doses.sorted { $0.takenAt < $1.takenAt }
        attack.note = note.trimmingCharacters(in: .whitespacesAndNewlines)
        for dose in doses { settings.rememberMedication(dose.name) }
        try? context.save()
        saved.toggle()

        // Replaces our old Health copy; an attack turned back into "still going" just loses it.
        AttackActions.syncToHealth(attack, previousHealthID: previousHealthID, context: context, settings: settings)
        if editing == nil { onSavedNew?() }
        dismiss()
    }
}
