import Foundation

public enum DailyChallenge {
  public static func key(for date: Date, timeZone: TimeZone = .current) -> String {
    var calendar = Calendar(identifier: .gregorian)
    calendar.timeZone = timeZone
    let parts = calendar.dateComponents([.year, .month, .day], from: date)
    return String(format: "%04d-%02d-%02d", parts.year!, parts.month!, parts.day!)
  }
  public static func date(for key: String) -> Date? {
    let formatter = DateFormatter()
    formatter.locale = Locale(identifier: "en_US_POSIX")
    formatter.calendar = Calendar(identifier: .gregorian)
    formatter.timeZone = TimeZone(secondsFromGMT: 0)
    formatter.dateFormat = "yyyy-MM-dd"
    formatter.isLenient = false
    guard let date = formatter.date(from: key), formatter.string(from: date) == key else {
      return nil
    }
    return date
  }
  public static func offset(_ key: String, days: Int) -> String? {
    guard let date = date(for: key) else { return nil }
    return self.key(
      for: date.addingTimeInterval(Double(days) * 86400), timeZone: TimeZone(secondsFromGMT: 0)!)
  }
  /// A deterministic daily selection from the bundled, verified puzzles. No network or random state.
  public static func level(for key: String, levels: [LevelDefinition]) -> LevelDefinition? {
    guard let date = date(for: key) else { return nil }
    let pool = levels.filter { $0.number >= 5 && $0.referenceSolution.count > 1 }.sorted {
      $0.id < $1.id
    }
    guard !pool.isEmpty else { return nil }
    let day = Int(floor(date.timeIntervalSince1970 / 86400))
    var level = pool[((day % pool.count) + pool.count) % pool.count]
    level.id = "daily.\(key)"
    return level
  }
}

public struct DailyRun: Codable, Equatable, Sendable {
  public var level: LevelDefinition
  public var session: GameSession
  public init(level: LevelDefinition) {
    self.level = level
    session = GameSession(level: level)
  }
}

public struct DailyProgress: Codable, Equatable, Sendable {
  public var runs: [String: DailyRun] = [:]
  public var bestMoves: [String: Int] = [:]
  public init() {}
  public mutating func start(day: String, level: LevelDefinition, restart: Bool = false)
    -> GameSession
  {
    if !restart, let run = runs[day], run.session.state.outcome != .won { return run.session }
    let run = DailyRun(level: level)
    runs[day] = run
    // Keep recent resumable games; completion records are retained separately.
    for old in runs.keys.sorted().filter({ $0 != day }).dropLast(6) {
      runs.removeValue(forKey: old)
    }
    return run.session
  }
  public mutating func commit(day: String, level: LevelDefinition, session: GameSession) {
    var run = DailyRun(level: level)
    run.session = session
    runs[day] = run
    for old in runs.keys.sorted().filter({ $0 != day }).dropLast(6) {
      runs.removeValue(forKey: old)
    }
    if session.state.outcome == .won {
      bestMoves[day] = min(bestMoves[day] ?? Int.max, session.state.movesUsed)
    }
  }
  public func streak(through today: String) -> Int {
    var cursor = bestMoves[today] == nil ? DailyChallenge.offset(today, days: -1) : today
    var count = 0
    while let key = cursor, bestMoves[key] != nil {
      count += 1
      cursor = DailyChallenge.offset(key, days: -1)
    }
    return count
  }
  public func isValid() -> Bool {
    guard runs.count <= 7,
      bestMoves.allSatisfy({ DailyChallenge.date(for: $0.key) != nil && $0.value > 0 })
    else { return false }
    return runs.allSatisfy { day, run in
      DailyChallenge.date(for: day) != nil && run.level.id == "daily.\(day)"
        && (try? Rules.validate(run.level)) != nil && run.session.isValid(for: run.level)
    }
  }
}
