import UIKit

/// Each collectible owns a matched, two-state illustration sheet: restored above, unlit below.
final class DrairtunvurLandmarkView: UIView {
  private static let frames = NSCache<NSString, UIImage>()
  private let assetName: String
  private let picture = UIImageView()
  var illuminated: Bool { didSet { updateImage() } }

  init(chapter: Int, milestone: Int, illuminated: Bool) {
    assetName = "Drairtunvur-keepsake-\(chapter)-\(milestone)"
    self.illuminated = illuminated
    super.init(frame: .zero)
    Self.frames.totalCostLimit = 32 * 1024 * 1024
    backgroundColor = Theme.navy
    isUserInteractionEnabled = false
    accessibilityElementsHidden = true
    clipsToBounds = true
    picture.contentMode = .scaleAspectFill
    picture.clipsToBounds = true
    picture.translatesAutoresizingMaskIntoConstraints = false
    addSubview(picture)
    NSLayoutConstraint.activate([
      picture.leadingAnchor.constraint(equalTo: leadingAnchor),
      picture.trailingAnchor.constraint(equalTo: trailingAnchor),
      picture.topAnchor.constraint(equalTo: topAnchor),
      picture.bottomAnchor.constraint(equalTo: bottomAnchor),
    ])
    updateImage()
  }
  required init?(coder: NSCoder) { fatalError() }

  private func updateImage() {
    let key = "\(assetName).\(illuminated ? "lit" : "unlit")" as NSString
    if let cached = Self.frames.object(forKey: key) {
      picture.image = cached
      return
    }
    guard let sheet = UIImage(named: assetName)?.cgImage else {
      assertionFailure("Missing collectible artwork: \(assetName)")
      return
    }
    // Select the requested atlas frame. Both states use the same crop and aspect ratio.
    let height = sheet.height / 2
    let rect = CGRect(x: 0, y: illuminated ? 0 : height, width: sheet.width, height: height)
    guard let frame = sheet.cropping(to: rect) else { return }
    let image = UIImage(cgImage: frame)
    Self.frames.setObject(image, forKey: key, cost: frame.bytesPerRow * frame.height)
    picture.image = image
  }
}
