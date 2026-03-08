import SwiftUI

struct BookmarksChaptersView: View {
    var playerManager: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme

    var body: some View {
        NavigationStack {
            List {
                Section("Bookmarks") {
                    if playerManager.bookmarks.isEmpty {
                        Text("No bookmarks yet — tap the bookmark button while playing")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(playerManager.bookmarks) { bookmark in
                            Button {
                                playerManager.seekTo(bookmark.time)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(bookmarkColor(bookmark.colorName))
                                    Text(bookmark.label)
                                        .foregroundStyle(bookmarkColor(bookmark.colorName))
                                }
                            }
                            .buttonStyle(.plain)
                        }
                        .onDelete(perform: playerManager.removeBookmark)
                    }
                }

                if !playerManager.chapters.isEmpty {
                    Section("Chapters") {
                        ForEach(playerManager.chapters) { chapter in
                            Button {
                                playerManager.seekTo(chapter.startTime)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "text.book.closed.fill")
                                        .foregroundStyle(.primary)
                                    VStack(alignment: .leading) {
                                        Text(chapter.title)
                                            .foregroundStyle(.primary)
                                        Text(playerManager.formatTime(chapter.startTime))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks & Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
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

