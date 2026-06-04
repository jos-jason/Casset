import SwiftUI
import AVFoundation
import Combine

// MARK: - Sort Options
enum BookSortOption: String, CaseIterable, Codable {
    case titleAZ          = "title_az"
    case authorAZ         = "author_az"
    case recentlyUsed     = "recently_used"
    case series           = "series"
    
    var displayName: String {
        switch self {
        case .titleAZ:         return "Title (A-Z)"
        case .authorAZ:        return "Author (A-Z)"
        case .recentlyUsed:    return "Recent"
        case .series:          return "Group by Series"
        }
    }
}

class LibraryManager: ObservableObject {
    @Published var books:  [Book]      = []
    @Published var groups: [BookGroup] = []
    @Published var sortOption: BookSortOption = .recentlyUsed {
        didSet {
            saveSortPreference()
        }
    }

    private let storageKey = "casset_library"
    private let groupsKey  = "casset_groups"
    private let sortKey    = "casset_sort_preference"

    init() {
        load()
        loadGroups()
        loadSortPreference()
        cleanupOrphanedBookIDs()
    }

    func addBook(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        guard let bookmarkData = try? url.bookmarkData(
            options: .minimalBookmark,
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            url.stopAccessingSecurityScopedResource()
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        let book  = Book(title: title, bookmarkData: bookmarkData)
        books.append(book)
        save()

        Task {
            defer { url.stopAccessingSecurityScopedResource() }
            let metadata = await extractMetadata(from: url, bookID: book.id)
            if let i = books.firstIndex(where: { $0.id == book.id }) {
                if let artwork = metadata.artworkFilename {
                    books[i].artworkFilename = artwork
                }
                if !metadata.genre.isEmpty {
                    books[i].genre = metadata.genre
                }
                save()
            }
        }
    }

    func removeBook(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            let docsDir = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
            if let filename = book.artworkFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            if let filename = book.cassetteBoxArtFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            if let filename = book.customCoverArtFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            if let filename = book.customCassetteCoverArtFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            // Remove book ID from all groups
            for i in groups.indices {
                groups[i].bookIDs.removeAll { $0 == book.id }
            }
        }
        books.remove(atOffsets: offsets)
        save()
        saveGroups()
    }

    func removeBooks(withIDs ids: [UUID]) {
        let idSet = Set(ids)
        let docsDir = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
        for book in books where idSet.contains(book.id) {
            if let filename = book.artworkFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            if let filename = book.cassetteBoxArtFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            if let filename = book.customCoverArtFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            if let filename = book.customCassetteCoverArtFilename {
                try? FileManager.default.removeItem(at: docsDir.appendingPathComponent(filename))
            }
            for i in groups.indices {
                groups[i].bookIDs.removeAll { $0 == book.id }
            }
        }
        books.removeAll { idSet.contains($0.id) }
        save()
        saveGroups()
    }
    
    /// Cleans up orphaned book IDs from all groups (books that no longer exist in the library)
    func cleanupOrphanedBookIDs() {
        let validBookIDs = Set(books.map { $0.id })
        var needsSave = false
        
        for i in groups.indices {
            let originalCount = groups[i].bookIDs.count
            groups[i].bookIDs = groups[i].bookIDs.filter { validBookIDs.contains($0) }
            if groups[i].bookIDs.count != originalCount {
                needsSave = true
            }
        }
        
        if needsSave {
            saveGroups()
        }
    }

    // MARK: Groups

    func addGroup(name: String) {
        groups.append(BookGroup(name: name))
        saveGroups()
    }

    func removeGroup(at offsets: IndexSet) {
        groups.remove(atOffsets: offsets)
        saveGroups()
    }

