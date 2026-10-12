import LightworksCore
import UIKit

final class SceneDelegate: UIResponder, UIWindowSceneDelegate {
  var window: UIWindow?
  var coordinator: AppCoordinator?
  func scene(
    _ scene: UIScene, willConnectTo session: UISceneSession,
    options connectionOptions: UIScene.ConnectionOptions
  ) {
    guard let scene = scene as? UIWindowScene else { return }
    #if DEBUG
      let args = ProcessInfo.processInfo.arguments
      if let index = args.firstIndex(of: "-ui-language"), args.count > index + 1 {
        Preferences.language = args[index + 1]
      }
    #endif
    let window = UIWindow(windowScene: scene)
    self.window = window
    window.overrideUserInterfaceStyle = .dark
    coordinator = AppCoordinator(window: window)
    coordinator?.start()
  }
  func sceneWillResignActive(_ scene: UIScene) { AppModel.shared.persist() }
  func sceneDidEnterBackground(_ scene: UIScene) {
    let task = UIApplication.shared.beginBackgroundTask()
    Task {
      await AppModel.shared.flush()
      if task != .invalid { UIApplication.shared.endBackgroundTask(task) }
    }
  }
}

@MainActor final class AppCoordinator {
  let window: UIWindow
  let tabs = CityTabController()
  init(window: UIWindow) { self.window = window }
  func start() {
    let launch = UIViewController()
    launch.view.backgroundColor = Theme.navy
    let label = Theme.label(
      L.text("光路工坊", "Lightworks"), size: 34, weight: .bold, color: Theme.gold)
    label.translatesAutoresizingMaskIntoConstraints = false
    launch.view.addSubview(label)
    NSLayoutConstraint.activate([
      label.centerXAnchor.constraint(equalTo: launch.view.centerXAnchor),
      label.centerYAnchor.constraint(equalTo: launch.view.centerYAnchor),
    ])
    window.rootViewController = launch
    window.makeKeyAndVisible()
    Task {
      await AppModel.shared.load()
      setup()
    }
  }
  private func setup() {
    let city = UINavigationController(rootViewController: CityViewController())
    let daily = UINavigationController(rootViewController: DailyViewController())
    let collection = UINavigationController(rootViewController: CollectionViewController())
    for nav in [city, daily, collection] {
      nav.setNavigationBarHidden(true, animated: false)
      nav.interactivePopGestureRecognizer?.isEnabled = false
    }
    city.tabBarItem = UITabBarItem(
      title: L.text("城市", "City"), image: UIImage(systemName: "house"),
      selectedImage: UIImage(systemName: "house.fill"))
    collection.tabBarItem = UITabBarItem(
      title: L.text("图鉴", "Collection"), image: UIImage(systemName: "book.closed"),
      selectedImage: UIImage(systemName: "book.closed.fill"))
    tabs.viewControllers = [city, daily, collection]
    window.rootViewController = tabs
    updateTitles()
    NotificationCenter.default.addObserver(
      self, selector: #selector(updateTitles), name: .languageChanged, object: nil)
    if !AppModel.shared.save.tutorialCompleted {
      city.pushViewController(GameViewController(level: AppModel.shared.levels[0]), animated: false)
    }
    #if DEBUG
      let args = ProcessInfo.processInfo.arguments
      if let index = args.firstIndex(of: "-ui-test-level"), args.count > index + 1,
        let level = AppModel.shared.level(args[index + 1])
      {
        city.setViewControllers(
          [city.viewControllers[0], GameViewController(level: level, restart: true)],
          animated: false)
      }
    #endif
  }
  @objc private func updateTitles() {
    tabs.viewControllers?[0].tabBarItem.title = L.text("城市", "City")
    tabs.viewControllers?[0].tabBarItem.accessibilityIdentifier = "tab.city"
    tabs.viewControllers?[1].tabBarItem.title = L.text("每日", "Daily")
    tabs.viewControllers?[1].tabBarItem.accessibilityIdentifier = "tab.daily"
    tabs.viewControllers?[2].tabBarItem.title = L.text("图鉴", "Collection")
    tabs.viewControllers?[2].tabBarItem.accessibilityIdentifier = "tab.collection"
    tabs.updateButtons()
  }
}
