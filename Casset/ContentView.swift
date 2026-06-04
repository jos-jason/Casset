import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker

    enum ImportType {
        case files
        case folder
    }

    @State private var showingImporter = false
    @State private var importType: ImportType = .files
    @State private var bookToGroup: Book? = nil
    @State private var isChoosingGroup    = false
    @State private var newGroupName       = ""
    @State private var isCreatingNewGroup = false

    // For navigating from mini player back into PlayerView
    @State private var miniPlayerTarget: Book? = nil
    @State private var isPushingFromMini: Bool = false

    // For editing book details
    @State private var bookToEdit: Book? = nil

    var body: some View {
        TabView {

            // MARK: Library tab
            ZStack(alignment: .bottom) {
                NavigationStack {
                    VStack {
                        // Hidden link used when tapping mini player cover
                        NavigationLink(
                            destination: miniPlayerDestination(),
                            isActive: $isPushingFromMini
                        ) { EmptyView() }
                        .hidden()

                        Group {
                            if libraryManager.books.isEmpty {
                                VStack(spacing: 16) {
                                    Image(systemName: "books.vertical")
                                        .font(.system(size: 60))
                                        .foregroundStyle(.secondary)
                                    Text("Your library is empty")
                                        .font(.title3)
                                        .foregroundStyle(.secondary)
                                    Button("Import Audio File") { 
                                        importType = .files
                                        showingImporter = true
                                    }
                                        .buttonStyle(.borderedProminent)
                                }
                            } else {
                                ScrollView {
                                    VStack(spacing: 10) {
                                        ForEach(libraryManager.sortedBooks) { book in
                                            NavigationLink(
                                                destination: PlayerView(book: book)
                                                    .environmentObject(libraryManager)
                                                    .environmentObject(playerManager)
                                                    .environmentObject(playerScreenTracker)
                                            ) {
                                                CassetteSpineView(book: book) {
                                                    // Play button: load and play the book
                                                    if let url = book.resolvedURL() {
                                                        playerManager.load(url: url, bookID: book.id)
                                                        if !playerManager.isPlaying {
                                                            playerManager.togglePlayPause()
                                                        }
                                                    }
                                                }
                                            }
                                            .buttonStyle(.plain)
                                            .contextMenu {
                                                Button {
                                                    bookToEdit = book
                                                } label: {
                                                    Label("Edit Book Info", systemImage: "pencil")
                                                }
                                                Button {
                                                    bookToGroup = book
                                                    isChoosingGroup = true
                                                } label: {
                                                    Label("Add to Collection", systemImage: "folder.badge.plus")
                                                }
                                                Button(role: .destructive) {
                                                    libraryManager.removeBooks(withIDs: [book.id])
                                                } label: {
                                                    Label("Delete", systemImage: "trash")
                                                }
                                            }
                                        }
                                    }
                                    .padding(12)
                                }
                                .padding(.horizontal, 8)
                                .padding(.bottom, 80)
                            }
                        }
                    }
                    .navigationTitle("Library")
                    .toolbar {
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                ForEach(BookSortOption.allCases, id: \.self) { option in
                                    Button {
                                        libraryManager.sortOption = option
                                    } label: {
                                        HStack {
                                            Text(option.displayName)
                                            if libraryManager.sortOption == option {
                                                Image(systemName: "checkmark")
                                            }
                                        }
                                    }
                                }
                            } label: {
                                Image(systemName: "arrow.up.arrow.down")
                            }
                        }
                        ToolbarItem(placement: .topBarTrailing) {
                            Menu {
                                Button {
                                    importType = .files
                                    showingImporter = true
                                } label: {
                                    Label("Import Files", systemImage: "doc.badge.plus")
                                }
                                Button {
                                    importType = .folder
                                    showingImporter = true
                                } label: {
                                    Label("Import Folder", systemImage: "folder.badge.plus")
                                }
                            } label: {
                                Image(systemName: "plus")
                            }
                        }
                        
                    }
                    .fileImporter(
                        isPresented: $showingImporter,
                        allowedContentTypes: importType == .files ? [.audio] : [.folder],
                        allowsMultipleSelection: importType == .files
                    ) { result in
                        do {
                            let urls = try result.get()
                            
                            if importType == .files {
                                // Import individual audio files
                                for url in urls {
                                    guard url.startAccessingSecurityScopedResource() else { continue }
                                    libraryManager.addBook(from: url)
                                    url.stopAccessingSecurityScopedResource()
                                }
                            } else {
                                // Import folder
                                guard let folderURL = urls.first else { return }
                                guard folderURL.startAccessingSecurityScopedResource() else { return }
                                defer { folderURL.stopAccessingSecurityScopedResource() }
                                
                                // Get all audio files in the folder (including subfolders)
                                if let enumerator = FileManager.default.enumerator(
                                    at: folderURL,
                                    includingPropertiesForKeys: [.isRegularFileKey],
                                    options: [.skipsHiddenFiles]
                                ) {
                                    for case let fileURL as URL in enumerator {
                                        // Check if it's an audio file
                                        if let resourceValues = try? fileURL.resourceValues(forKeys: [.typeIdentifierKey]),
                                           let typeIdentifier = resourceValues.typeIdentifier,
                                           UTType(typeIdentifier)?.conforms(to: .audio) == true {
                                            libraryManager.addBook(from: fileURL)
                                        }
                                    }
                                }
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
                    .sheet(item: $bookToEdit) { book in
                        BookEditView(book: book)
                            .environmentObject(libraryManager)
                    }
                }

                // Mini player overlay (hidden when full PlayerView is visible)
                if let currentID = playerManager.currentBookID,
                   let current = libraryManager.books.first(where: { $0.id == currentID }),
                   playerManager.player != nil,
                   playerScreenTracker.isShowingPlayer == false {
                    MiniPlayerBar(book: current) {
                        miniPlayerTarget = current
                        isPushingFromMini = true
                    }
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
                    MiniPlayerBar(book: current) {
                        miniPlayerTarget = current
                        isPushingFromMini = true
                    }
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

    func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryManager())
        .environmentObject(AudioPlayerManager())
        .environmentObject(PlayerScreenTracker())
}

