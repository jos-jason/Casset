import SwiftUI
import AVFoundation
import Combine
import MediaPlayer
import UIKit

struct Bookmark: Identifiable, Codable {
    let id = UUID()
    var time: Double
    var label: String
    var colorName: String = "default"
    var note: String = ""
}

struct Chapter: Identifiable {
    let id = UUID()
    var title: String
    var startTime: Double
}

class AudioPlayerManager: ObservableObject {
    /// Shared instance for App Intents to access when the app is running
    static weak var shared: AudioPlayerManager?
    
    @Published var player: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var bookmarks: [Bookmark] = []     // current book only
    @Published var chapters: [Chapter] = []
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    @Published var currentBookID: UUID?
    
    // Sleep Timer
    @Published var sleepTimerEndTime: Date?
    @Published var sleepTimerRemaining: TimeInterval = 0

    weak var libraryManager: LibraryManager?

    private var timer: Timer?
    private var sleepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastSavedTime: Double = -1
    private let saveInterval: Double = 5 // seconds between position saves
    private var wasPlayingBeforeInterruption: Bool = false

    var skipDuration: Double {
        let value = UserDefaults.standard.double(forKey: "skipDuration")
        return value == 0 ? 30 : value
    }

    var playbackSpeed: Double {
        let value = UserDefaults.standard.double(forKey: "playbackSpeed")
        return value == 0 ? 1.0 : value
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentTime / duration
    }

    var currentChapter: Chapter? {
        chapters.last { $0.startTime <= currentTime }
    }

    func attachLibraryManager(_ manager: LibraryManager) {
        self.libraryManager = manager
        AudioPlayerManager.shared = self
        setupAudioSession()
        setupRemoteTransportControls()
        setupSiriIntentHandlers()
        observeSettingsChanges()
    }
    
    // MARK: - Background Audio Setup
    
    private func setupAudioSession() {
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
            try audioSession.setActive(true)
            print("Audio session configured for background playback")
        } catch {
            print("Failed to set up audio session: \(error)")
        }
        
