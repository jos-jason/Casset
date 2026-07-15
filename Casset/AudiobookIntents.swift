import AppIntents
import AVFoundation
import Foundation

// MARK: - App Entity for Books

struct BookEntity: AppEntity {
    static var typeDisplayRepresentation = TypeDisplayRepresentation(name: "Audiobook")
    static var defaultQuery = BookEntityQuery()
    
    var id: UUID
    var title: String
    var author: String
    
    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "\(title)",
            subtitle: author.isEmpty ? nil : "\(author)"
        )
    }
}

struct BookEntityQuery: EntityQuery, EntityStringQuery {
    // MARK: - EntityQuery Protocol
    
    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        // Get specific books by ID
        guard let books = await getBooks() else { return [] }
        return books.filter { identifiers.contains($0.id) }
    }
    
    func suggestedEntities() async throws -> [BookEntity] {
        // Return recently played books
        guard let books = await getBooks() else { return [] }
        return Array(books.prefix(5))
    }
    
    // MARK: - EntityStringQuery Protocol
    
    func entities(matching string: String) async throws -> [BookEntity] {
        // Search books by title or author
        guard let books = await getBooks() else { return [] }
        
        if string.isEmpty {
            return books
        }
        
        return books.filter { book in
            book.title.localizedCaseInsensitiveContains(string) ||
            book.author.localizedCaseInsensitiveContains(string)
        }
    }
    
    // MARK: - Helper
    
    @MainActor
    private func getBooks() async -> [BookEntity]? {
        // Access the shared library manager
        // Note: This uses UserDefaults to read the library
        guard let data = UserDefaults.standard.data(forKey: "casset_library"),
              let books = try? JSONDecoder().decode([Book].self, from: data) else {
            return nil
        }
        
        // Convert to BookEntity and sort by last interaction
        return books
            .sorted { $0.lastInteracted > $1.lastInteracted }
            .map { book in
                BookEntity(
                    id: book.id,
                    title: book.title,
                    author: book.author
                )
            }
    }
}

// MARK: - Play Audiobook Intent

struct PlayAudiobookIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play Audiobook"
    static var description = IntentDescription("Plays a specific audiobook from your library")
    
    static var openAppWhenRun: Bool = true
    static var isDiscoverable: Bool = true
    
    @Parameter(title: "Book", description: "The audiobook to play")
    var book: BookEntity
    
    func perform() async throws -> some IntentResult {
        // Store the requested book ID so the app can pick it up once ready
        UserDefaults.standard.set(book.id.uuidString, forKey: "siri_pending_book_id")
        
        // If the player is already available, play immediately
        await MainActor.run {
            if let playerManager = AudioPlayerManager.shared {
                PlayAudiobookIntent.playBook(id: book.id, on: playerManager)
            }
        }
        
        return .result()
    }
    
    /// Loads and plays a book on the given player manager.
    @MainActor
    static func playBook(id: UUID, on playerManager: AudioPlayerManager) {
        guard let data = UserDefaults.standard.data(forKey: "casset_library"),
              let books = try? JSONDecoder().decode([Book].self, from: data),
              let bookModel = books.first(where: { $0.id == id }),
              let url = bookModel.resolvedURL() else {
            return
        }
        
        // Clear the pending request
        UserDefaults.standard.removeObject(forKey: "siri_pending_book_id")
        
        playerManager.load(url: url, bookID: id)
        if !playerManager.isPlaying {
            playerManager.togglePlayPause()
        }
    }
    
    static var parameterSummary: some ParameterSummary {
        Summary("Play \(\.$book)")
    }
}

// MARK: - Pause Audiobook Intent

struct PauseAudiobookIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Pause Audiobook"
    static var description = IntentDescription("Pauses your audiobook")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        await MainActor.run {
            if let playerManager = AudioPlayerManager.shared, playerManager.isPlaying {
                playerManager.togglePlayPause()
            }
        }
        return .result()
    }
}

// MARK: - Skip Forward Intent

