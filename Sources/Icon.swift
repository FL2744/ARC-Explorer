import AppKit
if CommandLine.arguments[1] == "--pack" {
 let folder=URL(fileURLWithPath:CommandLine.arguments[2])
 var body=Data()
 for (tag,name) in [("icp4","icon_16x16.png"),("icp5","icon_32x32.png"),("icp6","icon_32x32@2x.png"),("ic07","icon_128x128.png"),("ic08","icon_256x256.png"),("ic09","icon_512x512.png"),("ic10","icon_512x512@2x.png")] {
  let png=try Data(contentsOf:folder.appendingPathComponent(name));body.append(Data(tag.utf8));var size=UInt32(png.count+8).bigEndian;withUnsafeBytes(of:&size){body.append(contentsOf:$0)};body.append(png)
 }
 var file=Data("icns".utf8);var length=UInt32(body.count+8).bigEndian;withUnsafeBytes(of:&length){file.append(contentsOf:$0)};file.append(body);try file.write(to:URL(fileURLWithPath:CommandLine.arguments[3]));exit(0)
}
let target=CommandLine.arguments[1]
let image=NSImage(size:NSSize(width:1024,height:1024));image.lockFocus()
let tile=NSBezierPath(roundedRect:NSRect(x:56,y:56,width:912,height:912),xRadius:205,yRadius:205)
NSGradient(starting:NSColor(calibratedWhite:0.17,alpha:1),ending:NSColor(calibratedWhite:0.025,alpha:1))!.draw(in:tile,angle:-65)
let border=NSBezierPath(roundedRect:NSRect(x:58,y:58,width:908,height:908),xRadius:203,yRadius:203);border.lineWidth=3;NSColor(calibratedWhite:0.4,alpha:0.6).setStroke();border.stroke()
// An orbital compass: compute nodes arranged around a bright exploratory heading.
let orbit=NSBezierPath(ovalIn:NSRect(x:214,y:214,width:596,height:596));orbit.lineWidth=15;NSColor(calibratedWhite:0.53,alpha:1).setStroke();orbit.stroke()
let sweep=NSBezierPath();sweep.lineWidth=18;sweep.lineCapStyle = .round
sweep.move(to:NSPoint(x:213,y:472));sweep.curve(to:NSPoint(x:751,y:722),controlPoint1:NSPoint(x:251,y:207),controlPoint2:NSPoint(x:855,y:383));NSColor(calibratedWhite:0.84,alpha:1).setStroke();sweep.stroke()
// Clean, two-tone compass needle. The dark gap maintains definition at Dock size.
let lower=NSBezierPath();lower.move(to:NSPoint(x:476,y:526));lower.line(to:NSPoint(x:319,y:295));lower.line(to:NSPoint(x:554,y:443));lower.close();NSColor(calibratedWhite:0.48,alpha:1).setFill();lower.fill()
let arrow=NSBezierPath();arrow.move(to:NSPoint(x:737,y:755));arrow.line(to:NSPoint(x:603,y:412));arrow.line(to:NSPoint(x:528,y:506));arrow.line(to:NSPoint(x:423,y:572));arrow.close();NSColor(calibratedWhite:0.98,alpha:1).setFill();arrow.fill()
let facet=NSBezierPath();facet.move(to:NSPoint(x:737,y:755));facet.line(to:NSPoint(x:528,y:506));facet.line(to:NSPoint(x:603,y:412));facet.close();NSColor(calibratedWhite:0.76,alpha:1).setFill();facet.fill()
for (x,y,r) in [(224.0,438.0,23.0),(520.0,214.0,20.0),(808.0,512.0,17.0)] {
 NSColor(calibratedWhite:0.07,alpha:1).setFill();NSBezierPath(ovalIn:NSRect(x:x-r-8,y:y-r-8,width:2*r+16,height:2*r+16)).fill()
 NSColor.white.setFill();NSBezierPath(ovalIn:NSRect(x:x-r,y:y-r,width:2*r,height:2*r)).fill()
}
image.unlockFocus();let rep=NSBitmapImageRep(data:image.tiffRepresentation!)!;try rep.representation(using:.png,properties:[:])!.write(to:URL(fileURLWithPath:target))
