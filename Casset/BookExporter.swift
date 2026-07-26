import Foundation
import UniformTypeIdentifiers

// MARK: - Custom UTType

extension UTType {
    static let cassetBookArchive = UTType(exportedAs: "com.casset.book-export")
}

// MARK: - Manifest Types

struct ExportedBook: Codable {
    var title: String
    var author: String
    var series: String
    var genre: String
    var duration: Double
    var lastPosition: Double
    var customColorHex: String?
    var customTextColorHex: String?
    var boxArtPrompt: String
    var bookmarks: [Bookmark]
    var hasArtwork: Bool
    var hasCustomCover: Bool
    var hasCassetteCover: Bool
    var hasBoxArt: Bool
    var audioFileExtension: String
}

struct CassetManifest: Codable {
    var version: Int = 1
    var exportDate: Date = Date()
    var books: [String: ExportedBook] // keyed by UUID string
}

// MARK: - Book Exporter

enum BookExporter {

    enum ExportError: LocalizedError {
        case noAudioFile
        case copyFailed(String)
        case manifestEncodingFailed

        var errorDescription: String? {
            switch self {
            case .noAudioFile:
                return "Could not access the audio file for export."
            case .copyFailed(let detail):
                return "Failed to copy file: \(detail)"
            case .manifestEncodingFailed:
                return "Failed to encode manifest."
            }
        }
    }

    enum ImportError: LocalizedError {
        case noManifest
        case manifestDecodingFailed
        case noAudioInPackage(String)
        case bookmarkCreationFailed

        var errorDescription: String? {
            switch self {
            case .noManifest:
                return "The .casset file does not contain a valid manifest."
            case .manifestDecodingFailed:
                return "Could not read the .casset manifest."
            case .noAudioInPackage(let title):
                return "No audio file found for \"\(title)\"."
            case .bookmarkCreationFailed:
                return "Could not create a bookmark for the imported audio file."
            }
        }
    }

    // MARK: - Export

    /// Exports the given books into a `.casset` package directory and returns its URL.
    /// The caller is responsible for presenting the share sheet with the returned URL.
    static func exportBooks(_ books: [Book]) throws -> URL {
        let fm = FileManager.default
        let exportID = UUID().uuidString
        let packageName = books.count == 1
            ? "\(books[0].title).casset"
            : "Casset Library.casset"
        let packageURL = fm.temporaryDirectory
            .appendingPathComponent("CassetExport-\(exportID)")
            .appendingPathComponent(packageName)
        let booksDir = packageURL.appendingPathComponent("books")

        // Clean up any previous export at this path
        try? fm.removeItem(at: packageURL)
        try fm.createDirectory(at: booksDir, withIntermediateDirectories: true)

        var manifestBooks: [String: ExportedBook] = [:]

        for book in books {
            let bookKey = book.id.uuidString
            let bookDir = booksDir.appendingPathComponent(bookKey)
            try fm.createDirectory(at: bookDir, withIntermediateDirectories: true)

            // Copy audio file
            var audioExtension = "m4a"
            if let audioURL = book.resolvedURL() {
                let accessed = audioURL.startAccessingSecurityScopedResource()
                defer { if accessed { audioURL.stopAccessingSecurityScopedResource() } }
                audioExtension = audioURL.pathExtension.isEmpty ? "m4a" : audioURL.pathExtension
                let destAudio = bookDir.appendingPathComponent("audio.\(audioExtension)")
                try fm.copyItem(at: audioURL, to: destAudio)
            } else {
                throw ExportError.noAudioFile
            }

            // Copy images
            let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]

            let hasArtwork = copyImageIfExists(
                filename: book.artworkFilename,
                from: docsDir,
                to: bookDir.appendingPathComponent("artwork.jpg"),
                fm: fm
            )
            let hasCustomCover = copyImageIfExists(
                filename: book.customCoverArtFilename,
                from: docsDir,
                to: bookDir.appendingPathComponent("cover.jpg"),
                fm: fm
            )
            let hasCassetteCover = copyImageIfExists(
                filename: book.customCassetteCoverArtFilename,
                from: docsDir,
                to: bookDir.appendingPathComponent("cassettecover.jpg"),
                fm: fm
            )
            let hasBoxArt = copyImageIfExists(
                filename: book.cassetteBoxArtFilename,
                from: docsDir,
                to: bookDir.appendingPathComponent("boxart.jpg"),
                fm: fm
            )

            manifestBooks[bookKey] = ExportedBook(
                title: book.title,
                author: book.author,
                series: book.series,
                genre: book.genre,
                duration: book.duration,
                lastPosition: book.lastPosition,
                customColorHex: book.customColorHex,
                customTextColorHex: book.customTextColorHex,
                boxArtPrompt: book.boxArtPrompt,
                bookmarks: book.bookmarks,
                hasArtwork: hasArtwork,
                hasCustomCover: hasCustomCover,
                hasCassetteCover: hasCassetteCover,
                hasBoxArt: hasBoxArt,
                audioFileExtension: audioExtension
            )
        }

        // Write manifest
        let manifest = CassetManifest(books: manifestBooks)
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let manifestData = try? encoder.encode(manifest) else {
            throw ExportError.manifestEncodingFailed
        }
        try manifestData.write(to: packageURL.appendingPathComponent("manifest.json"))

