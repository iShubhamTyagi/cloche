import XCTest

final class LaunchSmokeTests: XCTestCase {
    @MainActor
    func testAppLaunchesToPrep() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshSession"]
        app.launch()

        XCTAssertTrue(app.staticTexts["prep.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["prep.preheat"].exists)
    }

    /// Prep → Preheat → door closes → baking, using the debug door override in place of sensors.
    @MainActor
    func testPreheatThenClosingTheDoorStartsTheBake() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshSession", "-doorDebug"]
        app.launch()

        app.buttons["temperature.high"].tap()
        attachScreenshot(of: app, named: "prep")
        app.buttons["prep.preheat"].tap()
        XCTAssertTrue(app.staticTexts["preheat.title"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "preheat")

        app.buttons["doorDebug.toggle"].tap()
        app.buttons["doorDebug.override.closed"].tap()
        app.buttons["doorDebug.toggle"].tap()
        let timer = app.descendants(matching: .any)["bake.timer"]
        XCTAssertTrue(timer.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "baking")
    }

    @MainActor
    func testBackFromPreheatReturnsToPrep() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshSession"]
        app.launch()

        app.buttons["prep.preheat"].tap()
        XCTAssertTrue(app.buttons["preheat.back"].waitForExistence(timeout: 5))
        app.buttons["preheat.back"].tap()
        XCTAssertTrue(app.buttons["prep.preheat"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        // Let the phase cross-fade finish so colours are captured at full strength.
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
