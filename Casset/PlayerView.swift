//
//  PlayerView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct PlayerView: View {
    @Environment(LibraryManager.self) private var library
    @Environment(AudioPlayerManager.self) private var player

    @State private var showBookmarksSheet = false
    @State private var isDraggingSlider = false
    @State private var sliderValue: Double = 0

    private let speeds: [Float] = [0.75, 1.0, 1.25, 1.5, 2.0]
    private let accent = Color(red: 0.9, green: 0.5, blue: 0.1)

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Cassette animation
                CassetteView(
                    isPlaying: player.isPlaying,
                    coverImageData: player.currentBook?.coverImageData
                )
                .padding(.top, 16)

                // Title & Author
                VStack(spacing: 4) {
                    MarqueeText(
                        text: player.currentBook?.title ?? "No book loaded",
                        font: .title2.bold(),
                        color: .primary
                    )
                    .frame(height: 30)
                    .padding(.horizontal)

                    Text(player.currentBook?.author ?? "")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)

                    if let chapter = player.currentChapter() {
                        Text(chapter.title)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                // Progress Slider
                VStack(spacing: 4) {
                    Slider(
                        value: Binding(
                            get: {
                                isDraggingSlider ? sliderValue : (player.duration > 0 ? player.currentTime / player.duration : 0)
                            },
                            set: { newValue in
                                sliderValue = newValue
                                isDraggingSlider = true
                            }
                        ),
                        in: 0...1,
                        onEditingChanged: { editing in
                            if !editing {
                                player.seek(to: sliderValue * player.duration)
                                isDraggingSlider = false
                            }
                        }
                    )
                    .tint(accent)
                    .padding(.horizontal)

                    HStack {
                        Text(timeString(player.currentTime))
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                        Spacer()
                        Text("-\(timeString(max(0, player.duration - player.currentTime)))")
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal)
                }

                // Playback Controls
                HStack(spacing: 44) {
                    Button {
                        player.skipBackward()
                    } label: {
                        Image(systemName: "gobackward.15")
                            .font(.title)
                    }

                    Button {
                        player.togglePlayPause()
                    } label: {
                        Image(systemName: player.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                            .font(.system(size: 64))
                            .foregroundStyle(accent)
                    }

                    Button {
                        player.skipForward()
                    } label: {
                        Image(systemName: "goforward.30")
                            .font(.title)
                    }
                }
                .foregroundStyle(.primary)

                // Speed picker
                HStack(spacing: 8) {
                    ForEach(speeds, id: \.self) { speed in
                        Button {
                            player.setRate(speed, library: library)
                        } label: {
                            Text(speedLabel(speed))
                                .font(.caption.bold())
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    player.playbackRate == speed ? accent : Color.secondary.opacity(0.2),
                                    in: Capsule()
                                )
                                .foregroundStyle(player.playbackRate == speed ? .white : .primary)
                        }
                    }
                }

                // Bookmarks button
                Button {
                    showBookmarksSheet = true
                } label: {
                    Label("Bookmarks & Chapters", systemImage: "bookmark.fill")
                        .font(.subheadline)
                        .foregroundStyle(accent)
                }
                .padding(.bottom)
            }
        }
        .navigationTitle("Now Playing")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $showBookmarksSheet) {
            if let book = player.currentBook {
                BookmarksChaptersView(book: book)
            }
        }
    }

    private func timeString(_ time: TimeInterval) -> String {
        let t = Int(max(0, time))
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }

    private func speedLabel(_ speed: Float) -> String {
        speed == 1.0 ? "1×" : String(format: "%.2g×", speed)
    }
}

#Preview {
    NavigationStack {
        PlayerView()
            .environment(LibraryManager())
            .environment(AudioPlayerManager())
    }
}
