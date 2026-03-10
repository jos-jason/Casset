//
//  LibraryManager.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import Foundation
import AVFoundation
import Observation

private struct LibraryData: Codable {
    var books: [Book]
    var groups: [BookGroup]
}

@Observable
class LibraryManager {
    var books: [Book] = []
    var groups: [BookGroup] = []
    var isImporting: Bool = false
    var importError: String?

    private let libraryURL: URL
    private let booksDirectory: URL

    init() {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        libraryURL = docs.appendingPathComponent("library.json")
        booksDirectory = docs.appendingPathComponent("Books")
        try? FileManager.default.createDirectory(at: booksDirectory, withIntermediateDirectories: true)
        load()
    }

    // MARK: - Persistence

    func save() {
        let data = LibraryData(books: books, groups: groups)
        if let encoded = try? JSONEncoder().encode(data) {
            try? encoded.write(to: libraryURL)
        }
    }

    private func load() {
        guard let data = try? Data(contentsOf: libraryURL),
              let decoded = try? JSONDecoder().decode(LibraryData.self, from: data) else { return }
        books = decoded.books
        groups = decoded.groups
    }

    // MARK: - Book Import

    func importBook(from sourceURL: URL) async {
        isImporting = true
        importError = nil
        defer { isImporting = false }

        let accessed = sourceURL.startAccessingSecurityScopedResource()
        defer { if accessed { sourceURL.stopAccessingSecurityScopedResource() } }

        let filename = UUID().uuidString + "_" + sourceURL.lastPathComponent
        let destURL = booksDirectory.appendingPathComponent(filename)

        do {
            try FileManager.default.copyItem(at: sourceURL, to: destURL)
        } catch {
            importError = "Failed to copy file: \(error.localizedDescription)"
            return
        }

        let asset = AVURLAsset(url: destURL)
        var title = sourceURL.deletingPathExtension().lastPathComponent
        var author = "Unknown Author"
        var coverImageData: Data?
        var duration: TimeInterval = 0
        var chapters: [Chapter] = []

        do {
            let durationValue = try await asset.load(.duration)
            duration = durationValue.seconds

            let metadata = try await asset.load(.metadata)
            for item in metadata {
                if let key = item.commonKey {
                    switch key {
                    case .commonKeyTitle:
                        if let value = try? await item.load(.stringValue) { title = value }
                    case .commonKeyArtist, .commonKeyAuthor:
                        if let value = try? await item.load(.stringValue) { author = value }
                    case .commonKeyArtwork:
                        if let data = try? await item.load(.dataValue) { coverImageData = data }
                    default:
                        break
                    }
                }
            }

            let chapterLocales = try await asset.load(.availableChapterLocales)
            if let locale = chapterLocales.first {
                let chapterGroups = try await asset.loadChapterMetadataGroups(
                    withTitleLocale: locale,
                    containingItemsWithCommonKeys: [.commonKeyTitle]
                )
                chapters = chapterGroups.enumerated().map { index, group in
                    let startTime = group.timeRange.start.seconds
                    let endTime = group.timeRange.end.seconds
                    var chapterTitle = "Chapter \(index + 1)"
                    for item in group.items {
                        if item.commonKey == .commonKeyTitle,
                           let value = item.value as? String {
                            chapterTitle = value
                        }
                    }
                    return Chapter(title: chapterTitle, startTime: startTime, endTime: endTime)
                }
            }
        } catch {
            // Metadata extraction failed — use defaults
        }

        let book = Book(
            title: title,
            author: author,
            filename: filename,
            coverImageData: coverImageData,
            duration: duration,
            chapters: chapters
        )

        books.append(book)
        save()
    }

    // MARK: - Book Management

    func removeBook(_ book: Book) {
        try? FileManager.default.removeItem(at: book.fileURL)
        for i in groups.indices {
            groups[i].bookIDs.removeAll { $0 == book.id }
        }
        books.removeAll { $0.id == book.id }
        save()
    }

    func updateBook(_ book: Book) {
        if let index = books.firstIndex(where: { $0.id == book.id }) {
            books[index] = book
            save()
        }
    }

    func addBookmark(name: String, to book: Book, at time: TimeInterval) {
        var updated = book
        let bookmark = Bookmark(timestamp: time, name: name)
        updated.bookmarks.append(bookmark)
        updated.bookmarks.sort { $0.timestamp < $1.timestamp }
        updateBook(updated)
    }

    func removeBookmark(_ bookmark: Bookmark, from book: Book) {
        var updated = book
        updated.bookmarks.removeAll { $0.id == bookmark.id }
        updateBook(updated)
    }

    // MARK: - Group Management

    func addGroup(name: String) {
        let group = BookGroup(name: name)
        groups.append(group)
        save()
    }

    func removeGroup(_ group: BookGroup) {
        groups.removeAll { $0.id == group.id }
        save()
    }

    func addBook(_ book: Book, to group: BookGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        if !groups[index].bookIDs.contains(book.id) {
            groups[index].bookIDs.append(book.id)
            save()
        }
    }

    func removeBook(_ book: Book, from group: BookGroup) {
        guard let index = groups.firstIndex(where: { $0.id == group.id }) else { return }
        groups[index].bookIDs.removeAll { $0 == book.id }
        save()
    }

    func ungroupedBooks() -> [Book] {
        let groupedIDs = Set(groups.flatMap { $0.bookIDs })
        return books.filter { !groupedIDs.contains($0.id) }
    }

    func books(in group: BookGroup) -> [Book] {
        group.bookIDs.compactMap { id in books.first { $0.id == id } }
    }

    // MARK: - Storage

    func storageUsedBytes() -> Int64 {
        var total: Int64 = 0
        if let enumerator = FileManager.default.enumerator(
            at: booksDirectory,
            includingPropertiesForKeys: [.fileSizeKey]
        ) {
            for case let url as URL in enumerator {
                if let size = try? url.resourceValues(forKeys: [.fileSizeKey]).fileSize {
                    total += Int64(size)
                }
            }
        }
        return total
    }

    func formattedStorageUsed() -> String {
        let bytes = storageUsedBytes()
        let formatter = ByteCountFormatter()
        formatter.allowedUnits = [.useMB, .useGB]
        formatter.countStyle = .file
        return formatter.string(fromByteCount: bytes)
    }

    func clearUnusedFiles() {
        let knownFilenames = Set(books.map { $0.filename })
        if let files = try? FileManager.default.contentsOfDirectory(atPath: booksDirectory.path) {
            for file in files where !knownFilenames.contains(file) {
                try? FileManager.default.removeItem(
                    at: booksDirectory.appendingPathComponent(file)
                )
            }
        }
    }
}
