import XCTest

extension XCTestCase {
    /// Launches a fresh session with the debug door override, and opens the door so the test
    /// doesn't depend on the simulator's posture (a folded Duo reports the door closed).
    @MainActor
    func launchWithOpenDoor(_ extraArguments: [String] = []) -> XCUIApplication {
        let app = XCUIApplication()
        app.launchArguments = ["-freshSession", "-doorDebug"] + extraArguments
        app.launch()
        XCTAssertTrue(app.buttons["doorDebug.toggle"].waitForExistence(timeout: 10))
        setDoor(app, "open")
        // Wait out the launch splash.
        XCTAssertTrue(app.buttons["prep.bake"].waitForExistence(timeout: 10))
        return app
    }

    /// Sets the door through the collapsible debug readout.
    @MainActor
    func setDoor(_ app: XCUIApplication, _ state: String) {
        app.buttons["doorDebug.toggle"].tap()
        app.buttons["doorDebug.override.\(state)"].tap()
        app.buttons["doorDebug.toggle"].tap()
    }
}
