//
//  BookmarkTimelineView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct BookmarkTimelineView: View {
    @Environment(AudioPlayerManager.self) private var player

    let book: Book
    let onSeek: (TimeInterval) -> Void

    private let accent = Color(red: 0.9, green: 0.5, blue: 0.1)
    private let trackHeight: CGFloat = 4
    private let dotSize: CGFloat = 14

    var body: some View {
        GeometryReader { geo in
            let width = geo.size.width
            let duration = book.duration > 0 ? book.duration : 1

            ZStack(alignment: .leading) {
                // Track background
                Capsule()
                    .fill(Color.secondary.opacity(0.2))
                    .frame(height: trackHeight)

                // Playback progress
                Capsule()
                    .fill(accent.opacity(0.4))
                    .frame(
                        width: CGFloat(player.currentTime / duration) * width,
                        height: trackHeight
                    )

                // Chapter markers
                ForEach(book.chapters) { chapter in
                    let x = CGFloat(chapter.startTime / duration) * width
                    Rectangle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 1, height: 10)
                        .position(x: x, y: 0)
                }

                // Bookmark dots
                ForEach(book.bookmarks) { bookmark in
                    let x = CGFloat(bookmark.timestamp / duration) * width
                    Circle()
                        .fill(accent)
                        .frame(width: dotSize, height: dotSize)
                        .overlay(Circle().strokeBorder(.white, lineWidth: 1.5))
                        .position(x: x, y: 0)
                        .onTapGesture {
                            onSeek(bookmark.timestamp)
                        }
                }

                // Current position cursor
                let cursorX = CGFloat(player.currentTime / duration) * width
                Rectangle()
                    .fill(.primary)
                    .frame(width: 2, height: 20)
                    .position(x: cursorX, y: 0)
            }
            .frame(height: 20)
        }
        .frame(height: 20)
        .padding(.horizontal)
        .contentShape(Rectangle())
        .gesture(
            DragGesture(minimumDistance: 0)
                .onChanged { value in
                    // Allow tapping anywhere on timeline to seek
                }
                .onEnded { value in
                    // Handled by individual tap gestures on dots
                }
        )
    }
}
