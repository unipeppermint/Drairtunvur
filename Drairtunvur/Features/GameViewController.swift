import LightworksCore
import UIKit

final class GameViewController: ScreenController {
  let model = AppModel.shared
  let level: LevelDefinition
  let dailyDay: String?
  var session: GameSession
  let board = BoardView()
  let status = Theme.label("", size: 14, color: Theme.muted)
  let hud = UIStackView()
  private let playArea = UIStackView()
  private let controls = UIStackView()
  private let boardHolder = UIView()
  private var trayHeight: NSLayoutConstraint!
  private var boardDimension: NSLayoutConstraint!
  private var holderWidth: NSLayoutConstraint!
  private var lastLayoutLandscape: Bool?
  var pieces = [PieceView]()
  var selected: Int?
  var undoButton: UIButton!
  var hintButton: UIButton!
  var locked = false
  private var revision = 0
  private var animationTask: Task<Void, Never>?
  private var hintTask: Task<Void, Never>?
  private var resultShown = false
  init(level: LevelDefinition, restart: Bool = false, dailyDay: String? = nil) {
    self.level = level
    self.dailyDay = dailyDay
    self.session =
      dailyDay.map { AppModel.shared.startDaily(day: $0, level: level, restart: restart) }
      ?? AppModel.shared.start(level, restart: restart)
    super.init(nibName: nil, bundle: nil)
    sceneChapter = level.chapter
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    content.spacing = 12
    let pause = Theme.button("", symbol: "pause.fill") { [weak self] in self?.pauseGame() }
    pause.accessibilityLabel = L.text("暂停", "Pause")
    pause.accessibilityIdentifier = "game.pause"
    pause.widthAnchor.constraint(equalToConstant: 48).isActive = true
    header(
      dailyDay.map { L.text("每日 · \($0.suffix(5))", "Daily · \($0.suffix(5))") }
        ?? "\(L.chapter(level.chapter)) · \(String(format:"%02d",level.number))", trailing: pause)
    hud.axis = .horizontal
    hud.distribution = .fillEqually
    hud.spacing = 6
    let hudPanel = Theme.inset(hud, by: 13)
    Theme.panel(hudPanel)
    content.addArrangedSubview(hudPanel)
    board.level = level
    board.state = session.state
    board.heightAnchor.constraint(equalTo: board.widthAnchor).isActive = true
    board.onTap = { [weak self] cell in self?.place(at: cell) }
    board.translatesAutoresizingMaskIntoConstraints = false
    boardHolder.addSubview(board)
    boardDimension = board.widthAnchor.constraint(equalToConstant: 340)
    holderWidth = boardHolder.widthAnchor.constraint(equalTo: board.widthAnchor)
    NSLayoutConstraint.activate([
      board.centerXAnchor.constraint(equalTo: boardHolder.centerXAnchor),
      board.topAnchor.constraint(equalTo: boardHolder.topAnchor),
      board.bottomAnchor.constraint(equalTo: boardHolder.bottomAnchor),
      board.widthAnchor.constraint(lessThanOrEqualTo: boardHolder.widthAnchor),
      boardDimension,
    ])
    controls.axis = .vertical
    controls.spacing = 12
    playArea.axis = .vertical
    playArea.spacing = 12
    playArea.addArrangedSubview(boardHolder)
    playArea.addArrangedSubview(controls)
    content.addArrangedSubview(playArea)
    status.textAlignment = .center
    status.accessibilityIdentifier = "game.status"
    status.heightAnchor.constraint(greaterThanOrEqualToConstant: 40).isActive = true
    controls.addArrangedSubview(status)
    for slot in 0..<3 {
      let piece = PieceView()
      piece.slot = slot
      piece.accessibilityIdentifier = "piece.\(slot)"
      piece.addAction(UIAction { [weak self] _ in self?.select(slot) }, for: .touchUpInside)
      piece.onPan = { [weak self] gesture, slot in self?.drag(gesture, slot: slot) }
      pieces.append(piece)
    }
    let tray = Theme.stack(pieces, axis: .horizontal, spacing: 10)
    tray.distribution = .fillEqually
    trayHeight = tray.heightAnchor.constraint(equalToConstant: 100)
    trayHeight.isActive = true
    controls.addArrangedSubview(tray)
    undoButton = Theme.button(L.text("撤销", "Undo"), symbol: "arrow.uturn.backward") { [weak self] in
      self?.undo()
    }
    undoButton.accessibilityIdentifier = "game.undo"
    hintButton = Theme.button(L.text("提示", "Hint"), symbol: "lightbulb") { [weak self] in
      self?.hint()
    }
    hintButton.accessibilityIdentifier = "game.hint"
    let tools = Theme.stack([undoButton, hintButton], axis: .horizontal, spacing: 12)
    tools.distribution = .fillEqually
    controls.addArrangedSubview(tools)
    NotificationCenter.default.addObserver(
      self, selector: #selector(interrupted), name: UIApplication.willResignActiveNotification,
      object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(becameActive), name: UIApplication.didBecomeActiveNotification,
      object: nil)
    render()
    if level.id == "1-01", session.state.movesUsed == 0 {
      selected = 0
      board.hintMove = level.referenceSolution.first
      updatePieces()
    }
  }
  override func viewDidLayoutSubviews() {
    super.viewDidLayoutSubviews()
    let landscape = view.bounds.width > view.bounds.height
    contentMaximumWidth.constant = landscape ? 960 : 560
    let availableWidth = min(
      view.safeAreaLayoutGuide.layoutFrame.width - 40, contentMaximumWidth.constant)
    let availableHeight = view.safeAreaLayoutGuide.layoutFrame.height
    let compact = !landscape && availableHeight < 700
    trayHeight.constant = compact ? 84 : 100
    content.spacing = compact ? 10 : 12
    controls.spacing = compact ? 10 : 12
    playArea.spacing = compact ? 10 : 12
    let size =
      landscape
      ? min(480, max(200, availableHeight - 186), availableWidth - 260)
      : min(availableWidth, max(240, availableHeight - 390))
    if lastLayoutLandscape != landscape {
      holderWidth.isActive = false
      playArea.axis = landscape ? .horizontal : .vertical
      playArea.alignment = landscape ? .top : .fill
      holderWidth.isActive = landscape
      lastLayoutLandscape = landscape
    }
    if abs(boardDimension.constant - size) > 0.5 { boardDimension.constant = size }
  }
  override func viewDidAppear(_ animated: Bool) {
    super.viewDidAppear(animated)
    finishIfNeeded()
  }
  override func viewWillDisappear(_ animated: Bool) {
    super.viewWillDisappear(animated)
    settleAnimation()
    hintTask?.cancel()
    revision += 1
  }
  @objc private func becameActive() { finishIfNeeded() }
  @objc private func interrupted() {
    settleAnimation()
    hintTask?.cancel()
    revision += 1
    model.persist()
  }
  func render() {
    board.state = session.state
    board.preview = nil
    board.invalidCells = []
    hud.arrangedSubviews.forEach {
      hud.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }
    let moves = Theme.label(
      "\(max(0,level.moveLimit-session.state.movesUsed))", size: 30, weight: .bold,
      color: Theme.gold)
    moves.textAlignment = .center
    moves.accessibilityIdentifier = "game.remaining"
    let caption = Theme.label(L.text("剩余步数", "MOVES LEFT"), size: 10, color: Theme.muted)
    caption.textAlignment = .center
    hud.addArrangedSubview(Theme.stack([caption, moves], axis: .horizontal, spacing: 4))
    let objective = Theme.label(
      L.text("点亮 \(level.targets.count) 座灯塔", "Restore \(level.targets.count) lights"), size: 12)
    objective.textAlignment = .center
    hud.addArrangedSubview(objective)
    for (i, t) in level.targets.enumerated() {
      let title = UIImageView(image: LighthouseDrawing.image(lit: session.state.energy[i] > 0))
      title.contentMode = .scaleAspectFit
      title.heightAnchor.constraint(equalToConstant: 32).isActive = true
      let value = Theme.label(
        "\(t.id) · \(session.state.energy[i])/\(t.capacity)", size: 12, color: Theme.muted)
      value.textAlignment = .center
      let stack = Theme.stack([title, value], spacing: 3)
      stack.isAccessibilityElement = true
      stack.accessibilityLabel = L.text(
        "灯 \(t.id)，\(session.state.energy[i]) / \(t.capacity)，第 \(t.cell.row+1) 行第 \(t.cell.col+1) 列",
        "Light \(t.id), \(session.state.energy[i]) of \(t.capacity), row \(t.cell.row+1) column \(t.cell.col+1)"
      )
      hud.addArrangedSubview(stack)
    }
    updatePieces()
    undoButton.isEnabled = !session.history.isEmpty && session.state.outcome != .won && !locked
    hintButton.isEnabled = session.state.outcome == .playing && !locked
    status.text = L.lesson(level.lesson)
  }
  private func updatePieces() {
    for i in 0..<3 {
      pieces[i].piece = session.state.candidates[i]
      pieces[i].highlightedPiece = selected == i
      if let p = pieces[i].piece {
        let coordinates = p.cells.map { "\($0.row+1),\($0.col+1)" }.joined(separator: "; ")
        pieces[i].accessibilityLabel = L.text(
          "候选 \(i+1)，\(p.cells.count) 格，相对位置 \(coordinates)",
          "Piece \(i+1), \(p.cells.count) cells, relative positions \(coordinates)")
        pieces[i].accessibilityHint = L.text(
          "双击选择，再在棋盘中双击左上锚点。",
          "Double tap to select, then activate the top-left anchor on the board.")
      } else {
        pieces[i].accessibilityLabel = L.text("候选 \(i+1) 已使用", "Piece \(i+1) used")
      }
    }
  }
  func select(_ slot: Int) {
    guard !locked, session.state.outcome == .playing, session.state.candidates[slot] != nil else {
      return
    }
    selected = slot
    board.preview = nil
    board.invalidCells = []
    board.hintMove = nil
    updatePieces()
    status.text = L.text(
      "已选候选 \(slot+1) · 点选棋盘上的左上锚点",
      "Piece \(slot+1) selected · Tap its top-left anchor on the board")
    Feedback.shared.select()
  }
  func place(at cell: Cell) {
    guard !locked, session.state.outcome == .playing else { return }
    guard let slot = selected else {
      status.text = L.text("先在下方选择一个方块。", "Select a piece below first.")
      return
    }
    let move = Move(slot: slot, anchor: cell)
    guard let resolution = try? session.place(move, level: level) else {
      status.text = L.text("这里放不下，请选择空白位置。", "That piece does not fit here. Try an empty space.")
      board.invalidCells = session.state.candidates[slot]?.translated(to: cell) ?? []
      Feedback.shared.invalid()
      return
    }
    revision += 1
    hintTask?.cancel()
    selected = nil
    board.hintMove = nil
    commitSession()  // Commit and persist exactly once, before any animation.
    locked = true
    render()
    board.pulse = resolution
    status.text =
      resolution.hasPulse
      ? L.text(
        "光脉冲 · \(resolution.chargedTargets.count) 盏灯获得能量",
        "Light pulse · \(resolution.chargedTargets.count) lights charged")
      : L.text("光路已延伸 · 补满一行或一列可触发脉冲", "Path extended · Complete a row or column to pulse")
    Feedback.shared.play(resolution.hasPulse ? .pulse : .place)
    let token = revision
    animationTask = Task { [weak self] in
      let duration: UInt64 =
        Preferences.reduceMotion ? 80_000_000 : (resolution.hasPulse ? 700_000_000 : 170_000_000)
      try? await Task.sleep(nanoseconds: duration)
      guard let self, !Task.isCancelled, self.revision == token else { return }
      self.locked = false
      self.board.pulse = nil
      self.render()
      self.finishIfNeeded()
    }
  }
  func drag(_ gesture: UIPanGestureRecognizer, slot: Int) {
    guard !locked, session.state.outcome == .playing, let piece = session.state.candidates[slot]
    else { return }
    if gesture.state == .began {
      select(slot)
      scroll.isScrollEnabled = false
    }
    var location = gesture.location(in: board)
    location.y -= 48
    location.x -= CGFloat((piece.cells.map(\.col).max() ?? 0)) * board.unit / 2
    let anchor = board.cell(at: location)
    if let anchor,
      let preview = try? Rules.apply(
        Move(slot: slot, anchor: anchor), to: session.state, level: level)
    {
      board.preview = preview
      board.invalidCells = []
      status.text =
        preview.hasPulse
        ? L.text(
          "落下后可为 \(preview.chargedTargets.count) 盏灯充能",
          "Release to charge \(preview.chargedTargets.count) lights")
        : L.text("可以放置 · 尚未形成消除", "Fits here · No line completed yet")
    } else {
      board.preview = nil
      board.invalidCells = anchor.map { piece.translated(to: $0) } ?? []
      status.text = L.text(
        "移动到空白格，方块预览在手指上方。", "Move over empty cells. Preview sits above your finger.")
    }
    if gesture.state == .ended {
      scroll.isScrollEnabled = true
      board.preview = nil
      board.invalidCells = []
      if let anchor { place(at: anchor) }
    }
    if gesture.state == .cancelled || gesture.state == .failed {
      scroll.isScrollEnabled = true
      board.preview = nil
      board.invalidCells = []
    }
  }
  func undo() {
    guard !locked else { return }
    hintTask?.cancel()
    revision += 1
    guard session.undo() else { return }
    resultShown = false
    selected = nil
    board.hintMove = nil
    commitSession()
    render()
    Feedback.shared.select()
  }
  func hint() {
    guard !locked, session.state.outcome == .playing else { return }
    hintTask?.cancel()
    let state = session.state
    let level = level
    let token = revision
    status.text = L.text("正在寻找可通关的后续步骤…", "Looking for a complete path to success…")
    hintButton.isEnabled = false
    hintTask = Task { [weak self] in
      let worker = Task.detached(priority: .userInitiated) {
        HintSolver.solve(state: state, level: level, budget: 0.5, cancelled: { Task.isCancelled })
      }
      let result = await withTaskCancellationHandler(
        operation: { await worker.value }, onCancel: { worker.cancel() })
      guard let self, !Task.isCancelled, self.revision == token else { return }
      self.hintButton.isEnabled = true
      switch result {
      case .solved(let path):
        guard let move = path.first else { return }
        self.selected = move.slot
        self.updatePieces()
        self.board.hintMove = move
        self.board.preview = try? Rules.apply(move, to: state, level: level)
        self.status.text = L.text(
          "已验证提示：候选 \(move.slot+1)，第 \(move.anchor.row+1) 行第 \(move.anchor.col+1) 列。",
          "Verified hint: piece \(move.slot+1), row \(move.anchor.row+1), column \(move.anchor.col+1)."
        )
        UIAccessibility.post(notification: .announcement, argument: self.status.text)
      case .noSolution:
        self.status.text = L.text(
          "当前局面已确认无法通关，试着撤销一步。", "No winning continuation exists. Try undoing a move.")
      case .timedOut:
        self.status.text = L.text(
          "暂未找到完整解法。可继续尝试或撤销；这不代表无解。",
          "No complete solution found within the search time. Try exploring or undoing; this does not mean it is unsolvable."
        )
      case .cancelled: break
      }
    }
  }
  private func commitSession() {
    if let dailyDay {
      model.commitDaily(day: dailyDay, level: level, session: session)
    } else {
      model.commit(session, level: level)
    }
  }
  private var returnTitle: String {
    dailyDay == nil ? L.text("回到城市", "Back to city") : L.text("回到每日", "Back to daily")
  }
  func settleAnimation() {
    animationTask?.cancel()
    animationTask = nil
    scroll.isScrollEnabled = true
    locked = false
    board.pulse = nil
    if isViewLoaded { render() }
  }
  func restart() {
    settleAnimation()
    revision += 1
    resultShown = false
    selected = nil
    board.hintMove = nil
    session =
      dailyDay.map { model.startDaily(day: $0, level: level, restart: true) }
      ?? model.start(level, restart: true)
    render()
  }
  private func finishIfNeeded() {
    guard !locked, !resultShown, session.state.outcome != .playing,
      navigationController?.topViewController === self, presentedViewController == nil
    else { return }
    resultShown = true
    if session.state.outcome == .won {
      Feedback.shared.play(.win)
      navigationController?.pushViewController(
        dailyDay.map {
          DailyResultViewController(day: $0, level: level, moves: session.state.movesUsed)
            as UIViewController
        } ?? ResultViewController(level: level, moves: session.state.movesUsed),
        animated: !Preferences.reduceMotion)
    } else {
      let reason: String
      switch session.state.outcome {
      case .outOfMoves:
        reason = L.text("步数用完了。已充入的光仍在，撤销后可以换一种铺法。", "No moves left. Undo to try a different path.")
      case .noSpace:
        reason = L.text(
          "剩余候选都放不下了。撤销后给大块留出空间。", "None of the remaining pieces fit. Undo to make room.")
      default:
        reason = L.text(
          "固定方块序列已用完，目标尚未充满。", "The piece sequence is exhausted before all lights are charged.")
      }
      let alert = UIAlertController(
        title: L.text("再试一条光路", "Try another path"), message: reason, preferredStyle: .alert)
      if !session.history.isEmpty {
        alert.addAction(
          UIAlertAction(title: L.text("撤销一步", "Undo last move"), style: .default) { [weak self] _ in
            self?.resultShown = false
            self?.undo()
          })
      }
      alert.addAction(
        UIAlertAction(title: L.text("重新挑战", "Try again"), style: .default) { [weak self] _ in
          self?.restart()
        })
      alert.addAction(
        UIAlertAction(title: returnTitle, style: .cancel) { [weak self] _ in
          self?.navigationController?.popToRootViewController(animated: true)
        })
      present(alert, animated: true)
    }
  }
  private func pauseGame() {
    settleAnimation()
    hintTask?.cancel()
    revision += 1
    let panel = UIAlertController(
      title: L.text("暂停修复", "Repair paused"),
      message: L.text("当前进度会保存在本机。", "Your progress is saved on this device."),
      preferredStyle: .alert)
    panel.addAction(
      UIAlertAction(title: L.text("继续", "Continue"), style: .cancel) { [weak self] _ in
        self?.finishIfNeeded()
      })
    panel.addAction(
      UIAlertAction(title: L.text("重新开始", "Restart"), style: .destructive) { [weak self] _ in
        self?.restart()
      })
    panel.addAction(
      UIAlertAction(title: returnTitle, style: .default) { [weak self] _ in
        self?.navigationController?.popToRootViewController(animated: true)
      })
    panel.addAction(
      UIAlertAction(title: L.text("玩法说明", "How to play"), style: .default) { [weak self] _ in
        self?.showRules()
      })
    present(panel, animated: true)
  }
  private func showRules() {
    navigationController?.pushViewController(DrairtunvurHelpViewController(), animated: true)
  }
}
