import XCTest

/// Checks the debug component gallery renders and exposes the spoken labels the handoff asks for.
final class ComponentGalleryTests: XCTestCase {
    @MainActor
    func testStarsAndRingClocksHaveSpokenLabels() {
        let app = XCUIApplication()
        app.launchArguments = ["-componentGallery"]
        app.launch()

        let gallery = app.scrollViews.firstMatch
        XCTAssertTrue(gallery.waitForExistence(timeout: 10))
        gallery.swipeUp()
        gallery.swipeUp()

        XCTAssertTrue(app.images["2 of 2 stars"].exists || app.otherElements["2 of 2 stars"].exists)
        XCTAssertTrue(app.images["4:12 left in the break"].exists)
        XCTAssertTrue(app.images["11 seconds left"].exists)

        let shot = XCTAttachment(screenshot: app.screenshot())
        shot.name = "gallery-bottom"
        shot.lifetime = .keepAlways
        add(shot)
    }
}
