import SwiftUI
import UIKit

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

// MARK: - Spinning Reel (Core Animation — render-server smooth)

/// The UIKit view that draws the reel and applies a CABasicAnimation to its
/// rotation transform.  Core Animation runs on the render server, a separate
/// process that is immune to main-thread SwiftUI work, timers, or view
/// re-evaluations, so the rotation is always perfectly smooth.
final class SpinningReelUIView: UIView {
    private let outerCircle = CAShapeLayer()
    private let innerCircle = CAShapeLayer()
    private let spokesLayer = CALayer()        // rotated by Core Animation
    private var spokeShapes: [CAShapeLayer] = []

    private(set) var isSpinning = false
    private var currentSpeed: Double = 1.0
    private var didSetup = false

    var reelColor: UIColor = .white {
        didSet { if reelColor != oldValue { applyColor() } }
    }

    override init(frame: CGRect) {
        super.init(frame: frame)
        backgroundColor = .clear
    }
    required init?(coder: NSCoder) {
        super.init(coder: coder)
        backgroundColor = .clear
    }

    // Build / reposition all layers when our size is known.
    override func layoutSubviews() {
        super.layoutSubviews()

        let bw = bounds.width, bh = bounds.height
        let size: CGFloat = 82
        let ox = (bw - size) / 2           // origin offset to center 82x82
        let oy = (bh - size) / 2
        let reelRect = CGRect(x: ox, y: oy, width: size, height: size)

        if !didSetup {
            didSetup = true

            // — outer circle —
            outerCircle.path = UIBezierPath(ovalIn: CGRect(origin: .zero, size: CGSize(width: size, height: size))).cgPath
            outerCircle.fillColor = UIColor.clear.cgColor
            outerCircle.lineWidth = 4
            layer.addSublayer(outerCircle)

            // — inner circle —
            let innerSize: CGFloat = 50
            let io = (size - innerSize) / 2
            innerCircle.path = UIBezierPath(ovalIn: CGRect(x: io, y: io, width: innerSize, height: innerSize)).cgPath
            innerCircle.fillColor = UIColor.clear.cgColor
            innerCircle.lineWidth = 3.5
            layer.addSublayer(innerCircle)

            // — spokes layer (this is what rotates) —
            spokesLayer.anchorPoint = CGPoint(x: 0.5, y: 0.5)
            layer.addSublayer(spokesLayer)

            let center = CGPoint(x: size / 2, y: size / 2)
            for i in 0..<3 {
                let spoke = CAShapeLayer()
                let w: CGFloat = 5, h: CGFloat = 20, cr: CGFloat = 3
                spoke.path = UIBezierPath(roundedRect: CGRect(x: -w/2, y: -h/2, width: w, height: h), cornerRadius: cr).cgPath
                spoke.bounds = CGRect(x: -w/2, y: -h/2, width: w, height: h)

                let angleRad = Double(i) * (.pi * 2.0 / 3.0)
                let dist: Double = 16
                spoke.position = CGPoint(
                    x: Double(center.x) + sin(angleRad) * dist,
                    y: Double(center.y) - cos(angleRad) * dist
                )
                spoke.transform = CATransform3DMakeRotation(angleRad, 0, 0, 1)
                spokesLayer.addSublayer(spoke)
                spokeShapes.append(spoke)
            }

            applyColor()
        }

        // Position all three containers identically (centered in our bounds).
        CALayer.performWithoutAnimation {
            outerCircle.frame = reelRect
            innerCircle.frame = reelRect
            // For spokesLayer use bounds + position so the anchorPoint stays centred.
            spokesLayer.bounds = CGRect(origin: .zero, size: CGSize(width: size, height: size))
            spokesLayer.position = CGPoint(x: reelRect.midX, y: reelRect.midY)
        }
    }

    private func applyColor() {
        outerCircle.strokeColor = reelColor.cgColor
        innerCircle.strokeColor = reelColor.cgColor
        for s in spokeShapes { s.fillColor = reelColor.cgColor }
    }

    override var intrinsicContentSize: CGSize { CGSize(width: 82, height: 82) }

    // MARK: – animation control

    func startSpinning(speed: Double) {
        guard !isSpinning else {
            updateSpeed(speed)
            return
        }
        currentSpeed = speed
        isSpinning = true
        addRotationAnimation()
    }

