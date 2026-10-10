import SwiftUI

struct MiniPlayerBar: View {
    var book: Book
    var onTap: () -> Void = {}          // tap on artwork opens PlayerView

    @EnvironmentObject var playerManager: AudioPlayerManager

    var coverImage: UIImage? {
        ImageCache.image(at: book.bestCoverArtURL(), maxPointSize: 80)
    }

    var body: some View {
        HStack(spacing: 12) {

            // Artwork thumbnail
            Group {
                if let img = coverImage {
                    Image(uiImage: img)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(.secondary)
                }
            }
            .frame(width: 40, height: 40)
            .clipShape(RoundedRectangle(cornerRadius: 8))

            // Title + subtle progress bar
            VStack(alignment: .leading, spacing: 4) {
                Text(book.title)
                    .font(.subheadline)
                    .lineLimit(1)

                MiniProgressBar(clock: playerManager.clock, duration: playerManager.duration)
            }

            Spacer()

            // Transport controls (match main player style)
            HStack(spacing: 24) {
                Button {
                    playerManager.skipBackward()
                } label: {
                    Image(systemName: "backward.end.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.primary.opacity(0.8))
                }
                .disabled(playerManager.player == nil)

                Button {
                    playerManager.togglePlayPause()
                } label: {
                    Image(systemName: playerManager.isPlaying ? "pause.fill" : "play.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(Color.primary)
                }
                .disabled(playerManager.player == nil)

                Button {
                    playerManager.skipForward()
                } label: {
                    Image(systemName: "forward.end.fill")
                        .font(.system(size: 18))
                        .foregroundStyle(Color.primary.opacity(0.8))
                }
                .disabled(playerManager.player == nil)
            }
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 8)
        .background(
            VisualEffectView(style: .systemMaterial)
                .clipShape(RoundedRectangle(cornerRadius: 16))
        )
        .contentShape(RoundedRectangle(cornerRadius: 16))
        .onTapGesture {
            onTap()
        }
    }

}

/// Observes only the playback clock, so time ticks redraw just this bar.
private struct MiniProgressBar: View {
    @ObservedObject var clock: PlaybackClock
    var duration: Double

    var body: some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(Color.secondary.opacity(0.2))
                .frame(height: 3)
            Capsule()
                .fill(Color.primary.opacity(0.6))
                .frame(width: progressWidth, height: 3)
        }
    }

    private var progressWidth: CGFloat {
        let progress = duration > 0 ? clock.currentTime / duration : 0
        return max(0, min(1, progress)) * 80   // 0–80pt bar
    }
}

// UIKit blur wrapper
struct VisualEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

