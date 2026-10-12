import UIKit

@MainActor enum Theme {
  static let navy = UIColor(red: 0.025, green: 0.075, blue: 0.12, alpha: 1)
  static let panel = UIColor(red: 0.035, green: 0.11, blue: 0.16, alpha: 0.94)
  static let gold = UIColor(red: 1, green: 0.79, blue: 0.40, alpha: 1)
  static let cream = UIColor(red: 1, green: 0.95, blue: 0.82, alpha: 1)
  static let muted = UIColor(red: 0.66, green: 0.77, blue: 0.80, alpha: 1)
  static let teal = UIColor(red: 0.28, green: 0.61, blue: 0.62, alpha: 1)
  static func label(
    _ text: String, size: CGFloat = 16, weight: UIFont.Weight = .regular, color: UIColor? = nil
  ) -> UILabel {
    let label = UILabel()
    label.text = text
    label.textColor = color ?? cream
    label.font = UIFontMetrics(forTextStyle: size >= 28 ? .title1 : .body).scaledFont(
      for: UIFont.systemFont(ofSize: size, weight: weight), maximumPointSize: size * 1.35)
    label.adjustsFontForContentSizeCategory = true
    label.numberOfLines = 0
    return label
  }
  static func button(
    _ title: String, symbol: String? = nil, primary: Bool = false, action: @escaping () -> Void
  ) -> UIButton {
    let button: UIButton = primary ? GoldButton(frame: .zero) : UIButton(type: .system)
    var config = primary ? UIButton.Configuration.filled() : UIButton.Configuration.tinted()
    config.title = title
    config.baseForegroundColor = primary ? navy : cream
    config.baseBackgroundColor = primary ? .clear : panel
    config.background.strokeColor = primary ? .clear : muted.withAlphaComponent(0.35)
    config.background.strokeWidth = primary ? 0 : 1
    config.cornerStyle = .capsule
    config.contentInsets = NSDirectionalEdgeInsets(top: 13, leading: 18, bottom: 13, trailing: 18)
    if let symbol {
      config.image = UIImage(systemName: symbol)
      config.imagePadding = 8
    }
    config.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer { incoming in
      var attributes = incoming
      attributes.font = UIFont.systemFont(ofSize: primary ? 20 : 16, weight: .semibold)
      return attributes
    }
    button.configuration = config
    button.titleLabel?.font = UIFont.systemFont(ofSize: 16, weight: .semibold)
    button.heightAnchor.constraint(greaterThanOrEqualToConstant: primary ? 58 : 46).isActive = true
    button.addAction(UIAction { _ in action() }, for: .touchUpInside)
    if primary {
      button.layer.shadowColor = gold.cgColor
      button.layer.shadowOpacity = 0.24
      button.layer.shadowRadius = 16
      button.layer.shadowOffset = .zero
    }
    return button
  }
  static func panel(_ view: UIView, radius: CGFloat = 14) {
    view.backgroundColor = panel
    view.layer.cornerRadius = radius
    view.layer.borderColor = muted.withAlphaComponent(0.22).cgColor
    view.layer.borderWidth = 1
  }
  static func stack(
    _ views: [UIView], axis: NSLayoutConstraint.Axis = .vertical, spacing: CGFloat = 12
  ) -> UIStackView {
    let stack = UIStackView(arrangedSubviews: views)
    stack.axis = axis
    stack.spacing = spacing
    return stack
  }
  static func inset(_ view: UIView, by inset: CGFloat = 16) -> UIView {
    let wrapper = UIView()
    wrapper.addSubview(view)
    view.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      view.leadingAnchor.constraint(equalTo: wrapper.leadingAnchor, constant: inset),
      view.trailingAnchor.constraint(equalTo: wrapper.trailingAnchor, constant: -inset),
      view.topAnchor.constraint(equalTo: wrapper.topAnchor, constant: inset),
      view.bottomAnchor.constraint(equalTo: wrapper.bottomAnchor, constant: -inset),
    ])
    return wrapper
  }
}

