import XCTest

@testable import LightworksCore

final class CoreTests: XCTestCase {
  let dot = Piece(id: "dot", cells: [Cell(0, 0)])
  func level(
    board: [Cell] = [], source: Cell = Cell(3, 0),
    targets: [Target] = [Target(id: "A", cell: Cell(3, 3), capacity: 1)], limit: Int = 10
  ) -> LevelDefinition {
    LevelDefinition(
      id: "test", initialOccupiedCells: board, sourceEntry: source, targets: targets,
      pieceBatches: Array(repeating: [dot, dot, dot], count: 4), moveLimit: limit)
  }
  func catalog() throws -> [LevelDefinition] {
    let root = URL(fileURLWithPath: #filePath).deletingLastPathComponent()
      .deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
      .deletingLastPathComponent()
    return try LevelCatalog.decode(
      Data(contentsOf: root.appendingPathComponent("Drairtunvur/Resources/levels.json")))
  }
  func testDailyScheduleStableAndEverySelectionSolvable() throws {
    let levels = try catalog()
    for offset in 0..<60 {
      let day = try XCTUnwrap(DailyChallenge.offset("2026-10-12", days: offset))
      let level = try XCTUnwrap(DailyChallenge.level(for: day, levels: levels))
      XCTAssertEqual(level, DailyChallenge.level(for: day, levels: levels.reversed()))
      var session = GameSession(level: level)
      for move in level.referenceSolution { try session.place(move, level: level) }
      XCTAssertEqual(session.state.outcome, .won)
    }
    XCTAssertNil(DailyChallenge.date(for: "2026-02-30"))
    XCTAssertNil(DailyChallenge.date(for: "2026-1-2"))
    XCTAssertEqual(DailyChallenge.offset("2024-03-01", days: -1), "2024-02-29")
    let instant = try XCTUnwrap(DailyChallenge.date(for: "2026-10-12"))
    XCTAssertEqual(
      DailyChallenge.key(for: instant, timeZone: TimeZone(secondsFromGMT: -3600)!), "2026-10-11")
    XCTAssertEqual(
      DailyChallenge.key(for: instant, timeZone: TimeZone(secondsFromGMT: 28800)!), "2026-10-12")
  }
  func testDailyResumeBestStreakAndCampaignIsolation() throws {
    let levels = try catalog()
    let day = "2026-10-12"
    let level = try XCTUnwrap(DailyChallenge.level(for: day, levels: levels))
    var save = SaveEnvelope()
    save.active = GameSession(level: levels[1])
    let campaign = save.active
    var daily = DailyProgress()
    var game = daily.start(day: day, level: level)
    try game.place(level.referenceSolution[0], level: level)
    daily.commit(day: day, level: level, session: game)
    save.daily = daily
    let restored = try JSONDecoder().decode(SaveEnvelope.self, from: JSONEncoder().encode(save))
    XCTAssertEqual(restored.daily?.runs[day]?.session, game)
    XCTAssertEqual(daily.start(day: day, level: level), game)
    for move in level.referenceSolution.dropFirst() { try game.place(move, level: level) }
    daily.commit(day: day, level: level, session: game)
    daily.commit(day: day, level: level, session: game)
    XCTAssertEqual(daily.bestMoves.count, 1)
    XCTAssertEqual(daily.bestMoves[day], game.state.movesUsed)
    XCTAssertEqual(daily.streak(through: "2026-10-13"), 1)
    XCTAssertEqual(daily.streak(through: "2026-10-14"), 0)
    daily.bestMoves["2026-10-11"] = 3
    XCTAssertEqual(daily.streak(through: day), 2)
    save.daily = daily
    XCTAssertEqual(save.active, campaign)
    XCTAssertTrue(save.bestMoves.isEmpty)
    XCTAssertFalse(save.tutorialCompleted)
    XCTAssertTrue(daily.isValid())
    _ = daily.start(day: day, level: level, restart: true)
    XCTAssertEqual(daily.bestMoves[day], game.state.movesUsed)
  }
  func testDailyLegacySaveAndMidnightIsolation() throws {
    let old = Data(
      #"{"schemaVersion":1,"revision":2,"bestMoves":{},"tutorialCompleted":true}"#.utf8)
    XCTAssertNil(try JSONDecoder().decode(SaveEnvelope.self, from: old).daily)
    let levels = try catalog()
    var daily = DailyProgress()
    for offset in 0..<10 {
      let day = DailyChallenge.offset("2026-10-12", days: offset)!
      let level = DailyChallenge.level(for: day, levels: levels)!
      _ = daily.start(day: day, level: level)
    }
    XCTAssertEqual(daily.runs.count, 7)
    let yesterday = "2026-10-20"
    let level = daily.runs[yesterday]!.level
    var game = daily.runs[yesterday]!.session
    for move in level.referenceSolution { try game.place(move, level: level) }
    daily.commit(day: yesterday, level: level, session: game)
    XCTAssertNotNil(daily.bestMoves[yesterday])
    XCTAssertNil(daily.bestMoves["2026-10-21"])
    XCTAssertEqual(daily.runs["2026-10-21"]?.session.state.movesUsed, 0)
    XCTAssertTrue(daily.isValid())
  }
  func testDailyRepositoryRoundTrip() async throws {
    let levels = try catalog()
    let root = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: root) }
    let repository = SaveRepository(directory: root)
    var save = SaveEnvelope()
    save.revision = 1
    let day = "2026-10-12"
    let level = DailyChallenge.level(for: day, levels: levels)!
    var daily = DailyProgress()
    _ = daily.start(day: day, level: level)
    save.daily = daily
    try await repository.write(save)
    let restored = try await SaveRepository(directory: root).load(levels: levels)
    XCTAssertEqual(restored.save, save)
  }
  func testAll45ReferenceSolutionsAndEveryPreviewUndo() throws {
    let levels = try catalog()
    XCTAssertEqual(levels.count, 45)
    for chapter in 1...3 { XCTAssertEqual(levels.filter { $0.chapter == chapter }.count, 15) }
    for l in levels {
      var session = GameSession(level: l)
      for move in l.referenceSolution {
        let before = session
        let preview = try Rules.apply(move, to: session.state, level: l)
        let actual = try session.place(move, level: l)
        XCTAssertEqual(preview, actual)
        XCTAssertTrue(session.isValid(for: l), l.id)
        if session.state.outcome != .won {
          XCTAssertTrue(session.undo())
          XCTAssertEqual(session, before)
          try session.place(move, level: l)
        }
      }
      XCTAssertEqual(session.state.outcome, .won, l.id)
      XCTAssertFalse(session.undo())
      XCTAssertEqual(
        HintSolver.solve(state: GameState(level: l), level: l), .solved(l.referenceSolution))
    }
  }
  func testIllegalMoveAndDiagonalAndNoPulse() throws {
    let l = level(board: [Cell(3, 0), Cell(2, 1)])
    let s = GameState(level: l)
    XCTAssertThrowsError(try Rules.apply(Move(slot: 0, anchor: Cell(3, 0)), to: s, level: l))
    XCTAssertThrowsError(try Rules.apply(Move(slot: 0, anchor: Cell(-1, 0)), to: s, level: l))
    XCTAssertEqual(s.movesUsed, 0)
    XCTAssertEqual(Rules.reachable(board: s.board, source: l.sourceEntry), Cell(3, 0).bit)
    let result = try Rules.apply(Move(slot: 0, anchor: Cell(3, 1)), to: s, level: l)
    XCTAssertEqual(result.state.energy, [0])
    XCTAssertFalse(result.hasPulse)
  }
  func testCrossClearChargesOnceBeforeClearingAndWinsOnLastMove() throws {
    let cells = (0..<8).filter { $0 != 3 }.flatMap { [Cell(3, $0), Cell($0, 3)] }
    let l = level(board: cells, targets: [Target(id: "A", cell: Cell(3, 3), capacity: 1)], limit: 1)
    let r = try Rules.apply(Move(slot: 0, anchor: Cell(3, 3)), to: GameState(level: l), level: l)
    XCTAssertEqual(r.cleared.nonzeroBitCount, 15)
    XCTAssertEqual(r.rows, [3])
    XCTAssertEqual(r.columns, [3])
    XCTAssertEqual(r.state.board, 0)
    XCTAssertEqual(r.state.energy, [1])
    XCTAssertEqual(r.state.outcome, .won)
  }
  func testMultipleLinesOnePulseCapacityAndNoGravity() throws {
    let board =
      (0..<8).flatMap { [Cell(3, $0), Cell(4, $0)] }.filter { $0.col != 7 } + [Cell(0, 2)]
    var l = level(
      board: board,
      targets: [
        Target(id: "A", cell: Cell(3, 3), capacity: 2),
        Target(id: "B", cell: Cell(4, 3), capacity: 1),
      ])
    l.pieceBatches[0][0] = Piece(id: "v2", cells: [Cell(0, 0), Cell(1, 0)])
    let r = try Rules.apply(Move(slot: 0, anchor: Cell(3, 7)), to: GameState(level: l), level: l)
    XCTAssertEqual(r.state.energy, [1, 1])
    XCTAssertEqual(r.state.board, Cell(0, 2).bit)
    var s = GameState(level: l)
    s.energy = [2, 1]
    let capped = try Rules.apply(Move(slot: 0, anchor: Cell(3, 7)), to: s, level: l)
    XCTAssertEqual(capped.state.energy, [2, 1])
  }
  func testDisconnectedTargetAndUncoveredSourceDontCharge() throws {
    let board = (0..<7).map { Cell(3, $0) } + [Cell(1, 4)]
    let l = level(board: board, targets: [Target(id: "A", cell: Cell(1, 4), capacity: 1)])
    XCTAssertEqual(
      try Rules.apply(Move(slot: 0, anchor: Cell(3, 7)), to: GameState(level: l), level: l).state
        .energy, [0])
    var other = l
    other.sourceEntry = Cell(0, 0)
    XCTAssertEqual(
      try Rules.apply(Move(slot: 0, anchor: Cell(3, 7)), to: GameState(level: other), level: other)
        .state.energy, [0])
  }
  func testBatchRefillExhaustionFailureUndoAndCodable() throws {
    var l = level(limit: 3)
    l.pieceBatches = [[dot, dot, dot], [dot, dot, dot]]
    var session = GameSession(level: l)
    for col in 0..<3 {
      try session.place(Move(slot: col, anchor: Cell(0, col)), level: l)
      if col < 2 { XCTAssertEqual(session.state.nextBatch, 1) }
    }
    XCTAssertEqual(session.state.nextBatch, 2)
    XCTAssertEqual(session.state.candidates.compactMap { $0 }.count, 3)
    XCTAssertEqual(session.state.outcome, .outOfMoves)
    XCTAssertTrue(session.undo())
    XCTAssertEqual(session.state.outcome, .playing)
    XCTAssertEqual(
      try JSONDecoder().decode(GameSession.self, from: JSONEncoder().encode(session)), session)
    l.moveLimit = 8
    l.pieceBatches = [[dot, dot, dot]]
    session = GameSession(level: l)
    for col in 0..<3 { try session.place(Move(slot: col, anchor: Cell(0, col)), level: l) }
    XCTAssertEqual(session.state.outcome, .exhausted)
  }
  func testNoSpaceAndValidation() throws {
    var l = level(
      board: (0..<8).flatMap { r in (0..<8).compactMap { c in (r + c) % 2 == 0 ? Cell(r, c) : nil }
      })
    let square = Piece(id: "square", cells: [Cell(0, 0), Cell(0, 1), Cell(1, 0), Cell(1, 1)])
    l.pieceBatches = [[square, square, square]]
    XCTAssertEqual(Rules.outcome(GameState(level: l), level: l), .noSpace)
    XCTAssertThrowsError(try Rules.validate(l, replay: false))
    l = level(board: (0..<8).map { Cell(0, $0) })
    XCTAssertThrowsError(try Rules.validate(l, replay: false))
  }
  func testHintsDistinguishBudgetExhaustionAndVerifiedSolution() throws {
    let l = try catalog()[9]
    var s = GameState(level: l)
    let off = Rules.legalMoves(s).first { !l.referenceSolution.contains($0) }!
    s = try Rules.apply(off, to: s, level: l).state
    XCTAssertEqual(HintSolver.solve(state: s, level: l, budget: 0), .timedOut)
    XCTAssertEqual(HintSolver.solve(state: s, level: l, cancelled: { true }), .cancelled)
    let impossible = level(limit: 1)
    XCTAssertEqual(
      HintSolver.solve(state: GameState(level: impossible), level: impossible, budget: 2),
      .noSolution)
  }
  func testSaveAtomicFailureBackupRecoveryAndStaleWrite() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    let levels = try catalog()
    let repo = SaveRepository(directory: dir)
    _ = try await repo.load(levels: levels)
    var a = SaveEnvelope()
    a.revision = 1
    a.active = GameSession(level: levels[0])
    let first = try await repo.write(a)
    XCTAssertTrue(first)
    var b = a
    b.revision = 2
    b.tutorialCompleted = true
    await repo.simulateNextWriteFailure()
    do {
      _ = try await repo.write(b)
      XCTFail("expected atomic failure")
    } catch {}
    XCTAssertEqual(
      try JSONDecoder().decode(
        SaveEnvelope.self, from: Data(contentsOf: dir.appendingPathComponent("save-v1.json"))), a)
    _ = try await repo.write(b)
    let stale = try await repo.write(a)
    XCTAssertFalse(stale)
    try Data("corrupt".utf8).write(to: dir.appendingPathComponent("save-v1.json"))
    let recovery = try await SaveRepository(directory: dir).load(levels: levels)
    XCTAssertTrue(recovery.recoveredBackup)
    XCTAssertEqual(recovery.save, a)
  }
  func testContentVersionResetProtectsProgressAndUnknownSchema() async throws {
    let dir = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    defer { try? FileManager.default.removeItem(at: dir) }
    var levels = try catalog()
    var save = SaveEnvelope()
    save.revision = 1
    save.active = GameSession(level: levels[0])
    save.bestMoves[levels[0].id] = 1
    _ = try await SaveRepository(directory: dir).write(save)
    levels[0].contentVersion = 2
    let report = try await SaveRepository(directory: dir).load(levels: levels)
    XCTAssertTrue(report.resetActive)
    XCTAssertNil(report.save.active)
    XCTAssertEqual(report.save.bestMoves, save.bestMoves)
    save.schemaVersion = 999
    try JSONEncoder().encode(save).write(to: dir.appendingPathComponent("save-v1.json"))
    let repo = SaveRepository(directory: dir)
    do {
      _ = try await repo.load(levels: levels)
      XCTFail()
    } catch {}
    do {
      _ = try await repo.write(SaveEnvelope())
      XCTFail()
    } catch {}
  }
  func testProgressIdempotencyAndCollectibleMilestones() throws {
    let levels = try catalog()
    var s = SaveEnvelope()
    for l in levels.prefix(5) {
      s.recordWin(level: l, moves: 3)
      s.recordWin(level: l, moves: 4)
      s.recordWin(level: l, moves: 2)
    }
    XCTAssertEqual(s.completed(in: 1, levels: levels), 5)
    XCTAssertEqual(s.collectibles(levels: levels), ["1-5"])
    XCTAssertEqual(s.bestMoves[levels[0].id], 2)
  }
  func testRefillBeforeNoSpaceAndSourceEdgeValidation() throws {
    var l = level(
      board: (0..<8).flatMap { r in (0..<8).compactMap { c in (r + c) % 2 == 0 ? Cell(r, c) : nil }
      })
    let square = Piece(id: "square", cells: [Cell(0, 0), Cell(0, 1), Cell(1, 0), Cell(1, 1)])
    l.pieceBatches = [[dot, dot, dot], [square, square, square]]
    var s = GameState(level: l)
    s.movesUsed = 2
    s.candidates = [nil, nil, dot]
    let next = try Rules.apply(Move(slot: 2, anchor: Cell(0, 1)), to: s, level: l).state
    XCTAssertEqual(next.nextBatch, 2)
    XCTAssertEqual(next.outcome, .noSpace)
    l.sourceEntry = Cell(4, 4)
    XCTAssertThrowsError(try Rules.validate(l, replay: false))
  }
  func testPreviewPerformanceAndOffReferenceHintCoverage() throws {
    let levels = try catalog()
    let l = levels[40]
    let state = GameState(level: l)
    let move = l.referenceSolution[0]
    let start = ProcessInfo.processInfo.systemUptime
    for _ in 0..<1000 { _ = try Rules.apply(move, to: state, level: l) }
    let average = (ProcessInfo.processInfo.systemUptime - start) * 1000 / 1000
    print("PREVIEW_AVERAGE_MS=\(average)")
    XCTAssertLessThan(average, 5)
    var solved = 0
    var timedOut = 0
    var impossible = 0
    for level in levels.enumerated().filter({ $0.offset % 5 == 0 }).map({ $0.element }) {
      let initial = GameState(level: level)
      guard
        let alternative = Rules.legalMoves(initial).first(where: {
          $0 != level.referenceSolution.first
        })
      else { continue }
      let deviated = try Rules.apply(alternative, to: initial, level: level).state
      switch HintSolver.solve(state: deviated, level: level, budget: 0.1) {
      case .solved(let path):
        var end = deviated
        for step in path { end = try Rules.apply(step, to: end, level: level).state }
        XCTAssertEqual(end.outcome, .won)
        solved += 1
      case .timedOut: timedOut += 1
      case .noSolution: impossible += 1
      case .cancelled: XCTFail()
      }
    }
    print(
      "HINT_DEVIATIONS solved=\(solved), timeout=\(timedOut), exhausted=\(impossible), budget=100ms"
    )
  }

}
