import Testing
import Foundation
import PDFKit
@testable import MigraineLog

@MainActor
struct PDFGeneratorTests {
    let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func text(_ url: URL) throws -> String {
        // Wrapped lines come back with line breaks; compare on single spaces.
        try #require(PDFDocument(url: url)?.string).split(whereSeparator: \.isWhitespace).joined(separator: " ")
    }

    @Test func reportHasTheKeyNumbersAndDisclaimer() throws {
        let attacks = DemoData.attacks(now: now, calendar: .current).map { ReportAttack(value: $0, note: "") }
        let url = PDFGenerator.generate(attacks: attacks, interval: StatsPeriod.quarter.interval(now: now), patientName: "Jane Doe", now: now)
        let pdf = try #require(PDFDocument(url: url))
        let s = try text(url)
        #expect(s.contains("Headache Diary Report"))
        #expect(s.contains("Jane Doe"))
        #expect(s.contains("HEADACHE DAYS"))
        #expect(s.contains("MEDICATION DAYS"))
        #expect(s.contains(DemoData.triptan))
        #expect(s.contains("not a medical device"))
        #expect(pdf.pageCount >= 2)
    }

    @Test func emptyPeriodSaysSo() throws {
        let url = PDFGenerator.generate(attacks: [], interval: StatsPeriod.month.interval(now: now), patientName: "", now: now)
        #expect(try text(url).contains("No headaches were logged"))
    }

    @Test func notesAndOngoingAttacksAppear() throws {
        let ongoing = AttackValue(start: now.addingTimeInterval(-3600), end: nil, intensity: 9)
        let url = PDFGenerator.generate(attacks: [ReportAttack(value: ongoing, note: "woke up with it")], interval: nil, patientName: "", now: now)
        let s = try text(url)
        #expect(s.contains("ongoing"))
        #expect(s.contains("woke up with it"))
    }

    @Test func perThirtyScales() {
        #expect(PDFGenerator.perThirty(9, 90) == 3)
        #expect(PDFGenerator.perThirty(4, 30) == 4)
        #expect(PDFGenerator.perThirty(1, 0) == 30)
    }
}
