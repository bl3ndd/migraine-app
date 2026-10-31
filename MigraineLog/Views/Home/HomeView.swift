import SwiftUI
import SwiftData

struct HomeView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Environment(PurchaseService.self) private var purchases
    @Query(sort: \Attack.start, order: .reverse) private var attacks: [Attack]
    @State private var showingLog = false
    @State private var editing: Attack?
    @State private var showingFirstPaywall = false
    @State private var showingReport = false
    @State private var confirmingEnd: Attack?

    private var ongoing: Attack? { attacks.first { $0.isOngoing } }

    var body: some View {
        NavigationStack {
            TimelineView(.everyMinute) { timeline in
                let now = timeline.date
                let values = attacks.map(\.value)
                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        Text(now.formatted(.dateTime.weekday(.wide).month(.wide).day()))
                            .font(.headline)
                            .foregroundStyle(AppColors.textSecondary)
                        if attacks.isEmpty {
                            emptyCard
                        } else {
                            if let ongoing {
                                ongoingCard(ongoing, now: now)
                            } else {
                                streakCard(values, now: now)
                            }
                            monthCard(values, now: now)
                            recentCard
                        }
                    }
                    .padding()
                }
            }
            .background(AppColors.bgApp)
            .navigationTitle("Migraine Log")
            .safeAreaInset(edge: .bottom) {
                if ongoing == nil {
                    Button {
                        showingLog = true
                    } label: {
                        Label("Log Headache", systemImage: "plus")
                    }
                    .buttonStyle(PrimaryButtonStyle())
                    .padding()
                }
            }
            .sheet(isPresented: $showingLog, onDismiss: offerProAfterFirstAttack) { LogAttackView() }
            .sheet(item: $editing) { LogAttackView(editing: $0) }
            .sheet(isPresented: $showingFirstPaywall) { PaywallView(source: "first_attack") }
            .sheet(isPresented: $showingReport) { ReportView() }
            .toolbar {
                if !attacks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingReport = true } label: { Label("Doctor Report", systemImage: "doc.text") }
                    }
                }
            }
            .confirmationDialog("End this headache now?",
                                isPresented: Binding(get: { confirmingEnd != nil }, set: { if !$0 { confirmingEnd = nil } }),
                                titleVisibility: .visible) {
                Button("End Now") {
                    if let a = confirmingEnd { AttackActions.end(a, context: context, settings: settings) }
                    confirmingEnd = nil
                }
                Button("Pick the End Time") {
                    editing = confirmingEnd
                    confirmingEnd = nil
                }
            }
            // Widget "log" link: on a cold launch the flag is already set when Home appears.
            .onAppear {
                openPendingLog()
                ReviewService.considerPrompt(headacheFreeDays: StatsEngine.headacheFreeDays(attacks.map(\.value), now: Date(), calendar: .current))
            }
            .onChange(of: settings.pendingLog) { openPendingLog() }
        }
    }

    /// Pro is offered once, after the first saved attack — by then the person has
    /// seen what the app does. Never again unprompted; Cancel doesn't count.
    private func offerProAfterFirstAttack() {
        guard !settings.hasSeenIntroPaywall, !purchases.isPro, !attacks.isEmpty else { return }
        settings.hasSeenIntroPaywall = true
        showingFirstPaywall = true
    }

    private func openPendingLog() {
        guard settings.pendingLog else { return }
        settings.pendingLog = false
        showingReport = false
        // With an attack already going, the link opens it to update or end.
        if let ongoing { editing = ongoing } else { showingLog = true }
    }

    // MARK: Cards

    private func ongoingCard(_ a: Attack, now: Date) -> some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("\(a.kind.title) in progress")
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                    Text(DurationText.format(now.timeIntervalSince(a.start)))
                        .font(AppFont.hero(52))
                        .foregroundStyle(AppColors.textPrimary)
                        .contentTransition(.numericText())
                    Text("since \(a.start.formatted(date: Calendar.current.isDateInToday(a.start) ? .omitted : .abbreviated, time: .shortened))")
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                }
                Spacer()
                IntensityBadge(intensity: a.intensity, size: 56)
            }
            if !a.medications.isEmpty {
                Label(a.medications.map(\.name).joined(separator: ", "), systemImage: "pills.fill")
                    .font(.subheadline)
                    .foregroundStyle(AppColors.textSecondary)
            }
            if a.intensity >= 9 { EmergencyNote() }
            HStack(spacing: 10) {
                Button("Update") { editing = a }
                    .buttonStyle(SecondaryButtonStyle())
                Button("It's Over") { confirmingEnd = a }
                    .buttonStyle(PrimaryButtonStyle())
            }
        }
        .padding(20)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.accentTint))
        .accessibilityElement(children: .contain)
    }

    private func streakCard(_ values: [AttackValue], now: Date) -> some View {
        let days = StatsEngine.headacheFreeDays(values, now: now, calendar: .current) ?? 0
        return CardView {
            HStack(alignment: .center, spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Headache-free")
                        .font(.headline)
                        .foregroundStyle(AppColors.textSecondary)
                    HStack(alignment: .firstTextBaseline, spacing: 6) {
                        Text("\(days)")
                            .font(AppFont.hero(84))
                            .foregroundStyle(AppColors.textPrimary)
                        Text(days == 1 ? "day" : "days")
                            .font(.title3.weight(.semibold))
                            .foregroundStyle(AppColors.textSecondary)
                    }
                    if let last = values.first(where: { $0.end != nil })?.end {
                        Text("Last headache ended \(last.formatted(.relative(presentation: .named)))")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textSecondary)
                    }
                }
                Spacer()
                StreakRing(days: days)
            }
            .accessibilityElement(children: .combine)
        }
    }

    private func monthCard(_ values: [AttackValue], now: Date) -> some View {
        let calendar = Calendar.current
        let month = calendar.dateInterval(of: .month, for: now) ?? DateInterval(start: now, duration: 0)
        let s = StatsEngine.summary(values, in: DateInterval(start: month.start, end: max(month.start, now)), now: now, calendar: calendar)
        let last30 = StatsEngine.summary(values, in: DateInterval(start: now.addingTimeInterval(-30 * 86_400), end: now), now: now, calendar: calendar)
        return CardView {
            VStack(alignment: .leading, spacing: 14) {
                Text(now.formatted(.dateTime.month(.wide)))
                    .font(.headline)
                    .foregroundStyle(AppColors.textSecondary)
                HStack(alignment: .top, spacing: 8) {
                    figure("\(s.headacheDays)", "Headache\ndays", AppColors.textPrimary)
                    figure("\(s.migraineDays)", "Migraine\ndays", AppColors.migraine)
                    figure("\(s.medicationDays)", "Medication\ndays", AppColors.textPrimary)
                }
                if last30.medicationDays >= StatsEngine.medicationDaysNotice {
                    HStack(alignment: .top, spacing: 10) {
                        Image(systemName: "info.circle.fill").foregroundStyle(AppColors.accent)
                        Text("You took headache medicine on \(last30.medicationDays) of the last 30 days. Doctors pay attention to 10 or more, so it's worth mentioning at your next visit.")
                            .font(.subheadline)
                            .foregroundStyle(AppColors.textPrimary)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(12)
                    .background(RoundedRectangle(cornerRadius: AppShape.chipRadius, style: .continuous).fill(AppColors.accentTint))
                }
            }
        }
    }

    private func figure(_ value: String, _ label: String, _ color: Color) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(AppFont.number(34)).foregroundStyle(color)
            Text(label).font(.subheadline).foregroundStyle(AppColors.textSecondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private var recentCard: some View {
        let recent = attacks.filter { !$0.isOngoing }.prefix(3)
        return VStack(alignment: .leading, spacing: 10) {
            if !recent.isEmpty {
                SectionLabel("Recent")
                    .padding(.top, 6)
                ForEach(Array(recent)) { a in
                    Button { editing = a } label: { AttackRow(attack: a) }
                        .buttonStyle(.plain)
                }
            }
        }
    }

    private var emptyCard: some View {
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                Image(systemName: "brain.head.profile")
                    .font(.system(size: 44))
                    .foregroundStyle(AppColors.accent)
                Text("Your headache diary")
                    .font(.title2.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Text("When a headache starts, tap Log Headache. Pain level is all you need; add the rest whenever you feel up to it. Your calendar, patterns and doctor report build from there.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
            }
        }
    }
}

/// Progress toward a 30-day headache-free month, as a ring with the day count.
struct StreakRing: View {
    let days: Int

    var body: some View {
        ZStack {
            Circle().stroke(AppColors.bgInput, lineWidth: 8)
            Circle()
                .trim(from: 0, to: min(1, Double(days) / 30))
                .stroke(AppColors.accent, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                .rotationEffect(.degrees(-90))
            Image(systemName: "sun.max.fill")
                .font(.title2)
                .foregroundStyle(AppColors.accent)
        }
        .frame(width: 72, height: 72)
        .accessibilityHidden(true)
    }
}

/// One attack in a list: pain badge, date, type and duration, medicines.
struct AttackRow: View {
    let attack: Attack

    var body: some View {
        HStack(spacing: 14) {
            IntensityBadge(intensity: attack.intensity, size: 44)
            VStack(alignment: .leading, spacing: 3) {
                Text(attack.start.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day().hour().minute()))
                    .font(.headline)
                    .foregroundStyle(AppColors.textPrimary)
                HStack(spacing: 6) {
                    Text(attack.kind.title).foregroundStyle(attack.kind.color).fontWeight(.semibold)
                    Text("·")
                    Text(attack.end.map { DurationText.format($0.timeIntervalSince(attack.start)) } ?? "ongoing")
                    if attack.source == .health {
                        Image(systemName: "heart.text.square").accessibilityLabel("From Apple Health")
                    }
                }
                .font(.subheadline)
                .foregroundStyle(AppColors.textSecondary)
                if !attack.medications.isEmpty {
                    Text(attack.medications.map(\.name).joined(separator: ", "))
                        .font(.subheadline)
                        .foregroundStyle(AppColors.textSecondary)
                        .lineLimit(1)
                }
            }
            Spacer(minLength: 0)
            Image(systemName: "chevron.right")
                .font(.footnote.weight(.semibold))
                .foregroundStyle(AppColors.textSecondary)
        }
        .padding(14)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.bgCard))
        .contentShape(Rectangle())
        .accessibilityElement(children: .combine)
    }
}
