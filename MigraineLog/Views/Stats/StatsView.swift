import SwiftUI
import SwiftData
import Charts

/// Pro statistics. Free users see the real layout blurred under an unlock
/// prompt — what they'd get, without the numbers.
struct StatsView: View {
    @Environment(PurchaseService.self) private var purchases
    @Query(sort: \Attack.start) private var attacks: [Attack]
    @State private var period = StatsPeriod.quarter
    @State private var showingPaywall = false
    @State private var showingReport = false

    private var locked: Bool { ProFeature.isLocked(.fullStats, isPro: purchases.isPro) }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    SegmentedChips(options: StatsPeriod.allCases, selection: $period) { $0.rawValue }

                    if attacks.isEmpty {
                        ContentUnavailableView("Nothing logged yet", systemImage: "chart.bar.xaxis",
                                               description: Text("Log a few headaches and your patterns show up here."))
                    } else {
                        ZStack(alignment: .top) {
                            StatsContent(all: attacks.map(\.value), period: period)
                                .blur(radius: locked ? 8 : 0)
                                .allowsHitTesting(!locked)
                                .accessibilityHidden(locked)
                            if locked { unlockCard.padding(.top, 40) }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Insights")
            .onAppear { Analytics.track(.statsOpened, ["pro": purchases.isPro ? "true" : "false"]) }
            .sheet(isPresented: $showingPaywall) { PaywallView(source: "stats") }
            .toolbar {
                if !attacks.isEmpty {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button { showingReport = true } label: { Label("Doctor Report", systemImage: "doc.text") }
                    }
                }
            }
            .sheet(isPresented: $showingReport) { ReportView() }
        }
    }

    private var unlockCard: some View {
        CardView {
            VStack(spacing: 12) {
                Image(systemName: "lock.fill").font(.title).foregroundStyle(AppColors.accent)
                Text("Insights are part of Pro")
                    .font(.title3.bold())
                    .foregroundStyle(AppColors.textPrimary)
                Text("Your common triggers, which medicine works, when attacks start, and how your month compares — from your own diary.")
                    .font(.body)
                    .foregroundStyle(AppColors.textSecondary)
                    .multilineTextAlignment(.center)
                Button("Unlock Pro") { showingPaywall = true }
                    .buttonStyle(PrimaryButtonStyle())
            }
            .frame(maxWidth: .infinity)
        }
    }
}

private struct StatsContent: View {
    let all: [AttackValue]
    let period: StatsPeriod

    private let calendar = Calendar.current
    private let now = Date()

    private var interval: DateInterval? { period.interval(now: now) }
    private var attacks: [AttackValue] { interval.map { StatsEngine.attacks(all, in: $0, now: now) } ?? all }

    var body: some View {
        let attacks = self.attacks
        VStack(spacing: 16) {
            if attacks.isEmpty {
                ContentUnavailableView("No headaches in this period", systemImage: "sun.max")
            } else {
                summaryCard(attacks)
                monthlyCard
                triggersCard(attacks)
                medicationCard(attacks)
                symptomsCard(attacks)
                timingCard(attacks)
                painCard(attacks)
            }
        }
    }

    // MARK: Cards

