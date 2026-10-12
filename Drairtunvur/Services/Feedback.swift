import AVFAudio
import UIKit

@MainActor final class Feedback {
  enum Sound: String { case place, pulse, win }
  static let shared = Feedback()
  private var players = [String: AVAudioPlayer]()
  private init() {
    try? AVAudioSession.sharedInstance().setCategory(
      .ambient, mode: .default, options: [.mixWithOthers])
    for sound in [Sound.place, .pulse, .win] {
      if let url = Bundle.main.url(forResource: sound.rawValue, withExtension: "wav"),
        let player = try? AVAudioPlayer(contentsOf: url)
      {
        player.prepareToPlay()
        players[sound.rawValue] = player
      }
    }
    NotificationCenter.default.addObserver(
      self, selector: #selector(stop), name: AVAudioSession.interruptionNotification, object: nil)
    NotificationCenter.default.addObserver(
      self, selector: #selector(stop), name: UIApplication.didEnterBackgroundNotification,
      object: nil)
  }
  func select() { if Preferences.haptics { UISelectionFeedbackGenerator().selectionChanged() } }
  func invalid() {
    if Preferences.haptics { UINotificationFeedbackGenerator().notificationOccurred(.warning) }
  }
  func play(_ sound: Sound) {
    if Preferences.sound, let player = players[sound.rawValue] {
      player.currentTime = 0
      player.volume = 0.4
      player.play()
    }
    if Preferences.haptics {
      if sound == .win {
        UINotificationFeedbackGenerator().notificationOccurred(.success)
      } else {
        UIImpactFeedbackGenerator(style: .soft).impactOccurred()
      }
    }
  }
  @objc private func stop() { players.values.forEach { $0.stop() } }
}
