import Foundation

public struct GameSession: Codable, Equatable, Sendable {
  public var levelID: String
  public var contentVersion: Int
  public var state: GameState
  public var history: [GameState]
  public init(level: LevelDefinition) {
    levelID = level.id
    contentVersion = level.contentVersion
    state = GameState(level: level)
    history = []
  }
  @discardableResult public mutating func place(_ move: Move, level: LevelDefinition) throws
    -> Resolution
  {
    let resolution = try Rules.apply(move, to: state, level: level)
    history.append(state)
    if history.count > 64 { history.removeFirst() }
    state = resolution.state
    return resolution
  }
  @discardableResult public mutating func undo() -> Bool {
    guard state.outcome != .won, let last = history.popLast() else { return false }
    state = last
    return true
  }
  public func isValid(for level: LevelDefinition) -> Bool {
    guard levelID == level.id, contentVersion == level.contentVersion, history.count <= 64,
      Rules.validate(state, level: level),
      history.allSatisfy({ Rules.validate($0, level: level) && $0.outcome == .playing })
    else { return false }
    let chain = history + [state]
    for (before, after) in zip(chain, chain.dropFirst()) {
      guard after.movesUsed == before.movesUsed + 1,
        Rules.legalMoves(before).contains(where: {
          (try? Rules.apply($0, to: before, level: level).state) == after
        })
      else { return false }
    }
    return history.isEmpty
      ? state == GameState(level: level)
      : history.first == GameState(level: level) || history.count == 64
  }
}
public struct SaveEnvelope: Codable, Equatable, Sendable {
  public var schemaVersion: Int = 1
  public var revision: Int = 0
  public var active: GameSession?
  public var daily: DailyProgress?
  public var bestMoves: [String: Int] = [:]
  public var bestContentVersions: [String: Int]?
  public var tutorialCompleted: Bool = false
  public init() {}
  public mutating func recordWin(level: LevelDefinition, moves: Int) {
    let previous = (bestContentVersions?[level.id] ?? 1) == level.contentVersion
      ? bestMoves[level.id] : nil
    bestMoves[level.id] = min(previous ?? Int.max, moves)
    if bestContentVersions == nil { bestContentVersions = [:] }
    bestContentVersions?[level.id] = level.contentVersion
    tutorialCompleted = true
  }
  public func completed(in chapter: Int, levels: [LevelDefinition]) -> Int {
    levels.filter { $0.chapter == chapter && bestMoves[$0.id] != nil }.count
  }
  public func collectibles(levels: [LevelDefinition]) -> Set<String> {
    var result = Set<String>()
    for chapter in 1...3 {
      for milestone in [5, 10, 15] where completed(in: chapter, levels: levels) >= milestone {
        result.insert("\(chapter)-\(milestone)")
      }
    }
    return result
  }
}
public enum SaveError: Error {
  case unsupportedVersion, invalidData, protectedCorruption, injectedFailure
}
public struct LoadReport: Sendable {
  public var save: SaveEnvelope
  public var recoveredBackup: Bool
  public var resetActive: Bool
}

/// Serial writes, atomic file replacement, monotonic revisions, and a separately validated backup.
public actor SaveRepository {
  public let directory: URL
  private var lastRevision = -1
  private var canWrite = true
  private var failNextWrite = false
  public init(directory: URL) { self.directory = directory }
  private var primary: URL { directory.appendingPathComponent("save-v1.json") }
  private var backup: URL { directory.appendingPathComponent("save-v1.backup.json") }
  public func simulateNextWriteFailure() { failNextWrite = true }
  public func load(levels: [LevelDefinition]) throws -> LoadReport {
    let fm = FileManager.default
    var encountered = false
    for (url, isBackup) in [(primary, false), (backup, true)] where fm.fileExists(atPath: url.path)
    {
      encountered = true
      do {
        let data = try Data(contentsOf: url)
        struct Header: Decodable { let schemaVersion: Int }
        let header = try JSONDecoder().decode(Header.self, from: data)
        guard header.schemaVersion == 1 else { throw SaveError.unsupportedVersion }
        var save = try JSONDecoder().decode(SaveEnvelope.self, from: data)
        guard save.schemaVersion == 1 else { throw SaveError.unsupportedVersion }
        guard save.revision >= 0,
          save.bestMoves.allSatisfy({ id, moves in
            !id.isEmpty && moves > 0
          })
        else { throw SaveError.invalidData }
        guard save.daily?.isValid() ?? true else { throw SaveError.invalidData }
        var reset = false
        if let active = save.active {
          if let level = levels.first(where: { $0.id == active.levelID }) {
            if active.contentVersion != level.contentVersion {
              save.active = nil
              reset = true
            } else if !active.isValid(for: level) {
              throw SaveError.invalidData
            }
          } else {
            save.active = nil
            reset = true
          }
        }
        canWrite = true
        lastRevision = save.revision
        if isBackup {
          // Preserve damaged/newer data for support before any next write.
          if fm.fileExists(atPath: primary.path) {
            let archive = directory.appendingPathComponent("unreadable-\(UUID().uuidString).json")
            try fm.copyItem(at: primary, to: archive)
          }
          try data.write(to: primary, options: .atomic)
        }
        return LoadReport(save: save, recoveredBackup: isBackup, resetActive: reset)
      } catch SaveError.unsupportedVersion {
        // An older app must not replace a newer-format save with an older backup.
        canWrite = false
        throw SaveError.unsupportedVersion
      } catch { continue }
    }
    if encountered {
      canWrite = false
      throw SaveError.protectedCorruption
    }
    canWrite = true
    lastRevision = -1
    return LoadReport(save: SaveEnvelope(), recoveredBackup: false, resetActive: false)
  }
  /// Called only after the player explicitly chooses to archive and start over.
  public func archiveAndReset() throws -> SaveEnvelope {
    let fm = FileManager.default
    let archive = directory.appendingPathComponent(
      "recovery-\(UUID().uuidString)", isDirectory: true)
    try fm.createDirectory(at: archive, withIntermediateDirectories: true)
    for source in [primary, backup] where fm.fileExists(atPath: source.path) {
      try fm.copyItem(at: source, to: archive.appendingPathComponent(source.lastPathComponent))
    }
    var fresh = SaveEnvelope()
    fresh.revision = max(0, lastRevision + 1)
    let data = try JSONEncoder().encode(fresh)
    try data.write(to: primary, options: .atomic)
    try data.write(to: backup, options: .atomic)
    lastRevision = fresh.revision
    canWrite = true
    return fresh
  }
  @discardableResult public func write(_ save: SaveEnvelope) throws -> Bool {
    guard canWrite else { throw SaveError.protectedCorruption }
    guard save.revision > lastRevision else { return false }
    try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
    let data = try JSONEncoder().encode(save)
    if failNextWrite {
      failNextWrite = false
      throw SaveError.injectedFailure
    }
    if FileManager.default.fileExists(atPath: primary.path) {
      let previous = try Data(contentsOf: primary)
      try previous.write(to: backup, options: .atomic)
    }
    try data.write(to: primary, options: .atomic)
    lastRevision = save.revision
    return true
  }
}

public enum LevelCatalog {
  public static func decode(_ data: Data) throws -> [LevelDefinition] {
    let levels = try JSONDecoder().decode([LevelDefinition].self, from: data)
    guard !levels.isEmpty, Set(levels.map(\.id)).count == levels.count else {
      throw RuleError.invalidLevel("duplicate ids")
    }
    for level in levels { try Rules.validate(level) }
    return levels
  }
}
