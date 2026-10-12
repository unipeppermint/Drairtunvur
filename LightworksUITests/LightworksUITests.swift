import XCTest

final class LightworksUITests: XCTestCase {
  func launch(level: String? = nil, language: String = "zh-Hans", reset: Bool = true)
    -> XCUIApplication
  {
    let app = XCUIApplication()
    app.launchArguments = ["-ui-testing", "-ui-language", language]
    if reset { app.launchArguments.append("-reset-test-save") }
    if let level { app.launchArguments += ["-ui-test-level", level] }
    app.launch()
    XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 15))
    return app
  }
  func screenshot(_ name: String) {
    let attachment = XCTAttachment(screenshot: XCUIScreen.main.screenshot())
    attachment.name = name
    attachment.lifetime = .keepAlways
    add(attachment)
  }
  func waitForPiece(_ piece: XCUIElement) {
    let ready = NSPredicate(format: "exists == true AND enabled == true")
    XCTAssertEqual(XCTWaiter.wait(for: [XCTNSPredicateExpectation(predicate: ready, object: piece)], timeout: 4), .completed)
  }
  func testTutorialWinReplayAndMap() {
    let app = launch()
    screenshot("01-tutorial")
    app.buttons["piece.0"].tap()
    app.buttons["cell.3.6"].tap()
    XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5))
    screenshot("02-victory")
    app.buttons["result.replay"].tap()
    XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 4))
    app.buttons["cell.3.6"].tap()
    XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5))
    app.buttons["result.city"].tap()
    XCTAssertTrue(app.buttons["city.continue"].waitForExistence(timeout: 4))
    screenshot("03-city")
    XCTAssertTrue(app.staticTexts["已点亮 1 / 15"].exists)
    app.descendants(matching: .any)["tab.collection"].firstMatch.tap()
    screenshot("04-collection")
    app.buttons["collection.1.5"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 3))
  }
  func testFailureUndoAndBackgroundResume() {
    let app = launch()
    app.buttons["cell.0.0"].tap()
    XCTAssertTrue(app.alerts.firstMatch.waitForExistence(timeout: 5))
    screenshot("05-failure")
    app.alerts.buttons["撤销一步"].tap()
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "1")
    app.buttons["game.hint"].tap()
    XCTAssertTrue(app.staticTexts["game.status"].waitForExistence(timeout: 3))
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.buttons["cell.3.6"].waitForExistence(timeout: 4))
    app.buttons["cell.3.6"].tap()
    XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5))
  }
  func testEnglishHintAndSettings() {
    let app = launch(level: "1-10", language: "en")
    app.buttons["game.hint"].tap()
    let hint = app.staticTexts["game.status"]
    XCTAssertTrue(hint.waitForExistence(timeout: 4))
    let predicate = NSPredicate(format: "label BEGINSWITH %@", "Verified hint")
    expectation(for: predicate, evaluatedWith: hint)
    waitForExpectations(timeout: 5)
    screenshot("06-english-hint")
    app.buttons["game.pause"].tap()
    app.alerts.buttons["Back to city"].tap()
    app.buttons["city.settings"].tap()
    screenshot("07-settings")
    XCTAssertTrue(app.segmentedControls["settings.language"].exists)
  }
  func testColdLaunchRestoresStateAndUndo() {
    let app = launch()
    app.buttons["cell.3.6"].tap()
    XCTAssertTrue(app.buttons["result.continue"].waitForExistence(timeout: 5))
    app.buttons["result.continue"].tap()
    XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 4))
    app.buttons["piece.0"].tap()
    app.buttons["cell.0.0"].tap()
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "3")
    app.terminate()
    app.launchArguments = ["-ui-testing", "-ui-language", "zh-Hans"]
    app.launch()
    XCTAssertTrue(app.buttons["city.continue"].waitForExistence(timeout: 10))
    app.buttons["city.continue"].tap()
    XCTAssertTrue(app.buttons["game.undo"].waitForExistence(timeout: 5))
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "3")
    app.buttons["game.undo"].tap()
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "4")
    app.buttons["piece.0"].tap()
    app.buttons["cell.4.0"].tap()
    XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5))
  }
  func testDragDropAndInterruptedPulse() {
    let app = launch()
    let piece = app.buttons["piece.0"]
    let target = app.buttons["cell.3.6"]
    let start = piece.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5))
    let end = target.coordinate(withNormalizedOffset: CGVector(dx: 0.5, dy: 0.5)).withOffset(
      CGVector(dx: target.frame.width / 2 + 2, dy: 48))
    start.press(forDuration: 0.1, thenDragTo: end)
    XCUIDevice.shared.press(.home)
    app.activate()
    XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 6))
  }

  func testFirstTenLevelsAndEarnedCollection() throws {
    struct Anchor: Decodable {
      var row: Int
      var col: Int
    }
    struct Move: Decodable {
      var slot: Int
      var anchor: Anchor
    }
    struct Solution: Decodable {
      var id: String
      var moves: [Move]
    }
    let url = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "ReferenceSolutions", withExtension: "json"))
    let solutions = try JSONDecoder().decode([Solution].self, from: Data(contentsOf: url))
    let app = launch()
    for (index, solution) in solutions.enumerated() {
      for move in solution.moves {
        let piece = app.buttons["piece.\(move.slot)"]
        XCTAssertTrue(piece.waitForExistence(timeout: 4))
        waitForPiece(piece)
        piece.tap()
        app.buttons["cell.\(move.anchor.row).\(move.anchor.col)"].tap()
      }
      XCTAssertTrue(app.staticTexts["result.title"].waitForExistence(timeout: 5), solution.id)
      if index < solutions.count - 1 { app.buttons["result.continue"].tap() }
    }
    app.buttons["result.city"].tap()
    app.descendants(matching: .any)["tab.collection"].firstMatch.tap()
    let earned = app.buttons["collection.1.5"]
    XCTAssertTrue(earned.waitForExistence(timeout: 4))
    earned.tap()
    XCTAssertTrue(app.staticTexts["归航的灯"].waitForExistence(timeout: 3))
    screenshot("08-earned-collection")
  }
  func testDailyChallengeResumeCompletionAndCampaignIsolation() throws {
    struct Cell: Decodable {
      var row: Int
      var col: Int
    }
    struct Move: Decodable {
      var slot: Int
      var anchor: Cell
    }
    struct Fixture: Decodable {
      var day: String
      var moveLimit: Int
      var moves: [Move]
    }
    let url = try XCTUnwrap(
      Bundle(for: Self.self).url(forResource: "DailyReferenceSolution", withExtension: "json"))
    let fixture = try JSONDecoder().decode(Fixture.self, from: Data(contentsOf: url))
    let app = XCUIApplication()
    app.launchArguments = [
      "-ui-testing", "-reset-test-save", "-ui-language", "zh-Hans", "-ui-test-date", fixture.day,
    ]
    app.launch()
    XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 15))
    app.buttons["cell.3.6"].tap()
    XCTAssertTrue(app.buttons["result.continue"].waitForExistence(timeout: 5))
    app.buttons["result.continue"].tap()
    app.buttons["piece.0"].tap()
    app.buttons["cell.0.0"].tap()
    app.buttons["game.pause"].tap()
    app.alerts.buttons["回到城市"].tap()
    app.buttons["tab.daily"].tap()
    XCTAssertTrue(app.staticTexts["daily.title"].waitForExistence(timeout: 4))
    XCTAssertEqual(app.staticTexts["daily.date"].label, fixture.day)
    screenshot("10-daily")
    app.buttons["daily.play"].tap()
    let first = fixture.moves[0]
    app.buttons["piece.\(first.slot)"].tap()
    app.buttons["cell.\(first.anchor.row).\(first.anchor.col)"].tap()
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "\(fixture.moveLimit - 1)")
    app.buttons["game.pause"].tap()
    app.alerts.buttons["回到每日"].tap()
    app.terminate()
    app.launchArguments.removeAll { $0 == "-reset-test-save" }
    app.launch()
    XCTAssertTrue(app.buttons["tab.daily"].waitForExistence(timeout: 10))
    app.buttons["tab.daily"].tap()
    app.buttons["daily.play"].tap()
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "\(fixture.moveLimit - 1)")
    for move in fixture.moves.dropFirst() {
      waitForPiece(app.buttons["piece.\(move.slot)"])
      app.buttons["piece.\(move.slot)"].tap()
      app.buttons["cell.\(move.anchor.row).\(move.anchor.col)"].tap()
    }
    XCTAssertTrue(app.staticTexts["daily.result.title"].waitForExistence(timeout: 5))
    screenshot("11-daily-completed")
    app.buttons["daily.result.back"].tap()
    XCTAssertEqual(app.staticTexts["daily.state"].label, "今日已完成 ✓")
    screenshot("12-daily-record")
    app.buttons["tab.city"].tap()
    XCTAssertTrue(app.staticTexts["已点亮 1 / 15"].exists)
    app.buttons["city.continue"].tap()
    XCTAssertEqual(app.staticTexts["game.remaining"].label, "3")
  }
  func testLandscapeLayout() {
    let app = launch(language: "en")
    XCUIDevice.shared.orientation = .landscapeLeft
    XCTAssertTrue(app.buttons["game.pause"].waitForExistence(timeout: 4))
    XCTAssertTrue(app.buttons["piece.0"].isHittable)
    XCTAssertTrue(app.buttons["cell.7.7"].isHittable)
    screenshot("09-landscape")
    XCUIDevice.shared.orientation = .portrait
  }

}
