import Foundation

public struct Cell: Codable, Hashable, Sendable {
  public var row: Int
  public var col: Int
  public init(_ row: Int, _ col: Int) {
    self.row = row
    self.col = col
  }
  public var isValid: Bool { (0..<8).contains(row) && (0..<8).contains(col) }
  public var bit: UInt64 { isValid ? UInt64(1) << (row * 8 + col) : 0 }
  public var neighbors: [Cell] {
    [Cell(row - 1, col), Cell(row + 1, col), Cell(row, col - 1), Cell(row, col + 1)].filter(
      \.isValid)
  }
}
public struct Piece: Codable, Hashable, Sendable {
  public var id: String
  public var cells: [Cell]
  public init(id: String, cells: [Cell]) {
    self.id = id
    self.cells = cells
  }
  public func translated(to anchor: Cell) -> [Cell] {
    cells.map { Cell($0.row + anchor.row, $0.col + anchor.col) }
  }
}
public struct Target: Codable, Hashable, Sendable {
  public var id: String
  public var cell: Cell
  public var capacity: Int
  public var initialEnergy: Int
  public init(id: String, cell: Cell, capacity: Int, initialEnergy: Int = 0) {
    self.id = id
    self.cell = cell
    self.capacity = capacity
    self.initialEnergy = initialEnergy
  }
}
public struct Move: Codable, Hashable, Sendable {
  public var slot: Int
  public var anchor: Cell
  public init(slot: Int, anchor: Cell) {
    self.slot = slot
    self.anchor = anchor
  }
}
public struct LevelDefinition: Codable, Hashable, Sendable {
  public var id: String
  public var chapter: Int
  public var number: Int
  public var schemaVersion: Int
  public var contentVersion: Int
  public var rulesVersion: Int
  public var boardSize: Int
  public var initialOccupiedCells: [Cell]
  public var sourceEntry: Cell
  public var targets: [Target]
  public var pieceBatches: [[Piece]]
  public var moveLimit: Int
  public var referenceSolution: [Move]
  public var lesson: String
  public init(
    id: String, chapter: Int = 1, number: Int = 1, initialOccupiedCells: [Cell], sourceEntry: Cell,
    targets: [Target], pieceBatches: [[Piece]], moveLimit: Int, referenceSolution: [Move] = [],
    lesson: String = "connect"
  ) {
    self.id = id
    self.chapter = chapter
    self.number = number
    self.schemaVersion = 1
    self.contentVersion = 1
    self.rulesVersion = 1
    self.boardSize = 8
    self.initialOccupiedCells = initialOccupiedCells
    self.sourceEntry = sourceEntry
    self.targets = targets
    self.pieceBatches = pieceBatches
    self.moveLimit = moveLimit
    self.referenceSolution = referenceSolution
    self.lesson = lesson
  }
}
public enum Outcome: String, Codable, Hashable, Sendable {
  case playing, won, outOfMoves, noSpace, exhausted
}
public struct GameState: Codable, Hashable, Sendable {
  public var board: UInt64
  public var energy: [Int]
  public var candidates: [Piece?]
  public var nextBatch: Int
  public var movesUsed: Int
  public var outcome: Outcome
  public init(level: LevelDefinition) {
    board = level.initialOccupiedCells.reduce(0) { $0 | $1.bit }
    energy = level.targets.map(\.initialEnergy)
    candidates = (level.pieceBatches.first ?? []).map(Optional.some)
    nextBatch = 1
    movesUsed = 0
    outcome = .playing
  }
  public func contains(_ cell: Cell) -> Bool { board & cell.bit != 0 }
}
public struct Resolution: Equatable, Sendable {
  public let state: GameState
  public let placed: [Cell]
  public let beforeClear: UInt64
  public let connected: UInt64
  public let cleared: UInt64
  public let rows: [Int]
  public let columns: [Int]
  public let chargedTargets: [Int]
  public var hasPulse: Bool { cleared != 0 }
}
public enum RuleError: Error, Equatable {
  case invalidMove
  case invalidLevel(String)
  case invalidState
}
