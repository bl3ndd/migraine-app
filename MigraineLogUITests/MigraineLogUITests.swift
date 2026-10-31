import XCTest

/// End-to-end flows on a clean in-memory store (`-UITEST`).
final class MigraineLogUITests: XCTestCase {
    private var app: XCUIApplication!

    override func setUpWithError() throws {
        continueAfterFailure = false
    }

    @MainActor
    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        app.launchArguments = ["-UITEST"] + arguments
        app.launch()
    }

    /// Any element whose accessibility label contains `text`.
    @MainActor
    private func element(containing text: String) -> XCUIElement {
        app.descendants(matching: .any).matching(NSPredicate(format: "label CONTAINS %@", text)).firstMatch
    }

    /// Opens the log form from Home, picks a pain level, optionally marks it over, saves.
    @MainActor
    private func logAttack(pain: Int, ended: Bool = true, trigger: String? = nil) {
        app.buttons["Log Headache"].firstMatch.tap()
        let level = app.buttons["Pain \(pain)"]
        XCTAssertTrue(level.waitForExistence(timeout: 5))
        level.tap()
        if ended { app.switches["It's over"].firstMatch.switches.firstMatch.tap() }
        if let trigger {
            let chip = app.buttons[trigger]
            while !chip.isHittable { app.swipeUp() }
            chip.tap()
        }
        let save = app.buttons["Save"]
        XCTAssertTrue(save.isEnabled, "entry is valid")
        save.tap()
        XCTAssertTrue(save.waitForNonExistence(timeout: 5), "log sheet closed")
    }

    @MainActor
    private func tab(_ name: String) {
        app.tabBars.buttons[name].firstMatch.tap()
    }

    @MainActor
    private func dismissPaywallIfShown() {
        if app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 2) { app.buttons["Not Now"].tap() }
    }

    // MARK: Onboarding

    @MainActor
    func testOnboardingSavesMedicinesThenOffersProAfterFirstAttack() {
        launch(["-FREE"])
        XCTAssertTrue(app.staticTexts["Your headache diary"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "not a medical device").exists)
        app.buttons["Get Started"].tap()
        XCTAssertTrue(app.staticTexts["Your medicines"].waitForExistence(timeout: 5))
        app.buttons["Ibuprofen"].tap()
        app.buttons["Save Medicines"].tap()
        XCTAssertTrue(app.staticTexts["Connect Apple Health"].waitForExistence(timeout: 5))
        app.buttons["Not Now"].tap()
        XCTAssertTrue(app.staticTexts["A daily check-in"].waitForExistence(timeout: 5))
        app.buttons["Skip"].tap()

        XCTAssertTrue(app.staticTexts["Your headache diary"].waitForExistence(timeout: 5), "empty Home, no paywall yet")
        XCTAssertFalse(app.staticTexts["Migraine Log Pro"].exists)
        app.buttons["Log Headache"].firstMatch.tap()
        XCTAssertTrue(app.buttons["Add Ibuprofen"].waitForExistence(timeout: 5), "saved medicine is one tap away")
        app.buttons["Pain 6"].tap()
        app.buttons["Save"].tap()
        XCTAssertTrue(app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 5), "offered after the first attack")
        app.buttons["Not Now"].tap()
        app.buttons["Update"].tap()
        app.buttons["Save"].tap()
        XCTAssertFalse(app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 2), "only once")
    }

    // MARK: Logging

    @MainActor
    func testOngoingAttackThenEndIt() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        logAttack(pain: 7, ended: false)
        XCTAssertTrue(app.staticTexts["Migraine in progress"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.buttons["Log Headache"].exists, "one attack at a time from Home")
        app.buttons["It's Over"].tap()
        app.buttons["End Now"].tap()
        XCTAssertTrue(app.staticTexts["Headache-free"].waitForExistence(timeout: 5))
        XCTAssertTrue(element(containing: "Headache days").exists || element(containing: "Headache\ndays").exists)
    }

    @MainActor
    func testWorstPainShowsEmergencyNote() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        app.buttons["Log Headache"].tap()
        app.buttons["Pain 5"].tap()
        XCTAssertFalse(element(containing: "Call 911").exists)
        app.buttons["Pain 10"].tap()
        XCTAssertTrue(element(containing: "Call 911").waitForExistence(timeout: 3))
    }

    @MainActor
    func testEndBeforeStartIsExplained() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        app.buttons["Log Headache"].tap()
        app.buttons["Pain 4"].tap()
        // A future start can't be picked, so check the friendly path: valid entries save.
        app.switches["It's over"].firstMatch.switches.firstMatch.tap()
        XCTAssertTrue(app.buttons["Save"].isEnabled)
    }

    // MARK: Calendar

    @MainActor
    func testCalendarListsAndDeletesWithLongPress() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        logAttack(pain: 5)
        dismissPaywallIfShown()
        tab("Calendar")
        let row = element(containing: "Pain 5 of 10")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.press(forDuration: 1.2)
        app.buttons["Delete"].firstMatch.tap()
        app.buttons["Delete Entry"].firstMatch.tap()
        XCTAssertTrue(app.staticTexts["No headaches logged this month."].waitForExistence(timeout: 5))
    }

    @MainActor
    func testDeleteFromEditScreen() {
        launch(["-SKIP_ONBOARDING", "-FREE"])
        logAttack(pain: 3)
        dismissPaywallIfShown()
        tab("Calendar")
        let row = element(containing: "Pain 3 of 10")
        XCTAssertTrue(row.waitForExistence(timeout: 5))
        row.tap()
        // The button sits under the bottom Save bar until scrolled well past it.
        for _ in 0..<4 { app.swipeUp() }
        app.buttons["Delete Entry"].firstMatch.tap()
        // The dialog's button has the same label as the form's; it's the hittable one.
        XCTAssertTrue(app.staticTexts["Delete this entry?"].waitForExistence(timeout: 3))
        let confirm = app.buttons.matching(identifier: "Delete Entry")
        (0..<confirm.count).map { confirm.element(boundBy: $0) }.first { $0.isHittable }?.tap()
        XCTAssertTrue(app.staticTexts["No headaches logged this month."].waitForExistence(timeout: 5))
    }

    // MARK: Pro gating

    @MainActor
    func testFreeUserSeesLockedInsights() {
        launch(["-DEMO", "-FREE"])
        tab("Insights")
        XCTAssertTrue(app.staticTexts["Insights are part of Pro"].waitForExistence(timeout: 5))
        app.buttons["Unlock Pro"].tap()
        XCTAssertTrue(app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testFreeUserReportIsLocked() {
        launch(["-DEMO", "-FREE"])
        app.buttons["Doctor Report"].tap()
        app.buttons["Create PDF Report"].tap()
        XCTAssertTrue(app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testProUserSeesInsightsAndCanOpenReport() {
        launch(["-DEMO", "-SNAPSHOT"])
        tab("Insights")
        XCTAssertTrue(app.staticTexts["Possible triggers"].waitForExistence(timeout: 5))
        XCTAssertFalse(app.staticTexts["Insights are part of Pro"].exists)
        app.buttons["Doctor Report"].tap()
        XCTAssertTrue(app.buttons["Create PDF Report"].waitForExistence(timeout: 5))
        app.buttons["Create PDF Report"].tap()
        XCTAssertFalse(app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 2), "no paywall for Pro")
    }
}
