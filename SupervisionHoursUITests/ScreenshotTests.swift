import XCTest

/// Captures App Store screenshots. Run with scripts/screenshots.sh SupervisionHours.
final class ScreenshotTests: XCTestCase {
    override func setUpWithError() throws { continueAfterFailure = false }

    func testAppScreens() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-skipOnboarding", "-uiTesting"]
        app.launch()

        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log Direct client contact"].waitForExistence(timeout: 10))
        snap("01-progress", app)

        app.buttons["Log Direct client contact"].tap()
        XCTAssertTrue(app.navigationBars["Log Hours"].waitForExistence(timeout: 5))
        snap("02-log-hours", app)
        app.buttons["Cancel"].tap()

        app.tabBars.buttons["Log"].tap()
        XCTAssertTrue(app.navigationBars["Log"].waitForExistence(timeout: 5))
        snap("03-log", app)

        app.tabBars.buttons["Report"].tap()
        XCTAssertTrue(app.navigationBars["Report"].waitForExistence(timeout: 5))
        snap("04-report", app)

        app.tabBars.buttons["Progress"].tap()
        app.buttons["Settings"].tap()
        XCTAssertTrue(app.navigationBars["Settings"].waitForExistence(timeout: 5))
        app.buttons["Supervisors"].firstMatch.tap()
        XCTAssertTrue(app.navigationBars["Supervisors"].waitForExistence(timeout: 5))
        snap("05-supervisors", app)
        app.navigationBars.buttons.element(boundBy: 0).tap()
        app.buttons["Done"].tap()

        app.buttons["How do I use this app"].tap()
        XCTAssertTrue(app.navigationBars.element.waitForExistence(timeout: 5))
        snap("06-how-to", app)
    }

    func testFieldworkScreen() {
        let app = XCUIApplication()
        app.launchArguments = ["-unlock", "-resetData", "-sampleData", "-fieldworkSample", "-skipOnboarding", "-uiTesting"]
        app.launch()
        XCTAssertTrue(app.navigationBars["Progress"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["Log Restricted activities"].waitForExistence(timeout: 10))
        snap("07-bcba", app)
    }

    func testPaywall() {
        let app = XCUIApplication()
        app.launchArguments = ["-skipOnboarding", "-uiTesting", "-mockPrices"]
        app.launch()
        XCTAssertTrue(app.staticTexts["Lifetime"].waitForExistence(timeout: 10))
        snap("paywall", app)
    }

    private func snap(_ name: String, _ app: XCUIApplication) {
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
