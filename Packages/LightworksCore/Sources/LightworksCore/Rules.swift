import Foundation

public enum Rules {
  public static func reachable(board: UInt64, source: Cell) -> UInt64 {
    guard board & source.bit != 0 else { return 0 }
    var reached = source.bit
    var queue = [source]
    var index = 0
    while index < queue.count {
      let cell = queue[index]
      index += 1
      for next in cell.neighbors where board & next.bit != 0 && reached & next.bit == 0 {
        reached |= next.bit
        queue.append(next)
      }
    }
    return reached
  }
  public static func fullLines(_ board: UInt64) -> (rows: [Int], columns: [Int], mask: UInt64) {
    var rows = [Int]()
    var columns = [Int]()
    var mask: UInt64 = 0
    for n in 0..<8 {
      let row = UInt64(255) << (n * 8)
      let col = UInt64(0x0101_0101_0101_0101) << n
      if board & row == row {
        rows.append(n)
        mask |= row
      }
      if board & col == col {
        columns.append(n)
        mask |= col
      }
    }
    return (rows, columns, mask)
  }
  public static func canPlace(_ piece: Piece, at anchor: Cell, board: UInt64) -> Bool {
    piece.translated(to: anchor).allSatisfy { $0.isValid && board & $0.bit == 0 }
  }
  public static func legalMoves(_ state: GameState) -> [Move] {
    guard state.outcome == .playing else { return [] }
    var moves = [Move]()
    for (slot, candidate) in state.candidates.enumerated() {
      guard let piece = candidate else { continue }
      for row in 0..<8 {
        for col in 0..<8 where canPlace(piece, at: Cell(row, col), board: state.board) {
          moves.append(Move(slot: slot, anchor: Cell(row, col)))
        }
      }
    }
    return moves
  }
  public static func outcome(_ state: GameState, level: LevelDefinition) -> Outcome {
    if zip(state.energy, level.targets).allSatisfy({ $0 >= $1.capacity }) { return .won }
    if state.movesUsed >= level.moveLimit { return .outOfMoves }
    if state.candidates.allSatisfy({ $0 == nil }) { return .exhausted }
    var active = state
    active.outcome = .playing
    if legalMoves(active).isEmpty { return .noSpace }
    return .playing
  }
  /// Preview and commit deliberately share this pure resolver. Animation never mutates a state.
  public static func apply(_ move: Move, to state: GameState, level: LevelDefinition) throws
    -> Resolution
  {
    guard state.outcome == .playing, state.candidates.indices.contains(move.slot),
      let piece = state.candidates[move.slot], canPlace(piece, at: move.anchor, board: state.board)
    else { throw RuleError.invalidMove }
    var next = state
    let placed = piece.translated(to: move.anchor)
    next.board = placed.reduce(state.board) { $0 | $1.bit }
    next.movesUsed += 1
    next.candidates[move.slot] = nil
    let beforeClear = next.board
    let lines = fullLines(beforeClear)
    let connected = reachable(board: beforeClear, source: level.sourceEntry)
    var charged = [Int]()
    if lines.mask != 0 {
      for i in level.targets.indices
      where connected & level.targets[i].cell.bit != 0 && next.energy[i] < level.targets[i].capacity
      {
        next.energy[i] += 1
        charged.append(i)
      }
      next.board &= ~lines.mask
    }
    if next.candidates.allSatisfy({ $0 == nil }) && next.nextBatch < level.pieceBatches.count {
      next.candidates = level.pieceBatches[next.nextBatch].map(Optional.some)
      next.nextBatch += 1
    }
    next.outcome = outcome(next, level: level)
    return Resolution(
      state: next, placed: placed, beforeClear: beforeClear, connected: connected,
      cleared: lines.mask, rows: lines.rows, columns: lines.columns, chargedTargets: charged)
  }
  public static func validate(_ level: LevelDefinition, replay: Bool = true) throws {
    func require(_ valid: Bool, _ message: String) throws {
      if !valid { throw RuleError.invalidLevel("\(level.id): \(message)") }
    }
    try require(
      level.schemaVersion == 1 && level.rulesVersion == 1 && level.contentVersion > 0
        && level.boardSize == 8, "version")
    try require(
      !level.id.isEmpty && (1...3).contains(level.chapter) && (1...15).contains(level.number),
      "identity")
    try require(
      level.sourceEntry.isValid
        && [level.sourceEntry.row, level.sourceEntry.col].contains(where: { $0 == 0 || $0 == 7 }),
      "source")
    try require(
      Set(level.initialOccupiedCells).count == level.initialOccupiedCells.count
        && level.initialOccupiedCells.allSatisfy(\.isValid), "occupied")
    try require(
      !level.targets.isEmpty && Set(level.targets.map(\.id)).count == level.targets.count
        && Set(level.targets.map(\.cell)).count == level.targets.count, "targets")
    try require(
      level.targets.allSatisfy {
        $0.cell.isValid && $0.capacity > 0 && (0..<$0.capacity).contains($0.initialEnergy)
      }, "energy")
    try require(
      level.moveLimit > 0 && !level.pieceBatches.isEmpty
        && level.pieceBatches.allSatisfy { $0.count == 3 }, "batches")
    for piece in level.pieceBatches.flatMap({ $0 }) {
      try require(
        !piece.cells.isEmpty && piece.cells.count <= 8
          && Set(piece.cells).count == piece.cells.count && piece.cells.allSatisfy(\.isValid)
          && piece.cells.map(\.row).min() == 0 && piece.cells.map(\.col).min() == 0, "shape")
      let bits = piece.cells.reduce(UInt64(0)) { $0 | $1.bit }
      try require(reachable(board: bits, source: piece.cells[0]) == bits, "disconnected shape")
    }
    let state = GameState(level: level)
    try require(fullLines(state.board).mask == 0, "initial full line")
    try require(outcome(state, level: level) == .playing, "initial terminal state")
    if replay {
      var replayState = state
      for move in level.referenceSolution {
        replayState = try apply(move, to: replayState, level: level).state
      }
      try require(replayState.outcome == .won, "reference does not win")
    }
  }
  public static func validate(_ state: GameState, level: LevelDefinition) -> Bool {
    guard state.energy.count == level.targets.count, state.candidates.count == 3,
      (1...level.pieceBatches.count).contains(state.nextBatch),
      (0...level.moveLimit).contains(state.movesUsed), fullLines(state.board).mask == 0
    else { return false }
    guard zip(state.energy, level.targets).allSatisfy({ (0...$1.capacity).contains($0) }) else {
      return false
    }
    let batch = level.pieceBatches[state.nextBatch - 1]
    guard
      state.candidates.enumerated().allSatisfy({
        $0.element == nil || $0.element == batch[$0.offset]
      })
    else { return false }
    let consumed = (state.nextBatch - 1) * 3 + state.candidates.filter({ $0 == nil }).count
    return consumed == state.movesUsed && state.outcome == outcome(state, level: level)
  }
}