struct SkipForwardIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Skip Forward in Audiobook"
    static var description = IntentDescription("Skips forward in your audiobook")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Seconds", default: 30)
    var seconds: Int?
    
    func perform() async throws -> some IntentResult {
        let skipSeconds = seconds
        await MainActor.run {
            if let playerManager = AudioPlayerManager.shared {
                if let skipSeconds, let player = playerManager.player {
                    player.currentTime = min(player.currentTime + Double(skipSeconds), player.duration)
                    playerManager.currentTime = player.currentTime
                } else {
                    playerManager.skipForward()
                }
            }
        }
        return .result()
    }
}

// MARK: - Skip Backward Intent

struct SkipBackwardIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Skip Backward in Audiobook"
    static var description = IntentDescription("Skips backward in your audiobook")
    
    static var openAppWhenRun: Bool = false
    
    @Parameter(title: "Seconds", default: 30)
    var seconds: Int?
    
    func perform() async throws -> some IntentResult {
        let skipSeconds = seconds
        await MainActor.run {
            if let playerManager = AudioPlayerManager.shared {
                if let skipSeconds, let player = playerManager.player {
                    player.currentTime = max(player.currentTime - Double(skipSeconds), 0)
                    playerManager.currentTime = player.currentTime
                } else {
                    playerManager.skipBackward()
                }
            }
        }
        return .result()
    }
}

// MARK: - Resume Audiobook Intent

struct ResumeAudiobookIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Resume Audiobook"
    static var description = IntentDescription("Resumes playback of your current audiobook")
    
    static var openAppWhenRun: Bool = true
    
    func perform() async throws -> some IntentResult {
        // If the player is already loaded, just resume
        let handled = await MainActor.run { () -> Bool in
            if let playerManager = AudioPlayerManager.shared,
               playerManager.player != nil, !playerManager.isPlaying {
                playerManager.togglePlayPause()
                return true
            }
            return false
        }
        
        if handled { return .result() }
        
        // Cold start: find the most recently played book and queue it up
        guard let data = UserDefaults.standard.data(forKey: "casset_library"),
              let books = try? JSONDecoder().decode([Book].self, from: data),
              let lastBook = books.sorted(by: { $0.lastInteracted > $1.lastInteracted }).first,
              lastBook.lastPosition > 0 else {
            return .result()
        }
        
        // Use the same pending mechanism as PlayAudiobookIntent
        UserDefaults.standard.set(lastBook.id.uuidString, forKey: "siri_pending_book_id")
        
        await MainActor.run {
            if let playerManager = AudioPlayerManager.shared {
                PlayAudiobookIntent.playBook(id: lastBook.id, on: playerManager)
            }
        }
        
        return .result()
    }
}

// MARK: - App Shortcuts Provider

struct AudiobookShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: ResumeAudiobookIntent(),
            phrases: [
                "Resume my audiobook in \(.applicationName)",
                "Continue my audiobook in \(.applicationName)",
                "Play my audiobook in \(.applicationName)"
            ],
            shortTitle: "Resume Audiobook",
            systemImageName: "book.fill"
        )
        
        AppShortcut(
            intent: PauseAudiobookIntent(),
            phrases: [
                "Pause my audiobook in \(.applicationName)",
                "Stop my audiobook in \(.applicationName)"
            ],
            shortTitle: "Pause Audiobook",
            systemImageName: "pause.fill"
        )
        
        AppShortcut(
            intent: SkipForwardIntent(),
            phrases: [
                "Skip forward in \(.applicationName)",
                "Skip ahead in \(.applicationName)"
            ],
            shortTitle: "Skip Forward",
            systemImageName: "goforward.30"
        )
        
        AppShortcut(
            intent: SkipBackwardIntent(),
            phrases: [
                "Skip back in \(.applicationName)",
                "Go back in \(.applicationName)"
            ],
            shortTitle: "Skip Back",
            systemImageName: "gobackward.30"
        )
        
        AppShortcut(
            intent: PlayAudiobookIntent(),
            phrases: [
                "Play \(\.$book) in \(.applicationName)",
                "Listen to \(\.$book) in \(.applicationName)",
                "Read \(\.$book) in \(.applicationName)"
            ],
            shortTitle: "Play Audiobook",
            systemImageName: "play.fill"
        )
    }
}
