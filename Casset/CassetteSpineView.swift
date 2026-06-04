import SwiftUI

struct CassetteSpineView: View {
    let book: Book
    let onPlay: () -> Void

    @State private var coverColors: CoverColors = ColorExtractor.defaultColors

    private var coverImage: UIImage? {
        guard let artURL = book.artworkURL() else { return nil }
        return UIImage(contentsOfFile: artURL.path)
    }

    var body: some View {
        HStack(spacing: 0) {
            // Left end: small cover art
            Group {
                if let uiImage = coverImage {
                    Image(uiImage: uiImage)
                        .resizable()
                        .scaledToFill()
                } else {
                    Image(systemName: "book.closed.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(coverColors.text.opacity(0.6))
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .frame(width: 52, height: 52)
            .clipShape(RoundedRectangle(cornerRadius: 4))
            .padding(.leading, 6)

            // Spine label area: title + author
            VStack(alignment: .leading, spacing: 2) {
                Text(book.title)
                    .font(.system(size: 15, weight: .bold))
                    .lineLimit(1)
                    .foregroundStyle(coverColors.text)

                if !book.author.isEmpty {
                    Text(book.author)
                        .font(.system(size: 12, weight: .medium))
                        .lineLimit(1)
                        .foregroundStyle(coverColors.text.opacity(0.7))
                }
            }
            .padding(.horizontal, 12)
            .frame(maxWidth: .infinity, alignment: .leading)

            // Right end: play button
            Button {
                onPlay()
            } label: {
                Image(systemName: "play.fill")
                    .font(.system(size: 14))
                    .foregroundStyle(coverColors.text)
                    .frame(width: 32, height: 32)
                    .background(
                        Circle()
                            .strokeBorder(coverColors.text.opacity(0.5), lineWidth: 1.5)
                    )
            }
            .buttonStyle(.plain)
            .padding(.trailing, 10)
        }
        .frame(height: 64)
        .background(
            RoundedRectangle(cornerRadius: 6)
                .fill(coverColors.background)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 6)
                .strokeBorder(coverColors.text.opacity(0.15), lineWidth: 0.5)
        )
        .onAppear {
            if let img = coverImage {
                coverColors = ColorExtractor.extractColors(from: img)
            }
        }
    }
}
