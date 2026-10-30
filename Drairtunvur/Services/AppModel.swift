import LightworksCore
import UIKit

@MainActor final class AppModel {
  static let shared = AppModel()
  let levels: [LevelDefinition]
  let dailyLevels: [LevelDefinition]
  let repository: SaveRepository
  var save = SaveEnvelope()
  var loadMessage: String?
  var saveError: String?
  var onChange: (() -> Void)?
  var loaded = false
  var storageNeedsRecovery = false
  var lastSavedRevision = -1
  private var pendingSave: Task<Void, Never>?
  private init() {
    do {
      guard let url = Bundle.main.url(forResource: "levels", withExtension: "json") else {
        throw RuleError.invalidLevel("Missing levels")
      }
      levels = try LevelCatalog.decode(Data(contentsOf: url))
      guard
        let dailyURL = Bundle.main.url(
          forResource: "Drairtunvur-daily-levels", withExtension: "json")
      else {
        throw RuleError.invalidLevel("Missing daily catalogue")
      }
      dailyLevels = try LevelCatalog.decode(Data(contentsOf: dailyURL))
    } catch { fatalError("Bundled level validation failed: \(error)") }
    var root = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
      .appendingPathComponent("Lightworks", isDirectory: true)
    #if DEBUG
      if ProcessInfo.processInfo.arguments.contains("-ui-testing") {
        root = root.deletingLastPathComponent().appendingPathComponent(
          "Lightworks-UITests", isDirectory: true)
        if ProcessInfo.processInfo.arguments.contains("-reset-test-save") {
          try? FileManager.default.removeItem(at: root)
        }
        if ProcessInfo.processInfo.arguments.contains("-ui-test-corrupt-save") {
          try? FileManager.default.createDirectory(at: root, withIntermediateDirectories: true)
          try? Data("invalid save fixture".utf8).write(
            to: root.appendingPathComponent("save-v1.json"))
        }
      }
    #endif
    repository = SaveRepository(directory: root)
  }
  func load() async {
    guard !loaded else { return }
    do {
      let report = try await repository.load(levels: levels)
      save = report.save
      if report.recoveredBackup {
        loadMessage = "Progress restored from backup."
      }
      if report.resetActive {
        loadMessage = "This level was updated. Your completed progress is preserved."
      }
    } catch SaveError.unsupportedVersion {
      storageNeedsRecovery = true
      loadMessage =
        "This save was created by a newer app version. Update the app to continue. The original files are preserved."
    } catch {
      storageNeedsRecovery = true
      loadMessage =
        "Your save could not be read. Original files are preserved. Open Settings to recover before playing."
    }
    loaded = true
    #if DEBUG
      let args = ProcessInfo.processInfo.arguments
      if args.contains("-ui-testing"), args.contains("-ui-test-completed"), !storageNeedsRecovery {
        for level in levels { save.recordWin(level: level, moves: level.referenceSolution.count) }
        persist()
      }
    #endif
    onChange?()
  }
  func level(_ id: String) -> LevelDefinition? { levels.first { $0.id == id } }
  func completed(_ chapter: Int) -> Int { save.completed(in: chapter, levels: levels) }
  func unlocked(_ level: LevelDefinition) -> Bool {
    let index = levels.firstIndex(where: { $0.id == level.id }) ?? 0
    return index == 0 || save.bestMoves[levels[index - 1].id] != nil
      || save.bestMoves[level.id] != nil
  }
  var campaignCompleted: Bool { levels.allSatisfy { save.bestMoves[$0.id] != nil } }
  var nextLevel: LevelDefinition {
    if let active = save.active, let l = level(active.levelID), active.state.outcome != .won,
      unlocked(l)
    {
      return l
    }
    return levels.first(where: { save.bestMoves[$0.id] == nil }) ?? levels[levels.count - 1]
  }
  func start(_ level: LevelDefinition, restart: Bool = false) -> GameSession {
    if !restart, let s = save.active, s.levelID == level.id, s.state.outcome != .won { return s }
    let s = GameSession(level: level)
    save.active = s
    persist()
    return s
  }
  func commit(_ session: GameSession, level: LevelDefinition) {
    save.active = session
    if session.state.outcome == .won {
      save.recordWin(level: level, moves: session.state.movesUsed)
    }
    persist()
    onChange?()
  }
  var daily: DailyProgress { save.daily ?? DailyProgress() }
  var today: String {
    #if DEBUG
      let args = ProcessInfo.processInfo.arguments
      if args.contains("-ui-testing"), let index = args.firstIndex(of: "-ui-test-date"),
        args.count > index + 1, DailyChallenge.date(for: args[index + 1]) != nil
      {
        return args[index + 1]
      }
    #endif
    return DailyChallenge.key(for: Date())
  }
  func dailyLevel(_ day: String) -> LevelDefinition {
    daily.runs[day]?.level ?? DailyChallenge.level(for: day, levels: dailyLevels)!
  }
  func startDaily(day: String, level: LevelDefinition, restart: Bool = false) -> GameSession {
    var progress = daily
    let session = progress.start(day: day, level: level, restart: restart)
    save.daily = progress
    persist()
    return session
  }
  func commitDaily(day: String, level: LevelDefinition, session: GameSession) {
    var progress = daily
    progress.commit(day: day, level: level, session: session)
    save.daily = progress
    persist()
    onChange?()
  }
  func persist() {
    guard loaded, !storageNeedsRecovery else { return }
    save.revision += 1
    let snapshot = save
    let repository = repository
    pendingSave = Task { [weak self] in
      do {
        let written = try await repository.write(snapshot)
        if written {
          self?.lastSavedRevision = max(self?.lastSavedRevision ?? -1, snapshot.revision)
          self?.saveError = nil
        }
      } catch {
        self?.saveError = "Could not save progress. Retry in Settings."
        self?.onChange?()
      }
    }
  }
  func recoverStorage(reset: Bool) async -> Bool {
    await flush()
    do {
      if reset {
        save = try await repository.archiveAndReset()
      } else {
        save = try await repository.load(levels: levels).save
      }
      storageNeedsRecovery = false
      saveError = nil
      loadMessage = nil
      lastSavedRevision = save.revision
      onChange?()
      return true
    } catch { return false }
  }
  func flush() async { await pendingSave?.value }
}

