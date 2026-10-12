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
    content.addArrangedSubview(
      Theme.button(L.text("玩法说明", "How to play"), symbol: "questionmark.circle") { [weak self] in
        self?.navigationController?.pushViewController(
          DrairtunvurHelpViewController(), animated: true)
      })
    let model = AppModel.shared
    if model.storageNeedsRecovery {
      content.addArrangedSubview(
        Theme.label(
          model.loadMessage ?? L.text("存档需要处理", "Save needs recovery"), size: 14, color: Theme.gold)
      )
      let retry = Theme.button(L.text("重新读取存档", "Try reading again"), symbol: "arrow.clockwise") {
        [weak self] in
        Task { [weak self] in
          let recovered = await model.recoverStorage(reset: false)
          self?.refresh()
          if !recovered {
            self?.alert(
              L.text("仍无法读取", "Unable to read save"),
              L.text(
                "原文件未改动。你可以保留副本并开始新的进度。",
                "The original files are unchanged. You can keep copies and start fresh."))
          }
        }
      }
      retry.accessibilityIdentifier = "settings.recover"
      content.addArrangedSubview(retry)
      let reset = Theme.button(
        L.text("保留副本并开始新进度", "Keep copies and start fresh"), symbol: "archivebox"
      ) { [weak self] in self?.confirmRecovery() }
      reset.accessibilityIdentifier = "settings.reset"
      content.addArrangedSubview(reset)
    } else if let message = model.saveError {
      content.addArrangedSubview(Theme.label(message, size: 13, color: Theme.gold))
      content.addArrangedSubview(
        Theme.button(L.text("重试保存", "Retry saving"), symbol: "arrow.clockwise") { [weak self] in
          Task { [weak self] in
            model.persist()
            await model.flush()
            self?.refresh()
            if model.saveError == nil {
              self?.alert(
                L.text("保存成功", "Saved"),
                L.text("进度已保存在本机。", "Your progress is saved on this device."))
            }
          }
        })
    }
    content.addArrangedSubview(
      Theme.label(L.text("关于光路工坊", "About Lightworks"), size: 21, weight: .semibold))
    let about =
      L.text(
        "一座城市，四十五条光路。\n三章共 45 关，按通关顺序开放；每日挑战独立记录。\n没有广告、没有账号，支持离线游玩。\n\n进度保存在本机，不进行云端同步。删除应用会失去本地进度。",
        "One city, forty-five paths of light.\nThree chapters and 45 levels, unlocked in sequence, plus separately tracked daily challenges.\nNo ads or account. Play offline.\n\nProgress stays on this device without cloud sync. Deleting the app removes local progress."
      ) + "\n\n"
      + L.text("版本 \(DrairtunvurSupport.version)", "Version \(DrairtunvurSupport.version)")
    let panel = Theme.inset(Theme.label(about, size: 14, color: Theme.muted))
    Theme.panel(panel)
    content.addArrangedSubview(panel)
    content.addArrangedSubview(
      Theme.label(
        L.text(
          "遇到问题时，可导出版本、系统及关卡信息，补充复现步骤后，通过 App Store 产品页的支持渠道反馈。导出不会自动发送数据。",
          "Export the version, system and level information, add steps to reproduce, then use the support channel on the App Store product page. Exporting does not send anything automatically."
        ), size: 13, color: Theme.muted))
    let support = Theme.button(
      L.text("导出问题信息", "Export issue details"), symbol: "square.and.arrow.up"
    ) { [weak self] in
      guard let self else { return }
      DrairtunvurSupport.share(from: self)
    }
    support.accessibilityIdentifier = "settings.support"
    content.addArrangedSubview(support)
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
  private func confirmRecovery() {
    let dialog = UIAlertController(
      title: L.text("开始新进度？", "Start fresh?"),
      message: L.text(
        "会先在本机保留原存档副本，再建立空白进度。旧进度不会自动合并到新进度中。",
        "Copies of the original save files will be kept on this device before creating a new save. Old progress will not be merged automatically."
      ), preferredStyle: .alert)
    dialog.addAction(UIAlertAction(title: L.text("取消", "Cancel"), style: .cancel))
    dialog.addAction(
      UIAlertAction(title: L.text("保留副本并重置", "Keep copies and reset"), style: .destructive) {
        [weak self] _ in
        Task { [weak self] in
          let recovered = await AppModel.shared.recoverStorage(reset: true)
          self?.refresh()
          self?.alert(
            recovered ? L.text("已建立新进度", "New save created") : L.text("操作未完成", "Recovery failed"),
            recovered
              ? L.text(
                "原存档副本已保留在本机。", "Copies of the original save files were kept on this device.")
              : L.text("请检查设备存储空间后重试。", "Check the available device storage and try again."))
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
