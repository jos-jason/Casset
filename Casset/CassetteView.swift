import SwiftUI
import Combine

// MARK: - Mode Enum
enum CassetteMode: String, CaseIterable {
    case classic   = "classic"
    case realistic = "realistic"
    case bold      = "bold"
    var label: String {
        switch self {
        case .classic:   return "Classic"
        case .realistic: return "Realistic"
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
// Rigid arc covers top 75% of each end cap (−90° → 45°).
// One smooth cubic per side spans the lower quarter of the cap + the bottom.
// Joint is at the 45° diagonal where arc and cubic tangents nearly agree — visually seamless.
// G1 continuous everywhere.
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
        let s2: CGFloat = 0.7071            // sin/cos 45°

        // 45° handoff points
        let rHx = x2 + r * s2              // right handoff x
        let rHy = cy + r * s2              // right handoff y
        let lHx = x1 - r * s2              // left  handoff x
        let lHy = cy + r * s2              // left  handoff y (same by symmetry)

        // Arc tangent at 45° on right cap (CCW): (−s2, s2) = down-left
        // Arc tangent at 135° on left cap (CCW): (−s2, −s2) = up-left
        // → cubic must ARRIVE at left handoff going up-left,
        //   so CP2 sits below-right of lH.

        // Handle lengths — capH grows with sag for organic deformation
        let capH   = r * 0.42 + sagAmount * 0.38
        let apexH  = (x2 - cx) * 0.30
        let apex   = CGPoint(x: cx, y: bottom + sagAmount)

        var p = Path()
        p.move(to: CGPoint(x: x1, y: top))
        p.addLine(to: CGPoint(x: x2, y: top))

        // ── Right cap: rigid arc, top (−90°) → 45° ─────────────
        p.addArc(
            center:     CGPoint(x: x2, y: cy),
            radius:     r,
            startAngle: .degrees(-90),
            endAngle:   .degrees(45),
            clockwise:  false
        )

        // ── Right blend: ONE cubic, 45° handoff → apex ──────────
        // Departs tangentially (down-left) from arc — G1 at handoff
        // Arrives horizontally at apex — G1 with left cubic
        p.addCurve(
            to:       apex,
            control1: CGPoint(x: rHx - capH * s2, y: rHy + capH * s2),
            control2: CGPoint(x: cx + apexH,       y: bottom + sagAmount)
        )

        // ── Left blend: ONE cubic, apex → 135° handoff ──────────
        // Departs horizontally from apex
        // Arrives tangentially (up-left) into left arc — G1 at handoff
        p.addCurve(
            to:       CGPoint(x: lHx, y: lHy),
            control1: CGPoint(x: cx - apexH,       y: bottom + sagAmount),
            control2: CGPoint(x: lHx + capH * s2,  y: lHy  + capH * s2)
        )

        // ── Left cap: rigid arc, 135° → 270° (= top) ───────────
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

// MARK: - Classic Mode (unchanged)
struct ClassicCassetteView: View {
    var isPlaying:  Bool
    var coverImage: UIImage?
    @State private var reelRotation: Double = 0
    @Environment(\.colorScheme) var colorScheme
    let timer = Timer.publish(every: 0.03, on: .main, in: .common).autoconnect()
    var strokeColor: Color { colorScheme == .dark ? .white : .black }
    var fillColor:   Color { colorScheme == .dark ? Color(white: 0.07) : Color(white: 0.93) }
    var bodyFill:    Color { colorScheme == .dark ? Color.white.opacity(0.04) : Color.black.opacity(0.04) }
    var body: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 20).fill(bodyFill)
                .overlay(RoundedRectangle(cornerRadius: 20).stroke(strokeColor.opacity(0.75), lineWidth: 1.5))
                .frame(width: 310, height: 170)
            Capsule().fill(fillColor)
                .overlay(Capsule().stroke(strokeColor.opacity(0.35), lineWidth: 1))
                .frame(width: 250, height: 110)
            reelView(rotation: reelRotation).offset(x: -72)
            reelView(rotation: reelRotation).offset(x:  72)
            if let img = coverImage {
                Image(uiImage: img).resizable().scaledToFill()
                    .frame(width: 36, height: 36)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).stroke(strokeColor.opacity(0.4), lineWidth: 1))
            } else {
                Circle().fill(fillColor)
                    .overlay(Circle().stroke(strokeColor.opacity(0.35), lineWidth: 1))
                    .frame(width: 18, height: 18)
            }
        }
        .onReceive(timer) { _ in if isPlaying { reelRotation += 1.5 } }
    }
    func reelView(rotation: Double) -> some View {
        ZStack {
            Circle().stroke(strokeColor.opacity(0.55), lineWidth: 1.5).frame(width: 78, height: 78)
            ForEach(0..<3, id: \.self) { i in
                Capsule().fill(strokeColor.opacity(0.55))
                    .frame(width: 2, height: 13).offset(y: -21)
                    .rotationEffect(.degrees(Double(i) * 120 + rotation))
            }
            Circle().fill(fillColor)
                .overlay(Circle().stroke(strokeColor.opacity(0.5), lineWidth: 1.5))
                .frame(width: 22, height: 22)
        }
    }
}

// MARK: - Realistic Mode
struct RealisticCassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage?
    var actionTrigger: UUID

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
        .onReceive(timer) { _ in if isPlaying { reelRotation += 1.5 } }
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
            // No hub dot
        }
    }
}

// MARK: - Bold Mode (unchanged)
struct BoldCassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage?
    var actionTrigger: UUID
    @State private var reelRotation: Double = 0
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
            Capsule().fill(fillColor)
                .overlay(Capsule().stroke(strokeColor, lineWidth: 3.5))
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
        .onReceive(timer) { _ in if isPlaying { reelRotation += 1.5 } }
    }
    func reelView(rotation: Double) -> some View {
        ZStack {
            Circle().stroke(strokeColor, lineWidth: 4).frame(width: 82, height: 82)
            Circle().stroke(strokeColor, lineWidth: 3.5).frame(width: 50, height: 50)
            ForEach(0..<3, id: \.self) { i in
                RoundedRectangle(cornerRadius: 3)
                    .fill(strokeColor)
                    .frame(width: 5, height: 20)
                    .offset(x: 3, y: -16)
                    .rotationEffect(.degrees(Double(i) * 120 + rotation))
            }
            Circle().fill(strokeColor).frame(width: 14, height: 14)
        }
    }
}

// MARK: - CassetteView (router)
struct CassetteView: View {
    var isPlaying:     Bool
    var coverImage:    UIImage? = nil
    var actionTrigger: UUID     = UUID()
    @AppStorage("showCoverOnCassette") var showCoverOnCassette: Bool   = true
    @AppStorage("cassetteMode")        var cassetteModeRaw:    String  = CassetteMode.classic.rawValue
    var cassetteMode:  CassetteMode { CassetteMode(rawValue: cassetteModeRaw) ?? .classic }
    var resolvedCover: UIImage?     { showCoverOnCassette ? coverImage : nil }
    var body: some View {
        switch cassetteMode {
        case .classic:
            ClassicCassetteView(isPlaying: isPlaying, coverImage: resolvedCover)
        case .realistic:
            RealisticCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger)
        case .bold:
            BoldCassetteView(isPlaying: isPlaying, coverImage: resolvedCover, actionTrigger: actionTrigger)
        }
    }
}

