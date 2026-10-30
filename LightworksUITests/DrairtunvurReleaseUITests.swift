import XCTest

final class DrairtunvurReleaseUITests: XCTestCase {
  func testCompletedCityAndEveryRestoredKeepsake() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-ui-testing", "-reset-test-save", "-ui-test-completed", "-AppleLanguages", "(en)",
    ]
    app.launch()
    XCTAssertTrue(app.buttons["city.continue"].waitForExistence(timeout: 15))
    XCTAssertTrue(app.buttons["city.continue"].label.contains("Revisit the paths"))
    app.buttons["tab.collection"].tap()
    XCTAssertTrue(app.staticTexts["9 / 9 collected"].waitForExistence(timeout: 5))
    for milestone in [5, 10, 15] {
      for chapter in 1...3 {
        let card = app.buttons["collection.\(chapter).\(milestone)"]
        for _ in 0..<6 {
          let tabTop = app.buttons["tab.collection"].frame.minY
          if card.isHittable && card.frame.maxY < tabTop { break }
          app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.75))
            .press(
              forDuration: 0.05,
              thenDragTo: app.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.45)))
        }
        XCTAssertTrue(card.isHittable)
        card.tap()
        let restoration = app.segmentedControls["collection.restoration"]
        XCTAssertTrue(restoration.waitForExistence(timeout: 5))
        restoration.buttons["Before"].tap()
        XCTAssertTrue(restoration.buttons["Before"].isSelected)
        restoration.buttons["Restored"].tap()
        XCTAssertTrue(restoration.buttons["Restored"].isSelected)
        let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
        attachment.name = "Drairtunvur-keepsake-\(chapter)-\(milestone)"
        attachment.lifetime = .keepAlways
        add(attachment)
        app.buttons["Back"].tap()
      }
    }
  }
  func testCorruptSaveRecoveryAndHelp() {
    let app = XCUIApplication()
    app.launchArguments = [
      "-ui-testing", "-reset-test-save", "-ui-test-corrupt-save", "-AppleLanguages", "(en)",
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
    app.launchArguments = ["-ui-testing", "-AppleLanguages", "(en)"]
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
