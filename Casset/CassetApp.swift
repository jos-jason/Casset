import SwiftUI
import AVFoundation

@main
struct CassetApp: App {
    @AppStorage("appAppearance") var appAppearanceRaw: String = AppAppearance.system.rawValue

    @StateObject private var libraryManager = LibraryManager()
    @StateObject private var playerManager  = AudioPlayerManager()
    @StateObject private var playerScreenTracker = PlayerScreenTracker()   // NEW

    init() {
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default)
        try? AVAudioSession.sharedInstance().setActive(true)
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
        }
    }
}
