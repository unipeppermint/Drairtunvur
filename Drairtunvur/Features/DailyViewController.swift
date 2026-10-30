import LightworksCore
import UIKit

final class DailyViewController: ScreenController {
  private let model = AppModel.shared
  override func viewDidLoad() {
    super.viewDidLoad()
    background.picture.alpha = 0.22
    for name in [
      UIApplication.didBecomeActiveNotification,
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
    let title = Theme.label("Daily Restoration", size: 32, weight: .bold)
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
      "Restore \(level.targets.count) lights · \(level.moveLimit) moves", size: 14,
      color: Theme.muted)
    let state = Theme.label(
      progress.bestMoves[day] == nil
        ? "A new path awaits your light"
        : "Completed today ✓", size: 15, weight: .semibold, color: Theme.gold)
    state.accessibilityIdentifier = "daily.state"
    let details = Theme.inset(Theme.stack([name, caption, state], spacing: 8))
    Theme.panel(details)
    content.addArrangedSubview(Theme.stack([artwork, details], spacing: 8))
    let session = progress.runs[day]?.session
    let resumable =
      session != nil && session?.state.outcome != .won && (session?.state.movesUsed ?? 0) > 0
    let play = Theme.button(
      resumable
        ? "Continue today's challenge"
        : progress.bestMoves[day] == nil
          ? "Start today's challenge" : "Play again",
      symbol: "chevron.right", primary: true
    ) { [weak self] in
      guard let self else { return }
      // Resolve at tap time as the day may have changed while this screen was visible.
      guard !self.model.storageNeedsRecovery else {
        self.navigationController?.pushViewController(SettingsViewController(), animated: true)
        return
      }
      let today = self.model.today
      self.navigationController?.pushViewController(
        GameViewController(level: self.model.dailyLevel(today), dailyDay: today), animated: true)
    }
    play.configuration?.imagePlacement = .trailing
    play.accessibilityIdentifier = "daily.play"
    content.addArrangedSubview(play)
    let stats = Theme.stack(
      [
        metric("Days completed", "\(progress.bestMoves.count)"),
        metric("Current streak", "\(progress.streak(through: day))"),
        metric("Today's best", progress.bestMoves[day].map(String.init) ?? "—"),
      ], axis: .horizontal)
    stats.distribution = .fillEqually
    let statsPanel = Theme.inset(stats, by: 14)
    Theme.panel(statsPanel)
    content.addArrangedSubview(statsPanel)
    content.addArrangedSubview(
      Theme.label("The last seven days", size: 18, weight: .semibold))
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
        "\(key), \(done ? "Completed" : "Not completed")"
      days.addArrangedSubview(tile)
    }
    content.addArrangedSubview(days)
    content.addArrangedSubview(
      Theme.label(
        "365 dedicated puzzles rotate at local midnight, repeating after 365 days. Replay to improve your best. Games started before midnight count toward their original day.",
        size: 12, color: Theme.muted))
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
    header("Daily · \(day.suffix(5))", back: false)
    let title = Theme.label(
      "Today's path is shining", size: 34, weight: .semibold, color: Theme.gold)
    title.textAlignment = .center
    title.accessibilityIdentifier = "daily.result.title"
    content.addArrangedSubview(title)
    let space = UIView()
    space.heightAnchor.constraint(equalToConstant: min(280, view.bounds.height * 0.29)).isActive =
      true
    content.addArrangedSubview(space)
    let best = AppModel.shared.daily.bestMoves[day] ?? moves
    let summary = Theme.label(
      "\(moves) moves · Best \(best)\nAll \(level.targets.count) lights restored", size: 20,
      weight: .semibold)
    summary.textAlignment = .center
    let panel = Theme.inset(summary)
    Theme.panel(panel)
    content.addArrangedSubview(panel)
    let back = Theme.button("Back to daily", symbol: "calendar", primary: true) {
      [weak self] in
      self?.navigationController?.popToRootViewController(animated: true)
    }
    back.accessibilityIdentifier = "daily.result.back"
    content.addArrangedSubview(back)
    let replay = Theme.button("Play again", symbol: "arrow.clockwise") {
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
        "Completion recorded for \(day). Come back tomorrow for another path.", size: 13,
        color: Theme.muted))
  }
}
