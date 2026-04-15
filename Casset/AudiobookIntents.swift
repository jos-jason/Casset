import AppIntents
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
    
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true
    
    @Parameter(title: "Book", description: "The audiobook to play")
    var book: BookEntity
    
    func perform() async throws -> some IntentResult {
        // Post notification to play the specific book
        NotificationCenter.default.post(
            name: NSNotification.Name("PlayAudiobookFromSiri"),
            object: nil,
            userInfo: ["bookID": book.id]
        )
        
        return .result()
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
        NotificationCenter.default.post(name: NSNotification.Name("PauseAudiobookFromSiri"), object: nil)
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
        NotificationCenter.default.post(
            name: NSNotification.Name("SkipForwardFromSiri"),
            object: nil,
            userInfo: seconds.map { ["seconds": $0] }
        )
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
        NotificationCenter.default.post(
            name: NSNotification.Name("SkipBackwardFromSiri"),
            object: nil,
            userInfo: seconds.map { ["seconds": $0] }
        )
        return .result()
    }
}

// MARK: - Resume Audiobook Intent

struct ResumeAudiobookIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Resume Audiobook"
    static var description = IntentDescription("Resumes playback of your current audiobook")
    
    static var openAppWhenRun: Bool = false
    
    func perform() async throws -> some IntentResult {
        NotificationCenter.default.post(name: NSNotification.Name("ResumeAudiobookFromSiri"), object: nil)
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
    }
}
