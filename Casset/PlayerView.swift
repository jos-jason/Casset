import SwiftUI
import AVFoundation

struct PlayerView: View {
    var book: Book

    @EnvironmentObject var libraryManager: LibraryManager
    @EnvironmentObject var playerManager: AudioPlayerManager
    @EnvironmentObject var playerScreenTracker: PlayerScreenTracker   // NEW

    @State private var isShowingPanel       = false
    @State private var isShowingSettings    = false
    @State private var isCreatingBookmark   = false
    @State private var bookmarkLabel        = ""
    @State private var bookmarkColor        = "default"
    @State private var resolvedURL: URL?
    @State private var cassetteActionTrigger = UUID()
    @AppStorage("showChapterTicker") var showChapterTicker: Bool = true

    var coverImage: UIImage? {
        guard let artURL = book.artworkURL() else { return nil }
        return UIImage(contentsOfFile: artURL.path)
    }

    var chapterText: String {
        guard let chapter = playerManager.currentChapter else { return "" }
        return "\(chapter.title)  ·  \(playerManager.formatTime(chapter.startTime))"
    }

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

            CassetteView(
                isPlaying: playerManager.isPlaying,
                coverImage: coverImage,
                actionTrigger: cassetteActionTrigger
            )
            .padding(.vertical, 24)

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

            if showChapterTicker && !chapterText.isEmpty {
                MarqueeText(
                    text: chapterText,
                    font: .system(size: 13, weight: .medium),
                    color: Color.primary.opacity(0.35),
                    speed: 35,
                    tracking: 3
                )
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
            playerScreenTracker.isShowingPlayer = true   // NEW
            loadBook()
        }
        .onDisappear {
            saveAndRelease()
            playerScreenTracker.isShowingPlayer = false  // NEW
        }
        .sheet(isPresented: $isCreatingBookmark) {
            BookmarkCreationView(
                label: $bookmarkLabel,
                selectedColor: $bookmarkColor
            ) {
                playerManager.addBookmark(label: bookmarkLabel, colorName: bookmarkColor)
                bookmarkLabel = ""
                bookmarkColor = "default"
            }
            .presentationDetents([.medium])
        }
        .sheet(isPresented: $isShowingPanel) {
            BookmarksChaptersView(playerManager: playerManager)
        }
        .sheet(isPresented: $isShowingSettings) {
            SettingsView()
        }
        .toolbar(.hidden, for: .tabBar)
    }

    private func loadBook() {
        guard let url = book.resolvedURL() else { return }
        guard url.startAccessingSecurityScopedResource() else { return }
        resolvedURL = url
        playerManager.load(url: url, bookID: book.id)
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

