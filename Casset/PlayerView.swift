import SwiftUI
import AVFoundation
import UniformTypeIdentifiers

struct PlayerView: View {
    var book: Book

    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker

    @State private var isShowingPanel       = false
    @State private var isShowingSettings    = false
    @State private var isCreatingBookmark   = false
    @State private var bookmarkLabel        = ""
    @State private var bookmarkColor        = "default"
    @State private var bookmarkNote         = ""
    @State private var resolvedURL: URL?
    @State private var cassetteActionTrigger = UUID()
    @State private var isShowingCoverArt    = false
    @State private var loadErrorMessage: String?
    @State private var cachedCoverImage: UIImage?
    @State private var cachedBlurredCassette: UIImage?
    @State private var cachedBlurredArt: UIImage?
    @State private var isShowingRelinkPicker = false

    @AppStorage("showChapterTicker") var showChapterTicker: Bool = true

    var body: some View {
        VStack(spacing: 0) {

            BookmarkTimelineView()
                .environmentObject(playerManager)
                .padding(.top, 8)

            Spacer()

            Text(book.title)
                .font(.system(size: 13, weight: .medium))
                .tracking(3)
                .foregroundStyle(Color.primary.opacity(0.7))
                .textCase(.uppercase)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()

            Button {
                if cachedCoverImage != nil {
                    isShowingCoverArt.toggle()
                }
            } label: {
                CassetteView(
                    isPlaying: playerManager.isPlaying,
                    coverImage: cachedCoverImage,
                    blurredCassetteImage: cachedBlurredCassette,
                    blurredArtImage: cachedBlurredArt,
                    actionTrigger: cassetteActionTrigger,
                    showArtOnly: isShowingCoverArt
                )
                .padding(.vertical, 24)
            }
            .buttonStyle(.plain)

            Spacer()

            HStack(spacing: 52) {
                Button {
                    playerManager.skipBackward()
                    cassetteActionTrigger = UUID()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(playerManager.player == nil
                                         ? Color.secondary.opacity(0.3)
                                         : Color.primary.opacity(0.8))
                }
                .disabled(playerManager.player == nil)

                Button {
                    playerManager.togglePlayPause()
                    cassetteActionTrigger = UUID()
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 26))
                        .foregroundStyle(Color.primary)
                        .frame(width: 64, height: 64)
                        .background(Circle().fill(Color.primary.opacity(0.1)))
                        .overlay(Circle().stroke(Color.primary.opacity(0.3), lineWidth: 1))
                }
                .disabled(playerManager.player == nil)

                Button {
                    playerManager.skipForward()
                    cassetteActionTrigger = UUID()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 22))
                        .foregroundStyle(playerManager.player == nil
                                         ? Color.secondary.opacity(0.3)
                                         : Color.primary.opacity(0.8))
                }
                .disabled(playerManager.player == nil)
            }
            .padding(.bottom, 28)

            HStack(spacing: 44) {
                Button { isCreatingBookmark = true } label: {
                    Image(systemName: "bookmark")
                        .font(.system(size: 18))
                        .foregroundStyle(playerManager.player == nil
                                         ? Color.secondary.opacity(0.3)
                                         : Color.secondary)
                }
                .disabled(playerManager.player == nil)

                Button { isShowingPanel = true } label: {
                    Image(systemName: "list.bullet")
                        .font(.system(size: 18))
                        .foregroundStyle(playerManager.player == nil
                                         ? Color.secondary.opacity(0.3)
                                         : Color.secondary)
                }
                .disabled(playerManager.player == nil)
            }
            .padding(.bottom, 28)

            if showChapterTicker {
                ChapterTickerView()
                    .environmentObject(playerManager)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 36)
            } else {
                Spacer().frame(height: 56)
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button { isShowingSettings = true } label: {
                    Image(systemName: "gear")
                }
            }
        }
        .onAppear {
            playerScreenTracker.isShowingPlayer = true
            if cachedCoverImage == nil {
                // Decoded at display size (largest use is the 330pt art view)
                // and blurred once, instead of blurring live on the GPU.
                let artURL = book.bestCassetteCoverArtURL()
                cachedCoverImage = ImageCache.image(at: artURL, maxPointSize: 330)
                cachedBlurredCassette = ImageCache.blurredImage(at: artURL, fillSize: CGSize(width: 310, height: 170), radius: 40)
                cachedBlurredArt = ImageCache.blurredImage(at: artURL, fillSize: CGSize(width: 330, height: 330), radius: 40)
            }
            loadBook()
        }
        .onDisappear {
            saveAndRelease()
            playerScreenTracker.isShowingPlayer = false
        }
        .sheet(isPresented: $isCreatingBookmark) {
            BookmarkCreationView(
                label: $bookmarkLabel,
                selectedColor: $bookmarkColor,
                note: $bookmarkNote
            ) {
                playerManager.addBookmark(label: bookmarkLabel, colorName: bookmarkColor, note: bookmarkNote)
                bookmarkLabel = ""
                bookmarkColor = "default"
                bookmarkNote = ""
            }
            .presentationDetents([.large])
        }
        .sheet(isPresented: $isShowingPanel) {
            BookmarksChaptersView(playerManager: playerManager)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .toolbar(.hidden, for: .tabBar)
        .alert("Playback Error", isPresented: Binding(
            get: { loadErrorMessage != nil },
            set: { if !$0 { loadErrorMessage = nil } }
        )) {
            Button("Re-link File") { isShowingRelinkPicker = true }
            Button("OK", role: .cancel) { loadErrorMessage = nil }
        } message: {
            Text((loadErrorMessage ?? "An unknown error occurred.") + "\n\nYou can re-link the original file to restore access without losing your bookmarks or progress.")
        }
        .fileImporter(
            isPresented: $isShowingRelinkPicker,
            allowedContentTypes: [UTType.audio],
            allowsMultipleSelection: false
        ) { result in
            switch result {
            case .success(let urls):
                guard let url = urls.first else { return }
                if libraryManager.repairBookmark(bookID: book.id, from: url) {
                    loadErrorMessage = nil
                    loadBook()
                } else {
                    loadErrorMessage = "Could not re-link the file. Please try again."
                }
            case .failure:
                break
            }
        }
    }

    private func loadBook() {
        loadErrorMessage = nil

        // Try resolving the bookmark, refreshing if stale
        guard let url = libraryManager.resolveAndRefreshBookmark(bookID: book.id) else {
            // Clear stale player so the user can't accidentally play the wrong book
            playerManager.player = nil
            playerManager.currentBookID = nil
            loadErrorMessage = "Could not locate the audio file. Try removing and re-importing the book."
            return
        }
        guard url.startAccessingSecurityScopedResource() else {
            // Clear stale player so the user can't accidentally play the wrong book
            playerManager.player = nil
            playerManager.currentBookID = nil
            loadErrorMessage = "Could not access the audio file. Try removing and re-importing the book."
            return
        }
        resolvedURL = url

        // If this is already the current book, do not reload playback
        if let currentID = playerManager.currentBookID,
           currentID == book.id,
           let player = playerManager.player {
            playerManager.duration    = player.duration
            playerManager.currentTime = player.currentTime
            return
        }

        if let error = playerManager.load(url: url, bookID: book.id) {
            switch error {
            case .alreadyLoaded:
                break // not an error
            case .audioSessionFailed, .playerInitFailed:
                loadErrorMessage = error.errorDescription
            }
            return
        }
        libraryManager.updateDuration(bookID: book.id, duration: playerManager.duration)
        if book.lastPosition > 0 {
            playerManager.seekTo(book.lastPosition)
        }
    }

    private func saveAndRelease() {
        resolvedURL?.stopAccessingSecurityScopedResource()
        libraryManager.updateLastPosition(bookID: book.id, position: playerManager.currentTime)
        libraryManager.updateDuration(bookID: book.id, duration: playerManager.duration)
    }
}

// MARK: - Chapter Ticker
/// Isolated view so that currentTime updates (every 0.5s) only re-evaluate
/// this lightweight view instead of the entire PlayerView hierarchy.
private struct ChapterTickerView: View {
    @EnvironmentObject var playerManager: AudioPlayerManager

    var body: some View {
        ChapterTickerContent(playerManager: playerManager, clock: playerManager.clock)
    }
}

private struct ChapterTickerContent: View {
    let playerManager: AudioPlayerManager
    @ObservedObject var clock: PlaybackClock

    var body: some View {
        let text = chapterText
        if text.isEmpty {
            Spacer().frame(height: 20)
        } else {
            MarqueeText(
                text: text,
                font: .system(size: 13, weight: .medium),
                color: Color.primary.opacity(0.35),
                speed: 35,
                tracking: 3
            )
            .frame(height: 20)
        }
    }

    private var chapterText: String {
        guard let chapter = playerManager.currentChapter else { return "" }
        return "\(chapter.title)  ·  \(playerManager.formatTime(chapter.startTime))"
    }
}

