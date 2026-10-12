import LightworksCore
import UIKit

final class CityViewController: ScreenController {
  let model = AppModel.shared
  var chapter = 1
  var nodePage = 0
  private var sceneHeight: NSLayoutConstraint?
  override func viewDidLoad() {
    dimScene = false
    super.viewDidLoad()
    chapter = model.nextLevel.chapter
    nodePage = (model.nextLevel.number - 1) / 6
    NotificationCenter.default.addObserver(
      self, selector: #selector(refresh), name: .languageChanged, object: nil)
    model.onChange = { [weak self] in
      if self?.navigationController?.topViewController === self { self?.refresh() }
    }
    refresh()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh()
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let height = max(160, min(440, view.safeAreaLayoutGuide.layoutFrame.height - 305))
    if abs((sceneHeight?.constant ?? 0) - height) > 0.5 { sceneHeight?.constant = height }
  }
  @objc func refresh() {
    guard isViewLoaded else { return }
    clearContent()
    background.chapter = chapter
    background.progress = CGFloat(model.completed(chapter)) / 15
    let title = Theme.label(L.text("光路工坊", "Lightworks"), size: 34, weight: .bold)
    let sub = Theme.label(
      L.text("拼出光的道路，点亮一座城市", "A little light. A city brought to life."), size: 13,
      color: Theme.muted)
    let settings = Theme.button("", symbol: "gearshape") { [weak self] in
      self?.navigationController?.pushViewController(SettingsViewController(), animated: true)
    }
    settings.accessibilityLabel = L.text("设置", "Settings")
    settings.accessibilityIdentifier = "city.settings"
    settings.configuration?.background.backgroundColor = .clear
    settings.configuration?.background.strokeWidth = 0
    settings.heightAnchor.constraint(equalToConstant: 46).isActive = true
    settings.widthAnchor.constraint(equalToConstant: 48).isActive = true
    let headingRow = Theme.stack(
      [Theme.stack([title, sub], spacing: 6), settings], axis: .horizontal, spacing: 8)
    headingRow.alignment = .center
    content.addArrangedSubview(headingRow)
    let sceneSpace = UIView()
    sceneHeight = sceneSpace.heightAnchor.constraint(equalToConstant: 320)
    sceneHeight?.isActive = true
    let nodes = CityNodesView()
    nodes.chapter = chapter
    nodes.start = nodePage * 6 + 1
    nodes.model = model
    nodes.onSelect = { [weak self] level in self?.open(level) }
    sceneSpace.addSubview(nodes)
    nodes.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      nodes.leadingAnchor.constraint(equalTo: sceneSpace.leadingAnchor),
      nodes.trailingAnchor.constraint(equalTo: sceneSpace.trailingAnchor),
      nodes.heightAnchor.constraint(equalToConstant: 94),
    ])
    content.addArrangedSubview(sceneSpace)
    let previous = Theme.button("", symbol: "chevron.left") { [weak self] in
      guard let self else { return }
      self.nodePage = max(0, self.nodePage - 1)
      self.refresh()
    }
    previous.isEnabled = nodePage > 0
    previous.accessibilityLabel = L.text("前六关", "Previous six levels")
    let next = Theme.button("", symbol: "chevron.right") { [weak self] in
      guard let self else { return }
      self.nodePage = min(2, self.nodePage + 1)
      self.refresh()
    }
    next.isEnabled = nodePage < 2
    next.accessibilityLabel = L.text("后六关", "Next six levels")
    let range = Theme.label(
      "\(String(format:"%02d",nodePage*6+1)) — \(String(format:"%02d",min(15,nodePage*6+6)))  /  15",
      size: 12, color: Theme.muted)
    range.textAlignment = .center
    range.numberOfLines = 1
    range.adjustsFontSizeToFitWidth = true
    range.minimumScaleFactor = 0.85
    for button in [previous, next] {
      button.widthAnchor.constraint(equalToConstant: 46).isActive = true
      button.configuration?.contentInsets = NSDirectionalEdgeInsets(
        top: 10, leading: 10, bottom: 10, trailing: 10)
    }
    let count = model.completed(chapter)
    let heading = Theme.label(
      L.text(
        "第 \(chapter) 章 · \(L.chapter(chapter))", "CHAPTER \(chapter) · \(L.chapter(chapter))"),
      size: 19, weight: .semibold)
    let choose = Theme.button("", symbol: "chevron.right") { [weak self] in self?.chooseChapter() }
    choose.accessibilityLabel = L.text("选择章节", "Choose chapter")
    choose.configuration?.background.backgroundColor = .clear
    choose.configuration?.background.strokeWidth = 0
    choose.widthAnchor.constraint(equalToConstant: 44).isActive = true
    let progressText = Theme.label(
      L.text("已点亮 \(count) / 15", "RESTORED  \(count) / 15"), size: 13, color: Theme.muted)
    let details = Theme.stack([heading, progressText], spacing: 6)
    let card = Theme.inset(Theme.stack([details, choose], axis: .horizontal, spacing: 8))
    Theme.panel(card)
    content.addArrangedSubview(card)
    let destination =
      model.levels.first { $0.chapter == chapter && model.save.bestMoves[$0.id] == nil } ?? model
      .levels.first { $0.chapter == chapter }!
    let active = model.save.active.flatMap { s in
      model.level(s.levelID).flatMap { $0.chapter == chapter && s.state.outcome != .won ? $0 : nil }
    }
    let target = active ?? destination
    let play = Theme.button(
      model.unlocked(target)
        ? (count == 15 ? L.text("回顾光路", "Revisit the paths") : L.text("继续修复", "Continue restoring"))
        : L.text("章节未解锁", "Chapter locked"), symbol: "chevron.right",
      primary: true
    ) { [weak self] in self?.open(target) }
    play.configuration?.subtitle = L.text(
      "第 \(String(format:"%02d",target.number)) 关", "LEVEL \(String(format:"%02d",target.number))")
    play.configuration?.titleAlignment = .center
    play.configuration?.imagePlacement = .trailing
    play.isEnabled = model.unlocked(target)
    if !play.isEnabled {
      play.configuration?.subtitle = L.text("完成前一章后开放", "Complete the previous chapter")
    }
    play.accessibilityIdentifier = "city.continue"
    let pages = Theme.stack([previous, range, next], axis: .horizontal, spacing: 10)
    Theme.panel(pages, radius: 23)
    sceneSpace.addSubview(pages)
    pages.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      pages.bottomAnchor.constraint(equalTo: sceneSpace.bottomAnchor),
      pages.centerXAnchor.constraint(equalTo: sceneSpace.centerXAnchor),
      pages.widthAnchor.constraint(equalToConstant: 248),
      pages.heightAnchor.constraint(equalToConstant: 46),
      nodes.bottomAnchor.constraint(equalTo: pages.topAnchor, constant: -18),
    ])
    content.addArrangedSubview(play)
    if let message = model.saveError {
      let retry = Theme.button(message, symbol: "arrow.clockwise") { [weak self] in
        self?.model.persist()
      }
      content.addArrangedSubview(retry)
    }
    if let message = model.loadMessage {
      content.addArrangedSubview(Theme.label(message, size: 12, color: Theme.gold))
    }
  }
  private func chooseChapter() {
    let sheet = UIAlertController(
      title: L.text("选择章节", "Choose chapter"), message: nil, preferredStyle: .actionSheet)
    for c in 1...3 {
      sheet.addAction(
        UIAlertAction(title: L.chapter(c), style: .default) { [weak self] _ in
          self?.chapter = c
          self?.nodePage = 0
          self?.refresh()
        })
    }
    sheet.addAction(UIAlertAction(title: L.text("取消", "Cancel"), style: .cancel))
    sheet.popoverPresentationController?.sourceView = view
    sheet.popoverPresentationController?.sourceRect = CGRect(
      x: view.bounds.midX, y: view.bounds.maxY - 180, width: 1, height: 1)
    present(sheet, animated: true)
  }
  func open(_ level: LevelDefinition) {
    guard !model.storageNeedsRecovery else {
      navigationController?.pushViewController(SettingsViewController(), animated: true)
      return
    }
    guard model.unlocked(level) else {
      alert(
        L.text("光路尚未抵达", "The light has not reached here"),
        L.text("先完成前一关，再来修复这里。", "Complete the previous level to unlock this one."))
      return
    }
    navigationController?.pushViewController(GameViewController(level: level), animated: true)
  }
}

