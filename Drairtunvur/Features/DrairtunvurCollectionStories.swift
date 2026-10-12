import Foundation

enum DrairtunvurCollectionStories {
  static func story(chapter: Int, milestone: Int) -> String {
    let stories: [(String,String)] = [
      ("值夜人把灯罩擦了又擦，直到第一束光越过防波堤。远处的船终于转向港口——今晚，回家的人不必再摸黑靠岸。", "The keeper polishes the lantern until its first beam reaches beyond the breakwater. A distant boat turns toward the harbor. Tonight, nobody has to find the shore in darkness."),
      ("沿栈道的七盏灯依次亮起。卖面包的小铺已经关门，木板上还留着白天的脚步声。循着这条弯弯的小路，海风会送你到家门口。", "Seven lamps mark the curve of the jetty. The bakery has closed, but the boards still hold the day's footsteps. Follow the gentle bend and the sea breeze will carry you home."),
      ("两座门塔之间，最后一段光路接通了。渔船从桥影下驶过，窗前的人放下手里的书。港湾恢复的不是热闹，而是有人等候的安宁。", "The final connection lights the harbor gate. A fishing boat passes beneath the arch, and someone at a window sets down a book. The harbor has found the quiet comfort of being expected."),
      ("藤蔓绕过旧灯架，把一盏小灯藏在叶间。园丁没有剪掉它，只把光路接回原处。入夜后，每片叶子都多了一道温柔的金边。", "A vine has curled around the old lantern, hiding it among the leaves. The gardener leaves it there and reconnects the light. After dusk, each leaf wears a soft golden edge."),
      ("池畔的小桥重新亮起，水面把灯光留成另一条路。你停下来时，涟漪慢慢散去，桥上与水中的两座城市终于重合。", "The footbridge shines again, and the pool keeps a second path of light. When you stop beside it, the ripples settle until the city above and the city below meet."),
      ("温室穹顶的每一道玻璃接缝都亮了。这里没有盛大的庆祝，只有新芽、暖灯和夜里翻开的观察笔记。明天的第一片叶子，已经准备好迎接清晨。", "Light traces every seam of the glass roof. There is no grand celebration—only new shoots, warm lamps and an open gardener's notebook. Tomorrow's first leaf is ready for morning."),
      ("雨棚下的灯一盏接着一盏亮起，铁轨把光带向远处。清扫站台的人停下扫帚，听见隧道里传来一声熟悉的鸣笛。", "Lamps return beneath the platform canopy, and the rails carry their glow into the distance. The platform sweeper pauses at the sound of a familiar whistle from the tunnel."),
      ("修好的钟没有追回失去的时间，只是重新开始走动。午夜那一声钟响很轻，却让候车室里的人都抬起了头。下一班车，仍值得等待。", "The repaired clock does not try to recover lost time. It simply begins again. Its quiet midnight chime makes everyone in the waiting room look up. The next train is still worth waiting for."),
      ("大厅的三扇门同时亮起。有人出发，有人归来，城市的光路在这里短暂相交。你合上修复日志，门外已有一条新路，等着明天继续。", "The three station doors glow together. Departures and homecomings briefly share the same light. You close the restoration journal. Outside, another path is waiting for tomorrow."),
    ]
    let value=stories[(chapter-1)*3+milestone/5-1]
    return L.text(value.0,value.1)
  }
}
