import XCTest

final class LaunchSmokeTests: XCTestCase {
    @MainActor
    func testAppLaunchesToPrep() {
        let app = XCUIApplication()
        app.launchArguments = ["-freshSession"]
        app.launch()

        XCTAssertTrue(app.staticTexts["prep.title"].waitForExistence(timeout: 10))
        XCTAssertTrue(app.buttons["prep.bake"].exists)
    }

    /// Prep → Bake → door closes → baking.
    @MainActor
    func testBakeThenClosingTheDoorStartsTheBake() {
        let app = launchWithOpenDoor()

        XCTAssertEqual(app.buttons["prep.bake"].label, "Bake, 25 minutes")
        app.buttons["length.medium"].tap()
        XCTAssertEqual(app.buttons["prep.bake"].label, "Bake, 50 minutes")
        attachScreenshot(of: app, named: "prep")
        app.buttons["prep.bake"].tap()
        XCTAssertTrue(app.staticTexts["preheat.title"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "preheat")

        setDoor(app, "closed")
        XCTAssertTrue(app.descendants(matching: .any)["bake.timer"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "baking")
    }

    /// Opening the door mid-bake shows the 15 s grace; closing it in time resumes the bake.
    @MainActor
    func testOpeningMidBakeShowsTheGraceAndClosingResumes() {
        let app = startBake()

        setDoor(app, "open")
        XCTAssertTrue(app.staticTexts["ajar.title"].waitForExistence(timeout: 5))
        XCTAssertTrue(app.descendants(matching: .any)["ajar.ring"].exists)
        attachScreenshot(of: app, named: "ajar")

        setDoor(app, "closed")
        XCTAssertTrue(app.descendants(matching: .any)["bake.timer"].waitForExistence(timeout: 5))
    }

    /// Leaving the door open past the grace ends the bake half-baked.
    @MainActor
    func testLeavingTheDoorOpenEndsTheBakeHalfBaked() {
        let app = startBake()

        setDoor(app, "open")
        XCTAssertTrue(app.staticTexts["ajar.title"].waitForExistence(timeout: 5))

        // After the 15 s grace: the half-baked grade, one star at most, and nothing lost.
        let eyebrow = app.descendants(matching: .any)["grade.eyebrow"]
        XCTAssertTrue(eyebrow.waitForExistence(timeout: 20))
        XCTAssertEqual(eyebrow.label.lowercased(), "opened early")
        XCTAssertEqual(app.descendants(matching: .any)["grade.stars"].label, "1 of 2 stars")
        attachScreenshot(of: app, named: "half-baked")

        app.buttons["grade.servePlain"].tap()
        XCTAssertTrue(app.staticTexts["interim.phase"].waitForExistence(timeout: 5))
    }

    @MainActor
    func testBackFromPreheatReturnsToPrep() {
        let app = launchWithOpenDoor()

        app.buttons["prep.bake"].tap()
        XCTAssertTrue(app.buttons["preheat.back"].waitForExistence(timeout: 5))
        app.buttons["preheat.back"].tap()
        XCTAssertTrue(app.buttons["prep.bake"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func startBake() -> XCUIApplication {
        let app = launchWithOpenDoor()
        app.buttons["prep.bake"].tap()
        XCTAssertTrue(app.staticTexts["preheat.title"].waitForExistence(timeout: 5))
        setDoor(app, "closed")
        XCTAssertTrue(app.descendants(matching: .any)["bake.timer"].waitForExistence(timeout: 5))
        return app
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
