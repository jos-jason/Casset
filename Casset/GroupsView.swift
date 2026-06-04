import SwiftUI

// MARK: - Collection Cover Grid
/// Shows a 2x2 grid of book covers for a collection's icon.
struct CollectionCoverGrid: View {
    let books: [Book]
    let size: CGFloat

    private var covers: [Book] {
        Array(books.prefix(4))
    }

    private var cellSize: CGFloat {
        (size - 2) / 2 // 2pt gap between cells
    }

    var body: some View {
        Group {
            if covers.isEmpty {
                // No books — show folder icon
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color.secondary.opacity(0.15))
                    .frame(width: size, height: size)
                    .overlay(
                        Image(systemName: "folder.fill")
                            .font(.system(size: size * 0.4))
                            .foregroundStyle(.secondary)
                    )
            } else {
                let columns = [
                    GridItem(.fixed(cellSize), spacing: 2),
                    GridItem(.fixed(cellSize), spacing: 2)
                ]
                LazyVGrid(columns: columns, spacing: 2) {
                    ForEach(0..<4, id: \.self) { index in
                        if index < covers.count,
                           let artURL = covers[index].bestCoverArtURL(),
                           let uiImage = UIImage(contentsOfFile: artURL.path) {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFill()
                                .frame(width: cellSize, height: cellSize)
                                .clipped()
                        } else {
                            Rectangle()
                                .fill(Color.secondary.opacity(0.15))
                                .frame(width: cellSize, height: cellSize)
                                .overlay(
                                    Image(systemName: "book.closed.fill")
                                        .font(.system(size: cellSize * 0.4))
                                        .foregroundStyle(.secondary)
                                )
                        }
                    }
                }
                .frame(width: size, height: size)
                .clipShape(RoundedRectangle(cornerRadius: 8))
            }
        }
    }
}

struct GroupsView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker
    @State private var isCreatingGroup = false
    @State private var newGroupName = ""

    // Mini player navigation (driven from outside or internally)
    @Binding var miniPlayerTarget: Book?
    @Binding var isPushingFromMini: Bool
    
    func actualBookCount(for group: BookGroup) -> Int {
        libraryManager.books.filter { group.bookIDs.contains($0.id) }.count
    }

    func booksInGroup(_ group: BookGroup) -> [Book] {
        libraryManager.books.filter { group.bookIDs.contains($0.id) }
    }

    @ViewBuilder
    private func miniPlayerDestination() -> some View {
        if let target = miniPlayerTarget {
            PlayerView(book: target)
                .environmentObject(libraryManager)
                .environmentObject(playerManager)
                .environmentObject(playerScreenTracker)
        } else {
            EmptyView()
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                NavigationLink(
                    destination: miniPlayerDestination(),
                    isActive: $isPushingFromMini
                ) { EmptyView() }
                .hidden()

                Group {
                    if libraryManager.groups.isEmpty {
                        VStack(spacing: 16) {
                            Image(systemName: "folder")
                                .font(.system(size: 60))
                                .foregroundStyle(.secondary)
                            Text("No collections yet")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                            Text("Swipe right on a book in your library to add it to a collection.")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                                .padding(.horizontal, 40)
                        }
                    } else {
                        List {
                            ForEach(libraryManager.groups) { group in
                                NavigationLink(
                                    destination: GroupDetailView(group: group)
                                        .environmentObject(libraryManager)
                                ) {
                                    let count = actualBookCount(for: group)
                                    HStack(spacing: 14) {
                                        CollectionCoverGrid(
                                            books: booksInGroup(group),
                                            size: 56
                                        )
                                        VStack(alignment: .leading, spacing: 4) {
                                            Text(group.name)
                                                .font(.headline)
                                            Text("\(count) book\(count == 1 ? "" : "s")")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.vertical, 4)
                                }
                            }
                            .onDelete(perform: libraryManager.removeGroup)
                        }
                    }
                }
            }
            .navigationTitle("Collections")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        isCreatingGroup = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                }
            }
            .alert("New Collection", isPresented: $isCreatingGroup) {
                TextField("Collection name", text: $newGroupName)
                Button("Create") {
                    if !newGroupName.isEmpty {
                        libraryManager.addGroup(name: newGroupName)
                        newGroupName = ""
                    }
                }
                Button("Cancel", role: .cancel) { newGroupName = "" }
            }
        }
    }
}