    func stopSpinning() {
        guard isSpinning else { return }
        isSpinning = false
        if let p = spokesLayer.presentation() {
            spokesLayer.transform = p.transform
        }
        spokesLayer.removeAnimation(forKey: "spin")
    }

    func updateSpeed(_ speed: Double) {
        // Re-adding the animation on every SwiftUI update is wasted work, so
        // only touch it when the speed actually changed.
        guard speed != currentSpeed else { return }
        currentSpeed = speed
        if isSpinning { updateAnimationSpeed() }
    }

    private func addRotationAnimation() {
        let a = CABasicAnimation(keyPath: "transform.rotation.z")
        a.fromValue = 0
        a.toValue = Double.pi * 2
        a.duration = 2.0 / currentSpeed
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        spokesLayer.removeAnimation(forKey: "spin")
        spokesLayer.add(a, forKey: "spin")
    }

    private func updateAnimationSpeed() {
        if let p = spokesLayer.presentation() {
            spokesLayer.transform = p.transform
        }
        let a = CABasicAnimation(keyPath: "transform.rotation.z")
        a.fromValue = 0
        a.toValue = Double.pi * 2
        a.duration = 2.0 / currentSpeed
        a.repeatCount = .infinity
        a.isRemovedOnCompletion = false
        a.isCumulative = true
        spokesLayer.add(a, forKey: "spin")
    }
}

private extension CALayer {
    static func performWithoutAnimation(_ block: () -> Void) {
        CATransaction.begin()
        CATransaction.setDisableActions(true)
        block()
        CATransaction.commit()
    }
}

/// SwiftUI wrapper for the Core Animation reel.
struct SpinningReelView: View {
    var isPlaying: Bool
    var playbackSpeed: Double
    var strokeColor: Color

    var body: some View {
        SpinningReelRepresentable(
            isPlaying: isPlaying,
            playbackSpeed: playbackSpeed,
            strokeColor: strokeColor
        )
        .frame(width: 82, height: 82)
    }
}

private struct SpinningReelRepresentable: UIViewRepresentable {
    var isPlaying: Bool
    var playbackSpeed: Double
    var strokeColor: Color

    func makeUIView(context: Context) -> SpinningReelUIView {
        let view = SpinningReelUIView(frame: CGRect(x: 0, y: 0, width: 82, height: 82))
        view.reelColor = UIColor(strokeColor)
        if isPlaying {
            view.startSpinning(speed: playbackSpeed)
        }
        return view
    }

    func updateUIView(_ uiView: SpinningReelUIView, context: Context) {
        uiView.reelColor = UIColor(strokeColor)
        if isPlaying {
            uiView.startSpinning(speed: playbackSpeed)
        } else {
            uiView.stopSpinning()
            uiView.updateSpeed(playbackSpeed)
        }
    }
}

// MARK: - Classic Mode
struct ClassicCassetteView: View {
    var isPlaying:  Bool
    var coverImage: UIImage?
    var blurredCoverImage: UIImage? = nil
    var actionTrigger: UUID
    var playbackSpeed: Double = 1.0
    
    @State private var windowSag: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme
    var strokeColor: Color { colorScheme == .dark ? .white : .black }
    var fillColor:   Color { colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93) }
    var bodyFill:    Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    
    var body: some View {
        ZStack {
            // Background: Cover art with blur mirror effect
            if let img = coverImage {
                ZStack {
                    // Blurred background fill (pre-rendered once when available)
                    if let blurred = blurredCoverImage {
                        Image(uiImage: blurred)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 310, height: 170)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    } else {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 310, height: 170)
                            .blur(radius: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 22))
                    }
                    
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
            SpinningReelView(isPlaying: isPlaying, playbackSpeed: playbackSpeed, strokeColor: strokeColor)
                .offset(x: -72)
            SpinningReelView(isPlaying: isPlaying, playbackSpeed: playbackSpeed, strokeColor: strokeColor)
                .offset(x:  72)
        }
        .onChange(of: isPlaying)     { triggerBounce() }
        .onChange(of: actionTrigger) { triggerBounce() }
    }
    
    private func triggerBounce() {
        withAnimation(.none) { windowSag = 14 }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.36, blendDuration: 0)) {
            windowSag = 0
        }
    }
}

