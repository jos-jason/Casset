import SwiftUI
import Combine

// MARK: - Mode Enum
enum CassetteMode: String, CaseIterable {
    case classic   = "classic"
    case realistic = "realistic"
    case bold      = "bold"
    var label: String {
        switch self {
        case .classic:   return "Graphic"
        case .realistic: return "Standard"
        case .bold:      return "Bold"
        }
    }
}

// MARK: - Tape Loop Shape
struct TapeLoopShape: Shape {
    var sagAmount: CGFloat
    var animatableData: CGFloat {
        get { sagAmount }
        set { sagAmount = newValue }
    }
    func path(in rect: CGRect) -> Path {
        var p = Path()
        let cx = rect.midX; let cy = rect.midY
        let offX: CGFloat = 72; let r: CGFloat = 38
        let lx = cx - offX; let rx = cx + offX
        p.move(to: CGPoint(x: lx, y: cy - r))
        p.addLine(to: CGPoint(x: rx, y: cy - r))
        p.addArc(center: CGPoint(x: rx, y: cy), radius: r,
                 startAngle: .degrees(-90), endAngle: .degrees(90), clockwise: false)
        p.addQuadCurve(to: CGPoint(x: lx, y: cy + r),
                       control: CGPoint(x: cx, y: cy + r + sagAmount))
        p.addArc(center: CGPoint(x: lx, y: cy), radius: r,
                 startAngle: .degrees(90), endAngle: .degrees(-90), clockwise: false)
        p.closeSubpath()
        return p
    }
}

// MARK: - Bounce Window Shape
struct BounceWindowShape: Shape {
    var sagAmount: CGFloat
    var animatableData: CGFloat {
        get { sagAmount }
        set { sagAmount = newValue }
    }

    func path(in rect: CGRect) -> Path {
        let r       = rect.height / 2
        let x1      = rect.minX + r
        let x2      = rect.maxX - r
        let cx      = rect.midX
        let cy      = rect.midY
        let top     = rect.minY
        let bottom  = rect.maxY
        let s2: CGFloat = 0.7071

        let rHx = x2 + r * s2
        let rHy = cy + r * s2
        let lHx = x1 - r * s2
        let lHy = cy + r * s2

        let capH   = r * 0.42 + sagAmount * 0.38
        let apexH  = (x2 - cx) * 0.30
        let apex   = CGPoint(x: cx, y: bottom + sagAmount)

        var p = Path()
        p.move(to: CGPoint(x: x1, y: top))
        p.addLine(to: CGPoint(x: x2, y: top))

        p.addArc(
            center:     CGPoint(x: x2, y: cy),
            radius:     r,
            startAngle: .degrees(-90),
            endAngle:   .degrees(45),
            clockwise:  false
        )

        p.addCurve(
            to:       apex,
            control1: CGPoint(x: rHx - capH * s2, y: rHy + capH * s2),
            control2: CGPoint(x: cx + apexH,       y: bottom + sagAmount)
        )

        p.addCurve(
            to:       CGPoint(x: lHx, y: lHy),
            control1: CGPoint(x: cx - apexH,       y: bottom + sagAmount),
            control2: CGPoint(x: lHx + capH * s2,  y: lHy  + capH * s2)
        )

        p.addArc(
            center:     CGPoint(x: x1, y: cy),
            radius:     r,
            startAngle: .degrees(135),
            endAngle:   .degrees(270),
            clockwise:  false
        )

        p.closeSubpath()
        return p
    }
}

// MARK: - Classic Mode
struct ClassicCassetteView: View {
    var isPlaying:  Bool
    var coverImage: UIImage?
    var actionTrigger: UUID
    var playbackSpeed: Double = 1.0
    
