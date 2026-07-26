import Foundation

struct Book: Identifiable, Codable {
    var id: UUID = UUID()
    var title: String
    var subtitle: String = ""
    var author: String = ""
    var series: String = ""
    var bookNumber: String = ""
    var bookmarkData: Data
    var duration: Double = 0
    var lastPosition: Double = 0
    var dateAdded: Date = Date()
    var lastInteracted: Date = Date()  // Tracks most recent interaction (added or played)
    var genre: String = ""
    var artworkFilename: String? = nil
    var customColorHex: String? = nil
    var customTextColorHex: String? = nil
    var cassetteBoxArtFilename: String? = nil
    var boxArtPrompt: String = ""
    var customCoverArtFilename: String? = nil       // Square (1:1) cover art
    var customCassetteCoverArtFilename: String? = nil // Cassette ratio (31:17) cover art

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

    func cassetteBoxArtURL() -> URL? {
        guard let filename = cassetteBoxArtFilename else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func customCoverArtURL() -> URL? {
        guard let filename = customCoverArtFilename else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    func customCassetteCoverArtURL() -> URL? {
        guard let filename = customCassetteCoverArtFilename else { return nil }
        return FileManager.default
            .urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent(filename)
    }

    /// Returns the best available cover image URL: custom square cover, then embedded artwork
    func bestCoverArtURL() -> URL? {
        customCoverArtURL() ?? artworkURL()
    }

    /// Returns the best available cassette cover URL: custom cassette cover, then square cover, then embedded
    func bestCassetteCoverArtURL() -> URL? {
        customCassetteCoverArtURL() ?? customCoverArtURL() ?? artworkURL()
    }
}
