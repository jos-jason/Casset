import SwiftUI

struct QuillInkwellIcon: View {
    var size: CGFloat = 20
    
    var body: some View {
        Canvas { context, canvasSize in
            let scale = size / 24.0 // Base size of 24pts
            
            // Main feather body - curved shape
            let featherPath = Path { path in
                // Start at the nib point
                path.move(to: CGPoint(x: 6 * scale, y: 22 * scale))
                
                // Left side of feather - flowing curve
                path.addCurve(
                    to: CGPoint(x: 3 * scale, y: 18 * scale),
                    control1: CGPoint(x: 4 * scale, y: 21 * scale),
                    control2: CGPoint(x: 3 * scale, y: 19.5 * scale)
                )
                
                path.addCurve(
                    to: CGPoint(x: 8 * scale, y: 8 * scale),
                    control1: CGPoint(x: 3 * scale, y: 14 * scale),
                    control2: CGPoint(x: 5 * scale, y: 10 * scale)
                )
                
                path.addCurve(
                    to: CGPoint(x: 18 * scale, y: 2 * scale),
                    control1: CGPoint(x: 10 * scale, y: 6 * scale),
                    control2: CGPoint(x: 14 * scale, y: 3 * scale)
                )
                
                // Top curve of feather
                path.addCurve(
                    to: CGPoint(x: 22 * scale, y: 1 * scale),
                    control1: CGPoint(x: 20 * scale, y: 1.5 * scale),
                    control2: CGPoint(x: 21 * scale, y: 1 * scale)
                )
                
                // Right side of feather - flowing back down
                path.addCurve(
                    to: CGPoint(x: 15 * scale, y: 10 * scale),
                    control1: CGPoint(x: 20 * scale, y: 3 * scale),
                    control2: CGPoint(x: 17 * scale, y: 6 * scale)
                )
                
                path.addCurve(
                    to: CGPoint(x: 11 * scale, y: 18 * scale),
                    control1: CGPoint(x: 13 * scale, y: 13 * scale),
                    control2: CGPoint(x: 11.5 * scale, y: 15.5 * scale)
                )
                
                // Back to nib
                path.addCurve(
                    to: CGPoint(x: 6 * scale, y: 22 * scale),
                    control1: CGPoint(x: 10.5 * scale, y: 20 * scale),
                    control2: CGPoint(x: 8 * scale, y: 21 * scale)
                )
            }
            
            // Central spine highlight - curved white line
            let spinePath = Path { path in
                path.move(to: CGPoint(x: 7 * scale, y: 20 * scale))
                
                path.addCurve(
                    to: CGPoint(x: 12 * scale, y: 10 * scale),
                    control1: CGPoint(x: 8 * scale, y: 16 * scale),
                    control2: CGPoint(x: 10 * scale, y: 12 * scale)
                )
                
                path.addCurve(
                    to: CGPoint(x: 19 * scale, y: 3 * scale),
                    control1: CGPoint(x: 14 * scale, y: 8 * scale),
                    control2: CGPoint(x: 16.5 * scale, y: 5 * scale)
                )
            }
            
            // Nib details - the pen tip
            let nibPath = Path { path in
                // Outer nib shape
                path.move(to: CGPoint(x: 6 * scale, y: 22 * scale))
                path.addLine(to: CGPoint(x: 4 * scale, y: 24 * scale))
                path.addLine(to: CGPoint(x: 5.5 * scale, y: 23 * scale))
                path.addLine(to: CGPoint(x: 6 * scale, y: 22 * scale))
                
                // Inner split line
                path.move(to: CGPoint(x: 5.5 * scale, y: 22.5 * scale))
                path.addLine(to: CGPoint(x: 6 * scale, y: 20 * scale))
            }
            
            // Small hole in nib
            let nibHole = Path { path in
                path.addEllipse(in: CGRect(
                    x: 5.5 * scale,
                    y: 20.5 * scale,
                    width: 1 * scale,
                    height: 1.2 * scale
                ))
            }
            
            // Draw the feather body (filled)
            context.fill(featherPath, with: .color(.primary))
            
            // Draw the spine highlight (white/light stroke)
            context.stroke(
                spinePath,
                with: .color(.white.opacity(0.9)),
                style: StrokeStyle(lineWidth: 1.5 * scale, lineCap: .round)
            )
            
            // Draw nib details
            context.fill(nibPath, with: .color(.primary))
            context.fill(nibHole, with: .color(.white))
        }
        .frame(width: size, height: size)
    }
}

// Preview
#Preview {
    VStack(spacing: 40) {
        HStack(spacing: 30) {
            QuillInkwellIcon(size: 16)
            QuillInkwellIcon(size: 22)
            QuillInkwellIcon(size: 30)
            QuillInkwellIcon(size: 50)
        }
        
        HStack(spacing: 30) {
            QuillInkwellIcon(size: 22)
                .environment(\.colorScheme, .light)
            QuillInkwellIcon(size: 22)
                .environment(\.colorScheme, .dark)
        }
        .padding()
        .background(Color.secondary.opacity(0.2))
    }
}

