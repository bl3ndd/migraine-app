import SwiftUI
import Charts
import UIKit

/// An attack with everything the report table shows.
nonisolated struct ReportAttack: Sendable {
    var value: AttackValue
    var note: String
}

extension ReportAttack {
    init(_ a: Attack) {
        self.init(value: a.value, note: a.note)
    }
}

/// The doctor report: the numbers a neurologist asks for first (headache and
/// migraine days, medication days), a monthly chart, suspected triggers and
/// how each medicine worked, then every attack. US Letter, since the audience
/// is US patients and their doctors' printers.
enum PDFGenerator {
    private static let pageWidth: CGFloat = 612
    private static let pageHeight: CGFloat = 792
    private static let margin: CGFloat = 44
    private static let footerHeight: CGFloat = 44
    private static var contentWidth: CGFloat { pageWidth - margin * 2 }

    private static let titleFont = UIFont.systemFont(ofSize: 22, weight: .bold)
    private static let headingFont = UIFont.systemFont(ofSize: 13, weight: .semibold)
    private static let bodyFont = UIFont.systemFont(ofSize: 10.5)
    private static let smallFont = UIFont.systemFont(ofSize: 8.5)
    private static let figureFont = UIFont.systemFont(ofSize: 20, weight: .bold)
    private static let tableFont = UIFont.systemFont(ofSize: 8.5)
    private static let tableBold = UIFont.systemFont(ofSize: 8.5, weight: .semibold)

    static let disclaimer = "Talk to your doctor about this diary. Entries were recorded by the patient in Migraine Log. Migraine Log is not a medical device and does not diagnose. Triggers are what the patient suspected at the time, not established causes."

