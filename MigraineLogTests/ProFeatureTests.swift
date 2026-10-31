import Testing
import Foundation
@testable import MigraineLog

struct ProFeatureTests {
    @Test(arguments: [ProFeature.pdfReport, .fullStats])
    func lockedOnlyWithoutPro(feature: ProFeature) {
        #expect(ProFeature.isLocked(feature, isPro: false))
        #expect(!ProFeature.isLocked(feature, isPro: true))
    }
}

@MainActor
@Suite(.serialized)
struct AnalyticsTests {
    @Test func sendsOnlyWhileEnabled() {
        var sent: [String] = []
        let saved = Analytics.sink
        Analytics.sink = { name, _ in sent.append(name) }
        defer { Analytics.sink = saved; Analytics.setEnabled(true) }
        Analytics.setEnabled(true)
        Analytics.track(.attackAdded)
        Analytics.setEnabled(false)
        Analytics.track(.reportCreated)
        #expect(sent == ["attack.added"])
    }
}
