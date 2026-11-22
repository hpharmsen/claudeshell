// Draws the app icon as a 1024 px PNG: the dark shell pane with a prompt on the left,
// the light Claude pane with the waiting dot on the right. Usage: swift scripts/make-icon.swift <out.png>
import AppKit

func color(_ rgb: UInt32) -> NSColor {
    NSColor(srgbRed: CGFloat(rgb >> 16 & 0xFF) / 255, green: CGFloat(rgb >> 8 & 0xFF) / 255,
            blue: CGFloat(rgb & 0xFF) / 255, alpha: 1)
}

let bitmap = NSBitmapImageRep(bitmapDataPlanes: nil, pixelsWide: 1024, pixelsHigh: 1024, bitsPerSample: 8,
                              samplesPerPixel: 4, hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB,
                              bytesPerRow: 0, bitsPerPixel: 0)!
NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)

// The macOS icon shape: an 824 px rounded square with a soft shadow; the Claude pane is its white fill.
let body = NSRect(x: 100, y: 100, width: 824, height: 824)
let shape = NSBezierPath(roundedRect: body, xRadius: 185, yRadius: 185)
NSGraphicsContext.saveGraphicsState()
let shadow = NSShadow()
shadow.shadowColor = NSColor.black.withAlphaComponent(0.3)
shadow.shadowOffset = NSSize(width: 0, height: -10)
shadow.shadowBlurRadius = 20
shadow.set()
color(0xFFFFFF).setFill()
shape.fill()
NSGraphicsContext.restoreGraphicsState()
shape.addClip()

// Shell pane with the prompt.
color(0x101214).setFill()
NSRect(x: 100, y: 100, width: 330, height: 824).fill()
let prompt = NSBezierPath()
prompt.move(to: NSPoint(x: 195, y: 617))
prompt.line(to: NSPoint(x: 326, y: 512))
prompt.line(to: NSPoint(x: 195, y: 407))
prompt.lineWidth = 62
prompt.lineCapStyle = .round
prompt.lineJoinStyle = .round
color(0x55CC55).setStroke()
prompt.stroke()

// The waiting dot in the Claude pane.
color(0xCF222E).setFill()
NSBezierPath(ovalIn: NSRect(x: 572, y: 407, width: 210, height: 210)).fill()

NSGraphicsContext.current?.flushGraphics()
try bitmap.representation(using: .png, properties: [:])!.write(to: URL(fileURLWithPath: CommandLine.arguments[1]))
