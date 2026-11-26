import AppKit
import Foundation
import Testing
@testable import MaestroCore

// MARK: - Helpers, shared with IconResolverTests

/// A solid colour that survives scaling and colour conversion well enough to be recognised again.
enum Tint: Sendable {
    case red, green, blue

    var bytes: [UInt8] {
        switch self {
        case .red: [255, 0, 0, 255]
        case .green: [0, 255, 0, 255]
        case .blue: [0, 0, 255, 255]
        }
    }

    /// Whether a pixel is opaque and of this colour, with room for rounding.
    func matches(_ color: NSColor?) -> Bool {
        guard let color = color?.usingColorSpace(.sRGB), color.alphaComponent > 0.9 else { return false }
        let channels = [color.redComponent, color.greenComponent, color.blueComponent]
        return zip(channels, bytes).allSatisfy { $1 == 255 ? $0 > 0.7 : $0 < 0.3 }
    }
}

/// PNG data of exactly `width` by `height` pixels; `fill` gives the byte at each index of the RGBA buffer.
func makePNG(width: Int, height: Int, fill: (Int) -> UInt8) throws -> Data {
    let rep = try #require(NSBitmapImageRep(
        bitmapDataPlanes: nil, pixelsWide: width, pixelsHigh: height, bitsPerSample: 8, samplesPerPixel: 4,
        hasAlpha: true, isPlanar: false, colorSpaceName: .deviceRGB, bytesPerRow: width * 4, bitsPerPixel: 32))
    let pixels = try #require(rep.bitmapData)
    for index in 0..<width * height * 4 { pixels[index] = fill(index) }
    return try #require(rep.representation(using: .png, properties: [:]))
}

/// PNG data of exactly `width` by `height` pixels in one colour.
func makePNG(width: Int, height: Int, tint: Tint = .red) throws -> Data {
    let bytes = tint.bytes
    return try makePNG(width: width, height: height) { bytes[$0 % 4] }
}

/// The pixel size of image data as [width, height], or nil when it is no image.
func pixelSize(of data: Data?) -> [Int]? {
    data.flatMap(NSBitmapImageRep.init(data:)).map { [$0.pixelsWide, $0.pixelsHigh] }
}

/// The colour of one pixel of image data; x runs from the left, y from the top.
func pixel(of data: Data?, x: Int, y: Int) -> NSColor? {
    data.flatMap(NSBitmapImageRep.init(data:))?.colorAt(x: x, y: y)
}

/// Whether a pixel exists and is see-through.
func isTransparent(_ color: NSColor?) -> Bool {
    color.map { $0.alphaComponent < 0.1 } ?? false
}

private let middle = IconImage.side / 2

// MARK: - Decoding (KTD12)

@Test func pngDataDecodesToAnImage() throws {
    #expect(IconImage(data: try makePNG(width: 64, height: 64)) != nil)
}

@Test func textBytesAreNoImage() {
    #expect(IconImage(data: Data("this is not an image".utf8)) == nil)
}

@Test func emptyDataIsNoImage() {
    #expect(IconImage(data: Data()) == nil)
}

@Test func truncatedPngIsNoImage() throws {
    #expect(IconImage(data: try makePNG(width: 64, height: 64).prefix(12)) == nil)
}

// MARK: - Normalising to a square PNG (KTD2)

@Test func storedSideIs128Pixels() {
    #expect(IconImage.side == 128)
}

@Test func largeSquarePngBecomes128Square() throws {
    let image = try #require(IconImage(data: try makePNG(width: 256, height: 256)))
    #expect(pixelSize(of: image.pngData()) == [128, 128])
}

@Test func smallSquarePngBecomes128Square() throws {
    let image = try #require(IconImage(data: try makePNG(width: 16, height: 16)))
    #expect(pixelSize(of: image.pngData()) == [128, 128])
}

@Test func squareImageFillsTheWholeSquareWithItsColour() throws {
    let png = try #require(IconImage(data: try makePNG(width: 256, height: 256, tint: .green))).pngData()
    #expect(Tint.green.matches(pixel(of: png, x: middle, y: middle)))
    #expect(Tint.green.matches(pixel(of: png, x: 4, y: 4)))
    #expect(Tint.green.matches(pixel(of: png, x: 123, y: 123)))
}

@Test func wideImageIsFittedAndCentredOnTransparent() throws {
    let png = try #require(IconImage(data: try makePNG(width: 300, height: 100, tint: .red))).pngData()
    #expect(pixelSize(of: png) == [128, 128])
    // 300 by 100 fitted in 128 is 128 by about 43: a band across the middle, see-through above and below.
    #expect(Tint.red.matches(pixel(of: png, x: middle, y: middle)))
    #expect(Tint.red.matches(pixel(of: png, x: 4, y: middle)))
    #expect(Tint.red.matches(pixel(of: png, x: 123, y: middle)))
    #expect(isTransparent(pixel(of: png, x: middle, y: 10)))
    #expect(isTransparent(pixel(of: png, x: middle, y: 117)))
}

@Test func tallImageIsFittedAndCentredOnTransparent() throws {
    let png = try #require(IconImage(data: try makePNG(width: 100, height: 300, tint: .blue))).pngData()
    #expect(pixelSize(of: png) == [128, 128])
    #expect(Tint.blue.matches(pixel(of: png, x: middle, y: middle)))
    #expect(Tint.blue.matches(pixel(of: png, x: middle, y: 4)))
    #expect(Tint.blue.matches(pixel(of: png, x: middle, y: 123)))
    #expect(isTransparent(pixel(of: png, x: 10, y: middle)))
    #expect(isTransparent(pixel(of: png, x: 117, y: middle)))
}

// MARK: - Too wide (KTD8)

@Test(arguments: [[300, 100], [100, 300], [151, 100], [100, 151]])
func longSideOverOneAndAHalfTimesTheShortSideIsTooWide(size: [Int]) throws {
    let image = try #require(IconImage(data: try makePNG(width: size[0], height: size[1])))
    #expect(image.isTooWide)
}

@Test(arguments: [[150, 100], [100, 150], [100, 100], [120, 100]])
func longSideUpToOneAndAHalfTimesTheShortSideIsNotTooWide(size: [Int]) throws {
    let image = try #require(IconImage(data: try makePNG(width: size[0], height: size[1])))
    #expect(!image.isTooWide)
}
