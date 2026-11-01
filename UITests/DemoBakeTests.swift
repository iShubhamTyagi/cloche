import XCTest

/// The whole Gate 0 loop through the 15 s demo bake, as App Review would try it.
final class DemoBakeTests: XCTestCase {
    @MainActor
    func testDemoBakeRunsTheWholeLoopAndEarnsNoStars() {
        let app = launchWithOpenDoor()

        app.buttons["prep.settings"].tap()
        XCTAssertTrue(app.buttons["settings.demoBake"].waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "settings")
        app.buttons["settings.demoBake"].tap()

        XCTAssertTrue(app.staticTexts["preheat.title"].waitForExistence(timeout: 5))
        setDoor(app, "closed")
        XCTAssertTrue(app.descendants(matching: .any)["bake.timer"].waitForExistence(timeout: 5))

        // The demo lasts 15 s; the face-down screen then shows "Prêt.".
        XCTAssertTrue(app.descendants(matching: .any)["bake.ready"].waitForExistence(timeout: 25))

        setDoor(app, "open")
        let revealTitle = app.staticTexts["reveal.title"]
        XCTAssertTrue(revealTitle.waitForExistence(timeout: 5))
        attachScreenshot(of: app, named: "reveal")

        if app.buttons["reveal.continue"].exists {
            app.buttons["reveal.continue"].tap()
        }
        let stars = app.descendants(matching: .any)["grade.stars"]
        XCTAssertTrue(stars.waitForExistence(timeout: 5))
        XCTAssertEqual(stars.label, "0 of 2 stars")

        app.buttons["grade.servePlain"].tap()
        XCTAssertTrue(app.staticTexts["interim.phase"].waitForExistence(timeout: 5))
    }

    /// The first Bake tap explains the notification; "Not now" still goes on.
    @MainActor
    func testNotificationPrePromptNotNowStillGoesOn() {
        let app = launchWithOpenDoor(["-notificationPrompt"])

        app.buttons["prep.bake"].tap()
        let notNow = app.buttons["notifications.notNow"]
        guard notNow.waitForExistence(timeout: 5) else {
            // The simulator already answered the system prompt in an earlier run, so there is
            // nothing left to ask; Bake must still have gone through.
            XCTAssertTrue(app.staticTexts["preheat.title"].waitForExistence(timeout: 5))
            return
        }
        attachScreenshot(of: app, named: "notification-preprompt")
        notNow.tap()
        XCTAssertTrue(app.staticTexts["preheat.title"].waitForExistence(timeout: 5))
    }

    @MainActor
    private func attachScreenshot(of app: XCUIApplication, named name: String) {
        Thread.sleep(forTimeInterval: 0.6)
        let attachment = XCTAttachment(screenshot: app.screenshot())
        attachment.name = name
        attachment.lifetime = .keepAlways
        add(attachment)
    }
}
