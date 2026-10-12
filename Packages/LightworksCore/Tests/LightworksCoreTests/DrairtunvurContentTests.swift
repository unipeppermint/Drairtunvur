import XCTest
@testable import LightworksCore

final class DrairtunvurContentTests: XCTestCase {
  var root: URL {
    URL(fileURLWithPath: #filePath).deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
  }
  func read(_ path: String) throws -> [LevelDefinition] {
    try LevelCatalog.decode(Data(contentsOf: root.appendingPathComponent(path)))
  }
  func signature(_ level: LevelDefinition) -> String {
    let cells = level.initialOccupiedCells.sorted { ($0.row,$0.col) < ($1.row,$1.col) }
    return "\(cells)|\(level.sourceEntry)|\(level.targets)"
  }
  func testDedicatedDailyYearIsDistinctAndEveryPuzzleWins() throws {
    let pool = try read("Drairtunvur/Resources/Drairtunvur-daily-levels.json")
    let city = try read("Drairtunvur/Resources/levels.json")
    XCTAssertEqual(pool.count,365)
    XCTAssertEqual(Set(pool.map(signature)).count,365)
    XCTAssertTrue(Set(pool.map(signature)).isDisjoint(with: Set(city.map(signature))))
    var seen = Set<String>()
    for offset in 0..<365 {
      let day = try XCTUnwrap(DailyChallenge.offset("2026-10-12", days: offset))
      let level = try XCTUnwrap(DailyChallenge.level(for: day, levels: pool))
      seen.insert(signature(level))
      var game = GameSession(level: level)
      for move in level.referenceSolution {
        let before = game
        try game.place(move, level: level)
        let after = game
        if game.state.outcome != .won {
          XCTAssertTrue(game.undo())
          XCTAssertEqual(game,before)
          try game.place(move, level: level)
          XCTAssertEqual(game,after)
        }
      }
      XCTAssertEqual(game.state.outcome,.won,day)
    }
    XCTAssertEqual(seen.count,365)
    let next = try XCTUnwrap(DailyChallenge.offset("2026-10-12", days:365))
    XCTAssertEqual(signature(DailyChallenge.level(for:"2026-10-12",levels:pool)!),signature(DailyChallenge.level(for:next,levels:pool)!))
  }
  func testCampaignHasCrossingsMultipleRoutesAndMixedChargeTargets() throws {
    let levels = try read("Drairtunvur/Resources/levels.json")
    var crossing=0, multiRoute=0, mixed=0
    for level in levels {
      var state=GameState(level:level), routes=Set<String>(), hasCross=false
      for move in level.referenceSolution {
        let result=try Rules.apply(move,to:state,level:level)
        result.rows.forEach { routes.insert("r\($0)") }
        result.columns.forEach { routes.insert("c\($0)") }
        hasCross = hasCross || result.rows.count+result.columns.count>1
        state=result.state
      }
      if routes.count>1 { multiRoute+=1 }
      if hasCross { crossing+=1 }
      if Set(level.targets.map(\.capacity)).count>1 { mixed+=1 }
    }
    XCTAssertGreaterThanOrEqual(multiRoute,35)
    XCTAssertGreaterThanOrEqual(crossing,10)
    XCTAssertGreaterThanOrEqual(mixed,5)
  }
  func testContentUpgradePreservesWinsAndInFlightLegacyDaily() async throws {
    let old = try read("verification/Drairtunvur-levels-v1.json")
    let current = try read("Drairtunvur/Resources/levels.json")
    let directory=FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at:directory) }
    var save=SaveEnvelope(); save.revision=1
    save.recordWin(level:old[5],moves:old[5].referenceSolution.count)
    save.active=GameSession(level:old[6])
    var daily=DailyProgress()
    let level=DailyChallenge.level(for:"2026-10-12",levels:old)!
    var session=daily.start(day:"2026-10-12",level:level)
    try session.place(level.referenceSolution[0],level:level)
    daily.commit(day:"2026-10-12",level:level,session:session)
    save.daily=daily
    let repo=SaveRepository(directory:directory)
    try await repo.write(save)
    let loaded=try await SaveRepository(directory:directory).load(levels:current)
    XCTAssertTrue(loaded.resetActive)
    XCTAssertNil(loaded.save.active)
    XCTAssertEqual(loaded.save.bestMoves,save.bestMoves)
    XCTAssertEqual(loaded.save.daily,save.daily)
    var replayed = loaded.save
    replayed.recordWin(level:current[5],moves:current[5].moveLimit)
    XCTAssertEqual(replayed.bestMoves[current[5].id],current[5].moveLimit)
    replayed.recordWin(level:current[5],moves:current[5].referenceSolution.count)
    XCTAssertEqual(replayed.bestMoves[current[5].id],current[5].referenceSolution.count)
  }
}
