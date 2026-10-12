import UIKit

/// A full-width navigation shelf matching the illustrated city screens.
final class CityTabController: UIViewController, UINavigationControllerDelegate {
  var viewControllers: [UIViewController]? {
    didSet { if isViewLoaded { displaySelected() } }
  }
  private var selectedIndex = 0
  private let shelf = UIView()
  private let row = UIStackView()
  private var active: UIViewController?
  override var childForStatusBarStyle: UIViewController? { active }
  override func viewDidLoad() {
    super.viewDidLoad()
    view.backgroundColor = Theme.navy
    shelf.backgroundColor = Theme.navy.withAlphaComponent(0.97)
    shelf.layer.cornerRadius = 24
    shelf.layer.maskedCorners = [.layerMinXMinYCorner, .layerMaxXMinYCorner]
    shelf.layer.borderWidth = 1
    shelf.layer.borderColor = Theme.teal.withAlphaComponent(0.45).cgColor
    shelf.translatesAutoresizingMaskIntoConstraints = false
    view.addSubview(shelf)
    row.axis = .horizontal
    row.distribution = .fillEqually
    row.translatesAutoresizingMaskIntoConstraints = false
    shelf.addSubview(row)
    NSLayoutConstraint.activate([
      shelf.leadingAnchor.constraint(equalTo: view.leadingAnchor),
      shelf.trailingAnchor.constraint(equalTo: view.trailingAnchor),
      shelf.bottomAnchor.constraint(equalTo: view.bottomAnchor),
      shelf.topAnchor.constraint(equalTo: view.safeAreaLayoutGuide.bottomAnchor, constant: -62),
      row.leadingAnchor.constraint(equalTo: shelf.leadingAnchor),
      row.trailingAnchor.constraint(equalTo: shelf.trailingAnchor),
      row.topAnchor.constraint(equalTo: shelf.topAnchor, constant: 3),
      row.heightAnchor.constraint(equalToConstant: 56),
    ])
    displaySelected()
  }
  func updateButtons() {
    guard isViewLoaded else { return }
    row.arrangedSubviews.forEach {
      row.removeArrangedSubview($0)
      $0.removeFromSuperview()
    }
    for (index, controller) in (viewControllers ?? []).enumerated() {
      let button = UIButton(type: .system)
      var configuration = UIButton.Configuration.plain()
      configuration.title = controller.tabBarItem.title
      configuration.image = UIImage(systemName: ["house", "calendar", "book"][index])
      configuration.imagePlacement = .top
      configuration.imagePadding = 3
      configuration.baseForegroundColor = index == selectedIndex ? Theme.gold : Theme.muted
      configuration.preferredSymbolConfigurationForImage = UIImage.SymbolConfiguration(
        pointSize: 22)
      configuration.titleTextAttributesTransformer = UIConfigurationTextAttributesTransformer {
        input in
        var output = input
        output.font = .systemFont(ofSize: 12, weight: .medium)
        return output
      }
      button.configuration = configuration
      button.accessibilityIdentifier = ["tab.city", "tab.daily", "tab.collection"][index]
      button.accessibilityTraits = index == selectedIndex ? [.button, .selected] : .button
      button.addAction(
        UIAction { [weak self] _ in
          self?.selectedIndex = index
          self?.displaySelected()
        }, for: .touchUpInside)
      row.addArrangedSubview(button)
    }
  }
  private func displaySelected() {
    guard let controllers = viewControllers, controllers.indices.contains(selectedIndex) else {
      return
    }
    if let active {
      active.willMove(toParent: nil)
      active.view.removeFromSuperview()
      active.removeFromParent()
    }
    let controller = controllers[selectedIndex]
    active = controller
    addChild(controller)
    view.insertSubview(controller.view, belowSubview: shelf)
    controller.view.frame = view.bounds
    controller.view.autoresizingMask = [.flexibleWidth, .flexibleHeight]
    controller.didMove(toParent: self)
    for nav in controllers.compactMap({ $0 as? UINavigationController }) { nav.delegate = self }
    updateShelf()
    updateButtons()
    setNeedsStatusBarAppearanceUpdate()
  }
  private func updateShelf(for next: UIViewController? = nil) {
    let nav = active as? UINavigationController
    let hidden = (next ?? nav?.topViewController)?.hidesBottomBarWhenPushed == true
    shelf.isHidden = hidden
    active?.additionalSafeAreaInsets.bottom = hidden ? 0 : 62
  }
  func navigationController(
    _ navigationController: UINavigationController, willShow viewController: UIViewController,
    animated: Bool
  ) {
    guard navigationController === active else { return }
    updateShelf(for: viewController)
  }
}
