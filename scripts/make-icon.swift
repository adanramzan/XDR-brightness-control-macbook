// Renders XDRBrightness/AppIcon.icns. Run: bash scripts/make-icon.sh
import AppKit

let out = CommandLine.arguments[1]

func render(_ size: Int) -> Data {
    let s = CGFloat(size) / 1024
    let ctx = CGContext(data: nil, width: size, height: size, bitsPerComponent: 8, bytesPerRow: 0,
                        space: CGColorSpace(name: CGColorSpace.sRGB)!, bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue)!
    ctx.scaleBy(x: s, y: s)
    let rgb = CGColorSpace(name: CGColorSpace.sRGB)!
    func color(_ r: CGFloat, _ g: CGFloat, _ b: CGFloat, _ a: CGFloat = 1) -> CGColor { CGColor(colorSpace: rgb, components: [r, g, b, a])! }
    func radial(_ colors: [CGColor], _ stops: [CGFloat], center: CGPoint, radius: CGFloat) {
        let gradient = CGGradient(colorsSpace: rgb, colors: colors as CFArray, locations: stops)!
        ctx.drawRadialGradient(gradient, startCenter: center, startRadius: 0, endCenter: center, endRadius: radius, options: [])
    }

    // macOS icon grid: 824pt rounded square centered on a 1024 canvas, with a soft drop shadow.
    let tile = CGRect(x: 100, y: 100, width: 824, height: 824)
    let shape = CGPath(roundedRect: tile, cornerWidth: 185, cornerHeight: 185, transform: nil)
    ctx.saveGState()
    ctx.setShadow(offset: CGSize(width: 0, height: -10), blur: 24, color: color(0, 0, 0, 0.35))
    ctx.addPath(shape); ctx.setFillColor(color(0.03, 0.04, 0.09)); ctx.fillPath()
    ctx.restoreGState()

    ctx.saveGState()
    ctx.addPath(shape); ctx.clip()
    let background = CGGradient(colorsSpace: rgb, colors: [color(0.16, 0.10, 0.36), color(0.02, 0.03, 0.10)] as CFArray, locations: [0, 1])!
    ctx.drawLinearGradient(background, start: CGPoint(x: 512, y: 924), end: CGPoint(x: 512, y: 100), options: [])
    let center = CGPoint(x: 512, y: 512)
    // HDR bloom spilling past the sun.
    radial([color(1, 0.62, 0.20, 0.55), color(1, 0.35, 0.25, 0.18), color(1, 0.3, 0.3, 0)], [0, 0.45, 1], center: center, radius: 470)

    // Rays: rounded capsules, alternating long and short.
    for i in 0..<12 {
        let long = i % 2 == 0
        ctx.saveGState()
        ctx.translateBy(x: center.x, y: center.y)
        ctx.rotate(by: CGFloat(i) * .pi / 6)
        let ray = CGRect(x: -21, y: long ? 258 : 268, width: 42, height: long ? 118 : 78)
        ctx.addPath(CGPath(roundedRect: ray, cornerWidth: 21, cornerHeight: 21, transform: nil))
        ctx.clip()
        let rayGradient = CGGradient(colorsSpace: rgb, colors: [color(1, 0.95, 0.75), color(1, 0.70, 0.25)] as CFArray, locations: [0, 1])!
        ctx.drawLinearGradient(rayGradient, start: CGPoint(x: 0, y: ray.minY), end: CGPoint(x: 0, y: ray.maxY), options: [])
        ctx.restoreGState()
    }

    // Sun disc: white-hot core fading to amber, brighter than "white" like XDR highlights.
    ctx.saveGState()
    ctx.addEllipse(in: CGRect(x: center.x - 205, y: center.y - 205, width: 410, height: 410))
    ctx.clip()
    radial([color(1, 1, 1), color(1, 0.96, 0.78), color(1, 0.74, 0.28), color(0.98, 0.50, 0.16)], [0, 0.35, 0.8, 1],
           center: CGPoint(x: center.x - 40, y: center.y + 50), radius: 270)
    ctx.restoreGState()
    ctx.restoreGState()

    // Hairline edge so the tile reads on dark backgrounds.
    ctx.addPath(shape); ctx.setStrokeColor(color(1, 1, 1, 0.12)); ctx.setLineWidth(2); ctx.strokePath()
    return NSBitmapImageRep(cgImage: ctx.makeImage()!).representation(using: .png, properties: [:])!
}

let iconset = URL(fileURLWithPath: out)
try? FileManager.default.createDirectory(at: iconset, withIntermediateDirectories: true)
for base in [16, 32, 128, 256, 512] {
    try! render(base).write(to: iconset.appendingPathComponent("icon_\(base)x\(base).png"))
    try! render(base * 2).write(to: iconset.appendingPathComponent("icon_\(base)x\(base)@2x.png"))
}