final class SceneBackdrop: UIView {
  let picture = UIImageView()
  private let shade = CAGradientLayer()
  private let lights = CALayer()
  var chapter = 1 {
    didSet { picture.image = UIImage(named: ["harbor-v2", "greenhouse", "station"][chapter - 1]) }
  }
  var progress: CGFloat = 0 { didSet { lights.opacity = Float(0.15 + 0.85 * progress) } }
  init(chapter: Int, dark: Bool = false) {
    super.init(frame: .zero)
    self.chapter = chapter
    isUserInteractionEnabled = false
    picture.image = UIImage(named: ["harbor-v2", "greenhouse", "station"][chapter - 1])
    picture.contentMode = .scaleAspectFill
    picture.clipsToBounds = true
    addSubview(picture)
    shade.colors = [
      Theme.navy.withAlphaComponent(dark ? 0.54 : 0.18).cgColor,
      Theme.navy.withAlphaComponent(dark ? 0.50 : 0.00).cgColor,
      Theme.navy.withAlphaComponent(dark ? 0.87 : 0.65).cgColor,
    ]
    shade.locations = [0, 0.40, 1]
    layer.addSublayer(shade)
    layer.addSublayer(lights)
    lights.isHidden = dark
    for i in 0..<12 {
      let dot = CALayer()
      dot.backgroundColor = Theme.gold.cgColor
      dot.cornerRadius = 2
      dot.shadowColor = Theme.gold.cgColor
      dot.shadowRadius = 9
      dot.shadowOpacity = 1
      dot.shadowOffset = .zero
      dot.name = "\(i)"
      lights.addSublayer(dot)
    }
    accessibilityElementsHidden = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func layoutSubviews() {
    super.layoutSubviews()
    picture.frame = bounds
    shade.frame = bounds
    lights.frame = bounds
    for (i, dot) in (lights.sublayers ?? []).enumerated() {
      let x = CGFloat((i * 37 + 19) % 100) / 100
      let y = CGFloat((i * 17 + 43) % 45 + 38) / 100
      dot.frame = CGRect(x: bounds.width * x, y: bounds.height * y, width: 3, height: 3)
    }
  }
}

class ScreenController: UIViewController {
  let scroll = UIScrollView()
  let content = UIStackView()
  var contentMaximumWidth: NSLayoutConstraint!
  var background: SceneBackdrop!
  var sceneChapter = 1
  var dimScene = true
  override var preferredStatusBarStyle: UIStatusBarStyle { .lightContent }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Theme.navy
    background = SceneBackdrop(chapter: sceneChapter, dark: dimScene)
    view.addSubview(background)
    background.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      background.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      background.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      background.topAnchor.constraint(equalTo: view.topAnchor),
      background.bottomAnchor.constraint(equalTo: view.bottomAnchor),
    ])
    scroll.contentLayoutGuide.widthAnchor.constraint(equalTo: scroll.frameLayoutGuide.widthAnchor)
      .isActive = true
    scroll.showsVerticalScrollIndicator = false
    scroll.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(scroll)
    NSLayoutConstraint.activate([
      scroll.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.topAnchor),
      scroll.bottomAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor),
      scroll.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      scroll.trailingAnchor.constraint(equalTo: view.trailingAnchor),
    ])
    content.axis = .vertical
    content.spacing = 14
    content.translatesAutoresizingMaskIntoConstraints = false
    scroll.addSubview(content)
    contentMaximumWidth = content.widthAnchor.constraint(lessThanOrEqualToConstant: 560)
    let width = content.widthAnchor.constraint(
      equalTo: scroll.frameLayoutGuide.widthAnchor, constant: -40)
    width.priority = UILayoutPriority(999)
    NSLayoutConstraint.activate([
      content.topAnchor.constraint(equalTo: scroll.contentLayoutGuide.topAnchor, constant: 12),
      content.bottomAnchor.constraint(
        equalTo: scroll.contentLayoutGuide.bottomAnchor, constant: -20),
      content.centerXAnchor.constraint(equalTo: scroll.centerXAnchor), width,
      contentMaximumWidth,
    ])
  }
  func clearContent() {
    content.arrangedSubviews.forEach {
      content.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }
  }
  func header(_ title: String, trailing: UIView? = nil, back: Bool = true) {
    let label = Theme.label(title, size: 17, weight: .semibold)
    label.textAlignment = .center
    var items = [UIView]()
    if back {
      let b = Theme.button("", symbol: "chevron.left") { [weak self] in
        self?.navigationController?.popViewController(animated: true)
      }
      b.accessibilityLabel = L.text("返回", "Back")
      b.widthAnchor.constraint(equalToConstant: 48).isActive = true
      items.append(b)
    }
    items.append(label)
    if let trailing { items.append(trailing) }
    content.addArrangedSubview(Theme.stack(items, axis: .horizontal, spacing: 8))
  }
  func alert(_ title: String, _ message: String) {
    let alert = UIAlertController(title: title, message: message, preferredStyle: .alert)
    alert.addAction(UIAlertAction(title: L.text("知道了", "OK"), style: .default))
    present(alert, animated: true)
  }
}
