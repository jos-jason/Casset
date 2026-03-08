import SwiftUI
import AVFoundation
import Combine

class LibraryManager: ObservableObject {
    @Published var books:  [Book]      = []
    @Published var groups: [BookGroup] = []

    private let storageKey = "casset_library"
    private let groupsKey  = "casset_groups"

    init() {
        load()
        loadGroups()
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
            if let artworkFilename = await extractArtwork(from: url, bookID: book.id) {
                if let i = books.firstIndex(where: { $0.id == book.id }) {
                    books[i].artworkFilename = artworkFilename
                    save()
                }
            }
        }
    }

    func removeBook(at offsets: IndexSet) {
        for index in offsets {
            let book = books[index]
            if let filename = book.artworkFilename {
                let url = FileManager.default
                    .urls(for: .documentDirectory, in: .userDomainMask)[0]
                    .appendingPathComponent(filename)
                try? FileManager.default.removeItem(at: url)
            }
            for i in groups.indices {
                groups[i].bookIDs.removeAll { $0 == book.id }
            }
        }
        books.remove(atOffsets: offsets)
        save()
        saveGroups()
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

    // MARK: Artwork

    private func extractArtwork(from url: URL, bookID: UUID) async -> String? {
        let asset = AVAsset(url: url)
        guard let metadata = try? await asset.load(.metadata) else { return nil }

        for item in metadata {
            guard item.commonKey == .commonKeyArtwork,
                  let data = try? await item.load(.dataValue)
            else { continue }

            let filename = "\(bookID.uuidString).jpg"
            let fileURL  = FileManager.default
                .urls(for: .documentDirectory, in: .userDomainMask)[0]
                .appendingPathComponent(filename)
            try? data.write(to: fileURL)
            return filename
        }
        return nil
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
}

