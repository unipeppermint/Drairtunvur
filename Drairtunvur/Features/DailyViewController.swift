import LightworksCore
import UIKit

final class DailyViewController: ScreenController {
  private let model = AppModel.shared
  override func viewDidLoad() {
    super.viewDidLoad()
    background.picture.alpha = 0.22
    for name in [
      Notification.Name.languageChanged, UIApplication.didBecomeActiveNotification,
      UIApplication.significantTimeChangeNotification, .NSCalendarDayChanged,
    ] {
      NotificationCenter.default.addObserver(
        self, selector: #selector(refresh), name: name, object: nil)
    }
    refresh()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh()
  }
  @objc private func refresh() {
    guard isViewLoaded else { return }
    clearContent()
    let day = model.today
    let level = model.dailyLevel(day)
    let progress = model.daily
    background.chapter = level.chapter
    let title = Theme.label(L.text("每日修复", "Daily Restoration"), size: 32, weight: .bold)
    title.accessibilityIdentifier = "daily.title"
    content.addArrangedSubview(title)
    let date = Theme.label(day, size: 14, color: Theme.gold)
    date.accessibilityIdentifier = "daily.date"
    content.addArrangedSubview(date)
    let artwork = SceneCropView(
      name: ["harbor-v2", "greenhouse", "station"][level.chapter - 1],
      focus: level.chapter == 1 ? 0.30 : 0.50)
    artwork.heightAnchor.constraint(equalToConstant: 190).isActive = true
    artwork.layer.cornerRadius = 16
    let name = Theme.label(L.chapter(level.chapter), size: 23, weight: .semibold)
    let caption = Theme.label(
      L.text(
        "点亮 \(level.targets.count) 盏灯 · 限 \(level.moveLimit) 步",
        "Restore \(level.targets.count) lights · \(level.moveLimit) moves"), size: 14,
      color: Theme.muted)
    let state = Theme.label(
      progress.bestMoves[day] == nil
        ? L.text("今日光路，等你点亮", "A new path awaits your light")
        : L.text("今日已完成 ✓", "Completed today ✓"), size: 15, weight: .semibold, color: Theme.gold)
    state.accessibilityIdentifier = "daily.state"
    let details = Theme.inset(Theme.stack([name, caption, state], spacing: 8))
    Theme.panel(details)
    content.addArrangedSubview(Theme.stack([artwork, details], spacing: 8))
    let session = progress.runs[day]?.session
    let resumable =
      session != nil && session?.state.outcome != .won && (session?.state.movesUsed ?? 0) > 0
    let play = Theme.button(
      resumable
        ? L.text("继续今日挑战", "Continue today's challenge")
        : progress.bestMoves[day] == nil
          ? L.text("开始今日挑战", "Start today's challenge") : L.text("再挑战一次", "Play again"),
      symbol: "chevron.right", primary: true
    ) { [weak self] in
      guard let self else { return }
      // Resolve at tap time as the day may have changed while this screen was visible.
      let today = self.model.today
      self.navigationController?.pushViewController(
        GameViewController(level: self.model.dailyLevel(today), dailyDay: today), animated: true)
    }
    play.configuration?.imagePlacement = .trailing
    play.accessibilityIdentifier = "daily.play"
    content.addArrangedSubview(play)
    let stats = Theme.stack(
      [
        metric(L.text("累计完成", "Days completed"), "\(progress.bestMoves.count)"),
        metric(L.text("连续完成", "Current streak"), "\(progress.streak(through: day))"),
        metric(L.text("今日最好", "Today's best"), progress.bestMoves[day].map(String.init) ?? "—"),
      ], axis: .horizontal)
    stats.distribution = .fillEqually
    let statsPanel = Theme.inset(stats, by: 14)
    Theme.panel(statsPanel)
    content.addArrangedSubview(statsPanel)
    content.addArrangedSubview(
      Theme.label(L.text("最近七天", "The last seven days"), size: 18, weight: .semibold))
    let days = Theme.stack([], axis: .horizontal, spacing: 4)
    days.distribution = .fillEqually
    for offset in -6...0 {
      let key = DailyChallenge.offset(day, days: offset)!
      let done = progress.bestMoves[key] != nil
      let mark = Theme.label(
        done ? "✓" : "·", size: 21, weight: .semibold, color: done ? Theme.gold : Theme.muted)
      mark.textAlignment = .center
      let number = Theme.label(
        String(key.suffix(2)), size: 12, color: offset == 0 ? Theme.gold : Theme.muted)
      number.textAlignment = .center
      let tile = Theme.inset(Theme.stack([number, mark], spacing: 5), by: 7)
      Theme.panel(tile, radius: 12)
      if offset == 0 { tile.layer.borderColor = Theme.gold.cgColor }
      tile.isAccessibilityElement = true
      tile.accessibilityLabel =
        "\(key), \(done ? L.text("已完成", "Completed") : L.text("未完成", "Not completed"))"
      days.addArrangedSubview(tile)
    }
    content.addArrangedSubview(days)
    content.addArrangedSubview(
      Theme.label(
        L.text(
          "每日从章节关卡轮换一题，本地日期零点更新。完成后可反复挑战最佳步数；跨日进行的对局仍记在开始当天。",
          "One chapter puzzle rotates daily at local midnight. Replay to improve your best. A game started before midnight counts toward its original day."
        ), size: 12, color: Theme.muted))
    if let error = model.saveError {
      content.addArrangedSubview(Theme.label(error, size: 12, color: Theme.gold))
    }
  }
  private func metric(_ caption: String, _ value: String) -> UIView {
    let number = Theme.label(value, size: 25, weight: .semibold, color: Theme.gold)
    number.textAlignment = .center
    let label = Theme.label(caption, size: 12, color: Theme.muted)
    label.textAlignment = .center
    return Theme.stack([number, label], spacing: 5)
  }
}

final class DailyResultViewController: ScreenController {
  private let day: String
  private let level: LevelDefinition
  private let moves: Int
  init(day: String, level: LevelDefinition, moves: Int) {
    self.day = day
    self.level = level
    self.moves = moves
    super.init(nibName: nil, bundle: nil)
    sceneChapter = level.chapter
    dimScene = false
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    if level.chapter == 1 { background.picture.image = UIImage(named: "harbor-victory") }
    header(L.text("每日修复 · \(day.suffix(5))", "Daily · \(day.suffix(5))"), back: false)
    let title = Theme.label(
      L.text("今日光路已点亮", "Today's path is shining"), size: 34, weight: .semibold, color: Theme.gold)
    title.textAlignment = .center
    title.accessibilityIdentifier = "daily.result.title"
    content.addArrangedSubview(title)
    let space = UIView()
    space.heightAnchor.constraint(equalToConstant: min(280, view.bounds.height * 0.29)).isActive =
      true
    content.addArrangedSubview(space)
    let best = AppModel.shared.daily.bestMoves[day] ?? moves
    let summary = Theme.label(
      L.text(
        "本次 \(moves) 步  ·  最好 \(best) 步\n全部 \(level.targets.count) 盏灯已点亮",
        "\(moves) moves · Best \(best)\nAll \(level.targets.count) lights restored"), size: 20,
      weight: .semibold)
    summary.textAlignment = .center
    let panel = Theme.inset(summary)
    Theme.panel(panel)
    content.addArrangedSubview(panel)
    let back = Theme.button(L.text("回到每日", "Back to daily"), symbol: "calendar", primary: true) {
      [weak self] in
      self?.navigationController?.popToRootViewController(animated: true)
    }
    back.accessibilityIdentifier = "daily.result.back"
    content.addArrangedSubview(back)
    let replay = Theme.button(L.text("再挑战一次", "Play again"), symbol: "arrow.clockwise") {
      [weak self] in
      guard let self, let nav = self.navigationController else { return }
      nav.setViewControllers(
        [
          nav.viewControllers[0],
          GameViewController(level: self.level, restart: true, dailyDay: self.day),
        ], animated: true)
    }
    replay.accessibilityIdentifier = "daily.result.replay"
    content.addArrangedSubview(replay)
    content.addArrangedSubview(
      Theme.label(
        L.text(
          "完成记录已计入 \(day)。明天再来点亮新的光路。",
          "Completion recorded for \(day). Come back tomorrow for another path."), size: 13,
        color: Theme.muted))
  }
}
