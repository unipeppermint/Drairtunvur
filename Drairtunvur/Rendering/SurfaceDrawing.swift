import UIKit

/// Shared glass material for the board and the draggable pieces.
@MainActor enum GlassDrawing {
  static func draw(in rect: CGRect, seed: Int = 0) {
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    let shape = UIBezierPath(roundedRect: rect, cornerRadius: 3)
    ctx.saveGState()
    shape.addClip()
    let gradient = CGGradient(
      colorsSpace: CGColorSpaceCreateDeviceRGB(),
      colors: [
        UIColor(red: 0.54, green: 0.76, blue: 0.72, alpha: 0.96).cgColor,
        UIColor(red: 0.19, green: 0.40, blue: 0.43, alpha: 0.96).cgColor,
        UIColor(red: 0.49, green: 0.66, blue: 0.58, alpha: 0.96).cgColor,
      ] as CFArray, locations: [0, 0.58, 1])!
    ctx.drawLinearGradient(
      gradient, start: rect.origin, end: CGPoint(x: rect.maxX, y: rect.maxY), options: [])
    for i in 0..<5 {
      let x = CGFloat((seed * 13 + i * 31 + 17) % 97) / 97
      let y = CGFloat((seed * 29 + i * 19 + 7) % 89) / 89
      let light = CGGradient(
        colorsSpace: CGColorSpaceCreateDeviceRGB(),
        colors: [
          Theme.cream.withAlphaComponent(i % 2 == 0 ? 0.30 : 0.13).cgColor, UIColor.clear.cgColor,
        ] as CFArray, locations: [0, 1])!
      let center = CGPoint(x: rect.minX + x * rect.width, y: rect.minY + y * rect.height)
      ctx.drawRadialGradient(
        light, startCenter: center, startRadius: 0, endCenter: center, endRadius: rect.width * 0.43,
        options: [])
    }
    let facet = UIBezierPath()
    facet.move(to: CGPoint(x: rect.minX, y: rect.minY + rect.height * 0.75))
    facet.addLine(to: CGPoint(x: rect.minX + rect.width * 0.7, y: rect.minY))
    facet.addLine(to: CGPoint(x: rect.minX + rect.width * 0.9, y: rect.minY))
    facet.addLine(to: CGPoint(x: rect.minX + rect.width * 0.2, y: rect.maxY))
    facet.close()
    UIColor.white.withAlphaComponent(0.08).setFill()
    facet.fill()
    ctx.restoreGState()
    Theme.cream.withAlphaComponent(0.75).setStroke()
    shape.lineWidth = 1
    shape.stroke()
    let shine = UIBezierPath()
    shine.move(to: CGPoint(x: rect.minX + 3, y: rect.maxY - 4))
    shine.addLine(to: CGPoint(x: rect.minX + 3, y: rect.minY + 3))
    shine.addLine(to: CGPoint(x: rect.maxX - 4, y: rect.minY + 3))
    UIColor.white.withAlphaComponent(0.32).setStroke()
    shine.lineWidth = 0.8
    shine.stroke()
  }
}

@MainActor enum LighthouseDrawing {
  static func image(lit: Bool) -> UIImage {
    UIGraphicsImageRenderer(size: CGSize(width: 30, height: 42)).image { _ in
      draw(in: CGRect(x: 2, y: 2, width: 26, height: 38), lit: lit)
    }
  }
  static func draw(in rect: CGRect, lit: Bool) {
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    ctx.saveGState()
    ctx.translateBy(x: rect.minX, y: rect.minY)
    ctx.scaleBy(x: rect.width / 30, y: rect.height / 42)
    let color = lit ? Theme.gold : Theme.muted
    if lit { ctx.setShadow(offset: .zero, blur: 5, color: Theme.gold.cgColor) }
    let tower = UIBezierPath()
    tower.move(to: CGPoint(x: 9, y: 19))
    tower.addLine(to: CGPoint(x: 21, y: 19))
    tower.addLine(to: CGPoint(x: 24, y: 38))
    tower.addLine(to: CGPoint(x: 6, y: 38))
    tower.close()
    (lit ? Theme.cream : Theme.panel).setFill()
    tower.fill()
    color.setStroke()
    tower.lineWidth = 1.5
    tower.stroke()
    let lantern = UIBezierPath(
      roundedRect: CGRect(x: 9, y: 8, width: 12, height: 11), cornerRadius: 1)
    color.withAlphaComponent(lit ? 1 : 0.25).setFill()
    lantern.fill()
    lantern.stroke()
    let roof = UIBezierPath()
    roof.move(to: CGPoint(x: 6, y: 8))
    roof.addLine(to: CGPoint(x: 15, y: 2))
    roof.addLine(to: CGPoint(x: 24, y: 8))
    roof.close()
    color.setStroke()
    roof.stroke()
    let lines = UIBezierPath()
    for y in [20, 38, 41] {
      lines.move(to: CGPoint(x: 4, y: y))
      lines.addLine(to: CGPoint(x: 26, y: y))
    }
    lines.move(to: CGPoint(x: 15, y: 9))
    lines.addLine(to: CGPoint(x: 15, y: 17))
    lines.lineWidth = 1.5
    lines.stroke()
    ctx.restoreGState()
  }
}