final class CityNodesView: UIView {
  var chapter = 1
  var start = 1
  var model: AppModel!
  var onSelect: ((LevelDefinition) -> Void)?
  private var nodes = [UIButton]()
  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = .clear
  }
  required init?(coder: NSCoder) { fatalError() }
  override func layoutSubviews() {
    super.layoutSubviews()
    if nodes.isEmpty, let model {
      for i in 0..<6 {
        guard
          let level = model.levels.first(where: { $0.chapter == chapter && $0.number == start + i })
        else { continue }
        let done = model.save.bestMoves[level.id] != nil
        let open = model.unlocked(level)
        let button = MapNodeButton(completed: done)
        button.setTitle(String(format: "%02d", level.number), for: .normal)
        button.titleLabel?.font = .systemFont(ofSize: 15, weight: .semibold)
        button.setTitleColor(done || open ? Theme.cream : Theme.muted, for: .normal)
        button.backgroundColor = .clear
        button.layer.cornerRadius = 22
        button.layer.borderWidth = done ? 0 : open ? 2 : 1
        button.layer.borderColor = (open ? Theme.gold : Theme.muted.withAlphaComponent(0.4)).cgColor
        if open {
          button.layer.shadowColor = Theme.gold.cgColor
          button.layer.shadowRadius = 12
          button.layer.shadowOpacity = 0.75
          button.layer.shadowOffset = .zero
        }
        button.accessibilityLabel = L.text(
          "第 \(level.number) 关，\(done ? "已完成" : open ? "可游玩" : "未解锁")",
          "Level \(level.number), \(done ? "completed" : open ? "available" : "locked")")
        button.accessibilityIdentifier = "level.\(level.id)"
        button.addAction(UIAction { [weak self] _ in self?.onSelect?(level) }, for: .touchUpInside)
        addSubview(button)
        nodes.append(button)
      }
    }
    for (i, node) in nodes.enumerated() {
      node.frame = CGRect(
        x: CGFloat(i) * (bounds.width - 44) / 5, y: [0, 13, 27, 38, 44, 46][i], width: 44,
        height: 44)
    }
    setNeedsDisplay()
  }
  override func draw(_ rect: CGRect) {
    let p = UIBezierPath()
    for (i, node) in nodes.enumerated() {
      if i == 0 { p.move(to: node.center) } else { p.addLine(to: node.center) }
    }
    Theme.gold.withAlphaComponent(0.5).setStroke()
    p.lineWidth = 2
    p.setLineDash([3, 5], count: 2, phase: 0)
    p.stroke()
  }
}

