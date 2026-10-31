import XCTest

/// Raw App Store screenshots from the demo data set. Skipped in normal test runs;
/// run with `TEST_RUNNER_STORE_SHOTS=1 xcodebuild test … -only-testing:MigraineLogUITests/StoreScreenshots`.
/// Shots are kept as named test attachments; appstore_screenshots/export.sh pulls them out.
final class StoreScreenshots: XCTestCase {
    private var app: XCUIApplication!
    private var savedAppearance: XCUIDevice.Appearance?

    override func setUpWithError() throws {
        try XCTSkipUnless(ProcessInfo.processInfo.environment["STORE_SHOTS"] != nil, "set STORE_SHOTS to capture")
        continueAfterFailure = false
        // The store shows the light look whatever the phone is set to.
        // This flips the whole phone, so put the owner's setting back afterwards.
        savedAppearance = XCUIDevice.shared.appearance
        XCUIDevice.shared.appearance = .light
    }

    override func tearDownWithError() throws {
        if let savedAppearance { XCUIDevice.shared.appearance = savedAppearance }
    }

    @MainActor
    private func launch(_ arguments: [String]) {
        app = XCUIApplication()
        // US formats in the store whatever region the test phone is set to ("6.7", "Oct 31").
        app.launchArguments = arguments + ["-AppleLocale", "en_US", "-AppleLanguages", "(en-US)"]
        app.launch()
    }

    @MainActor
    private func shot(_ name: String) {
        sleep(1)  // let animations settle
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }

    @MainActor
    private func tab(_ name: String) {
        app.tabBars.buttons[name].firstMatch.tap()
    }

    @MainActor
    private func waitForFocus(_ field: XCUIElement) {
        let focused = expectation(for: NSPredicate(format: "hasKeyboardFocus == true"), evaluatedWith: field)
        _ = XCTWaiter.wait(for: [focused], timeout: 3)
    }

    @MainActor
    func testProScreens() {
        launch(["-DEMO", "-SNAPSHOT"])
        XCTAssertTrue(app.buttons["Log Headache"].waitForExistence(timeout: 10))
        shot("01_Home")

        app.buttons["Log Headache"].tap()
        XCTAssertTrue(app.buttons["Pain 7"].waitForExistence(timeout: 5))
        app.buttons["Pain 7"].tap()
        app.buttons["Add Sumatriptan 50 mg"].tap()
        shot("02_Log")
        app.buttons["Cancel"].tap()

        tab("Calendar")
        shot("03_Calendar")

        tab("Insights")
        XCTAssertTrue(app.staticTexts["Possible triggers"].waitForExistence(timeout: 5))
        shot("04_Insights")
        app.swipeUp()
        shot("05_InsightsMore")

        tab("Today")
        app.buttons["Doctor Report"].tap()
        app.buttons["Create PDF Report"].tap()
        sleep(2)
        shot("06_Report")
    }

    @MainActor
    func testPaywall() {
        launch(["-DEMO", "-FREE"])
        tab("Insights")
        app.buttons["Unlock Pro"].tap()
        XCTAssertTrue(app.staticTexts["Migraine Log Pro"].waitForExistence(timeout: 5))
        shot("07_Paywall")
    }
}