    private func summaryCard(_ attacks: [AttackValue]) -> some View {
        let span = interval ?? DateInterval(start: attacks.map(\.start).min() ?? now, end: now)
        let s = StatsEngine.summary(all, in: span, now: now, calendar: calendar)
        let change = StatsEngine.headacheDayChange(all, period: period, now: now, calendar: calendar)
        return CardView {
            VStack(alignment: .leading, spacing: 16) {
                title("Overview")
                HStack(alignment: .top) {
                    metric("\(s.headacheDays)", "headache days")
                    metric("\(s.migraineDays)", "migraine days")
                    metric("\(s.medicationDays)", "medication days")
                }
                HStack(alignment: .top) {
                    metric("\(s.attacks)", s.attacks == 1 ? "attack" : "attacks")
                    metric(s.averageIntensity.map { $0.formatted(.number.precision(.fractionLength(1))) } ?? "—", "average pain")
                    metric(s.averageDuration.map(DurationText.format) ?? "—", "average length")
                }
                if let change {
                    let text = change == 0 ? "Same number of headache days as the previous \(period.rawValue)."
                        : "\(abs(change)) \(abs(change) == 1 ? "headache day" : "headache days") \(change < 0 ? "fewer" : "more") than the previous \(period.rawValue)."
                    Label(text, systemImage: change < 0 ? "arrow.down.right" : change > 0 ? "arrow.up.right" : "equal")
                        .font(.body.weight(.medium))
                        .foregroundStyle(change < 0 ? AppColors.success : AppColors.textPrimary)
                }
            }
        }
    }

