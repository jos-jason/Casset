import SwiftUI
import AVFoundation
import AppIntents

@main
struct CassetApp: App {
    @AppStorage("appAppearance") var appAppearanceRaw: String = AppAppearance.system.rawValue

    @Environment(\.scenePhase) private var scenePhase

    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var playerManager  = AudioPlayerManager()
    @StateObject private var playerScreenTracker = PlayerScreenTracker()   // NEW

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
        
        // Debug: Print registered shortcuts
        print("📱 App Shortcuts registered: \(AudiobookShortcuts.appShortcuts.count)")
    }

    var appearance: AppAppearance {
        AppAppearance(rawValue: appAppearanceRaw) ?? .system
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environmentObject(libraryManager)
                .environmentObject(playerManager)
                .environmentObject(playerScreenTracker)    // NEW
                .onAppear {
                    playerManager.attachLibraryManager(libraryManager)
                }
                .preferredColorScheme(appearance.colorScheme)
                .onChange(of: scenePhase) { _, newPhase in
                    if newPhase == .background || newPhase == .inactive {
                        playerManager.saveCurrentPosition()
                    }
                }
        }
    }
}
