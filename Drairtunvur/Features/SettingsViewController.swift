import UIKit

final class SettingsViewController: ScreenController {
  override func viewDidLoad() {
    super.viewDidLoad()
    hidesBottomBarWhenPushed = true
    refresh()
  }
  @objc private func refresh() {
    guard isViewLoaded else { return }
    clearContent()
    header(L.text("设置", "Settings"))
    content.addArrangedSubview(
      Theme.label(L.text("以喜欢的方式点亮城市", "Make yourself at home"), size: 25, weight: .semibold))
    toggle(L.text("音效", "Sound effects"), symbol: "speaker.wave.2", value: Preferences.sound) {
      Preferences.sound = $0
    }
    toggle(L.text("触觉反馈", "Haptic feedback"), symbol: "hand.tap", value: Preferences.haptics) {
      Preferences.haptics = $0
    }
    toggle(L.text("减少动画", "Reduce motion"), symbol: "sparkles", value: Preferences.reduceMotion) {
      Preferences.reduceMotion = $0
    }
    content.addArrangedSubview(Theme.label(L.text("语言", "Language"), size: 16, weight: .semibold))
    let language = UISegmentedControl(items: [L.text("跟随系统", "System"), "简体中文", "English"])
    language.selectedSegmentIndex =
      ["system", "zh-Hans", "en"].firstIndex(of: Preferences.language) ?? 0
    language.selectedSegmentTintColor = Theme.gold
    language.setTitleTextAttributes([.foregroundColor: Theme.cream], for: .normal)
    language.setTitleTextAttributes([.foregroundColor: Theme.navy], for: .selected)
    language.heightAnchor.constraint(equalToConstant: 44).isActive = true
    language.addAction(
      UIAction { [weak self, weak language] _ in
        guard let language else { return }
        Preferences.language = ["system", "zh-Hans", "en"][language.selectedSegmentIndex]
        self?.refresh()
      }, for: .valueChanged)
    language.accessibilityIdentifier = "settings.language"
    content.addArrangedSubview(language)
    if let message = AppModel.shared.saveError {
      content.addArrangedSubview(Theme.label(message, size: 13, color: Theme.gold))
      content.addArrangedSubview(
        Theme.button(L.text("重试保存", "Retry saving"), symbol: "arrow.clockwise") {
          AppModel.shared.persist()
        })
    }
    content.addArrangedSubview(
      Theme.label(L.text("关于光路工坊", "About Lightworks"), size: 21, weight: .semibold))
    let about = L.text(
      "一座城市，四十五条光路。\n三章共 45 关，按通关顺序逐步开放。\n没有广告、没有账号，关卡可离线游玩。\n\n进度保存在本机。首版不提供云端同步，删除应用可能删除本地进度。\n\n支持信息：如遇问题，请记录关卡编号、系统版本和复现步骤，并反馈给应用提供者。\n版本 1.0 · 本地首版",
      "One city, forty-five paths of light.\nThree chapters and 45 levels, unlocked as you progress.\nNo ads or account. Play all unlocked levels offline.\n\nProgress is stored on this device. Cloud sync is not available in this version. Deleting the app may delete local progress.\n\nSupport: record the level number, iOS version, and steps to reproduce the issue, then share them with the app provider.\nVersion 1.0 · Local first edition"
    )
    let panel = Theme.inset(Theme.label(about, size: 14, color: Theme.muted))
    Theme.panel(panel)
    content.addArrangedSubview(panel)
    content.addArrangedSubview(
      Theme.button(L.text("隐私说明", "Privacy"), symbol: "hand.raised") { [weak self] in
        self?.alert(
          L.text("隐私说明", "Privacy"),
          L.text(
            "本应用不创建业务账号，不接入广告或第三方分析服务，不向业务服务器上传对局。关卡、进度和偏好保存在设备中。没有内购功能。",
            "This app has no account, advertising, or third-party analytics. Gameplay is not uploaded to a business server. Levels, progress and preferences remain on your device. There are no in-app purchases."
          ))
      })
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
