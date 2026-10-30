import UIKit

final class SettingsViewController: ScreenController {
  init() {
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    refresh()
  }
  @objc private func refresh() {
    guard isViewLoaded else { return }
    clearContent()
    header("Settings")
    content.addArrangedSubview(
      Theme.label("Make yourself at home", size: 25, weight: .semibold))
    toggle("Sound effects", symbol: "speaker.wave.2", value: Preferences.sound) {
      Preferences.sound = $0
    }
    toggle("Haptic feedback", symbol: "hand.tap", value: Preferences.haptics) {
      Preferences.haptics = $0
    }
    toggle("Reduce motion", symbol: "sparkles", value: Preferences.reduceMotion) {
      Preferences.reduceMotion = $0
    }
    content.addArrangedSubview(
      Theme.button("How to play", symbol: "questionmark.circle") { [weak self] in
        self?.navigationController?.pushViewController(
          DrairtunvurHelpViewController(), animated: true)
      })
    let model = AppModel.shared
    if model.storageNeedsRecovery {
      content.addArrangedSubview(
        Theme.label(
          model.loadMessage ?? "Save needs recovery", size: 14, color: Theme.gold)
      )
      let retry = Theme.button("Try reading again", symbol: "arrow.clockwise") {
        [weak self] in
        Task { [weak self] in
          let recovered = await model.recoverStorage(reset: false)
          self?.refresh()
          if !recovered {
            self?.alert(
              "Unable to read save",
              "The original files are unchanged. You can keep copies and start fresh.")
          }
        }
      }
      retry.accessibilityIdentifier = "settings.recover"
      content.addArrangedSubview(retry)
      let reset = Theme.button(
        "Keep copies and start fresh", symbol: "archivebox"
      ) { [weak self] in self?.confirmRecovery() }
      reset.accessibilityIdentifier = "settings.reset"
      content.addArrangedSubview(reset)
    } else if let message = model.saveError {
      content.addArrangedSubview(Theme.label(message, size: 13, color: Theme.gold))
      content.addArrangedSubview(
        Theme.button("Retry saving", symbol: "arrow.clockwise") { [weak self] in
          Task { [weak self] in
            model.persist()
            await model.flush()
            self?.refresh()
            if model.saveError == nil {
              self?.alert(
                "Saved",
                "Your progress is saved on this device.")
            }
          }
        })
    }
    content.addArrangedSubview(
      Theme.label("About Lightworks", size: 21, weight: .semibold))
    let about =
      "One city, forty-five paths of light.\nFrom the quiet harbor to the midnight station, bring each scene to life.\n\nPlay offline. Progress is saved on this device and is removed if you delete the app."
    let panel = Theme.inset(Theme.label(about, size: 14, color: Theme.muted))
    Theme.panel(panel)
    content.addArrangedSubview(panel)
    content.addArrangedSubview(
      Theme.label(
        "Need help? Export issue details, describe what happened, and contact support through the App Store product page. Details are sent only when you choose to share them.",
        size: 13, color: Theme.muted))
    let support = Theme.button(
      "Export issue details", symbol: "square.and.arrow.up"
    ) { [weak self] in
      guard let self else { return }
      DrairtunvurSupport.share(from: self)
    }
    support.accessibilityIdentifier = "settings.support"
    content.addArrangedSubview(support)
    content.addArrangedSubview(
      Theme.button("Privacy", symbol: "hand.raised") { [weak self] in
        self?.alert(
          "Privacy",
          "Game progress and settings stay on your device and are not uploaded by the app. When exporting issue details, you can review the contents before choosing how to share them."
        )
      })
  }
  private func confirmRecovery() {
    let dialog = UIAlertController(
      title: "Start fresh?",
      message:
        "Copies of the original save files will be kept on this device before creating a new save. Old progress will not be merged automatically.",
      preferredStyle: .alert)
    dialog.addAction(UIAlertAction(title: "Cancel", style: .cancel))
    dialog.addAction(
      UIAlertAction(title: "Keep copies and reset", style: .destructive) {
        [weak self] _ in
        Task { [weak self] in
          let recovered = await AppModel.shared.recoverStorage(reset: true)
          self?.refresh()
          self?.alert(
            recovered ? "New save created" : "Recovery failed",
            recovered
              ? "Copies of the original save files were kept on this device."
              : "Check the available device storage and try again.")
        }
      })
    present(dialog, animated: true)
  }
  private func toggle(
    _ title: String, symbol: String, value: Bool, change: @escaping (Bool) -> Void
  ) {
    let icon = UIImageView(image: UIImage(systemName: symbol))
    icon.tintColor = Theme.gold
    icon.widthAnchor.constraint(equalToConstant: 26).isActive = true
    icon.contentMode = .scaleAspectFit
    let label = Theme.label(title)
    let control = UISwitch()
    control.isOn = value
    control.onTintColor = Theme.teal
    control.accessibilityLabel = title
    control.addAction(
      UIAction { [weak control] _ in if let control { change(control.isOn) } }, for: .valueChanged)
    let row = Theme.inset(
      Theme.stack([icon, label, control], axis: .horizontal, spacing: 12), by: 14)
    Theme.panel(row)
    content.addArrangedSubview(row)
  }
}
