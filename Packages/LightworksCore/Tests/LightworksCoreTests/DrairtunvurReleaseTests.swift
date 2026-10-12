import XCTest

@testable import LightworksCore

final class DrairtunvurReleaseTests: XCTestCase {
  private func catalog() throws -> [LevelDefinition] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    return try LevelCatalog.decode(
      Data(contentsOf: root.appendingPathComponent("Drairtunvur/Resources/levels.json")))
  }
  func testUpdatedLimitsAndRemovedLevelsPreserveHistoricalWins() async throws {
    var levels = try catalog()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    var save = SaveEnvelope()
    save.revision = 3
    save.bestMoves[levels[9].id] = levels[9].moveLimit
    save.bestMoves["retired-level"] = 20
    save.active = GameSession(level: levels[9])
    try await SaveRepository(directory: directory).write(save)
    levels[9].contentVersion += 1
    levels[9].moveLimit -= 1
    let report = try await SaveRepository(directory: directory).load(levels: levels)
    XCTAssertEqual(report.save.bestMoves, save.bestMoves)
    XCTAssertTrue(report.resetActive)
    XCTAssertNil(report.save.active)
    levels.remove(at: 9)
    let removed = try await SaveRepository(directory: directory).load(levels: levels)
    XCTAssertEqual(removed.save.bestMoves, save.bestMoves)
    XCTAssertTrue(removed.resetActive)
  }
  func testNewerSaveCannotBeReplacedByOlderBackup() async throws {
    let levels = try catalog()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    let repo = SaveRepository(directory: directory)
    var old = SaveEnvelope()
    old.revision = 1
    try await repo.write(old)
    var current = old
    current.revision = 2
    try await repo.write(current)
    // Future formats may rename all other fields, so read the version first.
    let future = Data(#"{"schemaVersion":2,"futureProgress":{"wins":45}}"#.utf8)
    let primary = directory.appendingPathComponent("save-v1.json")
    try future.write(to: primary)
    let reader = SaveRepository(directory: directory)
    do {
      _ = try await reader.load(levels: levels)
      XCTFail("Must not downgrade")
    } catch SaveError.unsupportedVersion {} catch { XCTFail("Unexpected: \(error)") }
    do {
      _ = try await reader.write(old)
      XCTFail("Writes must stay blocked")
    } catch {}
    XCTAssertEqual(try Data(contentsOf: primary), future)
  }
  func testExplicitRecoveryArchivesBothOriginalFilesAndAllowsSaving() async throws {
    let levels = try catalog()
    let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: directory) }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let primary = Data("damaged-primary".utf8)
    let backup = Data("damaged-backup".utf8)
    try primary.write(to: directory.appendingPathComponent("save-v1.json"))
    try backup.write(to: directory.appendingPathComponent("save-v1.backup.json"))
    let repo = SaveRepository(directory: directory)
    do {
      _ = try await repo.load(levels: levels)
      XCTFail()
    } catch {}
    var fresh = try await repo.archiveAndReset()
    let archive = try XCTUnwrap(
      FileManager.default.contentsOfDirectory(at: directory, includingPropertiesForKeys: nil).first
      { $0.lastPathComponent.hasPrefix("recovery-") })
    XCTAssertEqual(try Data(contentsOf: archive.appendingPathComponent("save-v1.json")), primary)
    XCTAssertEqual(
      try Data(contentsOf: archive.appendingPathComponent("save-v1.backup.json")), backup)
    fresh.revision += 1
    fresh.recordWin(level: levels[0], moves: 1)
    try await repo.write(fresh)
    let restored = try await SaveRepository(directory: directory).load(levels: levels)
    XCTAssertEqual(restored.save, fresh)
  }
  func testHintsHandleReorderedValidMovesAndRespectCancellation() throws {
    let levels = try catalog()
    for id in ["1-10", "2-08", "3-10"] {
      let level = try XCTUnwrap(levels.first { $0.id == id })
      let initial = GameState(level: level)
      let alternate = try Rules.apply(level.referenceSolution[1], to: initial, level: level).state
      guard case .solved(let moves) = HintSolver.solve(state: alternate, level: level) else {
        XCTFail("No hint after reordering independent placements: \(id)")
        continue
      }
      var replay = alternate
      for move in moves { replay = try Rules.apply(move, to: replay, level: level).state }
      XCTAssertEqual(replay.outcome, .won)
      XCTAssertEqual(
        HintSolver.solve(state: initial, level: level, cancelled: { true }), .cancelled)
    }
  }
}
