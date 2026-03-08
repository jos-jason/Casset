import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker   // NEW

    @State private var isImporting        = false
    @State private var bookToGroup: Book? = nil
    @State private var isChoosingGroup    = false
    @State private var newGroupName       = ""
    @State private var isCreatingNewGroup = false

    var body: some View {
        TabView {

            // MARK: Library tab
            ZStack(alignment: .bottom) {
                NavigationStack {
                    Group {
                        if libraryManager.books.isEmpty {
                            VStack(spacing: 16) {
                                Image(systemName: "books.vertical")
                                    .font(.system(size: 60))
                                    .foregroundStyle(.secondary)
                                Text("Your library is empty")
                                    .font(.title3)
                                    .foregroundStyle(.secondary)
                                Button("Import Audio File") { isImporting = true }
                                    .buttonStyle(.borderedProminent)
                            }
                        } else {
                            List {
                                ForEach(libraryManager.books) { book in
                                    NavigationLink(
                                        destination: PlayerView(book: book)
                                            .environmentObject(libraryManager)
                                            .environmentObject(playerManager)
                                            .environmentObject(playerScreenTracker)
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
                                            .padding(.vertical, 4)
                                        }
                                    }
                                    .swipeActions(edge: .leading) {
                                        Button {
                                            bookToGroup = book
                                            isChoosingGroup = true
                                        } label: {
                                            Label("Add to Collection", systemImage: "folder.badge.plus")
                                        }
                                        .tint(.yellow)
                                    }
                                }
                                .onDelete(perform: libraryManager.removeBook)
                            }
                        }
                    }
                    .navigationTitle("Library")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Button { isImporting = true } label: {
                                Image(systemName: "plus")
                            }
                        }
                        ToolbarItem(placement: .topBarLeading) {
                            EditButton()
                        }
                    }
                    .fileImporter(
                        isPresented: $isImporting,
                        allowedContentTypes: [.audio],
                        allowsMultipleSelection: true
                    ) { result in
                        do {
                            let urls = try result.get()
                            for url in urls {
                                guard url.startAccessingSecurityScopedResource() else { continue }
                                libraryManager.addBook(from: url)
                                url.stopAccessingSecurityScopedResource()
                            }
                        } catch {
                            print("Import failed: \(error)")
                        }
                    }
                    .confirmationDialog("Add to Collection", isPresented: $isChoosingGroup, titleVisibility: .visible) {
                        ForEach(libraryManager.groups) { group in
                            Button(group.name) {
                                if let book = bookToGroup {
                                    libraryManager.addBook(book.id, toGroup: group.id)
                                }
                            }
                        }
                        Button("New Collection...") { isCreatingNewGroup = true }
                        Button("Cancel", role: .cancel) {}
                    }
                    .alert("New Collection", isPresented: $isCreatingNewGroup) {
                        TextField("Collection name", text: $newGroupName)
                        Button("Create & Add") {
                            if !newGroupName.isEmpty {
                                libraryManager.addGroup(name: newGroupName)
                                if let book = bookToGroup,
                                   let group = libraryManager.groups.last {
                                    libraryManager.addBook(book.id, toGroup: group.id)
                                }
                            }
                            newGroupName = ""
                        }
                        Button("Cancel", role: .cancel) { newGroupName = "" }
                    }
                }

                if let currentID = playerManager.currentBookID,
                   let current = libraryManager.books.first(where: { $0.id == currentID }),
                   playerManager.player != nil,
                   playerScreenTracker.isShowingPlayer == false {   // HIDE when player on screen
                    MiniPlayerBar(book: current)
                        .environmentObject(playerManager)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .tabItem {
                Label("Library", systemImage: "books.vertical")
            }

            // MARK: Collections tab
            ZStack(alignment: .bottom) {
                GroupsView()
                    .environmentObject(libraryManager)

                if let currentID = playerManager.currentBookID,
                   let current = libraryManager.books.first(where: { $0.id == currentID }),
                   playerManager.player != nil,
                   playerScreenTracker.isShowingPlayer == false {
                    MiniPlayerBar(book: current)
                        .environmentObject(playerManager)
                        .padding(.horizontal, 12)
                        .padding(.bottom, 8)
                }
            }
            .tabItem {
                Label("Collections", systemImage: "folder")
            }
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

