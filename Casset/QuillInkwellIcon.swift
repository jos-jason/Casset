import SwiftUI

struct QuillInkwellIcon: View {
    var size: CGFloat = 20
    
    var body: some View {
        Canvas { context, size in
            // Inkwell (simple bottle shape)
            let inkwellPath = Path { path in
                let centerX = size.width * 0.35
                let bottleWidth: CGFloat = size.width * 0.25
                let bottleHeight: CGFloat = size.height * 0.6
                let neckHeight: CGFloat = size.height * 0.15
                
                // Bottle body
                path.move(to: CGPoint(x: centerX - bottleWidth/2, y: size.height * 0.85))
                path.addLine(to: CGPoint(x: centerX - bottleWidth/2, y: size.height * 0.4))
                
                // Neck
                path.addLine(to: CGPoint(x: centerX - bottleWidth/3, y: size.height * 0.25))
                path.addLine(to: CGPoint(x: centerX - bottleWidth/3, y: size.height * 0.15))
                
                // Top cap
                path.addLine(to: CGPoint(x: centerX + bottleWidth/3, y: size.height * 0.15))
                path.addLine(to: CGPoint(x: centerX + bottleWidth/3, y: size.height * 0.25))
                
                // Right side
                path.addLine(to: CGPoint(x: centerX + bottleWidth/2, y: size.height * 0.4))
                path.addLine(to: CGPoint(x: centerX + bottleWidth/2, y: size.height * 0.85))
                
                // Bottom curve
                path.addQuadCurve(
                    to: CGPoint(x: centerX - bottleWidth/2, y: size.height * 0.85),
                    control: CGPoint(x: centerX, y: size.height * 0.95)
                )
            }
            
            // Feather quill (simple curved line with barbs)
            let quillPath = Path { path in
                let startX = size.width * 0.55
                let startY = size.height * 0.75
                let endX = size.width * 0.9
                let endY = size.height * 0.15
                
                // Main shaft (slight curve)
                path.move(to: CGPoint(x: startX, y: startY))
                path.addQuadCurve(
                    to: CGPoint(x: endX, y: endY),
                    control: CGPoint(x: size.width * 0.65, y: size.height * 0.35)
                )
                
                // Left barbs (3 simple lines)
                for i in 0...2 {
                    let t = CGFloat(i) * 0.25 + 0.2
                    let pointOnCurve = calculateQuadPoint(
                        start: CGPoint(x: startX, y: startY),
                        control: CGPoint(x: size.width * 0.65, y: size.height * 0.35),
                        end: CGPoint(x: endX, y: endY),
                        t: t
                    )
                    
                    let barbLength: CGFloat = size.width * (0.08 - CGFloat(i) * 0.02)
                    path.move(to: pointOnCurve)
                    path.addLine(to: CGPoint(
                        x: pointOnCurve.x - barbLength,
                        y: pointOnCurve.y + barbLength * 0.5
                    ))
                }
            }
            
            context.stroke(inkwellPath, with: .color(.primary), lineWidth: 1.5)
            context.stroke(quillPath, with: .color(.primary), lineWidth: 1.5)
        }
        .frame(width: size, height: size)
    }
    
    private func calculateQuadPoint(start: CGPoint, control: CGPoint, end: CGPoint, t: CGFloat) -> CGPoint {
        let x = pow(1 - t, 2) * start.x + 2 * (1 - t) * t * control.x + pow(t, 2) * end.x
        let y = pow(1 - t, 2) * start.y + 2 * (1 - t) * t * control.y + pow(t, 2) * end.y
        return CGPoint(x: x, y: y)
    }
}

// Preview
#Preview {
    VStack(spacing: 40) {
        QuillInkwellIcon(size: 30)
        QuillInkwellIcon(size: 50)
        QuillInkwellIcon(size: 70)
    }
}