    @State private var reelRotation: Double = 0
    @State private var windowSag: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    var strokeColor: Color { colorScheme == .dark ? .white : .black }
    var fillColor:   Color { colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93) }
    var bodyFill:    Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    
    var body: some View {
        ZStack {
            // Background: Cover art with blur mirror effect
            if let img = coverImage {
                ZStack {
                    // Blurred background fill
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                        .frame(width: 310, height: 170)
                        .blur(radius: 40)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                    
                    // Clear center image fitted to height
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(height: 170)
                        .clipShape(RoundedRectangle(cornerRadius: 22))
                }
                .frame(width: 310, height: 170)
            } else {
                RoundedRectangle(cornerRadius: 22)
                    .fill(bodyFill)
                    .frame(width: 310, height: 170)
            }
            
            // Cassette outline (realistic style - thick stroke)
            RoundedRectangle(cornerRadius: 22)
                .stroke(strokeColor, lineWidth: 4)
                .frame(width: 310, height: 170)

            // Tape window shape (realistic style with bounce)
            BounceWindowShape(sagAmount: windowSag)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 248, height: 114)

            // Reels
            reelView(rotation: reelRotation).offset(x: -72)
            reelView(rotation: reelRotation).offset(x:  72)
        }
        .onReceive(timer) { _ in if isPlaying { reelRotation += 1.5 * playbackSpeed } }
        .onChange(of: isPlaying)     { triggerBounce() }
        .onChange(of: actionTrigger) { triggerBounce() }
    }
    
    private func triggerBounce() {
        withAnimation(.none) { windowSag = 14 }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.36, blendDuration: 0)) {
            windowSag = 0
        }
    }
    
    func reelView(rotation: Double) -> some View {
        ZStack {
            Circle().stroke(strokeColor, lineWidth: 4).frame(width: 82, height: 82)
            Circle().stroke(strokeColor, lineWidth: 3.5).frame(width: 50, height: 50)
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(strokeColor)
                    .frame(width: 5, height: 20)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(i) * 120 + rotation))
            }
        }
    }
}

// MARK: - Realistic Mode
struct RealisticCassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage?
    var actionTrigger: UUID
    var playbackSpeed: Double = 1.0

    @State private var reelRotation: Double  = 0
    @State private var windowSag:    CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()

    var strokeColor: Color { colorScheme == .dark ? .white : .black }
    var fillColor:   Color { colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93) }
    var bodyFill:    Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }

    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(bodyFill)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(strokeColor, lineWidth: 4))
                .frame(width: 310, height: 170)

            BounceWindowShape(sagAmount: windowSag)
                .fill(fillColor)
                .frame(width: 248, height: 114)

            BounceWindowShape(sagAmount: windowSag)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 248, height: 114)

            reelView(rotation: reelRotation).offset(x: -72)
            reelView(rotation: reelRotation).offset(x:  72)

            if let img = coverImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor.opacity(0.6), lineWidth: 2))
            }
        }
        .onReceive(timer) { _ in if isPlaying { reelRotation += 1.5 * playbackSpeed } }
        .onChange(of: isPlaying)     { triggerBounce() }
        .onChange(of: actionTrigger) { triggerBounce() }
    }

    private func triggerBounce() {
        withAnimation(.none) { windowSag = 14 }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.36, blendDuration: 0)) {
            windowSag = 0
        }
    }

    func reelView(rotation: Double) -> some View {
        ZStack {
            Circle().stroke(strokeColor, lineWidth: 4).frame(width: 82, height: 82)
            Circle().stroke(strokeColor, lineWidth: 3.5).frame(width: 50, height: 50)
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(strokeColor)
                    .frame(width: 5, height: 20)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(i) * 120 + rotation))
            }
        }
    }
}

