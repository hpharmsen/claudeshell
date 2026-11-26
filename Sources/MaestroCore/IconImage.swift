import AppKit

/// A decoded image that can become a tile icon.
public struct IconImage {
    /// Pixels along each side of the stored square PNG.
    public static let side = 128

    private let rep: NSImageRep
    private let width: CGFloat
    private let height: CGFloat

    /// Decodes image bytes; nil when they are no image.
    public init?(data: Data) {
        // A vector representation (SVG) has no pixel size and counts by its point size.
        func size(_ rep: NSImageRep) -> CGSize {
            rep.pixelsWide > 0 && rep.pixelsHigh > 0
                ? CGSize(width: rep.pixelsWide, height: rep.pixelsHigh) : rep.size
        }
        // Of a file with several sizes (ICO, ICNS) the largest counts.
        guard let rep = NSImage(data: data)?.representations
            .max(by: { size($0).width * size($0).height < size($1).width * size($1).height }),
            size(rep).width > 0, size(rep).height > 0
        else { return nil }
        self.rep = rep
        (width, height) = (size(rep).width, size(rep).height)
    }

    /// Whether the long side is more than one and a half times the short side.
    public var isTooWide: Bool { max(width, height) > 1.5 * min(width, height) }

    /// A square PNG of `side` pixels, with the image fitted and centred on a transparent background.
    public func pngData() -> Data? {
        let side = Self.side
        // An explicit pixel size keeps the result independent of the screen scale.
        guard let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: side, pixelsHigh: side, bitsPerSample: 8, samplesPerPixel: 4,
            hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0),
            let context = NSGraphicsContext(bitmapImageRep: bitmap)
        else { return nil }
        let scale = CGFloat(side) / max(width, height)
        let fitted = CGSize(width: width * scale, height: height * scale)
        let target = CGRect(x: (CGFloat(side) - fitted.width) / 2, y: (CGFloat(side) - fitted.height) / 2,
                            width: fitted.width, height: fitted.height)

        NSGraphicsContext.saveGraphicsState()
        defer { NSGraphicsContext.restoreGraphicsState() }
        NSGraphicsContext.current = context
        context.imageInterpolation = .high
        context.cgContext.clear(CGRect(x: 0, y: 0, width: side, height: side))
        guard rep.draw(in: target) else { return nil }
        return bitmap.representation(using: .png, properties: [:])
    }
}
