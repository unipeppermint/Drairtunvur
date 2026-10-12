import XCTest

final class DrairtunvurReleaseUITests: XCTestCase {
  func testCorruptSaveRecoveryAndHelp() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-ui-testing", "-reset-test-save", "-ui-test-corrupt-save", "-ui-language", "en",
    ]
    app.launch()
    XCTAssertTrue(app.buttons["city.settings"].waitForExistence(timeout: 15))
    app.buttons["city.continue"].tap()
    XCTAssertTrue(app.buttons["settings.recover"].waitForExistence(timeout: 5))
    app.buttons["settings.recover"].tap()
    XCTAssertTrue(app.alerts["Unable to read save"].waitForExistence(timeout: 5))
    app.alerts.buttons.firstMatch.tap()
    let reset = app.buttons["settings.reset"]
    if !reset.isHittable { app.swipeUp() }
    reset.tap()
    app.alerts.buttons["Cancel"].tap()
    XCTAssertTrue(reset.exists)
    reset.tap()
    app.alerts.buttons["Keep copies and reset"].tap()
    XCTAssertTrue(app.alerts["New save created"].waitForExistence(timeout: 5))
    app.alerts.buttons.firstMatch.tap()
    XCTAssertFalse(app.buttons["settings.reset"].exists)
    app.terminate()
    app.launchArguments = ["-ui-testing", "-ui-language", "en"]
    app.launch()
    XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 15))
    app.buttons["cell.3.6"].tap()
    XCTAssertTrue(app.buttons["result.city"].waitForExistence(timeout: 5))
    app.buttons["result.city"].tap()
    app.buttons["city.settings"].tap()
    app.buttons["How to play"].tap()
    XCTAssertTrue(app.staticTexts["Build a path"].waitForExistence(timeout: 5))
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = "Drairtunvur-help"
    attachment.lifetime = .keepAlways
    add(attachment)
  }
}
