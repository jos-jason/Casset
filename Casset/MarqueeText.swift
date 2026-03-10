//
//  MarqueeText.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct MarqueeText: View {
    let text: String
    var font: Font = .headline
    var color: Color = .primary
    var speed: Double = 30  // points per second

    @State private var textWidth: CGFloat = 0
    @State private var containerWidth: CGFloat = 0
    @State private var offset: CGFloat = 0
    @State private var isAnimating: Bool = false

    private var needsScrolling: Bool { textWidth > containerWidth }

    var body: some View {
        GeometryReader { geo in
            let cw = geo.size.width
            ZStack(alignment: .leading) {
                if needsScrolling {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .fixedSize()
                        .offset(x: offset)
                        .onAppear {
                            containerWidth = cw
                            startScrolling()
                        }
                        .onChange(of: text) {
                            offset = 0
                            isAnimating = false
                            startScrolling()
                        }
                } else {
                    Text(text)
                        .font(font)
                        .foregroundColor(color)
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
            .frame(width: cw, alignment: .leading)
            .clipped()
            .background(
                Text(text)
                    .font(font)
                    .fixedSize()
                    .hidden()
                    .background(GeometryReader { inner in
                        Color.clear.preference(
                            key: TextWidthKey.self,
                            value: inner.size.width
                        )
                    })
            )
            .onPreferenceChange(TextWidthKey.self) { w in
                textWidth = w
                containerWidth = cw
            }
        }
    }

    private func startScrolling() {
        guard needsScrolling, !isAnimating else { return }
        isAnimating = true
        let scrollDistance = textWidth + 40
        let duration = scrollDistance / speed
        withAnimation(.linear(duration: duration).delay(1.5).repeatForever(autoreverses: false)) {
            offset = -scrollDistance
        }
    }
}

private struct TextWidthKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

#Preview {
    VStack(spacing: 20) {
        MarqueeText(text: "A Short Title")
            .frame(width: 200, height: 30)
        MarqueeText(text: "This is a very long audiobook title that needs to scroll across the screen")
            .frame(width: 200, height: 30)
    }
    .padding()
}
