import Foundation

/// A tiny file holding the latest playback position of the book being played.
///
/// Written every few seconds during playback so progress survives crashes and
/// app kills, without rewriting the whole library (which lives in
/// UserDefaults alongside all its bookmarks and notes) each time.
/// `LibraryManager` folds it back into the library when a position is
/// committed, and on launch.
enum PlaybackPositionStore {
    struct Entry: Codable {
        let bookID: UUID
        let position: Double
        let date: Date
    }

    private static let fileURL: URL = {
        let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir.appendingPathComponent("pending_playback_position.json")
    }()

    static func stash(bookID: UUID, position: Double) {
        let entry = Entry(bookID: bookID, position: position, date: Date())
        guard let data = try? JSONEncoder().encode(entry) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }

    static func pending() -> Entry? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        return try? JSONDecoder().decode(Entry.self, from: data)
    }

    static func clear() {
        try? FileManager.default.removeItem(at: fileURL)
    }
}
