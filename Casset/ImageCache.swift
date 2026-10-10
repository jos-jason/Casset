import UIKit
import ImageIO
import CoreImage

/// Decodes cover art once, downsampled to the size it's actually shown at,
/// and keeps the result in memory.
///
/// View bodies re-evaluate often; decoding a full-resolution JPEG from disk
/// inside a body (as the library rows and mini player used to) burns CPU and
/// memory on every refresh. Entries are keyed by path + modification date, so
/// replacing a custom cover at the same filename is picked up automatically.
enum ImageCache {
    private static let cache: NSCache<NSString, UIImage> = {
        let c = NSCache<NSString, UIImage>()
        c.totalCostLimit = 64 * 1024 * 1024   // ~64 MB of decoded pixels
        return c
    }()

    private static let colorCache = NSCache<NSString, CoverColorsBox>()

    /// Returns the image at `url`, downsampled so its longest side is at most
    /// `maxPointSize` points (at screen scale).
    static func image(at url: URL?, maxPointSize: CGFloat) -> UIImage? {
        guard let url else { return nil }
        let maxPixels = Int(maxPointSize * screenScale)
        guard let key = cacheKey(url: url, variant: "\(maxPixels)") else { return nil }
        if let hit = cache.object(forKey: key) { return hit }

        guard let image = downsample(url: url, maxPixels: maxPixels) else { return nil }
        cache.setObject(image, forKey: key, cost: cost(of: image))
        return image
    }

    /// A pre-blurred copy of the image, rendered once, for display with
    /// `.scaledToFill()` in a frame of `fillSize` points. Matches SwiftUI's
    /// `.blur(radius:)` (including its soft edges) without the GPU having to
    /// recompute the blur whenever something nearby animates — like the
    /// spinning reels drawn on top of it.
    static func blurredImage(at url: URL?, fillSize: CGSize, radius: CGFloat) -> UIImage? {
        guard let url else { return nil }
        guard let key = cacheKey(url: url, variant: "blur-\(fillSize.width)x\(fillSize.height)-\(radius)") else { return nil }
        if let hit = cache.object(forKey: key) { return hit }

        // Size the image as it appears on screen with scaledToFill, at 1 pixel
        // per point: the blur is soft, so extra resolution is wasted work.
        guard let pixelSize = pixelSize(of: url), pixelSize.width > 0, pixelSize.height > 0 else { return nil }
        let fillScale = max(fillSize.width / pixelSize.width, fillSize.height / pixelSize.height)
        let displayedLongSide = max(pixelSize.width, pixelSize.height) * fillScale
        guard let small = downsample(url: url, maxPixels: Int(displayedLongSide.rounded(.up)), scale: 1),
              let blurred = blur(small, radius: radius) else { return nil }
        cache.setObject(blurred, forKey: key, cost: cost(of: blurred))
        return blurred
    }

    /// Cover colors for library spines, computed once per image + intensity.
    static func coverColors(at url: URL?, intensity: Double) -> CoverColors? {
        guard let url,
              let key = cacheKey(url: url, variant: "colors-\(intensity)") else { return nil }
        if let hit = colorCache.object(forKey: key) { return hit.colors }
        // A small thumbnail is plenty: the extractor samples at 30×30.
        guard let thumb = image(at: url, maxPointSize: 60) else { return nil }
        let colors = ColorExtractor.extractColors(from: thumb, intensity: intensity)
        colorCache.setObject(CoverColorsBox(colors), forKey: key)
        return colors
    }

    // MARK: - Helpers

    private static var screenScale: CGFloat {
        let scale = UITraitCollection.current.displayScale
        return scale > 0 ? scale : 3
    }

    private static func cacheKey(url: URL, variant: String) -> NSString? {
        guard let attrs = try? FileManager.default.attributesOfItem(atPath: url.path) else { return nil }
        let mtime = (attrs[.modificationDate] as? Date)?.timeIntervalSince1970 ?? 0
        return "\(url.path)|\(mtime)|\(variant)" as NSString
    }

    private static func downsample(url: URL, maxPixels: Int, scale: CGFloat = screenScale) -> UIImage? {
        let sourceOptions = [kCGImageSourceShouldCache: false] as CFDictionary
        guard let source = CGImageSourceCreateWithURL(url as CFURL, sourceOptions) else { return nil }
        let options = [
            kCGImageSourceCreateThumbnailFromImageAlways: true,
            kCGImageSourceShouldCacheImmediately: true,
            kCGImageSourceCreateThumbnailWithTransform: true,
            kCGImageSourceThumbnailMaxPixelSize: maxPixels
        ] as CFDictionary
        guard let cgImage = CGImageSourceCreateThumbnailAtIndex(source, 0, options) else { return nil }
        return UIImage(cgImage: cgImage, scale: scale, orientation: .up)
    }

    private static func pixelSize(of url: URL) -> CGSize? {
        guard let source = CGImageSourceCreateWithURL(url as CFURL, nil),
              let props = CGImageSourceCopyPropertiesAtIndex(source, 0, nil) as? [CFString: Any],
              let w = props[kCGImagePropertyPixelWidth] as? CGFloat,
              let h = props[kCGImagePropertyPixelHeight] as? CGFloat else { return nil }
        // EXIF orientations 5–8 are rotated 90°.
        let orientation = props[kCGImagePropertyOrientation] as? Int ?? 1
        return orientation >= 5 ? CGSize(width: h, height: w) : CGSize(width: w, height: h)
    }

    // Blur in gamma-encoded sRGB, like Core Animation does for SwiftUI's
    // `.blur`, so the result looks the same (linear light comes out brighter).
    private static let ciContext = CIContext(options: [
        .cacheIntermediates: false,
        .workingColorSpace: CGColorSpace(name: CGColorSpace.sRGB)!
    ])

    private static func blur(_ image: UIImage, radius: CGFloat) -> UIImage? {
        guard let input = CIImage(image: image) else { return nil }
        // Not clamped: like SwiftUI's blur, the edges fade out softly.
        let blurred = input
            .applyingGaussianBlur(sigma: Double(radius))
            .cropped(to: input.extent)
        guard let cg = ciContext.createCGImage(blurred, from: input.extent) else { return nil }
        return UIImage(cgImage: cg, scale: image.scale, orientation: .up)
    }

    private static func cost(of image: UIImage) -> Int {
        guard let cg = image.cgImage else { return 0 }
        return cg.bytesPerRow * cg.height
    }
}

private final class CoverColorsBox {
    let colors: CoverColors
    init(_ colors: CoverColors) { self.colors = colors }
}
