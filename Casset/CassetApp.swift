import SwiftUI
import AVFoundation
import AppIntents

@main
struct CassetApp: App {
    @AppStorage("appAppearance") var appAppearanceRaw: String = AppAppearance.dark.rawValue

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var playerManager  = AudioPlayerManager()
    @StateObject private var playerScreenTracker = PlayerScreenTracker()   // NEW

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        // Register App Shortcuts with the system so Siri can discover them
        AudiobookShortcuts.updateAppShortcutParameters()
        
        // Debug: Print registered shortcuts
        print("📱 App Shortcuts registered: \(AudiobookShortcuts.appShortcuts.count)")
    }

    var appearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    private func handlePendingSiriRequest() {
        guard let idString = UserDefaults.standard.string(forKey: "siri_pending_book_id"),
              let bookID = UUID(uuidString: idString) else {
            return
        }
        PlayAudiobookIntent.playBook(id: bookID, on: playerManager)
    }
    
    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryManager)
                .environmentObject(playerManager)
                .environmentObject(playerScreenTracker)    // NEW
                .onAppear {
                    // Ensure the player is attached when the UI appears
                    if playerManager.libraryManager == nil {
                        playerManager.attachLibraryManager(libraryManager)
                    }
                    // Handle any pending Siri play request
                    handlePendingSiriRequest()
                }
                .preferredColorScheme(appearance.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    // Attach on any scene phase change to cover background launches (e.g. Siri)
                    if playerManager.libraryManager == nil {
                        playerManager.attachLibraryManager(libraryManager)
                    }
                    if newPhase == .background || newPhase == .inactive {
                        playerManager.saveCurrentPosition()
                    }
                }
        }
    }
}
