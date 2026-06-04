import SwiftUI

struct GroupDetailView: View {
    var group: BookGroup
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @State private var showingAddBooks = false

    @AppStorage("useSimpleLibrary") var useSimpleLibrary: Bool = false

    var booksInGroup: [Book] {
        libraryManager.books.filter { group.bookIDs.contains($0.id) }
    }

    var booksNotInGroup: [Book] {
        libraryManager.books.filter { !group.bookIDs.contains($0.id) }
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
                    Button {
                        showingAddBooks = true
                    } label: {
                        Label("Add Books", systemImage: "plus")
                            .foregroundStyle(Color(.systemBackground))
                    }
                    .buttonStyle(.borderedProminent)
                    .tint(.primary)
                    .disabled(booksNotInGroup.isEmpty)
                }
            } else if useSimpleLibrary {
                List {
                    ForEach(booksInGroup) { book in
                        NavigationLink(
                            destination: PlayerView(book: book)
                                .environmentObject(libraryManager)
                                .environmentObject(playerManager)
                        ) {
                            HStack(spacing: 14) {
                                Group {
                                    if let artURL = book.bestCoverArtURL(),
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
            } else {
                // Cassette spine style
                ScrollView {
                    VStack(spacing: 10) {
                        ForEach(booksInGroup) { book in
                            NavigationLink(
                                destination: PlayerView(book: book)
                                    .environmentObject(libraryManager)
                                    .environmentObject(playerManager)
                            ) {
                                CassetteSpineView(book: book) {
                                    if let url = book.resolvedURL() {
                                        playerManager.load(url: url, bookID: book.id)
                                        if !playerManager.isPlaying {
                                            playerManager.togglePlayPause()
                                        }
                                    }
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(12)
                    .padding(.bottom, 80)
                }
                .padding(.horizontal, 8)
            }
        }
        .navigationTitle(group.name)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingAddBooks = true
                } label: {
                    Image(systemName: "plus")
                }
                .disabled(booksNotInGroup.isEmpty)
            }
        }
        .sheet(isPresented: $showingAddBooks) {
            AddBooksToGroupSheet(group: group)
                .environmentObject(libraryManager)
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Add Books Sheet

struct AddBooksToGroupSheet: View {
    var group: BookGroup
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.dismiss) private var dismiss
    @State private var selectedBookIDs: Set<UUID> = []

    var availableBooks: [Book] {
        libraryManager.books.filter { !group.bookIDs.contains($0.id) }
    }

    var body: some View {
        NavigationStack {
            Group {
                if availableBooks.isEmpty {
                    VStack(spacing: 16) {
                        Image(systemName: "book.closed")
                            .font(.system(size: 60))
                            .foregroundStyle(.secondary)
                        Text("All books are already in this collection")
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 40)
                    }
                } else {
                    List {
                        ForEach(availableBooks) { book in
                            Button {
                                if selectedBookIDs.contains(book.id) {
                                    selectedBookIDs.remove(book.id)
                                } else {
                                    selectedBookIDs.insert(book.id)
                                }
                            } label: {
                                HStack(spacing: 14) {
                                    Group {
                                        if let artURL = book.bestCoverArtURL(),
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
                                    .frame(width: 44, height: 44)
                                    .clipShape(RoundedRectangle(cornerRadius: 6))
                                    .background(
                                        RoundedRectangle(cornerRadius: 6)
                                            .fill(Color.secondary.opacity(0.15))
                                    )

                                    Text(book.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)

                                    Spacer()

                                    Image(systemName: selectedBookIDs.contains(book.id) ? "checkmark.circle.fill" : "circle")
                                        .foregroundStyle(selectedBookIDs.contains(book.id) ? .primary : .secondary)
                                        .font(.title3)
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Add Books")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Add") {
                        for bookID in selectedBookIDs {
                            libraryManager.addBook(bookID, toGroup: group.id)
                        }
                        dismiss()
                    }
                    .disabled(selectedBookIDs.isEmpty)
                }
            }
        }
    }
}