    private var monthlyCard: some View {
        let months = StatsEngine.monthly(all, months: period == .month || period == .quarter ? 6 : 12, now: now, calendar: calendar)
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("Headache days per month")
                Chart(months, id: \.month) { m in
                    // Side by side, not stacked: migraine days are part of headache days.
                    BarMark(x: .value("Month", m.month, unit: .month), y: .value("Days", m.headacheDays))
                        .foregroundStyle(AppColors.headache.opacity(0.55))
                        .position(by: .value("Type", "All"))
                        .cornerRadius(4)
                    BarMark(x: .value("Month", m.month, unit: .month), y: .value("Days", m.migraineDays))
                        .foregroundStyle(AppColors.migraine)
                        .position(by: .value("Type", "Migraine"))
                        .cornerRadius(4)
                }
                .chartXAxis { AxisMarks(values: .stride(by: .month, count: months.count > 6 ? 2 : 1)) { _ in AxisValueLabel(format: .dateTime.month(.abbreviated)) } }
                .frame(height: 180)
                HStack(spacing: 14) {
                    legend(AppColors.migraine, "Migraine days")
                    legend(AppColors.headache.opacity(0.55), "All headache days")
                }
            }
        }
    }

    @ViewBuilder
    private func triggersCard(_ attacks: [AttackValue]) -> some View {
        let shares = StatsEngine.triggerShares(attacks)
        CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("Possible triggers")
                if shares.isEmpty {
                    caption("Tick possible triggers when you log a headache, and the common ones show up here.")
                } else {
                    ForEach(shares.prefix(6), id: \.item) { s in
                        shareBar(s.item.title, share: s.share, detail: "\(s.count) of \(attacks.count)", color: AppColors.accent)
                    }
                    caption("Share of attacks where you noted it. A pattern to talk over with your doctor, not proof of a cause.")
                }
            }
        }
    }

    @ViewBuilder
    private func medicationCard(_ attacks: [AttackValue]) -> some View {
        let results = StatsEngine.medicationResults(attacks)
        CardView {
            VStack(alignment: .leading, spacing: 14) {
                title("Medication")
                if results.isEmpty {
                    caption("Add what you took when you log a headache, and answer \"Did it help?\" to see what works for you.")
                } else {
                    ForEach(results, id: \.name) { m in
                        VStack(alignment: .leading, spacing: 6) {
                            HStack {
                                Text(m.name).font(.headline).foregroundStyle(AppColors.textPrimary)
                                Spacer()
                                Text("\(m.doses) \(m.doses == 1 ? "dose" : "doses")").font(.subheadline).foregroundStyle(AppColors.textSecondary)
                            }
                            if let share = m.helpedShare {
                                ProgressView(value: share).tint(AppColors.success)
                                caption("Helped at least a little \(Int((share * 100).rounded()))% of the time (\(m.rated) rated)")
                            } else {
                                caption("No answers to \"Did it help?\" yet")
                            }
                        }
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func symptomsCard(_ attacks: [AttackValue]) -> some View {
        let shares = StatsEngine.symptomShares(attacks)
        if !shares.isEmpty {
            CardView {
                VStack(alignment: .leading, spacing: 12) {
                    title("Symptoms")
                    ForEach(shares.prefix(6), id: \.item) { s in
                        shareBar(s.item.title, share: s.share, detail: "\(s.count) of \(attacks.count)", color: AppColors.headache)
                    }
                }
            }
        }
    }

    private func timingCard(_ attacks: [AttackValue]) -> some View {
        let parts = StatsEngine.partOfDayCounts(attacks, calendar: calendar)
        let weekdays = StatsEngine.weekdayCounts(attacks, calendar: calendar)
        let symbols = calendar.shortWeekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 + 1 }
        return CardView {
            VStack(alignment: .leading, spacing: 14) {
                title("When attacks start")
                HStack(spacing: 8) {
                    ForEach(StatsEngine.PartOfDay.allCases, id: \.self) { p in
                        VStack(spacing: 4) {
                            Text("\(parts[p] ?? 0)").font(AppFont.number(22)).foregroundStyle(AppColors.textPrimary)
                            Text(p.title).font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background(RoundedRectangle(cornerRadius: AppShape.chipRadius, style: .continuous).fill(AppColors.bgInput))
                        .accessibilityElement(children: .combine)
                    }
                }
                Chart(order, id: \.self) { day in
                    BarMark(x: .value("Day", symbols[day - 1]), y: .value("Attacks", weekdays[day] ?? 0))
                        .foregroundStyle(AppColors.accent)
                        .cornerRadius(6)
                }
                .chartXScale(domain: order.map { symbols[$0 - 1] })
                .chartYAxis { AxisMarks(values: .automatic(desiredCount: 3)) }
                .frame(height: 140)
                caption("Night is midnight–6 AM, morning 6–noon, afternoon noon–6 PM, evening after 6 PM.")
            }
        }
    }

    private func painCard(_ attacks: [AttackValue]) -> some View {
        let counts = StatsEngine.intensityCounts(attacks)
        return CardView {
            VStack(alignment: .leading, spacing: 12) {
                title("Peak pain")
                ForEach(IntensityLevel.allCases.reversed(), id: \.self) { level in
                    let count = counts[level] ?? 0
                    shareBar("\(level.title) (\(level == .mild ? "1–3" : level == .moderate ? "4–6" : "7–10"))",
                             share: Double(count) / Double(max(attacks.count, 1)), detail: "\(count)", color: level.color)
                }
            }
        }
    }

    // MARK: Pieces

    private func shareBar(_ label: String, share: Double, detail: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 5) {
            HStack {
                Text(label).font(.body.weight(.medium)).foregroundStyle(AppColors.textPrimary)
                Spacer()
                Text(detail).font(.subheadline).foregroundStyle(AppColors.textSecondary)
            }
            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    Capsule().fill(AppColors.bgInput)
                    Capsule().fill(color).frame(width: max(8, geo.size.width * share))
                }
            }
            .frame(height: 8)
        }
        .accessibilityElement(children: .combine)
        .accessibilityValue("\(Int((share * 100).rounded())) percent")
    }

    private func metric(_ value: String, _ label: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(value).font(AppFont.number(28)).foregroundStyle(AppColors.textPrimary).lineLimit(1).minimumScaleFactor(0.6)
            Text(label).font(.subheadline).foregroundStyle(AppColors.textSecondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityElement(children: .combine)
    }

    private func legend(_ color: Color, _ text: String) -> some View {
        HStack(spacing: 6) {
            RoundedRectangle(cornerRadius: 3).fill(color).frame(width: 12, height: 12)
            Text(text).font(.caption).foregroundStyle(AppColors.textSecondary)
        }
    }

    private func title(_ text: String) -> some View {
        Text(text).font(.headline).foregroundStyle(AppColors.textSecondary)
    }

    private func caption(_ text: String) -> some View {
        Text(text).font(.subheadline).foregroundStyle(AppColors.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