// MARK: - Bold Mode
struct BoldCassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage?
    var actionTrigger: UUID
    var playbackSpeed: Double = 1.0
    
    @State private var reelRotation: Double = 0
    @State private var windowSag: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    var strokeColor: Color { colorScheme == .dark ? .white : .black }
    var fillColor:   Color { colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93) }
    var bodyFill:    Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    
    var backgroundColor: Color {
        if let image = coverImage, let centerColor = extractCenterColor(from: image) {
            return centerColor
        }
        return bodyFill
    }
    
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 22).fill(backgroundColor)
                .overlay(RoundedRectangle(cornerRadius: 22).stroke(strokeColor, lineWidth: 4))
                .frame(width: 310, height: 170)
            
            BounceWindowShape(sagAmount: windowSag)
                .fill(fillColor)
                .frame(width: 248, height: 114)
            
            BounceWindowShape(sagAmount: windowSag)
                .stroke(strokeColor, style: StrokeStyle(lineWidth: 3.5, lineCap: .round, lineJoin: .round))
                .frame(width: 248, height: 114)
            
            reelView(rotation: reelRotation).offset(x: -72)
            reelView(rotation: reelRotation).offset(x:  72)
            
            if let img = coverImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor.opacity(0.6), lineWidth: 2))
            }
        }
        .onReceive(timer) { _ in if isPlaying { reelRotation += 1.5 * playbackSpeed } }
        .onChange(of: isPlaying)     { triggerBounce() }
        .onChange(of: actionTrigger) { triggerBounce() }
    }
    
    private func triggerBounce() {
        withAnimation(.none) { windowSag = 14 }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.36, blendDuration: 0)) {
            windowSag = 0
        }
    }
    
    private func extractCenterColor(from image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        
        // Sample a small area from the center
        let centerX = width / 2
        let centerY = height / 2
        let sampleSize = 20 // Sample a 20x20 area
        
        guard let croppedImage = cgImage.cropping(to: CGRect(
            x: centerX - sampleSize / 2,
            y: centerY - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )) else { return nil }
        
        // Get pixel data
        let data = NSMutableData(length: sampleSize * sampleSize * 4)
        guard let pixelData = data else { return nil }
        
        let colorSpace = CGColorSpaceCreateDeviceRGB()
        let bitmapInfo = CGBitmapInfo(rawValue: CGImageAlphaInfo.premultipliedLast.rawValue)
        
        guard let context = CGContext(
            data: pixelData.mutableBytes,
            width: sampleSize,
            height: sampleSize,
            bitsPerComponent: 8,
            bytesPerRow: sampleSize * 4,
            space: colorSpace,
            bitmapInfo: bitmapInfo.rawValue
        ) else { return nil }
        
        context.draw(croppedImage, in: CGRect(x: 0, y: 0, width: sampleSize, height: sampleSize))
        
        // Calculate average color
        var totalRed: CGFloat = 0
        var totalGreen: CGFloat = 0
        var totalBlue: CGFloat = 0
        
        let pixels = pixelData.bytes.bindMemory(to: UInt8.self, capacity: sampleSize * sampleSize * 4)
        let pixelCount = sampleSize * sampleSize
        
        for i in 0..<pixelCount {
            let offset = i * 4
            totalRed += CGFloat(pixels[offset]) / 255.0
            totalGreen += CGFloat(pixels[offset + 1]) / 255.0
            totalBlue += CGFloat(pixels[offset + 2]) / 255.0
        }
        
        let avgRed = totalRed / CGFloat(pixelCount)
        let avgGreen = totalGreen / CGFloat(pixelCount)
        let avgBlue = totalBlue / CGFloat(pixelCount)
        
        return Color(red: avgRed, green: avgGreen, blue: avgBlue)
    }
    
    func reelView(rotation: Double) -> some View {
        ZStack {
            Circle().stroke(strokeColor, lineWidth: 4).frame(width: 82, height: 82)
            Circle().stroke(strokeColor, lineWidth: 3.5).frame(width: 50, height: 50)
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(strokeColor)
                    .frame(width: 5, height: 20)
                    .offset(y: -16)
                    .rotationEffect(.degrees(Double(i) * 120 + rotation))
            }
        }
    }
}

// MARK: - CassetteView (router with art toggle + fixed height)
struct CassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage? = nil
    var actionTrigger: UUID     = UUID()
    var showArtOnly:   Bool     = false

    @AppStorage("showCoverOnCassette") var showCoverOnCassette: Bool   = true
    @AppStorage("cassetteMode")        var cassetteModeRaw:    String  = CassetteMode.classic.rawValue
    @AppStorage("playbackSpeed")       var playbackSpeed:      Double  = 1.0

    @Environment(\.colorScheme) var colorScheme

    var cassetteMode:  CassetteMode { CassetteMode(rawValue: cassetteModeRaw) ?? .classic }
    var resolvedCover: UIImage?     { showCoverOnCassette ? coverImage : nil }
    var cassetteStrokeColor: Color  { colorScheme == .dark ? .white : .black }

    var body: some View {
        ZStack {
            if showArtOnly, let img = coverImage {
                Image(uiImage: img)
                    .resizable()
                    .scaledToFit()
                    .frame(width: 260, height: 170)
                    .clipShape(RoundedRectangle(cornerRadius: 22))
                    .overlay(
                        RoundedRectangle(cornerRadius: 22)
                            .stroke(cassetteStrokeColor, lineWidth: 4)
                    )
            } else {
                switch cassetteMode {
                case .classic:
                    ClassicCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger, playbackSpeed: playbackSpeed)
                case .realistic:
                    RealisticCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger, playbackSpeed: playbackSpeed)
                case .bold:
                    BoldCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger, playbackSpeed: playbackSpeed)
                }
            }
        }
        .frame(width: 310, height: 170)   // fixed size so title doesn’t move
    }
}

