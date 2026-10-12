import LightworksCore
import UIKit

final class BoardCellElement: UIAccessibilityElement {
  var activate: (() -> Void)?
  override func accessibilityActivate() -> Bool {
    activate?()
    return true
  }
}
final class BoardView: UIView {
  var level: LevelDefinition! { didSet { setNeedsDisplay() } }
  var state: GameState! {
    didSet {
      rebuildAccessibility()
      setNeedsDisplay()
    }
  }
  var preview: Resolution? { didSet { setNeedsDisplay() } }
  var invalidCells: [Cell] = [] { didSet { setNeedsDisplay() } }
  var hintMove: Move? { didSet { setNeedsDisplay() } }
  var onTap: ((Cell) -> Void)?
  var pulse: Resolution? {
    didSet {
      layer.sublayers?.filter { $0.name == "pulse" }.forEach { $0.removeFromSuperlayer() }
      if let event = pulse, event.hasPulse, !Preferences.reduceMotion { animatePulse(event) }
      setNeedsDisplay()
    }
  }
  private func animatePulse(_ event: Resolution) {
    let path = UIBezierPath()
    for row in 0..<8 {
      for col in 0..<8 {
        let cell = Cell(row, col)
        guard event.connected & cell.bit != 0 else { continue }
        for next in [Cell(row + 1, col), Cell(row, col + 1)]
        where next.isValid && event.connected & next.bit != 0 {
          let a = rect(for: cell)
          let b = rect(for: next)
          path.move(to: CGPoint(x: a.midX, y: a.midY))
          path.addLine(to: CGPoint(x: b.midX, y: b.midY))
        }
      }
    }
    let beam = CAShapeLayer()
    beam.name = "pulse"
    beam.path = path.cgPath
    beam.strokeColor = Theme.cream.cgColor
    beam.fillColor = nil
    beam.lineWidth = 3
    beam.shadowColor = Theme.gold.cgColor
    beam.shadowOpacity = 1
    beam.shadowRadius = 10
    beam.shadowOffset = .zero
    layer.addSublayer(beam)
    let trace = CABasicAnimation(keyPath: "strokeEnd")
    trace.fromValue = 0
    trace.toValue = 1
    trace.duration = 0.32
    beam.add(trace, forKey: "trace")
    let fade = CABasicAnimation(keyPath: "opacity")
    fade.fromValue = 1
    fade.toValue = 0
    fade.beginTime = CACurrentMediaTime() + 0.38
    fade.duration = 0.25
    fade.fillMode = .forwards
    fade.isRemovedOnCompletion = false
    beam.add(fade, forKey: "fade")
  }
  private var axCells = [BoardCellElement]()
  var gridRect: CGRect { bounds.insetBy(dx: 6, dy: 6) }
  var unit: CGFloat { gridRect.width / 8 }
  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    backgroundColor = Theme.navy.withAlphaComponent(0.97)
    layer.cornerRadius = 18
    layer.borderWidth = 1
    layer.borderColor = Theme.muted.withAlphaComponent(0.3).cgColor
    addGestureRecognizer(UITapGestureRecognizer(target: self, action: #selector(tapped(_:))))
    accessibilityIdentifier = "game.board"
  }
  required init?(coder: NSCoder) { fatalError() }
  func cell(at point: CGPoint) -> Cell? {
    guard gridRect.contains(point) else { return nil }
    return Cell(Int((point.y - gridRect.minY) / unit), Int((point.x - gridRect.minX) / unit))
  }
  func rect(for cell: Cell) -> CGRect {
    CGRect(
      x: gridRect.minX + CGFloat(cell.col) * unit, y: gridRect.minY + CGFloat(cell.row) * unit,
      width: unit, height: unit
    ).insetBy(dx: 2, dy: 2)
  }
  @objc private func tapped(_ g: UITapGestureRecognizer) {
    if let cell = cell(at: g.location(in: self)) { onTap?(cell) }
  }
  override func layoutSubviews() {
    super.layoutSubviews()
    rebuildAccessibility()
    setNeedsDisplay()
  }
  private func rebuildAccessibility() {
    guard let state, let level else { return }
    axCells = (0..<64).map { index in
      let cell = Cell(index / 8, index % 8)
      let element = BoardCellElement(accessibilityContainer: self)
      var description = L.text(
        "第 \(cell.row+1) 行，第 \(cell.col+1) 列", "Row \(cell.row+1), column \(cell.col+1)")
      description += state.contains(cell) ? L.text("，已占用", ", occupied") : L.text("，空格", ", empty")
      if cell == level.sourceEntry { description += L.text("，光源入口", ", light source") }
      if let i = level.targets.firstIndex(where: { $0.cell == cell }) {
        description += ", \(level.targets[i].id), \(state.energy[i])/\(level.targets[i].capacity)"
      }
      element.accessibilityLabel = description
      element.accessibilityTraits = .button
      element.accessibilityIdentifier = "cell.\(cell.row).\(cell.col)"
      element.accessibilityFrameInContainerSpace = rect(for: cell)
      element.activate = { [weak self] in self?.onTap?(cell) }
      return element
    }
    accessibilityElements = axCells
  }
  override func draw(_ dirty: CGRect) {
    guard let ctx = UIGraphicsGetCurrentContext(), let state, let level else { return }
    let rendered = pulse?.beforeClear ?? state.board
    let reachable =
      preview?.connected ?? pulse?.connected
      ?? Rules.reachable(board: rendered, source: level.sourceEntry)
    for row in 0..<8 {
      for col in 0..<8 {
        let cell = Cell(row, col)
        let rect = rect(for: cell)
        let path = UIBezierPath(roundedRect: rect, cornerRadius: 4)
        let filled = rendered & cell.bit != 0
        if filled {
          GlassDrawing.draw(in: rect, seed: row * 8 + col)
        } else {
          UIColor.white.withAlphaComponent(0.035).setFill()
          path.fill()
          Theme.muted.withAlphaComponent(0.15).setStroke()
          path.lineWidth = 0.8
          path.stroke()
        }
      }
    }
    // Orthogonal light links are rendered from exactly the same reachability mask as the resolver.
    ctx.saveGState()
    ctx.setShadow(offset: .zero, blur: 8, color: Theme.gold.cgColor)
    let route = UIBezierPath()
    route.lineWidth = 2.5
    route.lineCapStyle = .round
    for row in 0..<8 {
      for col in 0..<8 {
        let cell = Cell(row, col)
        guard reachable & cell.bit != 0 else { continue }
        for next in [Cell(row + 1, col), Cell(row, col + 1)]
        where next.isValid && reachable & next.bit != 0 {
          let a = rect(for: cell)
          let b = rect(for: next)
          route.move(to: CGPoint(x: a.midX, y: a.midY))
          route.addLine(to: CGPoint(x: b.midX, y: b.midY))
        }
      }
    }
    Theme.gold.withAlphaComponent(preview == nil && pulse == nil ? 0.55 : 1).setStroke()
    route.stroke()
    ctx.restoreGState()
    if let preview {
      for cell in preview.placed {
        let path = UIBezierPath(roundedRect: rect(for: cell), cornerRadius: 4)
        Theme.gold.withAlphaComponent(0.22).setFill()
        path.fill()
        Theme.gold.setStroke()
        path.lineWidth = 2
        path.setLineDash([4, 2], count: 2, phase: 0)
        path.stroke()
      }
      for i in 0..<64 where preview.cleared & (UInt64(1) << i) != 0 {
        Theme.gold.withAlphaComponent(0.09).setFill()
        UIBezierPath(roundedRect: rect(for: Cell(i / 8, i % 8)), cornerRadius: 4).fill()
      }
    }
    for cell in invalidCells where cell.isValid {
      UIColor.systemRed.withAlphaComponent(0.5).setFill()
      UIBezierPath(roundedRect: rect(for: cell), cornerRadius: 4).fill()
    }
    if let hint = hintMove, let piece = state.candidates[hint.slot] {
      for cell in piece.translated(to: hint.anchor) {
        let p = UIBezierPath(roundedRect: rect(for: cell), cornerRadius: 4)
        Theme.gold.withAlphaComponent(0.16).setFill()
        p.fill()
        Theme.gold.setStroke()
        p.lineWidth = 2.5
        p.setLineDash([5, 3], count: 2, phase: 0)
        p.stroke()
      }
    }
    for (i, target) in level.targets.enumerated() {
      let r = rect(for: target.cell)
      let center = CGPoint(x: r.midX, y: r.midY - 3)
      let completed = state.energy[i] >= target.capacity
      let glow =
        preview?.chargedTargets.contains(i) == true || pulse?.chargedTargets.contains(i) == true
      ctx.saveGState()
      if completed || glow { ctx.setShadow(offset: .zero, blur: 9, color: Theme.gold.cgColor) }
      LighthouseDrawing.draw(
        in: CGRect(
          x: center.x - unit * 0.23, y: r.minY + 2, width: unit * 0.46, height: unit * 0.70),
        lit: completed || glow || state.energy[i] > 0)
      for e in 0..<target.capacity {
        let dot = CGRect(
          x: r.midX - CGFloat(target.capacity) * 4 + CGFloat(e) * 8 + 1, y: r.maxY - 7, width: 6,
          height: 3)
        (e < state.energy[i] ? Theme.gold : Theme.muted.withAlphaComponent(0.45)).setFill()
        UIBezierPath(roundedRect: dot, cornerRadius: 1).fill()
      }
      ctx.restoreGState()
    }
    let sourceRect = rect(for: level.sourceEntry)
    var point = CGPoint(x: sourceRect.midX, y: sourceRect.midY)
    if level.sourceEntry.col == 0 {
      point.x = 5
    } else if level.sourceEntry.col == 7 {
      point.x = bounds.maxX - 5
    } else if level.sourceEntry.row == 0 {
      point.y = 5
    } else {
      point.y = bounds.maxY - 5
    }
    ctx.setShadow(offset: .zero, blur: 9, color: Theme.gold.cgColor)
    Theme.gold.setFill()
    UIBezierPath(ovalIn: CGRect(x: point.x - 4, y: point.y - 4, width: 8, height: 8)).fill()
  }
}

final class PieceView: UIControl {
  var piece: Piece? {
    didSet {
      isEnabled = piece != nil
      setNeedsDisplay()
    }
  }
  var highlightedPiece = false { didSet { setNeedsDisplay() } }
  var slot = 0
  var onPan: ((UIPanGestureRecognizer, Int) -> Void)?
  override init(frame: CGRect) {
    super.init(frame: frame)
    isOpaque = false
    clipsToBounds = true
    backgroundColor = Theme.panel
    layer.cornerRadius = 16
    layer.borderWidth = 1
    layer.borderColor = Theme.muted.withAlphaComponent(0.2).cgColor
    addGestureRecognizer(UIPanGestureRecognizer(target: self, action: #selector(pan(_:))))
    isAccessibilityElement = true
    accessibilityTraits = .button
  }
  required init?(coder: NSCoder) { fatalError() }
  @objc private func pan(_ g: UIPanGestureRecognizer) { onPan?(g, slot) }
  override func draw(_ rect: CGRect) {
    layer.borderColor =
      (highlightedPiece ? Theme.gold : Theme.muted.withAlphaComponent(0.2)).cgColor
    layer.borderWidth = highlightedPiece ? 2 : 1
    guard let piece else {
      let text = "✓"
      text.draw(
        at: CGPoint(x: bounds.midX - 8, y: bounds.midY - 12),
        withAttributes: [
          .font: UIFont.systemFont(ofSize: 23),
          .foregroundColor: Theme.muted.withAlphaComponent(0.4),
        ])
      return
    }
    let w = (piece.cells.map(\.col).max() ?? 0) + 1
    let h = (piece.cells.map(\.row).max() ?? 0) + 1
    let unit = min(30, min((bounds.width - 22) / CGFloat(w), (bounds.height - 22) / CGFloat(h)))
    let origin = CGPoint(
      x: (bounds.width - CGFloat(w) * unit) / 2, y: (bounds.height - CGFloat(h) * unit) / 2)
    for cell in piece.cells {
      let r = CGRect(
        x: origin.x + CGFloat(cell.col) * unit + 1, y: origin.y + CGFloat(cell.row) * unit + 1,
        width: unit - 2, height: unit - 2)
      GlassDrawing.draw(in: r, seed: cell.row * 8 + cell.col + slot * 13)
    }
  }
}
