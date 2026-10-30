import Foundation

enum DrairtunvurCollectionStories {
  static func story(chapter: Int, milestone: Int) -> String {
    let stories: [String] = [
      "The keeper polishes the lantern until its first beam reaches beyond the breakwater. A distant boat turns toward the harbor. Tonight, nobody has to find the shore in darkness.",
      "Seven lamps mark the curve of the jetty. The bakery has closed, but the boards still hold the day's footsteps. Follow the gentle bend and the sea breeze will carry you home.",
      "The final connection lights the harbor gate. A fishing boat passes beneath the arch, and someone at a window sets down a book. The harbor has found the quiet comfort of being expected.",
      "A vine has curled around the old lantern, hiding it among the leaves. The gardener leaves it there and reconnects the light. After dusk, each leaf wears a soft golden edge.",
      "The footbridge shines again, and the pool keeps a second path of light. When you stop beside it, the ripples settle until the city above and the city below meet.",
      "Light traces every seam of the glass roof. There is no grand celebration—only new shoots, warm lamps and an open gardener's notebook. Tomorrow's first leaf is ready for morning.",
      "Lamps return beneath the platform canopy, and the rails carry their glow into the distance. The platform sweeper pauses at the sound of a familiar whistle from the tunnel.",
      "The repaired clock does not try to recover lost time. It simply begins again. Its quiet midnight chime makes everyone in the waiting room look up. The next train is still worth waiting for.",
      "The three station doors glow together. Departures and homecomings briefly share the same light. You close the restoration journal. Outside, another path is waiting for tomorrow.",
    ]
    let value = stories[(chapter - 1) * 3 + milestone / 5 - 1]
    return value
  }
}
