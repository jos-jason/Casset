import SwiftUI
import AVFoundation
import AppIntents
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

    /// What Siri's App Shortcut parameters are built from; used to skip
    /// re-registering shortcuts when only progress or bookmarks changed.
    private var shortcutSignature: String?

    init() {
        load()
        // CassetApp registers shortcuts at launch; no need to repeat it on the first save.
        shortcutSignature = currentShortcutSignature
        applyPendingPlaybackPosition()
        loadGroups()
        loadSortPreference()
        cleanupOrphanedBookIDs()
        syncAutoCollections()
    }

    func addBook(from url: URL) {
        guard url.startAccessingSecurityScopedResource() else { return }
        guard let bookmarkData = try? url.bookmarkData(
            options: [],
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
            await MainActor.run {
                applyMetadata(metadata, toBookID: book.id)
            }
        }
    }

    /// Add a book from a URL that is already within an active security scope
    /// (e.g. a file discovered inside a user-selected folder).
    /// `folderCoverData` is optional pre-read image data from a cover file in the folder.
    func addBook(from url: URL, securityScopedParent: URL, folderCoverData: Data? = nil) {
        guard let bookmarkData = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else {
            return
        }

        let title = url.deletingPathExtension().lastPathComponent
        let book  = Book(title: title, bookmarkData: bookmarkData)
        books.append(book)
        save()

        // Metadata extraction happens asynchronously; the parent folder's
        // security scope may be released before the Task runs, so we resolve
        // the bookmark to re-acquire access inside the Task.
        Task {
            var isStale = false
            guard let resolvedURL = try? URL(
                resolvingBookmarkData: bookmarkData,
                options: .withoutUI,
                relativeTo: nil,
                bookmarkDataIsStale: &isStale
            ) else { return }
            guard resolvedURL.startAccessingSecurityScopedResource() else { return }
            defer { resolvedURL.stopAccessingSecurityScopedResource() }

            let metadata = await extractMetadata(from: resolvedURL, bookID: book.id)
            await MainActor.run {
                applyMetadata(metadata, toBookID: book.id, folderCoverData: folderCoverData)
            }
        }
    }

    /// Apply extracted metadata fields to a book in the library.
    /// `folderCoverData` is used as a fallback when no embedded artwork was found.
    private func applyMetadata(_ metadata: ExtractedMetadata, toBookID bookID: UUID, folderCoverData: Data? = nil) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        if let artwork = metadata.artworkFilename {
            books[i].artworkFilename = artwork
        } else if let coverData = folderCoverData {
            // No embedded artwork — use the folder cover image as fallback
            let filename = "\(bookID.uuidString).jpg"
            let destURL = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            if (try? coverData.write(to: destURL)) != nil {
                books[i].artworkFilename = filename
            }
        }
        if !metadata.genre.isEmpty {
            books[i].genre = metadata.genre
        }
        if !metadata.author.isEmpty && books[i].author.isEmpty {
            books[i].author = metadata.author
        }
        // Use album name as the book title if available (better than filename)
        if !metadata.albumName.isEmpty {
            books[i].title = metadata.albumName
        }
        save()
        syncAutoCollections()
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
        syncAutoCollections()
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
        syncAutoCollections()
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

    // MARK: Auto Collections (Series & Author)

    /// Syncs both auto-series and auto-author collections.
    func syncAutoCollections() {
        var changed = false
        changed = syncAutoGroups(type: .series, keyPath: \.series) || changed
        changed = syncAutoGroups(type: .author, keyPath: \.author) || changed
        if changed { saveGroups() }
    }

    /// Generic helper: syncs auto-generated groups for a given `AutoGroupType`.
    /// Returns `true` if any group was created, updated, or removed.
    private func syncAutoGroups(type: AutoGroupType, keyPath: KeyPath<Book, String>) -> Bool {
        // Build a map of tag value → [book IDs]
        var tagMap: [String: [UUID]] = [:]
        for book in books {
            let key = book[keyPath: keyPath].trimmingCharacters(in: .whitespacesAndNewlines)
            guard !key.isEmpty else { continue }
            tagMap[key, default: []].append(book.id)
        }

        var changed = false

        for (tagName, bookIDs) in tagMap {
            if bookIDs.count < 2 {
                // Fewer than 2 books — remove the auto group if one exists
                if let idx = groups.firstIndex(where: { $0.autoGroupType == type && $0.name == tagName }) {
                    groups.remove(at: idx)
                    changed = true
                }
                continue
            }

            let sorted = bookIDs.sorted { a, b in
                let titleA = books.first(where: { $0.id == a })?.title ?? ""
                let titleB = books.first(where: { $0.id == b })?.title ?? ""
                return titleA.localizedCaseInsensitiveCompare(titleB) == .orderedAscending
            }

            if let idx = groups.firstIndex(where: { $0.autoGroupType == type && $0.name == tagName }) {
                if groups[idx].bookIDs != sorted {
                    groups[idx].bookIDs = sorted
                    changed = true
                }
            } else {
                let group = BookGroup(name: tagName, bookIDs: sorted, autoGroupType: type)
                groups.append(group)
                changed = true
            }
        }

        // Remove auto groups whose tag no longer appears in any book
        let activeNames = Set(tagMap.keys)
        let before = groups.count
        groups.removeAll { $0.autoGroupType == type && !activeNames.contains($0.name) }
        if groups.count != before { changed = true }

        return changed
    }

    // MARK: Playback info

    /// Resolves the bookmark for a book, refreshing it if stale. Returns the URL or nil.
    func resolveAndRefreshBookmark(bookID: UUID) -> URL? {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return nil }
        let before = books[i].bookmarkData
        guard let url = books[i].resolveAndRefreshBookmark() else { return nil }
        if books[i].bookmarkData != before {
            save()  // persist refreshed bookmark data if it changed
        }
        return url
    }

    /// Repairs a book's bookmark data from a freshly-picked URL (document picker).
    /// Preserves all metadata, bookmarks, and playback position.
    func repairBookmark(bookID: UUID, from url: URL) -> Bool {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return false }
        guard url.startAccessingSecurityScopedResource() else { return false }
        defer { url.stopAccessingSecurityScopedResource() }
        guard let newData = try? url.bookmarkData(
            options: [],
            includingResourceValuesForKeys: nil,
            relativeTo: nil
        ) else { return false }
        books[i].bookmarkData = newData
        save()
        print("🔧 Repaired bookmark for: \(url.lastPathComponent)")
        return true
    }

    func updateLastPosition(bookID: UUID, position: Double) {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].lastPosition = position
        books[i].lastInteracted = Date()  // Update interaction timestamp
        save()
        // The library now holds this book's latest position.
        if PlaybackPositionStore.pending()?.bookID == bookID {
            PlaybackPositionStore.clear()
        }
    }

    /// Applies a position stashed during playback that never got committed
    /// (e.g. the app was killed while playing in the background).
    private func applyPendingPlaybackPosition() {
        guard let entry = PlaybackPositionStore.pending() else { return }
        if let i = books.firstIndex(where: { $0.id == entry.bookID }) {
            books[i].lastPosition = entry.position
            books[i].lastInteracted = max(books[i].lastInteracted, entry.date)
            save()
        }
        PlaybackPositionStore.clear()
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

    func updateBookDetails(bookID: UUID, title: String, subtitle: String = "", author: String, series: String, bookNumber: String = "", genre: String, customColorHex: String? = nil, customTextColorHex: String? = nil, boxArtPrompt: String = "") {
        guard let i = books.firstIndex(where: { $0.id == bookID }) else { return }
        books[i].title = title
        books[i].subtitle = subtitle
        books[i].author = author
        books[i].series = series
        books[i].bookNumber = bookNumber
        books[i].genre = genre
        books[i].customColorHex = customColorHex
        books[i].customTextColorHex = customTextColorHex
        books[i].boxArtPrompt = boxArtPrompt
        save()
        syncAutoCollections()
    }

    /// Applies custom text and/or box colors to all books sharing the same series.
    func applyColorsToSeries(series: String, textColorHex: String?, boxColorHex: String?) {
        guard !series.isEmpty else { return }
        for i in books.indices where books[i].series == series {
            if let hex = textColorHex {
                books[i].customTextColorHex = hex
            }
            if let hex = boxColorHex {
                books[i].customColorHex = hex
            }
        }
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

    // MARK: Import from .casset

    /// Adds a fully-constructed Book (from a .casset import) to the library.
    func addImportedBook(_ book: Book) {
        books.append(book)
        save()
        syncAutoCollections()
    }

    // MARK: Metadata Extraction

    private struct ExtractedMetadata {
        var artworkFilename: String?
        var genre: String = ""
        var author: String = ""
        var albumName: String = ""   // Often the book title in audiobook files
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

            // Extract author (artist)
            if item.commonKey == .commonKeyArtist,
               let artist = try? await item.load(.stringValue),
               !artist.isEmpty {
                result.author = artist
            }

            // Extract album name (often the book title for audiobooks)
            if item.commonKey == .commonKeyAlbumName,
               let album = try? await item.load(.stringValue),
               !album.isEmpty {
                result.albumName = album
            }
        }

        return result
    }

    // MARK: Persistence

    private func save() {
        if let data = try? JSONEncoder().encode(books) {
            UserDefaults.standard.set(data, forKey: storageKey)
        }
        // Keep Siri's book list in sync when the list of books changes.
        // Re-registering is expensive for the system, so skip it when only
        // progress, bookmarks or artwork changed.
        let signature = currentShortcutSignature
        if signature != shortcutSignature {
            shortcutSignature = signature
            AudiobookShortcuts.updateAppShortcutParameters()
        }
    }

    private var currentShortcutSignature: String {
        books.map { "\($0.id)\u{1F}\($0.title)\u{1F}\($0.author)" }.joined(separator: "\u{1E}")
    }

    private func load() {
        guard let data    = UserDefaults.standard.data(forKey: storageKey),
              let decoded = try? JSONDecoder().decode([Book].self, from: data)
        else { return }
        books = decoded
    }

    func saveGroupsPublic() { saveGroups() }

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
    
    // MARK: - Filtered Group Lists

    var seriesGroups: [BookGroup] {
        groups.filter { $0.autoGroupType == .series }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var authorGroups: [BookGroup] {
        groups.filter { $0.autoGroupType == .author }
            .sorted { $0.name.localizedCaseInsensitiveCompare($1.name) == .orderedAscending }
    }

    var manualGroups: [BookGroup] {
        groups.filter { $0.autoGroupType == .none }
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
                // Within same series, sort by book number then title
                let num1 = Double(book1.bookNumber)
                let num2 = Double(book2.bookNumber)
                switch (num1, num2) {
                case (.some(let n1), .some(let n2)):
                    if n1 != n2 { return n1 < n2 }
                case (.some, .none):
                    return true
                case (.none, .some):
                    return false
                case (.none, .none):
                    break
                }
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

