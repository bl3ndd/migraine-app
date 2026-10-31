import Foundation
import SwiftUI

/// Copy of the app's `WidgetSnapshot` (MigraineLog/Services/WidgetBridge.swift): change both together.
struct WidgetSnapshot: Codable, Equatable {
    var ongoingSince: Date?
    var lastEnd: Date?
    var monthHeadacheDays: Int
    var monthStart: Date

    static let appGroup = "group.white.tea.MigraineLog"
    static let key = "widgetSnapshot"
    static let logURL = URL(string: "simplymigraine://log")!

    static func load() -> WidgetSnapshot? {
        guard let data = UserDefaults(suiteName: appGroup)?.data(forKey: key) else { return nil }
        return try? JSONDecoder().decode(WidgetSnapshot.self, from: data)
    }

    static let sample = WidgetSnapshot(ongoingSince: nil, lastEnd: Date().addingTimeInterval(-4 * 86_400),
                                       monthHeadacheDays: 5, monthStart: Date())

    /// Whole days since the last attack ended, as of `date`; nil with no history.
    func headacheFreeDays(on date: Date, calendar: Calendar = .current) -> Int? {
        if ongoingSince != nil { return 0 }
        guard let lastEnd else { return nil }
        return max(0, calendar.dateComponents([.day], from: calendar.startOfDay(for: lastEnd), to: calendar.startOfDay(for: date)).day ?? 0)
    }

    /// The month count only means something within its own month.
    func monthDays(on date: Date, calendar: Calendar = .current) -> Int {
        calendar.isDate(monthStart, equalTo: date, toGranularity: .month) ? monthHeadacheDays : 0
    }
}

extension Color {
    static let brand = Color(light: 0x146B66, dark: 0x5FCBBF)

    init(light: UInt, dark: UInt) {
        self.init(uiColor: UIColor { traits in
            let hex = traits.userInterfaceStyle == .dark ? dark : light
            return UIColor(red: CGFloat((hex >> 16) & 0xFF) / 255, green: CGFloat((hex >> 8) & 0xFF) / 255,
                           blue: CGFloat(hex & 0xFF) / 255, alpha: 1)
        })
    }
}
