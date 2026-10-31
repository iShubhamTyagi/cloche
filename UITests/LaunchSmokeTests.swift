import XCTest

final class LaunchSmokeTests: XCTestCase {
    @MainActor
    func testAppLaunchesToRootScreen() {
        let app = XCUIApplication()
        app.launch()

        XCTAssertTrue(app.staticTexts["root.title"].waitForExistence(timeout: 10))
    }
}
