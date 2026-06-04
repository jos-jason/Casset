import SwiftUI
import UIKit

struct CoverColors {
    let background: Color
    let text: Color
}

enum ColorExtractor {
    /// Extracts two distinct colors from an image: one for background (more muted/dark),
    /// one for text (contrasting). Falls back to defaults if extraction fails.
    static func extractColors(from image: UIImage) -> CoverColors {
        guard let cgImage = image.cgImage else {
            return defaultColors
        }

        let width = 20
        let height = 20
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bytesPerPixel = 4
        let bytesPerRow = bytesPerPixel * width
        var pixelData = [UInt8](repeating: 0, count: width * height * bytesPerPixel)

        guard let context = CGContext(
            data: &pixelData,
            width: width,
            height: height,
            bitsPerComponent: 8,
            bytesPerRow: bytesPerRow,
            space: colorSpace,
            bitmapInfo: CGImageAlphaInfo.premultipliedLast.rawValue
        ) else {
            return defaultColors
        }

        context.draw(cgImage, in: CGRect(x: 0, y: 0, width: width, height: height))

        // Collect color samples with HSB values
        var colorBuckets: [(h: CGFloat, s: CGFloat, b: CGFloat, count: Int)] = []

        for y in 0..<height {
            for x in 0..<width {
                let offset = (y * width + x) * bytesPerPixel
                let r = CGFloat(pixelData[offset]) / 255.0
                let g = CGFloat(pixelData[offset + 1]) / 255.0
                let b = CGFloat(pixelData[offset + 2]) / 255.0

                let uiColor = UIColor(red: r, green: g, blue: b, alpha: 1.0)
                var hue: CGFloat = 0
                var sat: CGFloat = 0
                var bri: CGFloat = 0
                uiColor.getHue(&hue, saturation: &sat, brightness: &bri, alpha: nil)

                // Skip very dark or very light pixels (not interesting)
                if bri < 0.05 || (sat < 0.05 && bri > 0.9) { continue }

                // Try to bucket into existing color
                var found = false
                for i in colorBuckets.indices {
                    let dh = min(abs(colorBuckets[i].h - hue), 1 - abs(colorBuckets[i].h - hue))
                    let ds = abs(colorBuckets[i].s - sat)
                    let db = abs(colorBuckets[i].b - bri)
                    if dh < 0.08 && ds < 0.25 && db < 0.25 {
                        let c = CGFloat(colorBuckets[i].count)
                        colorBuckets[i].h = (colorBuckets[i].h * c + hue) / (c + 1)
                        colorBuckets[i].s = (colorBuckets[i].s * c + sat) / (c + 1)
                        colorBuckets[i].b = (colorBuckets[i].b * c + bri) / (c + 1)
                        colorBuckets[i].count += 1
                        found = true
                        break
                    }
                }
                if !found {
                    colorBuckets.append((h: hue, s: sat, b: bri, count: 1))
                }
            }
        }

        // Sort by frequency
        colorBuckets.sort { $0.count > $1.count }

        guard !colorBuckets.isEmpty else { return defaultColors }

        // Pick the most dominant color for background, darkened/muted
        let bg = colorBuckets[0]
        let backgroundColor = Color(
            hue: Double(bg.h),
            saturation: Double(min(bg.s * 0.7, 0.5)),
            brightness: Double(min(bg.b * 0.35, 0.3))
        )

        // Pick a contrasting color for text — try a different bucket, or lighten the first
        var textColor: Color
        if colorBuckets.count > 1 {
            // Find a bucket that's sufficiently different from background
            var chosen = colorBuckets[1]
            for bucket in colorBuckets.dropFirst() {
                let dh = min(abs(bucket.h - bg.h), 1 - abs(bucket.h - bg.h))
                if dh > 0.05 || abs(bucket.b - bg.b) > 0.2 {
                    chosen = bucket
                    break
                }
            }
            textColor = Color(
                hue: Double(chosen.h),
                saturation: Double(max(chosen.s * 0.8, 0.15)),
                brightness: Double(max(chosen.b, 0.75))
            )
        } else {
            // Only one color cluster — make a bright version for text
            textColor = Color(
                hue: Double(bg.h),
                saturation: Double(max(bg.s * 0.5, 0.1)),
                brightness: 0.85
            )
        }

        return CoverColors(background: backgroundColor, text: textColor)
    }

    static let defaultColors = CoverColors(
        background: Color(white: 0.18),
        text: Color(white: 0.85)
    )
}
