//
//  CassetteView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct CassetteView: View {
    let isPlaying: Bool
    var coverImageData: Data?

    @State private var reelAngle: Double = 0

    private let cassetteWidth: CGFloat = 280
    private let cassetteHeight: CGFloat = 180

    var body: some View {
        ZStack {
            cassetteBody
            tapeWindow
            labelArea
            reels
        }
        .frame(width: cassetteWidth, height: cassetteHeight)
        .shadow(color: .black.opacity(0.5), radius: 12, x: 0, y: 6)
        .onChange(of: isPlaying) { _, playing in
            if playing {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    reelAngle = 360
                }
            } else {
                withAnimation(.easeOut(duration: 0.3)) {
                    // Stop animation by removing the repeat
                }
                reelAngle = 0
            }
        }
        .onAppear {
            if isPlaying {
                withAnimation(.linear(duration: 2).repeatForever(autoreverses: false)) {
                    reelAngle = 360
                }
            }
        }
    }

    // MARK: - Sub-views

    private var cassetteBody: some View {
        RoundedRectangle(cornerRadius: 12)
            .fill(Color(red: 0.1, green: 0.08, blue: 0.06))
            .overlay(
                RoundedRectangle(cornerRadius: 12)
                    .strokeBorder(Color(white: 0.3), lineWidth: 1)
            )
    }

    private var tapeWindow: some View {
        RoundedRectangle(cornerRadius: 6)
            .fill(Color(red: 0.06, green: 0.05, blue: 0.04))
            .overlay(
                RoundedRectangle(cornerRadius: 6)
                    .strokeBorder(Color(white: 0.2), lineWidth: 1)
            )
            .frame(width: 160, height: 50)
            .offset(y: 20)
    }

    private var labelArea: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 6)
                .fill(
                    LinearGradient(
                        colors: [Color(red: 0.8, green: 0.4, blue: 0.05),
                                 Color(red: 0.6, green: 0.25, blue: 0.02)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    )
                )
                .frame(width: 200, height: 55)
                .offset(y: -40)
        }
    }

    private var reels: some View {
        HStack(spacing: 80) {
            reelView
            reelView
        }
        .offset(y: 22)
    }

    private var reelView: some View {
        ZStack {
            Circle()
                .fill(Color(white: 0.25))
                .frame(width: 44, height: 44)

            // Spokes
            ForEach(0..<3) { i in
                Rectangle()
                    .fill(Color(white: 0.5))
                    .frame(width: 2, height: 16)
                    .offset(y: -8)
                    .rotationEffect(.degrees(Double(i) * 120 + reelAngle))
            }

            Circle()
                .fill(Color(white: 0.15))
                .frame(width: 14, height: 14)

            Circle()
                .strokeBorder(Color(white: 0.5), lineWidth: 1)
                .frame(width: 44, height: 44)
        }
    }
}

#Preview {
    VStack(spacing: 30) {
        CassetteView(isPlaying: false)
        CassetteView(isPlaying: true)
    }
    .padding()
    .background(Color(red: 0.12, green: 0.1, blue: 0.08))
}
