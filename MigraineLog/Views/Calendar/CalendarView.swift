import SwiftUI
import SwiftData

/// The month at a glance: each day shaded by its worst pain, the month's
/// numbers, and its attacks below. Tapping a day narrows the list to it.
struct CalendarView: View {
    @Environment(\.modelContext) private var context
    @Environment(AppSettings.self) private var settings
    @Query(sort: \Attack.start, order: .reverse) private var attacks: [Attack]
    @State private var month = Calendar.current.dateInterval(of: .month, for: Date())?.start ?? Date()
    @State private var selectedDay: Date?
    @State private var editing: Attack?
    @State private var pendingDelete: Attack?
    @State private var showingLog = false

    private let calendar = Calendar.current

    private var monthInterval: DateInterval {
        calendar.dateInterval(of: .month, for: month) ?? DateInterval(start: month, duration: 0)
    }

    private var isCurrentMonth: Bool { calendar.isDate(month, equalTo: Date(), toGranularity: .month) }

    var body: some View {
        NavigationStack {
            let now = Date()
            let values = attacks.map(\.value)
            let interval = monthInterval
            let inMonth = attacks.filter { $0.value.interval(now: now).intersects(interval) || interval.contains($0.start) }
            let listed = selectedDay.map { day in
                inMonth.filter { StatsEngine.days(of: $0.value, now: now, calendar: calendar).contains(day) }
            } ?? inMonth
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    monthHeader
                    CardView {
                        MonthGrid(month: month, peaks: StatsEngine.dayPeaks(values, now: now, calendar: calendar, within: interval),
                                  selected: $selectedDay)
                    }
                    summaryRow(values, interval: interval, now: now)
                    HStack {
                        SectionLabel(selectedDay.map { $0.formatted(date: .complete, time: .omitted) } ?? "This month")
                        Spacer()
                        if selectedDay != nil {
                            Button("Show Month") { selectedDay = nil }
                                .font(.subheadline.weight(.semibold))
                        }
                    }
                    .padding(.top, 4)
                    if listed.isEmpty {
                        Text(selectedDay == nil ? "No headaches logged this month." : "No headache logged on this day.")
                            .font(.body)
                            .foregroundStyle(AppColors.textSecondary)
                            .padding(.horizontal, 4)
                    } else {
                        ForEach(listed) { a in
                            Button { editing = a } label: { AttackRow(attack: a) }
                                .buttonStyle(.plain)
                                // Long press: the only other way to delete is inside the entry.
                                .contextMenu {
                                    Button("Edit", systemImage: "pencil") { editing = a }
                                    Button("Delete", systemImage: "trash", role: .destructive) { pendingDelete = a }
                                        .tint(.red)
                                }
                        }
                    }
                }
                .padding()
            }
            .background(AppColors.bgApp)
            .navigationTitle("Calendar")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingLog = true } label: { Label("Log Headache", systemImage: "plus") }
                }
            }
            .sheet(item: $editing) { LogAttackView(editing: $0) }
            .sheet(isPresented: $showingLog) { LogAttackView() }
            .confirmationDialog("Delete this entry?",
                                isPresented: Binding(get: { pendingDelete != nil }, set: { if !$0 { pendingDelete = nil } }),
                                titleVisibility: .visible) {
                Button("Delete Entry", role: .destructive) {
                    if let a = pendingDelete { AttackActions.delete([a], context: context, settings: settings) }
                    pendingDelete = nil
                }
            } message: {
                Text("It will be removed from your diary. This can't be undone.")
            }
        }
    }

    private var monthHeader: some View {
        HStack {
            Button { shift(-1) } label: {
                Image(systemName: "chevron.left").font(.title3.weight(.semibold)).frame(width: 44, height: 44)
            }
            .accessibilityLabel("Previous month")
            Spacer()
            Text(month.formatted(.dateTime.month(.wide).year()))
                .font(.title2.bold())
                .foregroundStyle(AppColors.textPrimary)
            Spacer()
            Button { shift(1) } label: {
                Image(systemName: "chevron.right").font(.title3.weight(.semibold)).frame(width: 44, height: 44)
            }
            .disabled(isCurrentMonth)
            .accessibilityLabel("Next month")
        }
    }

    private func summaryRow(_ values: [AttackValue], interval: DateInterval, now: Date) -> some View {
        let s = StatsEngine.summary(values, in: DateInterval(start: interval.start, end: min(interval.end, max(interval.start, now))),
                                    now: now, calendar: calendar)
        return HStack(spacing: 10) {
            pill("\(s.headacheDays)", "headache days")
            pill("\(s.migraineDays)", "migraine days")
            pill("\(s.medicationDays)", "med days")
        }
    }

    private func pill(_ value: String, _ label: String) -> some View {
        VStack(spacing: 2) {
            Text(value).font(AppFont.number(24)).foregroundStyle(AppColors.textPrimary)
            Text(label).font(.caption).foregroundStyle(AppColors.textSecondary).lineLimit(1).minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(RoundedRectangle(cornerRadius: AppShape.cardRadius, style: .continuous).fill(AppColors.bgCard))
        .accessibilityElement(children: .combine)
    }

    private func shift(_ months: Int) {
        guard let next = calendar.date(byAdding: .month, value: months, to: month) else { return }
        month = next
        selectedDay = nil
    }
}

