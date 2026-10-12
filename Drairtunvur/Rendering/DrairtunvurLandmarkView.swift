import UIKit

/// Nine resolution-independent keepsakes, drawn as illuminated architectural studies.
final class DrairtunvurLandmarkView: UIView {
  let chapter: Int
  let milestone: Int
  var illuminated: Bool { didSet { setNeedsDisplay() } }
  init(chapter: Int, milestone: Int, illuminated: Bool) {
    self.chapter = chapter
    self.milestone = milestone
    self.illuminated = illuminated
    super.init(frame: .zero)
    isOpaque = false
    isUserInteractionEnabled = false
    contentMode = .redraw
    accessibilityElementsHidden = true
  }
  required init?(coder: NSCoder) { fatalError() }
  override func draw(_ rect: CGRect) {
    guard let ctx = UIGraphicsGetCurrentContext() else { return }
    let palette = [Theme.navy, UIColor(red: 0.035, green: 0.16, blue: 0.16, alpha: 1), UIColor(red: 0.09, green: 0.10, blue: 0.20, alpha: 1)]
    let gradient = CGGradient(colorsSpace: CGColorSpaceCreateDeviceRGB(), colors: [palette[chapter-1].cgColor, Theme.navy.cgColor] as CFArray, locations: [0,1])!
    ctx.drawLinearGradient(gradient, start: .zero, end: CGPoint(x: 0, y: rect.height), options: [])
    let scale = min(rect.width / 320, rect.height / 250)
    ctx.translateBy(x: (rect.width - 320*scale)/2, y: (rect.height - 250*scale)/2)
    ctx.scaleBy(x: scale, y: scale)
    let ink = Theme.teal.withAlphaComponent(illuminated ? 0.9 : 0.35)
    let light = illuminated ? Theme.gold : Theme.muted.withAlphaComponent(0.23)
    func path(_ points: [CGPoint], color: UIColor, width: CGFloat = 1.4, close: Bool = false, fill: UIColor? = nil) {
      guard let first = points.first else { return }
      let p = UIBezierPath(); p.move(to: first)
      for point in points.dropFirst() { p.addLine(to: point) }
      if close { p.close() }
      if let fill { fill.setFill(); p.fill() }
      color.setStroke(); p.lineWidth = width; p.stroke()
    }
    func line(_ x1: CGFloat, _ y1: CGFloat, _ x2: CGFloat, _ y2: CGFloat, _ color: UIColor, _ width: CGFloat = 1.4) {
      path([CGPoint(x:x1,y:y1), CGPoint(x:x2,y:y2)], color:color,width:width)
    }
    func box(_ x: CGFloat, _ y: CGFloat, _ w: CGFloat, _ h: CGFloat, _ color: UIColor, fill: UIColor? = nil) {
      let p = UIBezierPath(roundedRect: CGRect(x:x,y:y,width:w,height:h), cornerRadius: 2)
      if let fill { fill.setFill();p.fill() };color.setStroke();p.lineWidth=1.5;p.stroke()
    }
    func orb(_ x: CGFloat, _ y: CGFloat, _ r: CGFloat, _ color: UIColor) {
      ctx.saveGState()
      if illuminated { ctx.setShadow(offset: .zero, blur: r*4, color: color.withAlphaComponent(0.65).cgColor) }
      color.setFill();UIBezierPath(ovalIn:CGRect(x:x-r,y:y-r,width:r*2,height:r*2)).fill();ctx.restoreGState()
    }
    // Deterministic star field and engraved horizon retain the visual language of the city.
    for i in 0..<25 {
      let x=CGFloat((i*73+chapter*19)%300+10), y=CGFloat((i*37+milestone*3)%130+12)
      orb(x,y,i%5==0 ? 1.2 : 0.6,Theme.cream.withAlphaComponent(0.30))
    }
    line(30,207,290,207,ink)
    switch (chapter,milestone) {
    case (1,5): // Lantern tower with spiral walkway and sweeping light.
      path([.init(x:129,y:195),.init(x:141,y:83),.init(x:177,y:83),.init(x:191,y:195)],color:ink,close:true,fill:Theme.panel)
      box(134,63,50,27,light,fill:Theme.panel)
      path([.init(x:129,y:62),.init(x:159,y:39),.init(x:189,y:62)],color:ink,close:true)
      orb(159,76,6,light)
      for y in stride(from:110,through:174,by:32) { box(154,CGFloat(y),9,15,light) }
      path([.init(x:120,y:202),.init(x:206,y:181),.init(x:117,y:155)],color:ink)
      if illuminated { path([.init(x:159,y:76),.init(x:285,y:40),.init(x:285,y:105)],color:light.withAlphaComponent(0.12),close:true,fill:light.withAlphaComponent(0.09)) }
    case (1,10): // Jetty bends between its own seven lanterns.
      path([.init(x:45,y:216),.init(x:99,y:161),.init(x:194,y:161),.init(x:242,y:108)],color:ink,width:11)
      for i in 0..<7 {
        let x=CGFloat(66+i*28), y:CGFloat=i<2 ? 188-CGFloat(i*20) : 150-CGFloat(max(0,i-4)*22)
        line(x,y,x,y-35,ink,2);box(x-5,y-45,10,12,light);orb(x,y-40,2,light)
      }
      for i in 0..<5 { line(40+CGFloat(i*9),225+CGFloat(i*3),145+CGFloat(i*9),225+CGFloat(i*3),ink.withAlphaComponent(0.3)) }
    case (1,15): // Harbor arch, two towers and a returning boat.
      box(59,110,39,86,ink);box(221,110,39,86,ink)
      for x:CGFloat in [59,221] { path([.init(x:x-6,y:109),.init(x:x+19,y:83),.init(x:x+45,y:109)],color:light);box(x+14,123,11,18,light) }
      let arch=UIBezierPath();arch.move(to:.init(x:98,y:162));arch.addQuadCurve(to:.init(x:221,y:162),controlPoint:.init(x:159,y:63));ink.setStroke();arch.lineWidth=5;arch.stroke()
      for x in stride(from:108,through:208,by:20) { orb(CGFloat(x),139-abs(158-CGFloat(x))*0.18,2,light) }
      path([.init(x:132,y:195),.init(x:189,y:195),.init(x:177,y:210),.init(x:143,y:210)],color:ink,close:true);line(160,193,160,161,light)
    case (2,5): // A hanging vine lantern inside a leaf canopy.
      line(160,37,160,143,ink)
      for i in 0..<6 {
        let y=CGFloat(60+i*22), side:CGFloat=i%2==0 ? -1 : 1
        let leaf=UIBezierPath();leaf.move(to:.init(x:160,y:y));leaf.addQuadCurve(to:.init(x:160+side*62,y:y-18),controlPoint:.init(x:160+side*20,y:y-42));leaf.addQuadCurve(to:.init(x:160,y:y),controlPoint:.init(x:160+side*49,y:y+15));ink.withAlphaComponent(0.25).setFill();leaf.fill();ink.setStroke();leaf.stroke()
      }
      box(142,149,36,39,light);orb(160,169,7,light);line(132,195,188,195,ink)
    case (2,10): // Reflecting pool and arched footbridge.
      let pool=UIBezierPath(ovalIn:CGRect(x:47,y:151,width:226,height:57));ink.withAlphaComponent(0.17).setFill();pool.fill();ink.setStroke();pool.stroke()
      let arch=UIBezierPath();arch.move(to:.init(x:62,y:164));arch.addQuadCurve(to:.init(x:257,y:164),controlPoint:.init(x:160,y:72));ink.setStroke();arch.lineWidth=5;arch.stroke()
      for x in stride(from:84,through:234,by:30) { let y=CGFloat(114)+abs(CGFloat(x)-159)*0.29;line(CGFloat(x),y,CGFloat(x),y+23,ink);orb(CGFloat(x),y,3,light) }
      for i in 0..<5 { line(115-CGFloat(i*6),177+CGFloat(i*5),199+CGFloat(i*6),177+CGFloat(i*5),light.withAlphaComponent(0.35-CGFloat(i)*0.05)) }
    case (2,15): // Faceted glass conservatory with its central palm.
      path([.init(x:57,y:194),.init(x:57,y:101),.init(x:160,y:43),.init(x:263,y:101),.init(x:263,y:194)],color:ink,close:true,fill:ink.withAlphaComponent(0.09))
      for x in stride(from:80,through:240,by:40) { line(CGFloat(x),89+abs(CGFloat(x)-160)*0.12,CGFloat(x),192,ink);line(160,43,CGFloat(x),101,ink) }
      line(58,101,262,101,light);line(58,147,262,147,ink)
      line(160,180,160,116,light)
      for x:CGFloat in [122,140,180,198] { path([.init(x:160,y:133),.init(x:x,y:112),.init(x:x-5,y:151)],color:light,width:2) }
    case (3,5): // Railway canopy and amber lamps over receding rails.
      path([.init(x:43,y:96),.init(x:244,y:69),.init(x:277,y:92),.init(x:64,y:124)],color:ink,close:true,fill:Theme.panel)
      for x:CGFloat in [73,143,218] { line(x,116-(x-73)*0.13,x,189,ink,4);orb(x+16,112-(x-73)*0.13,4,light) }
      line(36,211,262,166,ink,2);line(47,229,273,184,ink,2)
      for i in 0..<12 { let x=CGFloat(45+i*19);line(x,210-(x-45)*0.20,x+8,224-(x-45)*0.20,ink) }
    case (3,10): // Midnight clock, independent of the station building.
      box(134,125,52,77,ink,fill:Theme.panel)
      let clock=UIBezierPath(ovalIn:CGRect(x:111,y:45,width:98,height:98));Theme.panel.setFill();clock.fill();light.setStroke();clock.lineWidth=2;clock.stroke()
      for i in 0..<12 { let a=CGFloat(i)*CGFloat.pi/6;line(160+sin(a)*39,94-cos(a)*39,160+sin(a)*43,94-cos(a)*43,light) }
      line(160,94,160,65,light,3);line(160,94,178,105,light,2);orb(160,94,3,light)
      box(147,159,26,30,light)
    default: // Terminal facade: three arches beneath a glass roof.
      path([.init(x:43,y:105),.init(x:160,y:52),.init(x:277,y:105)],color:ink,width:2,close:true,fill:ink.withAlphaComponent(0.12))
      box(51,106,218,89,ink,fill:Theme.panel)
      for x:CGFloat in [79,140,201] {
        let door=UIBezierPath(roundedRect:CGRect(x:x,y:129,width:39,height:66),cornerRadius:19);light.setStroke();door.lineWidth=2;door.stroke();line(x+19,148,x+19,194,ink);orb(x+19,147,3,light)
      }
      for x in stride(from:66,through:254,by:23) { orb(CGFloat(x),114,2,light) }
      line(160,52,160,103,ink);line(160,52,102,103,ink);line(160,52,218,103,ink)
    }
    // A small plate ties the keepsakes together without substituting text for artwork.
    let number=String(format:"%02d", (chapter-1)*3+milestone/5)
    (number as NSString).draw(at:CGPoint(x:278,y:224),withAttributes:[.font:UIFont.monospacedDigitSystemFont(ofSize:10,weight:.medium),.foregroundColor:ink])
  }
}
