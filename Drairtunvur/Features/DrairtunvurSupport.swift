import LightworksCore
import UIKit

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
      Lightworks
      Version: \(version)
      System: \(UIDevice.current.systemName) \(UIDevice.current.systemVersion)
      Language: en
      Level: \(active?.levelID ?? "—")
      Moves: \(active?.state.movesUsed ?? 0)
      Outcome: \(active?.state.outcome.rawValue ?? "—")
      Completed: \(model.levels.filter { model.save.bestMoves[$0.id] != nil }.count)/\(model.levels.count)
      Save: \(model.storageNeedsRecovery ? "recovery needed" : model.saveError == nil ? "available" : "write failed")

      \("Describe the issue and steps to reproduce:")
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
    header("How to play")
    let sections = [
      (
        "Build a path",
        "Select a piece, then tap its top-left anchor on the board, or drag it into place. Pieces cannot rotate or overlap existing blocks."
      ),
      (
        "Complete a line",
        "Light travels between orthogonally adjacent blocks. Completing any row or column triggers a pulse before clearing, adding one charge to each light connected to the source. Clearing several lines still produces one pulse."
      ),
      (
        "Restore every light",
        "Charge every light to win, even on your final move. Energy is retained; blocks do not fall after clearing. Use all three pieces to receive the next fixed batch."
      ),
      (
        "Explore, undo and get hints",
        "Each placement uses a move. If you run out of moves, space or pieces, undo or retry. Hints show only a move with a verified winning continuation. A search timeout does not mean the puzzle is impossible."
      ),
      (
        "City and daily challenges",
        "The city has 45 sequential levels across three chapters. Daily challenges rotate through 365 dedicated puzzles with separate progress and do not unlock city levels. Progress is stored on this device without cloud sync."
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
