import SwiftUI
import UniformTypeIdentifiers

struct ContentView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker

    @AppStorage("useSimpleLibrary") var useSimpleLibrary: Bool = false

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

    // Search
    @State private var searchText: String = ""
    @State private var isSearching: Bool = false

    // Export / Import
    @State private var isExporting: Bool = false
    @State private var exportURL: URL? = nil
    @State private var showingCassetImporter = false
    @State private var isSelectingForExport = false
    @State private var selectedBookIDs: Set<UUID> = []
    @State private var exportError: String? = nil
    @State private var showExportError = false
    @State private var importResultMessage: String? = nil
    @State private var showImportResult = false

    private var filteredBooks: [Book] {
        if searchText.isEmpty {
            return libraryManager.sortedBooks
        }
        return libraryManager.sortedBooks.filter { book in
            book.title.localizedCaseInsensitiveContains(searchText) ||
            book.author.localizedCaseInsensitiveContains(searchText)
        }
    }

    @State private var selectedTab: Int = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            // MARK: Tab content
            Group {
                if selectedTab == 0 {
                    libraryTab
                } else {
                    collectionsTab
                }
            }

            if !playerScreenTracker.isShowingPlayer {
                // Bottom fade gradient — sits above content, below tab bar
                VStack(spacing: 0) {
                    Spacer()
                    LinearGradient(
                        colors: [Color(.systemBackground), Color(.systemBackground).opacity(0)],
                        startPoint: .bottom,
                        endPoint: .top
                    )
                    .frame(height: 80)
                }
                .allowsHitTesting(false)

                // MARK: Custom tab bar — drawn on top of everything
                VStack(spacing: 0) {
                    Spacer()
                    GlassEffectContainer(spacing: 12) {
                        HStack(spacing: 12) {
                            Button {
                                selectedTab = 0
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "books.vertical")
                                        .font(.system(size: 18))
                                    Text("Library")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedTab == 0 ? .white : .gray)
                            }
                            .glassEffect(.regular.interactive(), in: .capsule)

                            Button {
                                selectedTab = 1
                            } label: {
                                VStack(spacing: 4) {
                                    Image(systemName: "folder")
                                        .font(.system(size: 18))
                                    Text("Collections")
                                        .font(.caption2)
                                }
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 8)
                                .foregroundStyle(selectedTab == 1 ? .white : .gray)
                            }
                            .glassEffect(.regular.interactive(), in: .capsule)
                        }
                        .padding(.horizontal, 40)
                    }
                    .padding(.bottom, 4)
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
    }

    // MARK: - Library Content

    @ViewBuilder
    private var libraryContent: some View {
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
        } else if useSimpleLibrary {
            simpleLibraryList
        } else {
            cassetteLibraryList
        }
    }

    private var simpleLibraryList: some View {
        List {
            ForEach(filteredBooks) { book in
                NavigationLink(
                    destination: PlayerView(book: book)
                        .environmentObject(libraryManager)
                        .environmentObject(playerManager)
                        .environmentObject(playerScreenTracker)
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
                            if !book.author.isEmpty {
                                Text(book.author)
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            } else if book.lastPosition > 0 {
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
                    Button {
                        exportSingleBook(book)
                    } label: {
                        Label("Export Book", systemImage: "square.and.arrow.up")
                    }
                    Button(role: .destructive) {
                        libraryManager.removeBooks(withIDs: [book.id])
                    } label: {
                        Label("Delete", systemImage: "trash")
                    }
                }
            }
        }
        .padding(.bottom, 60)
    }

    private var cassetteLibraryList: some View {
        ScrollView {
            VStack(spacing: 10) {
                ForEach(filteredBooks) { book in
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
                        Button {
                            exportSingleBook(book)
                        } label: {
                            Label("Export Book", systemImage: "square.and.arrow.up")
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
            .padding(.bottom, 80)
        }
        .padding(.horizontal, 8)
    }

    // MARK: - Library Tab
    private var libraryTab: some View {
        ZStack(alignment: .bottom) {
            NavigationStack {
                VStack {
                    // Hidden link used when tapping mini player cover
                    NavigationLink(
                        destination: miniPlayerDestination(),
                        isActive: $isPushingFromMini
                    ) { EmptyView() }
                    .hidden()

                    // Inline search bar — only visible when magnifying glass is tapped
                    if isSearching {
                        HStack {
                            HStack(spacing: 6) {
                                Image(systemName: "magnifyingglass")
                                    .foregroundStyle(.secondary)
                                TextField("Search by title or author", text: $searchText)
                                    .textFieldStyle(.plain)
                                    .autocorrectionDisabled()
                                if !searchText.isEmpty {
                                    Button {
                                        searchText = ""
                                    } label: {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }
                            .padding(8)
                            .background(.ultraThinMaterial, in: RoundedRectangle(cornerRadius: 10))

                            Button("Cancel") {
                                searchText = ""
                                isSearching = false
                            }
                            .foregroundStyle(.white)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 4)
                    }

                    libraryContent
                }
                .navigationTitle("Library")
                .toolbar {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button {
                            isSearching.toggle()
                        } label: {
                            Image(systemName: "magnifyingglass")
                        }
                    }
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
                            Section("Import") {
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
                                Button {
                                    showingCassetImporter = true
                                } label: {
                                    Label("Import Casset File", systemImage: "shippingbox.and.arrow.clockwise")
                                }
                            }
                            Section("Export") {
                                Button {
                                    exportAllBooks()
                                } label: {
                                    Label("Export All Books", systemImage: "square.and.arrow.up.on.square")
                                }
                                .disabled(libraryManager.books.isEmpty)
                                Button {
                                    isSelectingForExport = true
                                    selectedBookIDs = []
                                } label: {
                                    Label("Export Selected Books", systemImage: "checkmark.circle")
                                }
                                .disabled(libraryManager.books.isEmpty)
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
                            
                            // Look for a cover image in the folder
                            let coverNames = ["cover", "folder", "front", "artwork", "album"]
                            let imageExts  = ["jpg", "jpeg", "png"]
                            var folderCoverURL: URL? = nil
                            for name in coverNames {
                                for ext in imageExts {
                                    let candidate = folderURL.appendingPathComponent("\(name).\(ext)")
                                    if FileManager.default.fileExists(atPath: candidate.path) {
                                        folderCoverURL = candidate
                                        break
                                    }
                                }
                                if folderCoverURL != nil { break }
                            }
                            
                            // Read cover image data while we still have security-scoped access
                            var folderCoverData: Data? = nil
                            if let coverURL = folderCoverURL {
                                folderCoverData = try? Data(contentsOf: coverURL)
                            }
                            
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
                                        libraryManager.addBook(from: fileURL, securityScopedParent: folderURL, folderCoverData: folderCoverData)
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
                .padding(.bottom, 100)
            }
        }
        .sheet(isPresented: $isExporting) {
            if let url = exportURL {
                ShareSheetView(activityItems: [url])
            }
        }
        .sheet(isPresented: $isSelectingForExport) {
            ExportSelectionView(
                books: libraryManager.sortedBooks,
                selectedIDs: $selectedBookIDs,
                onExport: { ids in
                    isSelectingForExport = false
                    let booksToExport = libraryManager.books.filter { ids.contains($0.id) }
                    guard !booksToExport.isEmpty else { return }
                    do {
                        exportURL = try BookExporter.exportBooks(booksToExport)
                        isExporting = true
                    } catch {
                        exportError = error.localizedDescription
                        showExportError = true
                    }
                },
                onCancel: {
                    isSelectingForExport = false
                }
            )
        }
        .fileImporter(
            isPresented: $showingCassetImporter,
            allowedContentTypes: [.cassetBookArchive, .folder],
            allowsMultipleSelection: false
        ) { result in
            do {
                let urls = try result.get()
                guard let url = urls.first else { return }
                let count = try BookExporter.importBooks(from: url, into: libraryManager)
                importResultMessage = "Successfully imported \(count) book\(count == 1 ? "" : "s")."
                showImportResult = true
            } catch {
                exportError = "Import failed: \(error.localizedDescription)"
                showExportError = true
            }
        }
        .alert("Export Error", isPresented: $showExportError) {
            Button("OK") {}
        } message: {
            Text(exportError ?? "An unknown error occurred.")
        }
        .alert("Import Complete", isPresented: $showImportResult) {
            Button("OK") {}
        } message: {
            Text(importResultMessage ?? "")
        }
    }

    // MARK: - Collections Tab
    private var collectionsTab: some View {
        ZStack(alignment: .bottom) {
            GroupsView(
                miniPlayerTarget: $miniPlayerTarget,
                isPushingFromMini: $isPushingFromMini
            )
            .environmentObject(libraryManager)
            .environmentObject(playerManager)
            .environmentObject(playerScreenTracker)

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
                .padding(.bottom, 100)
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

    // MARK: - Export Helpers

    private func exportSingleBook(_ book: Book) {
        do {
            exportURL = try BookExporter.exportBooks([book])
            isExporting = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    private func exportAllBooks() {
        guard !libraryManager.books.isEmpty else { return }
        do {
            exportURL = try BookExporter.exportBooks(libraryManager.books)
            isExporting = true
        } catch {
            exportError = error.localizedDescription
            showExportError = true
        }
    }

    func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}

// MARK: - Share Sheet

struct ShareSheetView: UIViewControllerRepresentable {
    let activityItems: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: activityItems, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}

// MARK: - Export Selection View

struct ExportSelectionView: View {
    let books: [Book]
    @Binding var selectedIDs: Set<UUID>
    var onExport: (Set<UUID>) -> Void
    var onCancel: () -> Void

    var body: some View {
        NavigationStack {
            List {
                ForEach(books) { book in
                    Button {
                        if selectedIDs.contains(book.id) {
                            selectedIDs.remove(book.id)
                        } else {
                            selectedIDs.insert(book.id)
                        }
                    } label: {
                        HStack {
                            Image(systemName: selectedIDs.contains(book.id) ? "checkmark.circle.fill" : "circle")
                                .foregroundStyle(selectedIDs.contains(book.id) ? .blue : .secondary)
                            VStack(alignment: .leading, spacing: 2) {
                                Text(book.title)
                                    .font(.headline)
                                    .foregroundStyle(.primary)
                                if !book.author.isEmpty {
                                    Text(book.author)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .padding(.vertical, 4)
                    }
                }
            }
            .navigationTitle("Select Books to Export")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { onCancel() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Export (\(selectedIDs.count))") {
                        onExport(selectedIDs)
                    }
                    .disabled(selectedIDs.isEmpty)
                }
                ToolbarItem(placement: .bottomBar) {
                    Button("Select All") {
                        if selectedIDs.count == books.count {
                            selectedIDs = []
                        } else {
                            selectedIDs = Set(books.map(\.id))
                        }
                    }
                }
            }
        }
    }
}

#Preview {
    ContentView()
        .environmentObject(LibraryManager())
        .environmentObject(AudioPlayerManager())
        .environmentObject(PlayerScreenTracker())
}