    static func generate(attacks: [ReportAttack], interval: DateInterval?, patientName: String,
                         now: Date = Date(), calendar: Calendar = .current) -> URL {
        let rows = attacks.sorted { $0.value.start < $1.value.start }
        let values = rows.map(\.value)
        let start = interval?.start ?? values.first.map { calendar.startOfDay(for: $0.start) } ?? now
        let end = interval?.end ?? now
        let period = DateInterval(start: min(start, end), end: end)
        let summary = StatsEngine.summary(values, in: period, now: now, calendar: calendar)
        let periodDays = max(1, Int((period.duration / 86_400).rounded()))

        let folder = FileManager.default.temporaryDirectory.appendingPathComponent("report-\(UUID().uuidString)", isDirectory: true)
        try? FileManager.default.createDirectory(at: folder, withIntermediateDirectories: true)
        let url = folder.appendingPathComponent("Headache Diary \(now.formatted(.iso8601.year().month().day())).pdf")

        // A monthly chart of whole months only: a month the period starts halfway
        // through would show a misleadingly short bar. The current month is in so far.
        let monthStart = calendar.dateInterval(of: .month, for: period.start)?.start ?? period.start
        let firstWhole = monthStart == period.start ? monthStart : (calendar.date(byAdding: .month, value: 1, to: monthStart) ?? monthStart)
        let months = (calendar.dateComponents([.month], from: firstWhole, to: now).month ?? 0) + 1
        let monthly = months >= 2 ? StatsEngine.monthly(values, months: min(months, 24), now: now, calendar: calendar) : []
        let chartImage = monthly.count >= 2 ? renderChart(monthly) : nil

        let renderer = UIGraphicsPDFRenderer(bounds: CGRect(x: 0, y: 0, width: pageWidth, height: pageHeight))
        let data = renderer.pdfData { context in
            var y: CGFloat = 0
            var page = 0
            let bottom = pageHeight - margin - footerHeight

            func newPage() {
                context.beginPage()
                page += 1
                y = margin
                drawFooter(page: page)
            }

            func ensure(_ needed: CGFloat) -> Bool {
                if y + needed > bottom { newPage(); return true }
                return false
            }

            func text(_ s: String, _ font: UIFont, color: UIColor = .black, x: CGFloat = margin, width: CGFloat = contentWidth) {
                let attrs: [NSAttributedString.Key: Any] = [.font: font, .foregroundColor: color]
                let h = (s as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                     options: [.usesLineFragmentOrigin, .usesFontLeading], attributes: attrs, context: nil).height
                _ = ensure(h + 4)
                (s as NSString).draw(in: CGRect(x: x, y: y, width: width, height: h + 2), withAttributes: attrs)
                y += h + 4
            }

            func heading(_ s: String) {
                _ = ensure(40)
                y += 10
                text(s, headingFont)
                UIColor(white: 0.85, alpha: 1).setFill()
                UIRectFill(CGRect(x: margin, y: y, width: contentWidth, height: 0.75))
                y += 6
            }

            func figure(_ caption: String, _ value: String, _ sub: String?, column: Int, of columns: Int) {
                let w = contentWidth / CGFloat(columns)
                let x = margin + w * CGFloat(column)
                (caption as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray])
                (value as NSString).draw(at: CGPoint(x: x, y: y + 12), withAttributes: [.font: figureFont, .foregroundColor: UIColor.black])
                if let sub {
                    (sub as NSString).draw(at: CGPoint(x: x, y: y + 38), withAttributes: [.font: smallFont, .foregroundColor: UIColor.darkGray])
                }
            }

            func line(_ label: String, _ value: String) {
                let attrs: [NSAttributedString.Key: Any] = [.font: tableBold.withSize(10.5), .foregroundColor: UIColor.black]
                let width = contentWidth - 200
                let h = max(16, (value as NSString).boundingRect(with: CGSize(width: width, height: .greatestFiniteMagnitude),
                                                                 options: [.usesLineFragmentOrigin], attributes: attrs, context: nil).height + 4)
                _ = ensure(h)
                (label as NSString).draw(at: CGPoint(x: margin, y: y), withAttributes: [.font: bodyFont, .foregroundColor: UIColor.darkGray])
                (value as NSString).draw(in: CGRect(x: margin + 200, y: y, width: width, height: h), withAttributes: attrs)
                y += h
            }

            // MARK: Header
            newPage()
            text("Headache Diary Report", titleFont)
            if !patientName.trimmingCharacters(in: .whitespaces).isEmpty { text(patientName, headingFont) }
            text("Period: \(period.start.formatted(date: .abbreviated, time: .omitted)) – \(period.end.formatted(date: .abbreviated, time: .omitted)) (\(periodDays) days)    Generated: \(now.formatted(date: .abbreviated, time: .omitted))",
                 bodyFont, color: .darkGray)

            // MARK: Summary
            heading("Summary")
            guard summary.attacks > 0 else {
                text("No headaches were logged in this period.", bodyFont)
                return
            }
            let perMonth = { (days: Int) in periodDays > 31 ? "≈ \(perThirty(days, periodDays)) per 30 days" : "of \(periodDays) days" }
            _ = ensure(56)
            figure("HEADACHE DAYS", "\(summary.headacheDays)", perMonth(summary.headacheDays), column: 0, of: 3)
            figure("MIGRAINE DAYS", "\(summary.migraineDays)", perMonth(summary.migraineDays), column: 1, of: 3)
            figure("MEDICATION DAYS", "\(summary.medicationDays)", perMonth(summary.medicationDays), column: 2, of: 3)
            y += 58
            _ = ensure(56)
            figure("ATTACKS", "\(summary.attacks)", nil, column: 0, of: 3)
            figure("AVERAGE PEAK PAIN", summary.averageIntensity.map { "\($0.formatted(.number.precision(.fractionLength(1)))) / 10" } ?? "—", nil, column: 1, of: 3)
            figure("AVERAGE DURATION", summary.averageDuration.map(DurationText.format) ?? "—", nil, column: 2, of: 3)
            y += 50

            let levels = StatsEngine.intensityCounts(values)
            line("By peak pain", IntensityLevel.allCases.map { "\($0.title) (\(range($0))) \(levels[$0] ?? 0)" }.joined(separator: " · "))
            let parts = StatsEngine.partOfDayCounts(values, calendar: calendar)
            line("When attacks started", StatsEngine.PartOfDay.allCases.map { "\($0.title) \(parts[$0] ?? 0)" }.joined(separator: " · "))
            let aura = values.filter { $0.symptoms.contains(.aura) }.count
            line("Attacks with aura", "\(aura) of \(values.count)")
            if perThirty(summary.medicationDays, periodDays) >= StatsEngine.medicationDaysNotice {
                text("Headache medicine was taken on \(StatsEngine.medicationDaysNotice) or more days per 30 days in this period.", tableBold.withSize(10), color: .black)
            }

            // MARK: Chart
            if let chartImage {
                heading("Headache days per month")
                let h = contentWidth * chartImage.size.height / chartImage.size.width
                _ = ensure(h)
                chartImage.draw(in: CGRect(x: margin, y: y, width: contentWidth, height: h))
                y += h + 4
            }

            // MARK: Triggers, symptoms, medicines
            let triggers = StatsEngine.triggerShares(values)
            if !triggers.isEmpty {
                heading("Suspected triggers")
                for t in triggers.prefix(8) { line(t.item.title, "\(t.count) of \(values.count) attacks (\(percent(t.share)))") }
            }
            let symptoms = StatsEngine.symptomShares(values)
            if !symptoms.isEmpty {
                heading("Symptoms")
                for s in symptoms.prefix(8) { line(s.item.title, "\(s.count) of \(values.count) attacks (\(percent(s.share)))") }
            }
            let meds = StatsEngine.medicationResults(values)
            if !meds.isEmpty {
                heading("Medication")
                for m in meds {
                    let rating = m.rated == 0 ? "no ratings" : "helped \(m.helped), a little \(m.partly), no \(m.rated - m.helped - m.partly)"
                    line(m.name, "\(m.doses) \(m.doses == 1 ? "dose" : "doses") · \(rating)")
                }
            }

            // MARK: Table
            heading("All attacks")
            let columns: [(String, CGFloat)] = [("Date", 0.11), ("Start", 0.08), ("Duration", 0.10), ("Pain", 0.06), ("Type", 0.09),
                                                ("Symptoms", 0.18), ("Triggers", 0.15), ("Medication", 0.23)]
            func tableHeader() {
                var x = margin
                for (title, share) in columns {
                    (title as NSString).draw(at: CGPoint(x: x, y: y), withAttributes: [.font: tableBold, .foregroundColor: UIColor.darkGray])
                    x += contentWidth * share
                }
                y += 14
            }
            _ = ensure(30)
            tableHeader()
            for (i, r) in rows.enumerated() {
                let a = r.value
                let medsText = a.medications.map { "\($0.name) (\($0.effect == .unknown ? "?" : $0.effect.title.lowercased()))" }.joined(separator: "; ")
                let cells = [a.start.formatted(date: .abbreviated, time: .omitted),
                             a.start.formatted(date: .omitted, time: .shortened),
                             a.duration.map(DurationText.format) ?? "ongoing",
                             "\(a.intensity)",
                             a.kind.title,
                             a.symptoms.map(\.title).joined(separator: ", "),
                             a.triggers.map(\.title).joined(separator: ", "),
                             [medsText, r.note].filter { !$0.isEmpty }.joined(separator: " — ")]
                // Every cell may wrap: the tallest sets the row.
                let cellHeights = cells.enumerated().map { c, cell in
                    (cell as NSString).boundingRect(with: CGSize(width: contentWidth * columns[c].1 - 4, height: .greatestFiniteMagnitude),
                                                    options: [.usesLineFragmentOrigin],
                                                    attributes: [.font: c == 3 ? tableBold : tableFont], context: nil).height
                }
                let rowHeight = max(13, (cellHeights.max() ?? 0) + 3)
                if ensure(rowHeight) { tableHeader() }
                if i.isMultiple(of: 2) {
                    UIColor(white: 0.96, alpha: 1).setFill()
                    UIRectFill(CGRect(x: margin - 4, y: y - 1, width: contentWidth + 8, height: rowHeight))
                }
                var x = margin
                for (c, cell) in cells.enumerated() {
                    let width = contentWidth * columns[c].1 - 4
                    (cell as NSString).draw(in: CGRect(x: x, y: y, width: width, height: rowHeight),
                                            withAttributes: [.font: c == 3 ? tableBold : tableFont, .foregroundColor: UIColor.black])
                    x += contentWidth * columns[c].1
                }
                y += rowHeight
            }
        }
        try? data.write(to: url)
        return url
    }

    /// Days scaled to a 30-day month, rounded.
    static func perThirty(_ days: Int, _ periodDays: Int) -> Int {
        Int((Double(days) * 30 / Double(max(periodDays, 1))).rounded())
    }

    private static func range(_ level: IntensityLevel) -> String {
        switch level {
        case .mild: "1–3"
        case .moderate: "4–6"
        case .severe: "7–10"
        }
    }

    private static func percent(_ share: Double) -> String { "\(Int((share * 100).rounded()))%" }

    private static func drawFooter(page: Int) {
        let rect = CGRect(x: margin, y: pageHeight - margin - footerHeight + 8, width: contentWidth - 50, height: footerHeight)
        (disclaimer as NSString).draw(in: rect, withAttributes: [.font: smallFont, .foregroundColor: UIColor.gray])
        ("Page \(page)" as NSString).draw(at: CGPoint(x: pageWidth - margin - 40, y: rect.minY),
                                          withAttributes: [.font: smallFont, .foregroundColor: UIColor.gray])
    }

    /// Headache and migraine days per month as a print-friendly chart image.
    private static func renderChart(_ months: [StatsEngine.MonthCount]) -> UIImage? {
        let chart = Chart(months, id: \.month) { m in
            BarMark(x: .value("Month", m.month, unit: .month), y: .value("Days", m.headacheDays))
                .foregroundStyle(by: .value("Type", "Headache days"))
                .position(by: .value("Type", "Headache days"))
            BarMark(x: .value("Month", m.month, unit: .month), y: .value("Days", m.migraineDays))
                .foregroundStyle(by: .value("Type", "Migraine days"))
                .position(by: .value("Type", "Migraine days"))
        }
        .chartForegroundStyleScale(["Headache days": Color(white: 0.62), "Migraine days": Color(red: 0.36, green: 0.25, blue: 0.62)])
        // A year or more repeats month names, so those labels carry the year.
        .chartXAxis {
            AxisMarks(values: .stride(by: .month, count: months.count > 12 ? 3 : 1)) { _ in
                AxisValueLabel(format: months.count >= 12 ? .dateTime.month(.abbreviated).year(.twoDigits) : .dateTime.month(.abbreviated))
            }
        }
        .chartLegend(position: .top, alignment: .leading)
        .frame(width: 516, height: 180)
        .padding(4)
        .background(Color.white)
        .environment(\.colorScheme, .light)

        let renderer = ImageRenderer(content: chart)
        renderer.scale = 3
        return renderer.uiImage
    }
}
