import LightworksCore
import UIKit

final class CollectionViewController: ScreenController {
  override func viewDidLoad() {
    super.viewDidLoad()
    background.picture.alpha = 0.18
    NotificationCenter.default.addObserver(
      self, selector: #selector(refresh), name: .languageChanged, object: nil)
    refresh()
  }
  override func viewWillAppear(_ animated: Bool) {
    super.viewWillAppear(animated)
    refresh()
  }
  @objc func refresh() {
    guard isViewLoaded else { return }
    clearContent()
    let model = AppModel.shared
    let collected = model.save.collectibles(levels: model.levels)
    let heading = Theme.label(L.text("城市图鉴", "City Collection"), size: 32, weight: .bold)
    let count = Theme.label(
      L.text("已收藏 \(collected.count) / 9", "\(collected.count) / 9 collected"), size: 13,
      color: Theme.cream)
    count.setContentHuggingPriority(.required, for: .horizontal)
    content.addArrangedSubview(Theme.stack([heading, count], axis: .horizontal))
    let hero = CollectionCard(chapter: model.nextLevel.chapter, milestone: 15, unlocked: true, scenePreview: true)
    hero.accessibilityIdentifier = "collection.currentChapter"
    hero.heightAnchor.constraint(equalToConstant: 250).isActive = true
    hero.isAccessibilityElement = false
    hero.isUserInteractionEnabled = false
    if let caption = hero.viewWithTag(101) as? UILabel {
      caption.text =
        model.campaignCompleted
        ? L.text("全部光路已修复 · 45 / 45", "All paths restored · 45 / 45")
        : L.text(
          "修复进行中 · 已点亮 \(model.completed(model.nextLevel.chapter)) / 15",
          "Restoring · \(model.completed(model.nextLevel.chapter)) / 15")
    }
    content.addArrangedSubview(hero)
    var cards = [UIView]()
    for milestone in [5, 10, 15] {
      for chapter in 1...3 {
        let unlocked = collected.contains("\(chapter)-\(milestone)")
        let card = CollectionCard(chapter: chapter, milestone: milestone, unlocked: unlocked)
        card.heightAnchor.constraint(equalToConstant: 180).isActive = true
        card.addAction(
          UIAction { [weak self] _ in
            guard let self else { return }
            if unlocked {
              self.navigationController?.pushViewController(
                CollectionDetailController(chapter: chapter, milestone: milestone), animated: true)
            } else {
              self.alert(
                L.text("待点亮的风景", "A view waiting for light"),
                L.text(
                  "完成「\(L.chapter(chapter))」中的 \(milestone) 关即可收藏。当前 \(model.completed(chapter))/\(milestone)。",
                  "Complete \(milestone) levels in \(L.chapter(chapter)) to collect this view. Progress: \(model.completed(chapter))/\(milestone)."
                ))
            }
          }, for: .touchUpInside)
        cards.append(card)
      }
    }
    for index in stride(from: 0, to: cards.count, by: 2) {
      let row = Theme.stack(
        [cards[index], index + 1 < cards.count ? cards[index + 1] : UIView()], axis: .horizontal,
        spacing: 10)
      row.distribution = .fillEqually
      content.addArrangedSubview(row)
    }
  }
}
final class CollectionCard: UIControl {
  init(chapter: Int, milestone: Int, unlocked: Bool, scenePreview: Bool = false) {
    super.init(frame: .zero)
    layer.cornerRadius = 18
    clipsToBounds = true
    layer.borderColor = Theme.muted.withAlphaComponent(0.3).cgColor
    layer.borderWidth = 1
    let image: UIView = scenePreview
      ? SceneCropView(name: ["harbor-v2", "greenhouse", "station"][chapter - 1], focus: 0.5)
      : DrairtunvurLandmarkView(chapter: chapter, milestone: milestone, illuminated: unlocked)
    addSubview(image)
    image.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      image.leadingAnchor.constraint(equalTo: leadingAnchor),
      image.trailingAnchor.constraint(equalTo: trailingAnchor),
      image.topAnchor.constraint(equalTo: topAnchor),
      image.bottomAnchor.constraint(equalTo: bottomAnchor, constant: scenePreview ? 0 : -60),
    ])
    let title = Theme.label(
      "\(unlocked ? "✦" : "◇")  \(Self.name(chapter,milestone))", size: 16, weight: .semibold)
    let subtitle = Theme.label(
      unlocked
        ? L.text("已收藏 · 查看风景", "Collected · View scene")
        : L.text("完成本章 \(milestone) 关解锁", "Complete \(milestone) chapter levels"), size: 12,
      color: unlocked ? Theme.gold : Theme.muted)
    subtitle.tag = 101
    let text = Theme.inset(Theme.stack([title, subtitle], spacing: 4), by: 13)
    text.backgroundColor = Theme.navy.withAlphaComponent(0.86)
    text.isUserInteractionEnabled = false
    addSubview(text)
    text.translatesAutoresizingMaskIntoConstraints = false
    NSLayoutConstraint.activate([
      text.leadingAnchor.constraint(equalTo: leadingAnchor),
      text.trailingAnchor.constraint(equalTo: trailingAnchor),
      text.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    isAccessibilityElement = true
    accessibilityLabel = "\(title.text ?? ""), \(subtitle.text ?? "")"
    accessibilityTraits = .button
    accessibilityIdentifier = "collection.\(chapter).\(milestone)"
  }
  required init?(coder: NSCoder) { fatalError() }
  static func name(_ chapter: Int, _ milestone: Int) -> String {
    let names = [
      [
        L.text("归航的灯", "Homeward light"), L.text("港湾小径", "Harbor pathways"),
        L.text("静谧港湾", "Quiet Harbor"),
      ],
      [
        L.text("叶间星光", "Stars among leaves"), L.text("池畔微光", "The reflecting pool"),
        L.text("温室微光", "Glasshouse Glow"),
      ],
      [
        L.text("站台灯影", "Platform lights"), L.text("午夜钟声", "The midnight clock"),
        L.text("候车之夜", "Midnight Station"),
      ],
    ]
    return names[chapter - 1][milestone / 5 - 1]
  }
}
final class CollectionDetailController: ScreenController {
  let chapter: Int
  let milestone: Int
  init(chapter: Int, milestone: Int) {
    self.chapter = chapter
    self.milestone = milestone
    super.init(nibName: nil, bundle: nil)
    sceneChapter = chapter
    dimScene = true
    hidesBottomBarWhenPushed = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func viewDidLoad() {
    super.viewDidLoad()
    header(CollectionCard.name(chapter, milestone))
    let artwork = DrairtunvurLandmarkView(chapter: chapter, milestone: milestone, illuminated: true)
    artwork.layer.cornerRadius = 20
    artwork.clipsToBounds = true
    artwork.heightAnchor.constraint(equalTo: artwork.widthAnchor, multiplier: 0.80).isActive = true
    content.addArrangedSubview(artwork)
    let state = UISegmentedControl(items: [L.text("点亮之前", "Before"), L.text("修复之后", "Restored")])
    state.selectedSegmentIndex = 1
    state.selectedSegmentTintColor = Theme.gold
    state.backgroundColor = Theme.panel
    state.setTitleTextAttributes([.foregroundColor: Theme.cream], for: .normal)
    state.setTitleTextAttributes([.foregroundColor: Theme.navy], for: .selected)
    state.heightAnchor.constraint(equalToConstant: 44).isActive = true
    state.accessibilityIdentifier = "collection.restoration"
    state.addAction(UIAction { [weak artwork, weak state] _ in
      artwork?.illuminated = state?.selectedSegmentIndex == 1
    }, for: .valueChanged)
    content.addArrangedSubview(state)
    let journal = Theme.inset(Theme.stack([
      Theme.label(L.text("城市修复日志", "Restoration journal"), size: 21, weight: .semibold, color: Theme.gold),
      Theme.label(DrairtunvurCollectionStories.story(chapter: chapter, milestone: milestone), size: 17),
    ]))
    Theme.panel(journal)
    content.addArrangedSubview(journal)
    content.addArrangedSubview(
      Theme.label(
        L.text(
          "收藏于完成「\(L.chapter(chapter))」\(milestone) 关之后。",
          "Collected after restoring \(milestone) levels in \(L.chapter(chapter))."), size: 14,
        color: Theme.muted))
  }
}