final class GoldButton: UIButton {
  private let goldLayer = CAGradientLayer()
  override init(frame: CGRect) {
    super.init(frame: frame)
    goldLayer.zPosition = -1
    goldLayer.colors = [
      UIColor(red: 1, green: 0.90, blue: 0.61, alpha: 1).cgColor, Theme.gold.cgColor,
      UIColor(red: 0.94, green: 0.65, blue: 0.29, alpha: 1).cgColor,
    ]
    goldLayer.startPoint = CGPoint(x: 0, y: 0)
    goldLayer.endPoint = CGPoint(x: 1, y: 1)
    goldLayer.borderWidth = 1.5
    goldLayer.borderColor = Theme.cream.cgColor
    layer.insertSublayer(goldLayer, at: 0)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func layoutSubviews() {
    super.layoutSubviews()
    CATransaction.begin()
    CATransaction.setDisableActions(true)
    goldLayer.frame = bounds
    goldLayer.cornerRadius = bounds.height / 2
    CATransaction.commit()
  }
}

/// Crop scenic artwork around its subject while preserving its aspect ratio.
final class SceneCropView: UIView {
  private let picture: UIImageView
  private let focus: CGFloat
  init(name: String, focus: CGFloat) {
    self.focus = focus
    picture = UIImageView(image: UIImage(named: name))
    super.init(frame: .zero)
    clipsToBounds = true
    isUserInteractionEnabled = false
    addSubview(picture)
  }
  required init?(coder: NSCoder) { fatalError() }
  override func layoutSubviews() {
    super.layoutSubviews()
    guard let size = picture.image?.size else { return }
    let scale = max(bounds.width / size.width, bounds.height / size.height)
    let width = size.width * scale
    let height = size.height * scale
    picture.frame = CGRect(
      x: (bounds.width - width) / 2,
      y: min(0, max(bounds.height - height, bounds.midY - height * focus)), width: width,
      height: height)
  }
}

final class MapNodeButton: UIButton {
  private let completed: Bool
  init(completed: Bool) {
    self.completed = completed
    super.init(frame: .zero)
    isOpaque = false
  }
  required init?(coder: NSCoder) { fatalError() }
  override func draw(_ rect: CGRect) {
    guard completed else {
      Theme.panel.setFill()
      UIBezierPath(ovalIn: bounds).fill()
      return
    }
    let pin = UIBezierPath()
    pin.move(to: CGPoint(x: bounds.midX, y: bounds.maxY))
    pin.addCurve(
      to: CGPoint(x: 7, y: 17), controlPoint1: CGPoint(x: 12, y: 31),
      controlPoint2: CGPoint(x: 7, y: 27))
    pin.addArc(
      withCenter: CGPoint(x: bounds.midX, y: 17), radius: 15, startAngle: .pi, endAngle: 0,
      clockwise: true)
    pin.addCurve(
      to: CGPoint(x: bounds.midX, y: bounds.maxY),
      controlPoint1: CGPoint(x: bounds.maxX - 7, y: 27), controlPoint2: CGPoint(x: 32, y: 31))
    Theme.gold.withAlphaComponent(0.75).setFill()
    pin.fill()
    Theme.cream.setStroke()
    pin.lineWidth = 1.5
    pin.stroke()
  }
}
