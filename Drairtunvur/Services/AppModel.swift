import LightworksCore
import UIKit

@MainActor final class AppModel {
  static let shared = AppModel()
  let levels: [LevelDefinition]
  let repository: SaveRepository
  var save = SaveEnvelope()
  var loadMessage: String?
  var saveError: String?
  var onChange: (() -> Void)?
  var loaded = false
  var lastSavedRevision = -1
  private var pendingSave: Task<Void, Never>?
  private init() {
    do {
      guard let url = Bundle.main.url(forResource: "levels", withExtension: "json") else {
        throw RuleError.invalidLevel("Missing levels")
      }
      levels = try LevelCatalog.decode(Data(contentsOf: url))
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
        loadMessage = L.text("已从备份恢复进度。", "Progress restored from backup.")
      }
      if report.resetActive {
        loadMessage = L.text(
          "关卡已更新，当前关卡将重新开始。已完成进度保留。",
          "This level was updated. Your completed progress is preserved.")
      }
    } catch {
      loadMessage = L.text(
        "存档暂时无法读取。原文件已保留，本次进度可能无法保存。",
        "Your save could not be read. Original files are preserved; saving may be unavailable.")
    }
    loaded = true
    onChange?()
  }
  func level(_ id: String) -> LevelDefinition? { levels.first { $0.id == id } }
  func completed(_ chapter: Int) -> Int { save.completed(in: chapter, levels: levels) }
  func unlocked(_ level: LevelDefinition) -> Bool {
    let index = levels.firstIndex(where: { $0.id == level.id }) ?? 0
    return index == 0 || save.bestMoves[levels[index - 1].id] != nil
      || save.bestMoves[level.id] != nil
  }
  var nextLevel: LevelDefinition {
    if let active = save.active, let l = level(active.levelID), active.state.outcome != .won,
      unlocked(l)
    {
      return l
    }
    return levels.first(where: { save.bestMoves[$0.id] == nil }) ?? levels[0]
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
    daily.runs[day]?.level ?? DailyChallenge.level(for: day, levels: levels)!
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
    guard loaded else { return }
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
        self?.saveError = L.text("进度保存失败，请在设置中重试。", "Could not save progress. Retry in Settings.")
        self?.onChange?()
      }
    }
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
  static var language: String {
    get { UserDefaults.standard.string(forKey: "language") ?? "system" }
    set {
      UserDefaults.standard.set(newValue, forKey: "language")
      NotificationCenter.default.post(name: .languageChanged, object: nil)
    }
  }
}
extension Notification.Name {
  static let languageChanged = Notification.Name("LightworksLanguageChanged")
}
@MainActor enum L {
  static var english: Bool {
    Preferences.language == "en"
      || (Preferences.language == "system"
        && !(Locale.preferredLanguages.first ?? "en").hasPrefix("zh"))
  }
  static func text(_ zh: String, _ en: String) -> String {
    let locale = L.english ? "en" : "zh-Hans"
    if let path = Bundle.main.path(forResource: locale, ofType: "lproj"),
      let bundle = Bundle(path: path)
    {
      return bundle.localizedString(forKey: en, value: english ? en : zh, table: "Localizable")
    }
    return english ? en : zh
  }
  static func chapter(_ number: Int) -> String {
    [
      text("静谧港湾", "Quiet Harbor"), text("温室微光", "Glasshouse Glow"),
      text("候车之夜", "Midnight Station"),
    ][max(0, min(2, number - 1))]
  }
  static func lesson(_ key: String) -> String {
    switch key {
    case "first":
      return text(
        "点选横向方块，再点亮起的空格。补满一行，让光抵达 A。",
        "Select the horizontal piece, then tap the glowing gap. Complete the row to charge A.")
    case "branches":
      return text(
        "先接通分支，再补满一行或一列，让一次脉冲点亮多盏灯。",
        "Connect the branches before completing a line to charge several lights at once.")
    case "rebuild":
      return text(
        "目标需要两次脉冲。消除后重建光路，已获得的能量会保留。",
        "Targets need two pulses. Rebuild the cleared path; stored energy is kept.")
    default:
      return text(
        "方块上下左右导光。只有补满整行或整列，才会为相连的灯充能。",
        "Blocks carry light orthogonally. Complete a row or column to charge connected lights.")
    }
  }
}
