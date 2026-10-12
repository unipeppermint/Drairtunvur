import UIKit
import LightworksCore

@MainActor enum DrairtunvurSupport {
  static var version: String {
    let version =
      Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "—"
    let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "—"
    return "\(version) (\(build))"
  }
  static func share(from controller: UIViewController) {
    let model = AppModel.shared
    let active = model.save.active
    let report = """
      Lightworks / 光路工坊
      Version: \(version)
      System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
      Language: \(Preferences.language)
      Level: \(active?.levelID ?? "—")
      Moves: \(active?.state.movesUsed ?? 0)
      Outcome: \(active?.state.outcome.rawValue ?? "—")
      Completed: \(model.levels.filter { model.save.bestMoves[$0.id] != nil }.count)/\(model.levels.count)
      Save: \(model.storageNeedsRecovery ? "recovery needed" : model.saveError == nil ? "available" : "write failed")

      \(L.text("问题描述与复现步骤（请填写）：", "Describe the issue and steps to reproduce:"))
      """
    let sheet = UIActivityViewController(activityItems: [report], applicationActivities: nil)
    sheet.popoverPresentationController?.sourceView = controller.view
    sheet.popoverPresentationController?.sourceRect = CGRect(
      x: controller.view.bounds.midX, y: controller.view.bounds.midY, width: 1, height: 1)
    controller.present(sheet, animated: true)
  }
}

final class DrairtunvurHelpViewController: ScreenController {
  override func viewDidLoad() {
    super.viewDidLoad()
    header(L.text("玩法说明", "How to play"))
    let sections = [
      (
        L.text("铺出光路", "Build a path"),
        L.text(
          "选择候选方块，再点棋盘上的左上角锚点，也可以拖放。方块朝向固定，放置时不能与已有方块重叠。",
          "Select a piece, then tap its top-left anchor on the board, or drag it into place. Pieces cannot rotate or overlap existing blocks."
        )
      ),
      (
        L.text("补满一行或一列", "Complete a line"),
        L.text(
          "光只在上下左右相邻的方块间传递。补满任意整行或整列，会在消除前触发一次光脉冲，为与入口连通的灯各充能一次。一次消除多条线仍只充能一次。",
          "Light travels between orthogonally adjacent blocks. Completing any row or column triggers a pulse before clearing, adding one charge to each light connected to the source. Clearing several lines still produces one pulse."
        )
      ),
      (
        L.text("点亮所有灯", "Restore every light"),
        L.text(
          "充满所有灯即可通关，最后一步也能赢。能量会保留，消除后方块不会下落。三个候选全部用完，才会补充下一批固定方块。",
          "Charge every light to win, even on your final move. Energy is retained; blocks do not fall after clearing. Use all three pieces to receive the next fixed batch."
        )
      ),
      (
        L.text("尝试、撤销与提示", "Explore, undo and get hints"),
        L.text(
          "每次放置消耗一步。步数用完、候选无法放下或序列耗尽时，可以撤销或重试。提示只显示已验证能够通关的下一步；暂未找到提示不代表当前局面无解。",
          "Each placement uses a move. If you run out of moves, space or pieces, undo or retry. Hints show only a move with a verified winning continuation. A search timeout does not mean the puzzle is impossible."
        )
      ),
      (
        L.text("主线与每日", "City and daily challenges"),
        L.text(
          "主线按顺序开放，共三章 45 关。每日从章节题目中轮换，独立保存进度，不改变主线解锁。进度保存在本机，不进行云端同步。",
          "The city has 45 levels across three chapters, unlocked in sequence. A chapter puzzle rotates daily with separate progress and does not unlock city levels. Progress is stored on this device without cloud sync."
        )
      ),
    ]
    for (title, body) in sections {
      let panel = Theme.inset(
        Theme.stack(
          [
            Theme.label(title, size: 19, weight: .semibold, color: Theme.gold),
            Theme.label(body, size: 15, color: Theme.cream),
          ], spacing: 9))
      Theme.panel(panel)
      content.addArrangedSubview(panel)
    }
  }
  init() {
    super.init(nibName: nil, bundle: nil)
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
}