/// Seven columns starting on the user's first weekday. Days with a headache
/// carry the peak pain number on its band's color, so the grid reads without color too.
struct MonthGrid: View {
    let month: Date
    let peaks: [Date: Int]
    @Binding var selected: Date?

    private let calendar = Calendar.current

    private var days: [Date?] {
        guard let interval = calendar.dateInterval(of: .month, for: month),
              let count = calendar.range(of: .day, in: .month, for: month)?.count else { return [] }
        let leading = (calendar.component(.weekday, from: interval.start) - calendar.firstWeekday + 7) % 7
        return Array(repeating: nil, count: leading)
            + (0..<count).compactMap { calendar.date(byAdding: .day, value: $0, to: interval.start) }
    }

    var body: some View {
        let symbols = calendar.veryShortStandaloneWeekdaySymbols
        let order = (0..<7).map { (calendar.firstWeekday - 1 + $0) % 7 }
        let columns = Array(repeating: GridItem(.flexible(), spacing: 6), count: 7)
        VStack(spacing: 8) {
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(order, id: \.self) { i in
                    Text(symbols[i]).font(.caption.weight(.semibold)).foregroundStyle(AppColors.textSecondary)
                }
            }
            .accessibilityHidden(true)
            LazyVGrid(columns: columns, spacing: 6) {
                ForEach(Array(days.enumerated()), id: \.offset) { _, day in
                    if let day { cell(day) } else { Color.clear.frame(height: 42) }
                }
            }
        }
    }

    private func cell(_ day: Date) -> some View {
        let peak = peaks[day]
        let isToday = calendar.isDateInToday(day)
        let isFuture = day > Date()
        let isSelected = selected.map { calendar.isDate($0, inSameDayAs: day) } ?? false
        return Button {
            selected = isSelected ? nil : day
        } label: {
            VStack(spacing: 0) {
                Text("\(calendar.component(.day, from: day))")
                    .font(.subheadline.weight(peak != nil || isToday ? .bold : .regular))
                    .foregroundStyle(peak.map { PainRamp.text($0) } ?? (isFuture ? AppColors.textSecondary.opacity(0.5) : AppColors.textPrimary))
                if let peak {
                    Text("\(peak)").font(.system(size: 10, weight: .semibold)).foregroundStyle(PainRamp.text(peak).opacity(0.85))
                }
            }
            .frame(maxWidth: .infinity, minHeight: 42)
            .background(RoundedRectangle(cornerRadius: AppShape.chipRadius, style: .continuous)
                .fill(peak.map { PainRamp.fill($0) } ?? .clear))
            .overlay(RoundedRectangle(cornerRadius: AppShape.chipRadius, style: .continuous)
                .strokeBorder(isSelected ? AppColors.textPrimary : (isToday ? AppColors.accent : .clear), lineWidth: 2))
        }
        .buttonStyle(.plain)
        .disabled(isFuture)
        .accessibilityLabel(day.formatted(date: .complete, time: .omitted) + (peak.map { ", headache, pain \($0)" } ?? ", no headache"))
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}
