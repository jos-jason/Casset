import SwiftUI

struct MiniPlayerBar: View {
    var book: Book
    @EnvironmentObject var playerManager: AudioPlayerManager

    var coverImage: UIImage? {
        guard let artURL = book.artworkURL() else { return nil }
        return UIImage(contentsOfFile: artURL.path)
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

                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(Color.secondary.opacity(0.2))
                        .frame(height: 3)
                    Capsule()
                        .fill(Color.primary.opacity(0.6))
                        .frame(width: progressWidth, height: 3)
                }
            }

            Spacer()

            // Transport controls (match PlayerView style)
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
    }

    private var progressWidth: CGFloat {
        let progress = playerManager.progress
        return max(0, min(1, progress)) * 80 // 80pt max width for bar
    }
}

// UIKit blur wrapper for subtle background
struct VisualEffectView: UIViewRepresentable {
    let style: UIBlurEffect.Style

    func makeUIView(context: Context) -> UIVisualEffectView {
        UIVisualEffectView(effect: UIBlurEffect(style: style))
    }

    func updateUIView(_ uiView: UIVisualEffectView, context: Context) {}
}

