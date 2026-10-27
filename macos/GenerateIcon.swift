// Render the existing Lightmail envelope mark without external image dependencies.
import AppKit
import Foundation

guard CommandLine.arguments.count == 2 else {
    fatalError("Usage: GenerateIcon <output.iconset>")
}
let output = URL(fileURLWithPath: CommandLine.arguments[1], isDirectory: true)
try FileManager.default.createDirectory(at: output, withIntermediateDirectories: true)

for size in [16, 32, 128, 256, 512] {
    for scale in [1, 2] {
        let pixels = size * scale
        let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: pixels,
                                      pixelsHigh: pixels, bitsPerSample: 8,
                                      samplesPerPixel: 4, hasAlpha: true,
                                      isPlanar: false, colorSpaceName: .deviceRGB,
                                      bytesPerRow: 0, bitsPerPixel: 0)!
        let context = NSGraphicsContext(bitmapImageRep: bitmap)!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = context
        context.cgContext.clear(CGRect(x: 0, y: 0, width: pixels, height: pixels))
        context.cgContext.scaleBy(x: CGFloat(pixels) / 1024, y: CGFloat(pixels) / 1024)
        context.imageInterpolation = .high

        let tile = NSBezierPath(roundedRect: NSRect(x: 64, y: 64, width: 896, height: 896),
                                xRadius: 200, yRadius: 200)
        NSColor(srgbRed: 206.0 / 255, green: 84.0 / 255, blue: 47.0 / 255, alpha: 1).setFill()
        tile.fill()

        NSColor.white.setStroke()
        let envelope = NSBezierPath(roundedRect: NSRect(x: 242, y: 302, width: 540, height: 390),
                                    xRadius: 16, yRadius: 16)
        envelope.lineWidth = 48
        envelope.lineJoinStyle = .round
        envelope.stroke()
        let flap = NSBezierPath()
        flap.move(to: NSPoint(x: 250, y: 685))
        flap.line(to: NSPoint(x: 512, y: 482))
        flap.line(to: NSPoint(x: 774, y: 685))
        flap.lineWidth = 48
        flap.lineJoinStyle = .round
        flap.lineCapStyle = .round
        flap.stroke()
        let accent = NSBezierPath()
        accent.move(to: NSPoint(x: 602, y: 812))
        accent.line(to: NSPoint(x: 812, y: 812))
        accent.lineWidth = 48
        accent.lineCapStyle = .round
        accent.stroke()

        NSGraphicsContext.restoreGraphicsState()
        let suffix = scale == 2 ? "@2x" : ""
        let target = output.appendingPathComponent("icon_\(size)x\(size)\(suffix).png")
        try bitmap.representation(using: .png, properties: [:])!.write(to: target)
    }
}
