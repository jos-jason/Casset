import SwiftUI

struct BookmarkTimelineView: View {
    @EnvironmentObject var playerManager: AudioPlayerManager

    var body: some View {
        // Only the inner view observes the fast-ticking clock.
        BookmarkTimelineContent(playerManager: playerManager, clock: playerManager.clock)
    }
}

private struct BookmarkTimelineContent: View {
    let playerManager: AudioPlayerManager
    @ObservedObject var clock: PlaybackClock
    @Environment(\.colorScheme) var colorScheme

    var nearbyBookmarks: [Bookmark] {
        playerManager.bookmarks.filter {
            abs(clock.currentTime - $0.time) <= 10
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            ForEach(nearbyBookmarks) { bookmark in
                VStack(spacing: 2) {
                    Image(systemName: "bookmark.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(bookmarkColor(bookmark.colorName))
                    Text(bookmark.label)
                        .font(.caption2)
                        .foregroundStyle(bookmarkColor(bookmark.colorName))
                }
                .transition(.opacity)
            }
        }
        .animation(.easeInOut(duration: 0.4), value: nearbyBookmarks.map(\.id))
        .frame(height: 44)
    }

    func bookmarkColor(_ name: String) -> Color {
        switch name {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "blue":   return .blue
        case "purple": return .purple
        case "pink":   return .pink
        default:       return colorScheme == .dark ? .white : .black
        }
    }
}

