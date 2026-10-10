import SwiftUI
import UIKit

struct CoverColors {
    let background: Color
    let text: Color
    let accent: Color
}

enum ColorExtractor {
    /// Extracts colors from an image. `intensity` (0–1) shifts the dominant color
    /// darker (0) or brighter (1), with 0.5 using the color as-is.
    static func extractColors(from image: UIImage, intensity: Double = 0.5) -> CoverColors {
        guard let cgImage = image.cgImage else {
            return defaultColors
        }

        let width = 30
        let height = 30
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

                // Skip only truly black or pure white pixels
                if bri < 0.02 { continue }
                if sat < 0.03 && bri > 0.95 { continue }

                // Try to bucket into existing color (don't average — keep the original color)
                var found = false
                for i in colorBuckets.indices {
                    let dh = min(abs(colorBuckets[i].h - hue), 1 - abs(colorBuckets[i].h - hue))
                    let ds = abs(colorBuckets[i].s - sat)
                    let db = abs(colorBuckets[i].b - bri)
                    if dh < 0.08 && ds < 0.25 && db < 0.25 {
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

        // Use the most dominant color, shifted by intensity preference
        let bg = colorBuckets[0]
        // intensity 0 = darker (multiply brightness by 0.4), 0.5 = as-is, 1 = brighter (push toward 1.0)
        let baseBri = Double(bg.b)
        let adjustedBri: Double
        if intensity <= 0.5 {
            // 0→0.5 maps to 0.4×...1.0× of the original brightness
            let factor = 0.4 + (intensity / 0.5) * 0.6
            adjustedBri = baseBri * factor
        } else {
            // 0.5→1.0 lerps brightness from original toward 1.0
            let t = (intensity - 0.5) / 0.5
            adjustedBri = baseBri + (1.0 - baseBri) * t * 0.6
        }
        let backgroundColor = Color(
            hue: Double(bg.h),
            saturation: Double(bg.s),
            brightness: min(adjustedBri, 1.0)
        )

        // Derive accent stripe from the same color, shifted opposite direction
        let accentColor: Color
        if adjustedBri > 0.6 {
            accentColor = Color(
                hue: Double(bg.h),
                saturation: Double(min(bg.s + 0.15, 1.0)),
                brightness: adjustedBri * 0.65
            )
        } else {
            accentColor = Color(
                hue: Double(bg.h),
                saturation: Double(bg.s * 0.6),
                brightness: min(adjustedBri + 0.3, 1.0)
            )
        }

        // White text for contrast (the sketch lines are also white)
        let textColor = Color.white

        return CoverColors(background: backgroundColor, text: textColor, accent: accentColor)
    }

    static let defaultColors = CoverColors(
        background: Color(white: 0.18),
        text: Color(white: 0.85),
        accent: Color(white: 0.5)
    )
}
