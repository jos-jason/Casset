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

/// The fast-changing playback values, kept in their own observable object.
///
/// `currentTime` changes twice a second while playing. When it lived on
/// `AudioPlayerManager`, every view observing the manager — the whole library,
/// every cassette spine, the player screen — re-rendered twice a second. Only
/// the few small views that actually display the time observe this instead.
final class PlaybackClock: ObservableObject {
    @Published var currentTime: Double = 0
    @Published var sleepTimerRemaining: TimeInterval = 0
}

class AudioPlayerManager: ObservableObject {
    /// Shared instance for App Intents to access when the app is running
    static weak var shared: AudioPlayerManager?
    
    @Published var player: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var bookmarks: [Bookmark] = []     // current book only
    @Published var chapters: [Chapter] = []
    @Published var duration: Double = 1
    @Published var currentBookID: UUID?
    
    let clock = PlaybackClock()

    /// Current playback position. Stored on `clock` (not published here) so
    /// that time ticks don't re-render views observing the manager.
    var currentTime: Double {
        get { clock.currentTime }
        set { if clock.currentTime != newValue { clock.currentTime = newValue } }
    }

    // Sleep Timer
    @Published var sleepTimerEndTime: Date?
    var sleepTimerRemaining: TimeInterval {
        get { clock.sleepTimerRemaining }
        set { if clock.sleepTimerRemaining != newValue { clock.sleepTimerRemaining = newValue } }
    }

    weak var libraryManager: LibraryManager?

    private var timer: Timer?
    private var sleepTimer: Timer?
    private var cancellables = Set<AnyCancellable>()
    private var lastSavedTime: Double = -1
    private let saveInterval: Double = 5 // seconds between position saves
    private var wasPlayingBeforeInterruption: Bool = false
    private var isInBackground = false
    private var cachedArtwork: (bookID: UUID, image: UIImage?)?
    private var appliedRate: Float?

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
        observeAppLifecycle()
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
        // The clock isn't refreshed while backgrounded, so sync it first —
        // lock screen controls call this while the app is in the background.
        if let player { currentTime = player.currentTime }

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
    
    // Helper to load artwork from book. Cached per book: this runs on every
    // play/pause/skip, and re-reading the cover from disk each time adds up.
    private func loadArtwork(for book: Book) -> UIImage? {
        if let cached = cachedArtwork, cached.bookID == book.id {
            return cached.image
        }
        let image = ImageCache.image(at: book.bestCoverArtURL(), maxPointSize: 600)
        cachedArtwork = (book.id, image)
        return image
    }

    private func observeSettingsChanges() {
        NotificationCenter.default.publisher(for: UserDefaults.didChangeNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                // This fires on every UserDefaults write, not just speed changes.
                let newRate = Float(self.playbackSpeed)
                guard newRate != self.appliedRate, let player = self.player else { return }
                self.appliedRate = newRate
                player.enableRate = true
                player.rate = newRate
            }
            .store(in: &cancellables)
    }

    /// While the app is in the background nothing is on screen, so the clock
    /// doesn't need refreshing twice a second; it only ticks to save position.
    private func observeAppLifecycle() {
        NotificationCenter.default.publisher(for: UIApplication.didEnterBackgroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isInBackground = true
                if self.isPlaying { self.startTimer() }
            }
            .store(in: &cancellables)
        NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)
            .sink { [weak self] _ in
                guard let self else { return }
                self.isInBackground = false
                if let player = self.player { self.currentTime = player.currentTime }
                if self.isPlaying { self.startTimer() }
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

        // Switching books: commit the outgoing book's position to the library.
        if player != nil, currentBookID != nil {
            if isPlaying {
                player?.pause()
                isPlaying = false
                stopTimer()
            }
            saveCurrentPosition()
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
            appliedRate = Float(playbackSpeed)
            isPlaying = false
            duration = player?.duration ?? 1
            currentTime = 0
            lastSavedTime = -1
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
        stashCurrentPosition()
        
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
        stashCurrentPosition()
        
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
        stashCurrentPosition()
        
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

    /// Commits the current playback position to the library. Called at
    /// natural stopping points (pause, interruption, backgrounding, switching
    /// books); rewrites the library, so it isn't used for periodic saves.
    func saveCurrentPosition() {
        guard let bookID = currentBookID, let player = player else { return }
        libraryManager?.updateLastPosition(bookID: bookID, position: player.currentTime)
    }

    /// Cheaply records the position in a tiny file so it survives app kills
    /// and crashes during playback. Re-saving the whole library (and
    /// refreshing every library view) every few seconds used to drain the
    /// battery; the library picks this up on the next commit or launch.
    private func stashCurrentPosition() {
        guard let bookID = currentBookID, let player = player else { return }
        let time = player.currentTime
        // Avoid redundant writes
        guard abs(time - lastSavedTime) > 0.5 else { return }
        lastSavedTime = time
        PlaybackPositionStore.stash(bookID: bookID, position: time)
    }

    private func startTimer() {
        timer?.invalidate()
        // Foreground: refresh the on-screen clock twice a second.
        // Background: nothing is visible, so just wake up to save position.
        let interval = isInBackground ? saveInterval : 0.5
        var tickCount: Int = 0
        let ticksPerSave = max(1, Int(saveInterval / interval))
        let newTimer = Timer(timeInterval: interval, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            if !self.isInBackground {
                self.currentTime = player.currentTime
            }
            tickCount += 1
            if tickCount >= ticksPerSave {
                tickCount = 0
                self.stashCurrentPosition()
            }
        }
        // Tolerance lets iOS batch wakeups with other work.
        newTimer.tolerance = interval * 0.2
        RunLoop.main.add(newTimer, forMode: .default)
        timer = newTimer
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
        sleepTimer?.tolerance = 0.2
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