final class ResultViewController: ScreenController {
  let level: LevelDefinition
  let moves: Int
  init(level: LevelDefinition, moves: Int) {
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
    let model = AppModel.shared
    let count = model.completed(level.chapter)
    let lastLevel = level.id == model.levels.last?.id
    let allRestored = lastLevel && model.campaignCompleted
    background.progress = CGFloat(count) / 15
    header("\(L.chapter(level.chapter)) · \(String(format:"%02d",level.number))", back: false)
    let title = Theme.label(
      allRestored
        ? L.text("城市已点亮", "The city shines")
        : [
          L.text("灯塔亮了", "A little brighter"), L.text("温室亮了", "The glasshouse glows"),
          L.text("站台亮了", "The station shines"),
        ][level.chapter - 1], size: 46, weight: .regular, color: Theme.gold)
    title.font = UIFont(name: "STSongti-SC-Bold", size: 46) ?? title.font
    title.textAlignment = .center
    title.accessibilityIdentifier = "result.title"
    content.addArrangedSubview(title)
    let ornament = Theme.label("─────  ✧  ─────", size: 14, color: Theme.gold)
    ornament.textAlignment = .center
    content.addArrangedSubview(ornament)
    let spacer = UIView()
    spacer.heightAnchor.constraint(equalToConstant: max(160, min(320, view.bounds.height * 0.32)))
      .isActive = true
    content.addArrangedSubview(spacer)
    let progress = UIProgressView(progressViewStyle: .default)
    progress.progressTintColor = Theme.gold
    progress.trackTintColor = Theme.muted.withAlphaComponent(0.3)
    progress.progress = Float(count) / 15
    let progressLabel = Theme.label(
      L.text("章节修复  \(count) / 15", "CHAPTER RESTORED  \(count) / 15"), size: 17, weight: .semibold)
    progressLabel.textAlignment = .center
    let panel = Theme.inset(Theme.stack([progressLabel, progress], spacing: 12))
    Theme.panel(panel)
    content.addArrangedSubview(panel)
    func metric(_ caption: String, _ value: String) -> UIView {
      let label = Theme.label(caption, size: 14)
      label.textAlignment = .center
      let number = Theme.label(value, size: 28, weight: .semibold, color: Theme.gold)
      number.textAlignment = .center
      return Theme.stack([label, number], spacing: 4)
    }
    let metrics = Theme.stack(
      [
        metric(L.text("使用步数", "Moves used"), "\(moves)"),
        metric(L.text("点亮目标", "Lights restored"), "\(level.targets.count)/\(level.targets.count)"),
      ], axis: .horizontal)
    metrics.distribution = .fillEqually
    content.addArrangedSubview(metrics)
    let best = Theme.label(
      L.text(
        "本关最好 \(model.save.bestMoves[level.id] ?? moves) 步",
        "Best for this level: \(model.save.bestMoves[level.id] ?? moves) moves"), size: 13,
      color: Theme.muted)
    best.textAlignment = .center
    content.addArrangedSubview(best)
    if allRestored {
      content.addArrangedSubview(
        Theme.label(
          L.text(
            "45 条光路全部修复。你可以回顾关卡，或在每日修复中继续点亮城市。",
            "All 45 paths are restored. Revisit your favorite levels or return for a daily challenge."
          ), size: 15, color: Theme.cream))
    }
    let next = Theme.button(
      lastLevel ? L.text("回到城市", "Back to city") : L.text("继续修复", "Continue restoring"),
      symbol: "arrow.right", primary: true
    ) { [weak self] in
      guard let self, let nav = self.navigationController,
        let index = model.levels.firstIndex(where: { $0.id == self.level.id })
      else { return }
      guard index + 1 < model.levels.count else {
        nav.popToRootViewController(animated: true)
        return
      }
      let level = model.levels[index + 1]
      let next: UIViewController = GameViewController(level: level)
      nav.setViewControllers([nav.viewControllers[0], next], animated: true)
    }
    next.configuration?.imagePlacement = .trailing
    next.accessibilityIdentifier = "result.continue"
    content.addArrangedSubview(next)
    let replay = Theme.button(L.text("再玩一次", "Play again"), symbol: "arrow.clockwise") {
      [weak self] in
      guard let self, let nav = self.navigationController else { return }
      nav.setViewControllers(
        [nav.viewControllers[0], GameViewController(level: self.level, restart: true)],
        animated: true)
    }
    replay.accessibilityIdentifier = "result.replay"
    let city = Theme.button(L.text("回到城市", "Back to city"), symbol: "house") { [weak self] in
      self?.navigationController?.popToRootViewController(animated: true)
    }
    city.accessibilityIdentifier = "result.city"
    for button in [replay, city] {
      button.configuration?.image = nil
      button.configuration?.background.backgroundColor = .clear
      button.configuration?.background.strokeWidth = 0
    }
    content.addArrangedSubview(Theme.stack([replay, city], axis: .horizontal, spacing: 10))
  }
}
