import SwiftUI
import SwiftData
import UniformTypeIdentifiers

struct SettingsView: View {
    @Environment(\.modelContext) private var context
    @Environment(PurchaseService.self) private var purchases
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Attack.start) private var attacks: [Attack]

    @State private var backup: BackupDocument?
    @State private var showImporter = false
    @State private var message: String?
    @State private var syncing = false
    @State private var newMedication = ""

    var body: some View {
        NavigationStack {
            Form {
                if HealthService.isAvailable {
                    Section {
                        Toggle("Sync with Apple Health", isOn: Binding(
                            get: { settings.healthEnabled },
                            set: { on in Task { await setHealth(on) } }
                        ))
                        .tint(AppColors.accent)
                        if settings.healthEnabled {
                            Button {
                                Task { await syncNow() }
                            } label: {
                                if syncing {
                                    HStack { ProgressView(); Text("Syncing…") }
                                } else {
                                    Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                                }
                            }
                            .disabled(syncing)
                        }
                    } header: {
                        Text("Apple Health")
                    } footer: {
                        Text("Finished headaches are saved to Apple Health as mild, moderate or severe, and headaches other apps log there show up here. Apple Health keeps them in sync across your devices: on a new iPhone, turn this on and your diary comes back.")
                    }
                }

                Section {
                    reminderRow
                } header: {
                    Text("Reminder")
                } footer: {
                    Text("One gentle check-in a day, so headaches you'd forget still make it into your monthly count.")
                }

                Section {
                    ForEach(settings.medicationNames, id: \.self) { name in
                        Text(name)
                    }
                    .onDelete { offsets in settings.medicationNames.remove(atOffsets: offsets) }
                    HStack {
                        TextField("Add a medicine", text: $newMedication)
                            .submitLabel(.done)
                            .onSubmit(addMedication)
                        Button("Add", action: addMedication)
                            .disabled(newMedication.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                } header: {
                    Text("My medicines")
                } footer: {
                    Text("Shown as one-tap buttons when you log a headache. Swipe left to remove one.")
                }

                Section {
                    Button {
                        prepareBackup()
                    } label: {
                        Label("Back Up Diary", systemImage: "square.and.arrow.up")
                    }
                    .disabled(attacks.isEmpty)
                    Button {
                        showImporter = true
                    } label: {
                        Label("Restore from Backup", systemImage: "square.and.arrow.down")
                    }
                } header: {
                    Text("Backup")
                } footer: {
                    Text("Saves your whole diary to a file, wherever you choose. Restoring only adds entries you don't already have — nothing gets deleted.")
                }

                Section("Purchases") {
                    if purchases.isPro {
                        Label("Migraine Log Pro is unlocked", systemImage: "checkmark.seal.fill")
                            .foregroundStyle(AppColors.success)
                    }
                    Button("Restore Purchases") {
                        Task { message = PurchaseService.message(for: await purchases.restore()) }
                    }
                    .disabled(purchases.isWorking)
                }

                @Bindable var settings = settings
                Section {
                    Toggle("Share anonymous usage stats", isOn: $settings.analyticsEnabled)
                        .tint(AppColors.accent)
                } header: {
                    Text("Privacy")
                } footer: {
                    Text("Counts which features get used, so we know what to improve. Never your headaches, medicines, Health data or anything you type.")
                }

                Section("About") {
                    Link(destination: AppLinks.privacyPolicy) { Label("Privacy Policy", systemImage: "hand.raised.fill") }
                    Link(destination: AppLinks.support) { Label("Contact Support", systemImage: "envelope.fill") }
                    Text("Migraine Log is a diary, not a medical device. It doesn't diagnose or treat anything, and triggers it shows are what you noted, not proven causes. Always check with your doctor before making medical decisions.")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
            }
            .navigationTitle("Settings")
            .scrollContentBackground(.hidden)
            .background(AppColors.bgApp)
            .fileExporter(
                isPresented: Binding(get: { backup != nil }, set: { if !$0 { backup = nil } }),
                document: backup,
                contentType: .json,
                defaultFilename: BackupService.filename()
            ) { result in
                if case .failure = result { message = "The backup couldn't be saved. Please try again." }
            }
            .fileImporter(isPresented: $showImporter, allowedContentTypes: [.json]) { result in
                restore(result)
            }
            .alert("Migraine Log", isPresented: Binding(get: { message != nil }, set: { if !$0 { message = nil } })) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(message ?? "")
            }
        }
    }

    // MARK: Reminder

    @ViewBuilder
    private var reminderRow: some View {
        let current = settings.reminderMinutes.first
        Toggle("Daily check-in", isOn: Binding(
            get: { current != nil },
            set: { on in Task { await setReminder(on ? (current ?? NotificationService.defaultEvening) : nil) } }
        ))
        .tint(AppColors.accent)
        if let current {
            DatePicker("Time", selection: Binding(
                get: { ReminderTime.date(fromMinutes: current) },
                set: { date in Task { await setReminder(ReminderTime.minutes(from: date)) } }
            ), displayedComponents: .hourAndMinute)
        }
    }

    private func setReminder(_ minutes: Int?) async {
        if minutes != nil, !(await NotificationService.requestPermission()) {
            message = "Notifications are off for Migraine Log. Turn them on in the Settings app to get the reminder."
            return
        }
        settings.reminderMinutes = minutes.map { [$0] } ?? []
        NotificationService.schedule(minutes: settings.reminderMinutes)
        Analytics.track(.remindersChanged, ["count": String(settings.reminderMinutes.count)])
    }

    private func addMedication() {
        settings.rememberMedication(newMedication)
        newMedication = ""
    }

    // MARK: Health

    private func setHealth(_ on: Bool) async {
        guard on else {
            settings.healthEnabled = false
            return
        }
        guard await HealthService.requestAuthorization() else {
            message = "Apple Health isn't available right now. Please try again."
            return
        }
        settings.healthEnabled = true
        Analytics.track(.healthEnabled, ["from": "settings"])
        await syncNow()
    }

    /// Pull first, so headaches synced from another device aren't written back as duplicates.
    private func syncNow() async {
        syncing = true
        let imported = await HealthService.importNew(into: context, deletedIDs: settings.deletedIDs)
        let saved = await HealthService.backfill(context)
        syncing = false
        Analytics.track(.healthSynced)
        message = "Brought in \(imported) headaches from Apple Health and saved \(saved) to it. If nothing moved, check Settings › Health › Data Access & Devices › Migraine Log and allow Headache."
    }

    private func prepareBackup() {
        do {
            backup = BackupDocument(data: try BackupService.export(attacks))
            Analytics.track(.backupSaved)
        } catch {
            message = "The backup couldn't be created. Please try again."
        }
    }

    private func restore(_ result: Result<URL, Error>) {
        guard case .success(let url) = result else { return }
        // The picker hands back a URL outside the sandbox; reading it needs scoped access.
        let opened = url.startAccessingSecurityScopedResource()
        defer { if opened { url.stopAccessingSecurityScopedResource() } }
        do {
            let outcome = try BackupService.restore(from: try Data(contentsOf: url), into: context)
            Analytics.track(.backupRestored)
            message = "Added \(outcome.added) entries. Skipped \(outcome.skipped) you already had."
        } catch {
            message = "This file doesn't look like a Migraine Log backup."
        }
    }
}
