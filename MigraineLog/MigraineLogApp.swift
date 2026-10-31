import SwiftUI
import SwiftData

@main
struct MigraineLogApp: App {
    @State private var settings: AppSettings
    @State private var purchases = PurchaseService()
    @Environment(\.scenePhase) private var scenePhase
    private let container: ModelContainer
    /// The store on disk couldn't be opened; the app runs on an empty in-memory one and says so.
    @State private var storeFailed = false

    init() {
        let settings = AppSettings(defaults: LaunchMode.isThrowaway ? UserDefaults(suiteName: "uitest-\(UUID().uuidString)")! : .standard)
        if LaunchMode.skipOnboarding {
            settings.hasCompletedOnboarding = true
            settings.hasSeenIntroPaywall = true
        }
        if LaunchMode.isThrowaway { ReviewService.prompt = {} }
        Analytics.configure(enabled: settings.analyticsEnabled)
        _settings = State(initialValue: settings)
        // Local only: no iCloud for health data in v1 (guideline 5.1.3).
        // The app's own container, not the App Group's: SwiftData picks the group
        // container by default when the app has one, and only the widget's small
        // snapshot belongs there.
        let config = ModelConfiguration(isStoredInMemoryOnly: LaunchMode.isThrowaway, groupContainer: .none, cloudKitDatabase: .none)
        if let opened = try? ModelContainer(for: Attack.self, configurations: config) {
            container = opened
        } else {
            // Better than a crash on every launch: the file stays untouched for a later fix or support.
            container = try! ModelContainer(for: Attack.self, configurations: ModelConfiguration(isStoredInMemoryOnly: true))
            _storeFailed = State(initialValue: true)
        }
        if LaunchMode.isDemo {
            for a in DemoData.attacks(now: Date(), calendar: .current, days: LaunchMode.isDemoLarge ? 5 * 365 : 90) {
                container.mainContext.insert(Attack(start: a.start, end: a.end, intensity: a.intensity, kind: a.kind, locations: a.locations,
                                                    symptoms: a.symptoms, triggers: a.triggers, medications: a.medications))
            }
            settings.medicationNames = [DemoData.triptan, DemoData.ibuprofen]
        }
    }

    var body: some Scene {
        WindowGroup {
            Group {
                if settings.hasCompletedOnboarding {
                    MainTabView()
                } else {
                    OnboardingView()
                }
            }
                .environment(settings)
                .environment(purchases)
                .tint(AppColors.accent)
                .alert("Your diary couldn't be opened", isPresented: $storeFailed) {
                    Button("OK", role: .cancel) {}
                } message: {
                    Text("Nothing has been deleted. Please restart Migraine Log. If this keeps happening, contact support from Settings.")
                }
                .onOpenURL { url in
                    if WidgetBridge.isLogLink(url) { settings.pendingLog = true }
                }
                .onChange(of: scenePhase) { _, phase in
                    // Picks up headaches other apps wrote to Health while we were away.
                    guard phase == .active, settings.healthEnabled else { return }
                    Task { await HealthService.importNew(into: container.mainContext, deletedIDs: settings.deletedIDs) }
                }
        }
        .modelContainer(container)
    }
}
