import Foundation

public enum HintResult: Equatable, Sendable {
  case solved([Move])
  case noSolution, timedOut, cancelled
}
public enum HintSolver {
  public static func solve(
    state: GameState, level: LevelDefinition, budget: TimeInterval = 0.5,
    cancelled: @Sendable () -> Bool = { false }
  ) -> HintResult {
    if state.outcome == .won { return .solved([]) }
    if state.outcome != .playing { return .noSolution }
    // A matching reference suffix is still verified in full against the current state.
    var cursor = GameState(level: level)
    for i in 0...level.referenceSolution.count {
      if cursor == state {
        let suffix = Array(level.referenceSolution.dropFirst(i))
        var end = state
        for move in suffix {
          guard let result = try? Rules.apply(move, to: end, level: level) else {
            return .noSolution
          }
          end = result.state
        }
        if end.outcome == .won { return .solved(suffix) }
      }
      if i < level.referenceSolution.count,
        let result = try? Rules.apply(level.referenceSolution[i], to: cursor, level: level)
      {
        cursor = result.state
      }
    }
    let deadline = ProcessInfo.processInfo.systemUptime + max(0, budget)
    var visited = Set<GameState>()
    var stopped = false
    var wasCancelled = false
    func search(_ current: GameState) -> [Move]? {
      if cancelled() {
        stopped = true
        wasCancelled = true
        return nil
      }
      if ProcessInfo.processInfo.systemUptime >= deadline {
        stopped = true
        return nil
      }
      if current.outcome == .won { return [] }
      guard current.outcome == .playing && visited.insert(current).inserted else { return nil }
      let remaining = level.moveLimit - current.movesUsed
      if zip(current.energy, level.targets).contains(where: { $1.capacity - $0 > remaining }) {
        return nil
      }
      var children = [(Move, Resolution, Int)]()
      for move in Rules.legalMoves(current) {
        if cancelled() {
          stopped = true
          wasCancelled = true
          return nil
        }
        if ProcessInfo.processInfo.systemUptime >= deadline {
          stopped = true
          return nil
        }
        guard let result = try? Rules.apply(move, to: current, level: level) else { continue }
        let score =
          result.chargedTargets.count * 1000 + result.cleared.nonzeroBitCount * 4
          + result.connected.nonzeroBitCount
        children.append((move, result, score))
      }
      children.sort { $0.2 > $1.2 }
      for (move, resolution, _) in children {
        if let tail = search(resolution.state) { return [move] + tail }
        if stopped { return nil }
      }
      return nil
    }
    if let path = search(state) { return .solved(path) }
    return wasCancelled ? .cancelled : (stopped ? .timedOut : .noSolution)
  }
}