    func addBook(_ bookID: UUID, toGroup groupID: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == groupID }) else { return }
        if !groups[i].bookIDs.contains(bookID) {
            groups[i].bookIDs.append(bookID)
            saveGroups()
        }
    }

    func removeBook(_ bookID: UUID, fromGroup groupID: UUID) {
        guard let i = groups.firstIndex(where: { $0.id == groupID }) else { return }
        groups[i].bookIDs.removeAll { $0 == bookID }
        saveGroups()
    }

    // MARK: Playback info

    func updateLastPosition(bookID: UUID, position: Double) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].lastPosition = position
        books[i].lastInteracted = Date()  // Update interaction timestamp
        save()
    }

    func updateDuration(bookID: UUID, duration: Double) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].duration = duration
        save()
    }

    func updateBookmarks(bookID: UUID, bookmarks: [Bookmark]) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].bookmarks = bookmarks
        save()
    }

    // MARK: Book Details

    func updateBookDetails(bookID: UUID, title: String, author: String, series: String, genre: String, customColorHex: String? = nil, boxArtPrompt: String = "") {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].title = title
        books[i].author = author
        books[i].series = series
        books[i].genre = genre
        books[i].customColorHex = customColorHex
        books[i].boxArtPrompt = boxArtPrompt
        save()
    }

    func saveCassetteBoxArt(bookID: UUID, image: UIImage) {
        let filename = "boxart_\(bookID.uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url)
            if let i = books.firstIndex(where: { $0.id == bookID }) {
                books[i].cassetteBoxArtFilename = filename
                save()
            }
        }
    }

    func removeCassetteBoxArt(bookID: UUID) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        if let filename = books[i].cassetteBoxArtFilename {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        books[i].cassetteBoxArtFilename = nil
        save()
    }

    // MARK: Custom Cover Art (Square 1:1)

    func saveCustomCoverArt(bookID: UUID, image: UIImage) {
        let filename = "cover_\(bookID.uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url)
            if let i = books.firstIndex(where: { $0.id == bookID }) {
                books[i].customCoverArtFilename = filename
                save()
            }
        }
    }

    func removeCustomCoverArt(bookID: UUID) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        if let filename = books[i].customCoverArtFilename {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        books[i].customCoverArtFilename = nil
        save()
    }

    // MARK: Custom Cassette Cover Art (31:17)

    func saveCustomCassetteCoverArt(bookID: UUID, image: UIImage) {
        let filename = "cassettecover_\(bookID.uuidString).jpg"
        let url = FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
        if let data = image.jpegData(compressionQuality: 0.85) {
            try? data.write(to: url)
            if let i = books.firstIndex(where: { $0.id == bookID }) {
                books[i].customCassetteCoverArtFilename = filename
                save()
            }
        }
    }

    func removeCustomCassetteCoverArt(bookID: UUID) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        if let filename = books[i].customCassetteCoverArtFilename {
            let url = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try? FileManager.default.removeItem(at: url)
        }
        books[i].customCassetteCoverArtFilename = nil
        save()
    }

    // MARK: Metadata Extraction

    private struct ExtractedMetadata {
        var artworkFilename: String?
        var genre: String = ""
    }

    private func extractMetadata(from url: URL, bookID: UUID) async -> ExtractedMetadata {
        let asset = AVAsset(url: url)
        guard let metadata = try? await asset.load(.metadata) else { return ExtractedMetadata() }

        var result = ExtractedMetadata()

        for item in metadata {
            // Extract artwork
            if item.commonKey == .commonKeyArtwork,
               let data = try? await item.load(.dataValue) {
                let filename = "\(bookID.uuidString).jpg"
                let fileURL  = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? data.write(to: fileURL)
                result.artworkFilename = filename
            }

            // Extract genre
            if item.commonKey == .commonKeyType,
               let genre = try? await item.load(.stringValue),
               !genre.isEmpty {
                result.genre = genre
            }
        }

        return result
    }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
    }

    private func load() {
        guard let data    = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        books = decoded
    }

    private func saveGroups() {
        if let data = try? JSONEncoder().encode(groups) {
            UserDefaults.standard.set(data, forKey: groupsKey)
        }
    }

    private func loadGroups() {
        guard let data    = UserDefaults.standard.data(forKey: groupsKey),
              let decoded = try? JSONDecoder().decode([BookGroup].self, from: data)
        else { return }
        groups = decoded
    }
    
    // MARK: - Sorting
    
    var sortedBooks: [Book] {
        switch sortOption {
        case .titleAZ:
            return books.sorted { $0.title.localizedCaseInsensitiveCompare($1.title) == .orderedAscending }
        case .authorAZ:
            return books.sorted { $0.author.localizedCaseInsensitiveCompare($1.author) == .orderedAscending }
        case .recentlyUsed:
            return books.sorted { $0.lastInteracted > $1.lastInteracted }
        case .series:
            return books.sorted { book1, book2 in
                // First sort by series
                if book1.series != book2.series {
                    // Put books with no series at the end
                    if book1.series.isEmpty { return false }
                    if book2.series.isEmpty { return true }
                    return book1.series.localizedCaseInsensitiveCompare(book2.series) == .orderedAscending
                }
                // Within same series, sort by title
                return book1.title.localizedCaseInsensitiveCompare(book2.title) == .orderedAscending
            }
        }
    }
    
    private func saveSortPreference() {
        UserDefaults.standard.set(sortOption.rawValue, forKey: sortKey)
    }
    
    private func loadSortPreference() {
        guard let rawValue = UserDefaults.standard.string(forKey: sortKey),
              let option = BookSortOption(rawValue: rawValue)
        else { return }
        sortOption = option
    }
}