@MainActor enum Preferences {
  static var sound: Bool {
    get { UserDefaults.standard.object(forKey: "sound") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "sound") }
  }
  static var haptics: Bool {
    get { UserDefaults.standard.object(forKey: "haptics") as? Bool ?? true }
    set { UserDefaults.standard.set(newValue, forKey: "haptics") }
  }
  static var reduceMotion: Bool {
    get {
      UserDefaults.standard.bool(forKey: "reduceMotion") || UIAccessibility.isReduceMotionEnabled
    }
    set { UserDefaults.standard.set(newValue, forKey: "reduceMotion") }
  }
}

@MainActor enum L {
  static func chapter(_ number: Int) -> String {
    [
      "Quiet Harbor", "Glasshouse Glow",
      "Midnight Station",
    ][max(0, min(2, number - 1))]
  }
  static func lesson(_ key: String) -> String {
    switch key {
    case "cascade":
      return
        "Trace the source to each line. Clearing upstream can disconnect lights downstream; plan the order."
    case "relay":
      return
        "Clearing leaves a gap. Repair the connection before carrying light to the next target."
    case "cross":
      return
        "Prepare the branches, then finish the crossing. Clearing several lines together still gives just one charge."
    case "switchback":
      return
        "Lights need different charge counts. Send light along one axis, then rebuild the crossing to use the other route."
    case "double-rebuild":
      return
        "A double clear charges once. Use the next batch to rebuild both lines for a second pulse."
    case "first":
      return "Select the horizontal piece, then tap the glowing gap. Complete the row to charge A."
    case "branches":
      return "Connect the branches before completing a line to charge several lights at once."
    case "rebuild":
      return "Targets need two pulses. Rebuild the cleared path; stored energy is kept."
    default:
      return "Blocks carry light orthogonally. Complete a row or column to charge connected lights."
    }
  }
}
