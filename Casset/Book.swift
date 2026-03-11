import Foundation

struct Book: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var author: String = ""
    var series: String = ""
    var bookmarkData: Data
    var duration: Double = 0
    var lastPosition: Double = 0
    var dateAdded: Date = Date()
    var lastInteracted: Date = Date()  // Tracks most recent interaction (added or played)
    var artworkFilename: String? = nil

    // Per‑book bookmarks (backward‑compatible default)
    var bookmarks: [Bookmark] = []

    func resolvedURL() -> URL? {
        var isStale = false
        return try? URL(
            resolvingBookmarkData: bookmarkData,
            options: .withoutUI,
            relativeTo: nil,
            bookmarkDataIsStale: &isStale
        )
    }

    func artworkURL() -> URL? {
        guard let filename = artworkFilename else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }
}