        // Observe audio interruptions (e.g. GPS announcements, phone calls)
        // so we can resume playback after the interruption ends.
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(handleAudioInterruption(_:)),
            name: AVAudioSession.interruptionNotification,
            object: AVAudioSession.sharedInstance()
        )
    }
    
    @objc private func handleAudioInterruption(_ notification: Notification) {
        guard let userInfo = notification.userInfo,
              let typeValue = userInfo[AVAudioSessionInterruptionTypeKey] as? UInt,
              let type = AVAudioSession.InterruptionType(rawValue: typeValue) else {
            return
        }
        
        switch type {
        case .began:
            // System interrupted our audio — pause playback state tracking
            if isPlaying {
                wasPlayingBeforeInterruption = true
                isPlaying = false
                stopTimer()
                saveCurrentPosition()
                // Update Now Playing to reflect paused state
                if let library = libraryManager,
                   let bookID = currentBookID,
                   let book = library.books.first(where: { $0.id == bookID }) {
                    let artwork = loadArtwork(for: book)
                    updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
                }
            }
            
        case .ended:
            guard wasPlayingBeforeInterruption else { return }
            wasPlayingBeforeInterruption = false
            
            // Check if we should resume
            let shouldResume: Bool
            if let optionsValue = userInfo[AVAudioSessionInterruptionOptionKey] as? UInt {
                shouldResume = AVAudioSession.InterruptionOptions(rawValue: optionsValue)
                    .contains(.shouldResume)
            } else {
                shouldResume = true
            }
            
            if shouldResume {
                // Re-activate the audio session and resume playback
                do {
                    try AVAudioSession.sharedInstance().setActive(true)
                } catch {
                    print("Failed to reactivate audio session: \(error)")
                }
                
                player?.enableRate = true
                player?.rate = Float(playbackSpeed)
                player?.play()
                isPlaying = true
                startTimer()
                
                // Update Now Playing to reflect playing state
                if let library = libraryManager,
                   let bookID = currentBookID,
                   let book = library.books.first(where: { $0.id == bookID }) {
                    let artwork = loadArtwork(for: book)
                    updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
                }
            }
            
        @unknown default:
            break
        }
    }
    
    private func setupRemoteTransportControls() {
        let commandCenter = MPRemoteCommandCenter.shared()
        
        // Play command
        commandCenter.playCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            if !self.isPlaying {
                self.togglePlayPause()
            }
            return .success
        }
        
        // Pause command
        commandCenter.pauseCommand.addTarget { [weak self] event in
            guard let self else { return .commandFailed }
            if self.isPlaying {
                self.togglePlayPause()
            }
            return .success
        }
        
        // Skip forward command
        commandCenter.skipForwardCommand.isEnabled = true
        commandCenter.skipForwardCommand.preferredIntervals = [NSNumber(value: skipDuration)]
        commandCenter.skipForwardCommand.addTarget { [weak self] event in
            self?.skipForward()
            return .success
        }
        
        // Skip backward command
        commandCenter.skipBackwardCommand.isEnabled = true
        commandCenter.skipBackwardCommand.preferredIntervals = [NSNumber(value: skipDuration)]
        commandCenter.skipBackwardCommand.addTarget { [weak self] event in
            self?.skipBackward()
            return .success
        }
        
        // Change playback position command (scrubbing)
        commandCenter.changePlaybackPositionCommand.addTarget { [weak self] event in
            guard let self,
                  let event = event as? MPChangePlaybackPositionCommandEvent else {
                return .commandFailed
            }
            self.seekTo(event.positionTime)
            return .success
        }
    }
    
    // MARK: - Siri Intent Handlers
    // Siri intents now call AudioPlayerManager.shared directly from AudiobookIntents.swift.
    // No NotificationCenter handlers needed.
    private func setupSiriIntentHandlers() { }
    
    private func updateNowPlayingInfo(bookTitle: String? = nil, artwork: UIImage? = nil) {
        var nowPlayingInfo = [String: Any]()
        
        // Title and artist
        if let title = bookTitle {
            nowPlayingInfo[MPMediaItemPropertyTitle] = title
        }
        nowPlayingInfo[MPMediaItemPropertyArtist] = "Audiobook"
        
        // Timing information
        nowPlayingInfo[MPMediaItemPropertyPlaybackDuration] = duration
        nowPlayingInfo[MPNowPlayingInfoPropertyElapsedPlaybackTime] = currentTime
        nowPlayingInfo[MPNowPlayingInfoPropertyPlaybackRate] = isPlaying ? playbackSpeed : 0.0
        
        // Chapter information
        if let chapter = currentChapter {
            nowPlayingInfo[MPNowPlayingInfoPropertyChapterNumber] = chapters.firstIndex(where: { $0.id == chapter.id }).map { $0 + 1 } ?? 1
            nowPlayingInfo[MPNowPlayingInfoPropertyChapterCount] = chapters.count
        }
        
        // Artwork
        if let artwork = artwork {
            nowPlayingInfo[MPMediaItemPropertyArtwork] = MPMediaItemArtwork(boundsSize: artwork.size) { _ in artwork }
        }
        
        MPNowPlayingInfoCenter.default().nowPlayingInfo = nowPlayingInfo
    }
    
    // Helper to load artwork from book
    private func loadArtwork(for book: Book) -> UIImage? {
        guard let artworkURL = book.bestCoverArtURL(),
              let data = try? Data(contentsOf: artworkURL),
              let image = UIImage(data: data) else {
            return nil
        }
        return image
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                let newRate = self.playbackSpeed
                if let player = self.player {
                    player.enableRate = true
                    player.rate = Float(newRate)
                }
            }
            .store(in: &cancellables)
    }

    // MARK: - Playback

    enum LoadError: LocalizedError {
        case alreadyLoaded
        case audioSessionFailed(Error)
        case playerInitFailed(Error)

        var errorDescription: String? {
            switch self {
            case .alreadyLoaded:
                return nil
            case .audioSessionFailed(let error):
                return "Audio session failed: \(error.localizedDescription)"
            case .playerInitFailed(let error):
                return "Could not load audio file: \(error.localizedDescription)"
            }
        }
    }

    /// Loads audio from the given URL. Returns nil on success, or a LoadError on failure.
    @discardableResult
    func load(url: URL, bookID: UUID) -> LoadError? {
        // If this is already the current book, don't reload the audio
        if let current = currentBookID,
           current == bookID,
           let player = player {
            duration    = player.duration
            currentTime = player.currentTime
            isPlaying   = player.isPlaying
            return .alreadyLoaded
        }

        // Re-activate the audio session to recover from reboots / interruptions
        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playback, mode: .spokenAudio, options: [])
            try audioSession.setActive(true)
        } catch {
            print("Failed to reactivate audio session: \(error)")
            return .audioSessionFailed(error)
        }

        do {
            player = try AVAudioPlayer(contentsOf: url)
            player?.prepareToPlay()
            player?.enableRate = true
            player?.rate = Float(playbackSpeed)
            isPlaying = false
            duration = player?.duration ?? 1
            currentTime = 0
            chapters = []
            currentBookID = bookID

            if let library = libraryManager,
               let book = library.books.first(where: { $0.id == bookID }) {
                bookmarks = book.bookmarks
                
                // Update Now Playing info with book title and cover
                let artwork = loadArtwork(for: book)
                updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
            } else {
                bookmarks = []
                updateNowPlayingInfo()
            }

            Task { await loadChapters(from: url) }
            return nil
        } catch {
            print("Failed to load audio: \(error)")
            return .playerInitFailed(error)
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            stopTimer()
            saveCurrentPosition()
        } else {
            player.enableRate = true
            player.rate = Float(playbackSpeed)
            player.play()
            startTimer()
        }
        isPlaying.toggle()
        
        // Update Now Playing info with new playback state
        if let library = libraryManager,
           let bookID = currentBookID,
           let book = library.books.first(where: { $0.id == bookID }) {
            let artwork = loadArtwork(for: book)
            updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
        } else {
            updateNowPlayingInfo()
        }
    }

    func skipForward() {
        guard let player else { return }
        player.currentTime = min(player.currentTime + skipDuration, player.duration)
        currentTime = player.currentTime
        saveCurrentPosition()
        
        // Update Now Playing info with new position
        if let library = libraryManager,
           let bookID = currentBookID,
           let book = library.books.first(where: { $0.id == bookID }) {
            let artwork = loadArtwork(for: book)
            updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
        }
    }

    func skipBackward() {
        guard let player else { return }
        player.currentTime = max(player.currentTime - skipDuration, 0)
        currentTime = player.currentTime
        saveCurrentPosition()
        
        // Update Now Playing info with new position
        if let library = libraryManager,
           let bookID = currentBookID,
           let book = library.books.first(where: { $0.id == bookID }) {
            let artwork = loadArtwork(for: book)
            updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
        }
    }

    // MARK: - Bookmarks

    func addBookmark(label: String, colorName: String = "default", note: String = "") {
        guard let player else { return }
        let time = player.currentTime
        let finalLabel = label.isEmpty ? formatTime(time) : label
        bookmarks.append(Bookmark(time: time, label: finalLabel, colorName: colorName, note: note))
        persistBookmarks()
    }

    func removeBookmark(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        persistBookmarks()
    }
    
    func updateBookmark(_ bookmark: Bookmark, label: String? = nil, note: String? = nil) {
        guard let index = bookmarks.firstIndex(where: { $0.id == bookmark.id }) else { return }
        if let label = label {
            bookmarks[index].label = label
        }
        if let note = note {
            bookmarks[index].note = note
        }
        persistBookmarks()
    }

    func seekTo(_ time: Double) {
        player?.currentTime = time
        currentTime = time
        saveCurrentPosition()
        
        // Update Now Playing info with new position
        if let library = libraryManager,
           let bookID = currentBookID,
           let book = library.books.first(where: { $0.id == bookID }) {
            let artwork = loadArtwork(for: book)
            updateNowPlayingInfo(bookTitle: book.title, artwork: artwork)
        }
    }

    // MARK: - Helpers

    func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }

    private func persistBookmarks() {
        guard let bookID = currentBookID else { return }
        libraryManager?.updateBookmarks(bookID: bookID, bookmarks: bookmarks)
    }

    /// Persists the current playback position to the library so it survives
    /// app kills, crashes, and backgrounding.
    func saveCurrentPosition() {
        guard let bookID = currentBookID, let player = player else { return }
        let time = player.currentTime
        // Avoid redundant writes
        guard abs(time - lastSavedTime) > 0.5 else { return }
        lastSavedTime = time
        libraryManager?.updateLastPosition(bookID: bookID, position: time)
    }

    private func startTimer() {
        timer?.invalidate()
        var tickCount: Int = 0
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
            // Save position every ~5 seconds (every 10 ticks at 0.5s interval)
            tickCount += 1
            if tickCount >= Int(self.saveInterval / 0.5) {
                tickCount = 0
                self.saveCurrentPosition()
            }
        }
    }

    private func stopTimer() {
        timer?.invalidate()
        timer = nil
    }

    @MainActor
    private func loadChapters(from url: URL) async {
        let asset = AVAsset(url: url)
        guard let locales = try? await asset.load(.availableChapterLocales),
              !locales.isEmpty else { return }

        var loaded: [Chapter] = []
        for locale in locales {
            guard let groups = try? await asset.loadChapterMetadataGroups(
                withTitleLocale: locale,
                containingItemsWithCommonKeys: [.commonKeyTitle]
            ) else { continue }

            for group in groups {
                let title = (try? await group.items.first?.load(.stringValue)) ?? "Chapter"
                let startTime = group.timeRange.start.seconds
                loaded.append(Chapter(title: title, startTime: startTime))
            }
            break
        }
        chapters = loaded.sorted { $0.startTime < $1.startTime }
    }
    
    // MARK: - Sleep Timer
    
    func setSleepTimer(minutes: Int) {
        cancelSleepTimer()
        
        let endTime = Date().addingTimeInterval(TimeInterval(minutes * 60))
        sleepTimerEndTime = endTime
        sleepTimerRemaining = TimeInterval(minutes * 60)
        
        // Start a timer to update remaining time and check if we should stop
        sleepTimer = Timer.scheduledTimer(withTimeInterval: 1.0, repeats: true) { [weak self] _ in
            guard let self else { return }
            
            if let endTime = self.sleepTimerEndTime {
                let remaining = endTime.timeIntervalSinceNow
                
                if remaining <= 0 {
                    // Time's up - pause playback
                    if self.isPlaying {
                        self.togglePlayPause()
                    }
                    self.cancelSleepTimer()
                } else {
                    self.sleepTimerRemaining = remaining
                }
            }
        }
    }
    
    func cancelSleepTimer() {
        sleepTimer?.invalidate()
        sleepTimer = nil
        sleepTimerEndTime = nil
        sleepTimerRemaining = 0
    }
    
    var isSleepTimerActive: Bool {
        sleepTimerEndTime != nil
    }
}

