import SwiftUI
import SwiftData

/// Four short steps: what the app is (and isn't), your usual medicines, Apple
/// Health, the daily check-in. Everything after the first is skippable —
/// nothing in the app requires it (guideline 5.1.2(i)).
struct OnboardingView: View {
    @Environment(AppSettings.self) private var settings
    @Environment(\.modelContext) private var context

    @State private var step = 0
    @State private var reminderOn = true
    @State private var reminder = ReminderTime.date(fromMinutes: NotificationService.defaultEvening)
    @State private var picked: Set<String> = []
    @State private var custom = ""

    /// Common over-the-counter and prescription names, as one-tap starters.
    static let commonMedicines = ["Ibuprofen", "Acetaminophen", "Naproxen", "Excedrin", "Sumatriptan", "Rizatriptan", "Ubrelvy", "Nurtec"]

    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 20) {
                    switch step {
                    case 0: welcome
                    case 1: medicines
                    case 2: health
                    default: reminders
                    }
                }
                .padding(24)
                .frame(maxWidth: .infinity, alignment: .leading)
            }
            VStack(spacing: 12) {
                Button(primaryTitle, action: primary).buttonStyle(PrimaryButtonStyle())
                if step > 0 {
                    Button(step == 2 ? "Not Now" : "Skip", action: next)
                        .font(.body.weight(.medium))
                        .frame(minHeight: 44)
                }
            }
            .padding(24)
        }
        .background(AppColors.bgApp)
        .animation(.default, value: step)
    }

    // MARK: Steps

    private var welcome: some View {
        Group {
            header("brain.head.profile", "Your headache diary")
            bullet("hand.tap", "Log a migraine in a few taps, even mid-attack.")
            bullet("calendar", "See your headache days at a glance.")
            bullet("chart.bar.xaxis", "Spot your triggers and what medicine works.")
            bullet("doc.richtext", "Bring a clear report to your doctor.")
            HStack(alignment: .top, spacing: 10) {
                Image(systemName: "info.circle.fill").font(.title2).foregroundStyle(AppColors.accent)
                Text("Migraine Log is a diary, not a medical device. It doesn't diagnose or treat anything. Always check with your doctor before making medical decisions.")
                    .font(.body.weight(.semibold))
                    .foregroundStyle(AppColors.textPrimary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            .padding(14)
            .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.accentTint))
        }
    }

    private var medicines: some View {
        Group {
            header("pills.fill", "Your medicines")
            Text("Pick what you usually take for a headache. They'll be one tap away when you log one. You can change this any time in Settings.")
                .font(.title3)
                .foregroundStyle(AppColors.textSecondary)
            CardView {
                VStack(alignment: .leading, spacing: 14) {
                    ChipGroup(items: Self.commonMedicines + picked.filter { !Self.commonMedicines.contains($0) }.sorted(),
                              selection: $picked) { $0 }
                    HStack {
                        TextField("Something else", text: $custom)
                            .submitLabel(.done)
                            .onSubmit(addCustom)
                        Button("Add", action: addCustom)
                            .font(.body.weight(.semibold))
                            .disabled(custom.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                }
            }
        }
    }

    private var health: some View {
        Group {
            header("heart.fill", "Connect Apple Health")
            Text("Finished headaches are saved to Apple Health, and headaches other apps log there show up in your diary.")
                .font(.title3)
                .foregroundStyle(AppColors.textSecondary)
            bullet("arrow.triangle.2.circlepath", "Apple Health keeps your diary in sync across your devices.")
            bullet("lock.fill", "Your data stays on your devices. We never see it.")
        }
    }

    private var reminders: some View {
        Group {
            header("bell.fill", "A daily check-in")
            Text("Headaches you forget to log make your monthly count look better than it is. One reminder in the evening helps.")
                .font(.title3)
                .foregroundStyle(AppColors.textSecondary)
            CardView {
                HStack {
                    Toggle("Remind me at", isOn: $reminderOn).font(.title3.weight(.medium)).tint(AppColors.accent)
                    if reminderOn {
                        DatePicker("Reminder time", selection: $reminder, displayedComponents: .hourAndMinute)
                            .labelsHidden()
                    }
                }
            }
        }
    }

    // MARK: Pieces

    private func header(_ icon: String, _ title: String) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            Image(systemName: icon).font(.system(size: 48, weight: .light)).foregroundStyle(AppColors.accent)
            Text(title).font(.largeTitle.bold()).foregroundStyle(AppColors.textPrimary)
        }
        .padding(.top, 24)
    }

    private func bullet(_ icon: String, _ text: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon).font(.title2).foregroundStyle(AppColors.accent).frame(width: 32)
            Text(text).font(.title3).foregroundStyle(AppColors.textPrimary)
                .fixedSize(horizontal: false, vertical: true)
        }
    }

    private func addCustom() {
        let clean = custom.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !clean.isEmpty else { return }
        picked.insert(clean)
        custom = ""
    }

    // MARK: Actions

    private var primaryTitle: String {
        switch step {
        case 0: "Get Started"
        case 1: picked.isEmpty ? "Continue" : "Save Medicines"
        case 2: "Connect Apple Health"
        default: "Turn On Reminder"
        }
    }

    private func primary() {
        switch step {
        case 0:
            next()
        case 1:
            // Common names in the order shown, then anything typed.
            for name in Self.commonMedicines where picked.contains(name) { settings.rememberMedication(name) }
            for name in picked.sorted() where !Self.commonMedicines.contains(name) { settings.rememberMedication(name) }
            next()
        case 2:
            Task {
                if await HealthService.requestAuthorization() {
                    settings.healthEnabled = true
                    await HealthService.importNew(into: context, deletedIDs: settings.deletedIDs)
                    await HealthService.backfill(context)
                }
                next()
            }
        default:
            Task {
                if reminderOn, await NotificationService.requestPermission() {
                    settings.reminderMinutes = [ReminderTime.minutes(from: reminder)]
                    NotificationService.schedule(minutes: settings.reminderMinutes)
                }
                next()
            }
        }
    }

    private func next() {
        if step < 3 {
            step += 1
            Analytics.track(.onboardingStep, ["step": String(step + 1)])
        } else {
            Analytics.track(.onboardingCompleted, ["health": settings.healthEnabled ? "on" : "off",
                                                   "reminders": settings.reminderMinutes.isEmpty ? "off" : "on"])
            settings.hasCompletedOnboarding = true
        }
    }
}
