import SwiftUI
import SwiftData

struct MainTabView: View {
    enum Page: Hashable { case home, calendar, stats, settings }

    @Environment(AppSettings.self) private var settings
    @Query(sort: \Attack.start) private var attacks: [Attack]
    @State private var page = Page.home

    var body: some View {
        TabView(selection: $page) {
            Tab("Today", systemImage: "sun.max", value: Page.home) { HomeView() }
            Tab("Calendar", systemImage: "calendar", value: Page.calendar) { CalendarView() }
            Tab("Insights", systemImage: "chart.bar.xaxis", value: Page.stats) { StatsView() }
            Tab("Settings", systemImage: "gearshape", value: Page.settings) { SettingsView() }
        }
        // A widget's "log" link lands on Home, which opens the log form.
        .onChange(of: settings.pendingLog) { _, pending in
            if pending { page = .home }
        }
        .onAppear { WidgetBridge.publish(attacks.map(\.value)) }
        .onChange(of: widgetFingerprint) { WidgetBridge.publish(attacks.map(\.value)) }
    }

    /// Changes whenever an attack is added, deleted, ended or retimed, so the widget never goes stale.
    private var widgetFingerprint: [Int] {
        [attacks.count, attacks.filter(\.isOngoing).count,
         attacks.reduce(0) { $0 &+ Int($1.start.timeIntervalSince1970) &* 31 &+ Int($1.end?.timeIntervalSince1970 ?? 0) }]
    }
}