// MARK: - Realistic Mode
struct RealisticCassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage?
    var actionTrigger: UUID
    var playbackSpeed: Double = 1.0

    @State private var windowSag: CGFloat = 0
    @Environment(\.colorScheme) var colorScheme

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

            SpinningReelView(isPlaying: isPlaying, playbackSpeed: playbackSpeed, strokeColor: strokeColor)
                .offset(x: -72)
            SpinningReelView(isPlaying: isPlaying, playbackSpeed: playbackSpeed, strokeColor: strokeColor)
                .offset(x:  72)

            if let img = coverImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor.opacity(0.6), lineWidth: 2))
            }
        }
        .onChange(of: isPlaying)     { triggerBounce() }
        .onChange(of: actionTrigger) { triggerBounce() }
    }

    private func triggerBounce() {
        withAnimation(.none) { windowSag = 14 }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.36, blendDuration: 0)) {
            windowSag = 0
        }
    }
}

// MARK: - Bold Mode
struct BoldCassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage?
    var actionTrigger: UUID
    var playbackSpeed: Double = 1.0
    
    @State private var windowSag: CGFloat = 0
    @State private var cachedBackgroundColor: Color?
    @Environment(\.colorScheme) var colorScheme
    var strokeColor: Color { colorScheme == .dark ? .white : .black }
    var fillColor:   Color { colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93) }
    var bodyFill:    Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    
    var backgroundColor: Color {
        cachedBackgroundColor ?? bodyFill
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
            
            SpinningReelView(isPlaying: isPlaying, playbackSpeed: playbackSpeed, strokeColor: strokeColor)
                .offset(x: -72)
            SpinningReelView(isPlaying: isPlaying, playbackSpeed: playbackSpeed, strokeColor: strokeColor)
                .offset(x:  72)
            
            if let img = coverImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 34, height: 34)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor.opacity(0.6), lineWidth: 2))
            }
        }
        .onChange(of: isPlaying)     { triggerBounce() }
        .onChange(of: actionTrigger) { triggerBounce() }
        .onAppear { extractColorIfNeeded() }
        .task(id: coverImage) {
            extractColorIfNeeded()
        }
    }
    
    private func extractColorIfNeeded() {
        guard cachedBackgroundColor == nil, let image = coverImage else { return }
        cachedBackgroundColor = Self.extractCenterColor(from: image)
    }

    private func triggerBounce() {
        withAnimation(.none) { windowSag = 14 }
        withAnimation(.spring(response: 0.62, dampingFraction: 0.36, blendDuration: 0)) {
            windowSag = 0
        }
    }
    
    private static func extractCenterColor(from image: UIImage) -> Color? {
        guard let cgImage = image.cgImage else { return nil }
        
        let width = cgImage.width
        let height = cgImage.height
        let centerX = width / 2
        let centerY = height / 2
        let sampleSize = 20
        
        guard let croppedImage = cgImage.cropping(to: CGRect(
            x: centerX - sampleSize / 2,
            y: centerY - sampleSize / 2,
            width: sampleSize,
            height: sampleSize
        )) else { return nil }
        
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
    

}

// MARK: - CassetteView (router with art toggle + fixed height)
struct CassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage? = nil
    /// Pre-blurred cover for the classic cassette background (310×170).
    var blurredCassetteImage: UIImage? = nil
    /// Pre-blurred cover for the art-only view (330×330).
    var blurredArtImage: UIImage? = nil
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
                ZStack {
                    // Background: Cover art with blur mirror effect
                    if let blurred = blurredArtImage {
                        Image(uiImage: blurred)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 330, height: 330)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                    } else {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFill()
                            .frame(width: 330, height: 330)
                            .blur(radius: 40)
                            .clipShape(RoundedRectangle(cornerRadius: 28))
                    }
                    
                    // Main cover image
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFit()
                        .frame(width: 330, height: 330)
                        .clipShape(RoundedRectangle(cornerRadius: 28))
                    
                    // Border stroke
                    RoundedRectangle(cornerRadius: 28)
                        .stroke(cassetteStrokeColor, lineWidth: 4)
                        .frame(width: 330, height: 330)
                }
                .frame(width: 330, height: 330)
            } else {
                switch cassetteMode {
                case .classic:
                    ClassicCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, blurredCoverImage: showCoverOnCassette ? blurredCassetteImage : nil, actionTrigger: actionTrigger, playbackSpeed: playbackSpeed)
                case .realistic:
                    RealisticCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger, playbackSpeed: playbackSpeed)
                case .bold:
                    BoldCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger, playbackSpeed: playbackSpeed)
                }
            }
        }
        .frame(width: 310, height: 170)   // fixed size so title doesn't move
    }
}

