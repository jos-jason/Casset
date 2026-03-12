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

struct BookEntityQuery: EntityQuery {
    func entities(for identifiers: [UUID]) async throws -> [BookEntity] {
        // Get books from the app's library manager
        // Note: This requires accessing shared data
        return []
    }
    
    func suggestedEntities() async throws -> [BookEntity] {
        // Return recently played books
        return []
    }
}

// MARK: - Play Audiobook Intent

struct PlayAudiobookIntent: AudioPlaybackIntent {
    static var title: LocalizedStringResource = "Play Audiobook"
    static var description = IntentDescription("Plays your audiobook")
    
    static var openAppWhenRun: Bool = false
    static var isDiscoverable: Bool = true
    
    @Parameter(title: "Book")
    var book: BookEntity?
    
    func perform() async throws -> some IntentResult {
        // Post notification to play the book
        NotificationCenter.default.post(
            name: NSNotification.Name("PlayAudiobookFromSiri"),
            object: nil,
            userInfo: book.map { ["bookID": $0.id] }
        )
        return .result()
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
                "Skip ahead in my audiobook"
            ],
            shortTitle: "Skip Forward",
            systemImageName: "goforward.30"
        )
        
        AppShortcut(
            intent: SkipBackwardIntent(),
            phrases: [
                "Skip back in \(.applicationName)",
                "Go back in my audiobook"
            ],
            shortTitle: "Skip Back",
            systemImageName: "gobackward.30"
        )
    }
}