        return packageURL
    }

    // MARK: - Import

    /// Imports books from a `.casset` package directory into the given LibraryManager.
    /// Returns the number of books successfully imported.
    @discardableResult
    static func importBooks(from packageURL: URL, into libraryManager: LibraryManager) throws -> Int {
        let fm = FileManager.default
        let accessed = packageURL.startAccessingSecurityScopedResource()
        defer { if accessed { packageURL.stopAccessingSecurityScopedResource() } }

        let manifestURL = packageURL.appendingPathComponent("manifest.json")
        guard fm.fileExists(atPath: manifestURL.path) else {
            throw ImportError.noManifest
        }

        let manifestData = try Data(contentsOf: manifestURL)
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(CassetManifest.self, from: manifestData) else {
            throw ImportError.manifestDecodingFailed
        }

        let docsDir = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let audioDir = docsDir.appendingPathComponent("ImportedAudio")
        try? fm.createDirectory(at: audioDir, withIntermediateDirectories: true)

        var importedCount = 0

        for (bookKey, exported) in manifest.books {
            let bookDir = packageURL.appendingPathComponent("books").appendingPathComponent(bookKey)
            let audioSource = bookDir.appendingPathComponent("audio.\(exported.audioFileExtension)")

            guard fm.fileExists(atPath: audioSource.path) else {
                print("Skipping \(exported.title): no audio file found")
                continue
            }

            // Copy audio to Documents/ImportedAudio/ with a unique name
            let newBookID = UUID()
            let audioFilename = "\(newBookID.uuidString).\(exported.audioFileExtension)"
            let audioDest = audioDir.appendingPathComponent(audioFilename)
            try? fm.removeItem(at: audioDest)
            try fm.copyItem(at: audioSource, to: audioDest)

            // Create a bookmark for the copied audio file
            guard let bookmarkData = try? audioDest.bookmarkData(
                options: .minimalBookmark,
                includingResourceValuesForKeys: nil,
                relativeTo: nil
            ) else {
                // Clean up the copied audio if bookmark fails
                try? fm.removeItem(at: audioDest)
                print("Skipping \(exported.title): could not create bookmark")
                continue
            }

            // Copy image files with new UUID-based names
            var artworkFilename: String? = nil
            var customCoverFilename: String? = nil
            var cassetteCoverFilename: String? = nil
            var boxArtFilename: String? = nil

            if exported.hasArtwork {
                let src = bookDir.appendingPathComponent("artwork.jpg")
                let filename = "\(newBookID.uuidString).jpg"
                if copyFileIfExists(from: src, to: docsDir.appendingPathComponent(filename), fm: fm) {
                    artworkFilename = filename
                }
            }
            if exported.hasCustomCover {
                let src = bookDir.appendingPathComponent("cover.jpg")
                let filename = "cover_\(newBookID.uuidString).jpg"
                if copyFileIfExists(from: src, to: docsDir.appendingPathComponent(filename), fm: fm) {
                    customCoverFilename = filename
                }
            }
            if exported.hasCassetteCover {
                let src = bookDir.appendingPathComponent("cassettecover.jpg")
                let filename = "cassettecover_\(newBookID.uuidString).jpg"
                if copyFileIfExists(from: src, to: docsDir.appendingPathComponent(filename), fm: fm) {
                    cassetteCoverFilename = filename
                }
            }
            if exported.hasBoxArt {
                let src = bookDir.appendingPathComponent("boxart.jpg")
                let filename = "boxart_\(newBookID.uuidString).jpg"
                if copyFileIfExists(from: src, to: docsDir.appendingPathComponent(filename), fm: fm) {
                    boxArtFilename = filename
                }
            }

            // Build the Book struct
            var book = Book(
                title: exported.title,
                bookmarkData: bookmarkData
            )
            book.id = newBookID
            book.author = exported.author
            book.series = exported.series
            book.genre = exported.genre
            book.duration = exported.duration
            book.lastPosition = exported.lastPosition
            book.customColorHex = exported.customColorHex
            book.customTextColorHex = exported.customTextColorHex
            book.boxArtPrompt = exported.boxArtPrompt
            book.bookmarks = exported.bookmarks
            book.artworkFilename = artworkFilename
            book.customCoverArtFilename = customCoverFilename
            book.customCassetteCoverArtFilename = cassetteCoverFilename
            book.cassetteBoxArtFilename = boxArtFilename
            book.dateAdded = Date()
            book.lastInteracted = Date()

            libraryManager.addImportedBook(book)
            importedCount += 1
        }

        return importedCount
    }

    // MARK: - Helpers

    /// Copies an image file from the documents directory to a destination if it exists.
    /// Returns true if the file was copied successfully.
    @discardableResult
    private static func copyImageIfExists(
        filename: String?,
        from sourceDir: URL,
        to destination: URL,
        fm: FileManager
    ) -> Bool {
        guard let filename = filename else { return false }
        let source = sourceDir.appendingPathComponent(filename)
        guard fm.fileExists(atPath: source.path) else { return false }
        do {
            try fm.copyItem(at: source, to: destination)
            return true
        } catch {
            print("Failed to copy image \(filename): \(error)")
            return false
        }
    }

    /// Copies a file from source to destination if the source exists.
    /// Returns true if successful.
    @discardableResult
    private static func copyFileIfExists(
        from source: URL,
        to destination: URL,
        fm: FileManager
    ) -> Bool {
        guard fm.fileExists(atPath: source.path) else { return false }
        do {
            try? fm.removeItem(at: destination)
            try fm.copyItem(at: source, to: destination)
            return true
        } catch {
            print("Failed to copy file: \(error)")
            return false
        }
    }
}
