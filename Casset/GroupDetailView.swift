import SwiftUI

struct GroupDetailView: View {
    var group: BookGroup
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager

    var booksInGroup: [Book] {
        libraryManager.books.filter { group.bookIDs.contains($0.id) }
    }

    var body: some View {
        Group {
            if booksInGroup.isEmpty {
                VStack(spacing: 16) {
                    Image(systemName: "books.vertical")
                        .font(.system(size: 60))
                        .foregroundStyle(.secondary)
                    Text("No books in this group yet")
                        .foregroundStyle(.secondary)
                }
            } else {
                List {
                    ForEach(booksInGroup) { book in
                        NavigationLink(
                            destination: PlayerView(book: book)
                                .environmentObject(libraryManager)
                                .environmentObject(playerManager)
                        ) {
                            HStack(spacing: 14) {
                                Group {
                                    if let artURL = book.artworkURL(),
                                       let uiImage = UIImage(contentsOfFile: artURL.path) {
                                        Image(uiImage: uiImage)
                                            .resizable()
                                            .scaledToFill()
                                    } else {
                                        Image(systemName: "book.closed.fill")
                                            .font(.system(size: 28))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 56, height: 56)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                                .background(
                                    RoundedRectangle(cornerRadius: 8)
                                        .fill(Color.secondary.opacity(0.15))
                                )

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(book.title)
                                        .font(.headline)
                                    if book.lastPosition > 0 {
                                        Text("Last played: \(formatTime(book.lastPosition))")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    } else {
                                        Text("Not started")
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(.vertical, 4)
                        }
                    }
                    .onDelete { offsets in
                        for i in offsets {
                            libraryManager.removeBook(booksInGroup[i].id, fromGroup: group.id)
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
    }

    func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

