import SwiftUI

struct MarqueeText: View {
    var text: String
    var font: Font = .system(size: 13, weight: .medium)
    var color: Color = Color.primary.opacity(0.7)
    var speed: Double = 35
    var tracking: Double = 3

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var isAnimating = false

    private var gap: CGFloat { 60 }
    var shouldScroll: Bool { textWidth > containerWidth }
    var duration: Double { (textWidth + gap) / speed }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {

                Text(text.uppercased())
                    .font(font)
                    .tracking(tracking)
                    .fixedSize()
                    .hidden()
                    .background(
                        GeometryReader { inner in
                            Color.clear
                                .onAppear {
                                    textWidth = inner.size.width
                                    containerWidth = geo.size.width
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isAnimating = shouldScroll
                                    }
                                }
                                .onChange(of: text) {
                                    textWidth = inner.size.width
                                    containerWidth = geo.size.width
                                    isAnimating = false
                                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                                        isAnimating = shouldScroll
                                    }
                                }
                        }
                    )

                if shouldScroll {
                    HStack(spacing: gap) {
                        Text(text.uppercased())
                            .font(font)
                            .tracking(tracking)
                            .foregroundStyle(color)
                            .fixedSize()
                        Text(text.uppercased())
                            .font(font)
                            .tracking(tracking)
                            .foregroundStyle(color)
                            .fixedSize()
                    }
                    .offset(x: isAnimating ? -(textWidth + gap) : 0)
                    .animation(
                        isAnimating
                            ? .linear(duration: duration).repeatForever(autoreverses: false)
                            : .none,
                        value: isAnimating
                    )
                } else {
                    Text(text.uppercased())
                        .font(font)
                        .tracking(tracking)
                        .foregroundStyle(color)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .mask(
                HStack(spacing: 0) {
                    LinearGradient(colors: [.clear, .black], startPoint: .leading, endPoint: .trailing)
                        .frame(width: shouldScroll ? 32 : 0)
                    Rectangle()
                    LinearGradient(colors: [.black, .clear], startPoint: .leading, endPoint: .trailing)
                        .frame(width: shouldScroll ? 32 : 0)
                }
            )
        }
        .frame(height: 20)
    }
}

