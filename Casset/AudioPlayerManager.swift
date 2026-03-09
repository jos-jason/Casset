import SwiftUI
import AVFoundation
import Combine

struct Bookmark: Identifiable, Codable {
    let id = UUID()
    var time: Double
    var label: String
    var colorName: String = "default"
}

struct Chapter: Identifiable {
    let id = UUID()
    var title: String
    var startTime: Double
}

class AudioPlayerManager: ObservableObject {
    @Published var player: AVAudioPlayer?
    @Published var isPlaying: Bool = false
    @Published var bookmarks: [Bookmark] = []     // current book only
    @Published var chapters: [Chapter] = []
    @Published var currentTime: Double = 0
    @Published var duration: Double = 1
    @Published var currentBookID: UUID?

    weak var libraryManager: LibraryManager?

    private var timer: Timer?
    private var cancellables = Set<AnyCancellable>()

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
        observeSettingsChanges()
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

    func load(url: URL, bookID: UUID) {
        // NEW: If this is already the current book, don't reload the audio
        if let current = currentBookID,
           current == bookID,
           let player = player {
            duration    = player.duration
            currentTime = player.currentTime
            isPlaying   = player.isPlaying
            return
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
            } else {
                bookmarks = []
            }

            Task { await loadChapters(from: url) }
        } catch {
            print("Failed to load audio: \(error)")
        }
    }

    func togglePlayPause() {
        guard let player else { return }
        if isPlaying {
            player.pause()
            stopTimer()
        } else {
            player.enableRate = true
            player.rate = Float(playbackSpeed)
            player.play()
            startTimer()
        }
        isPlaying.toggle()
    }

    func skipForward() {
        guard let player else { return }
        player.currentTime = min(player.currentTime + skipDuration, player.duration)
        currentTime = player.currentTime
    }

    func skipBackward() {
        guard let player else { return }
        player.currentTime = max(player.currentTime - skipDuration, 0)
        currentTime = player.currentTime
    }

    // MARK: - Bookmarks

    func addBookmark(label: String, colorName: String = "default") {
        guard let player else { return }
        let time = player.currentTime
        let finalLabel = label.isEmpty ? formatTime(time) : label
        bookmarks.append(Bookmark(time: time, label: finalLabel, colorName: colorName))
        persistBookmarks()
    }

    func removeBookmark(at offsets: IndexSet) {
        bookmarks.remove(atOffsets: offsets)
        persistBookmarks()
    }

    func seekTo(_ time: Double) {
        player?.currentTime = time
        currentTime = time
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

    private func startTimer() {
        timer?.invalidate()
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            guard let self, let player = self.player else { return }
            self.currentTime = player.currentTime
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
}

