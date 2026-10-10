import SwiftUI

struct CassetteSpineView: View {
    let book: Book
    let onPlay: () -> Void

    @AppStorage("colorIntensity") private var colorIntensity: Double = 0.5
    @State private var coverColors: CoverColors = ColorExtractor.defaultColors
    @Environment(\.colorScheme) private var colorScheme

    // Cached and downsampled: these used to be decoded from disk at full
    // resolution every time the view body ran.
    private var coverImage: UIImage? {
        ImageCache.image(at: book.bestCoverArtURL(), maxPointSize: 120)
    }

    private var cassetteBoxArtImage: UIImage? {
        ImageCache.image(at: book.cassetteBoxArtURL(), maxPointSize: 440)
    }

    private var hasSubtitle: Bool { !book.subtitle.isEmpty }

    private var titleSize: CGFloat {
        let length = book.title.count
        if hasSubtitle {
            // Smaller title when subtitle needs space below
            if length > 50 { return 12 }
            if length > 30 { return 14 }
            return 16
        }
        if length > 60 { return 15 }
        if length > 40 { return 17 }
        return 20
    }

    private var subtitleSize: CGFloat {
        let length = book.subtitle.count
        if length > 60 { return 8 }
        if length > 40 { return 9 }
        return 10
    }

    private var lineColor: Color { colorScheme == .dark ? .white : .black }
    private var textColor: Color {
        if let hex = book.customTextColorHex, let color = Self.color(from: hex) {
            return color
        }
        return lineColor
    }
    private let lineWidth: CGFloat = 1.2

    private var authorNameParts: [String] {
        let parts = book.author.split(separator: " ", maxSplits: 1).map(String.init)
        return parts.isEmpty ? [book.author] : parts
    }

    private var boxBackground: Color {
        if let hex = book.customColorHex, let color = Self.color(from: hex) {
            return color
        }
        return coverColors.background
    }


    private static func color(from hex: String) -> Color? {
        let cleaned = hex.trimmingCharacters(in: CharacterSet(charactersIn: "#"))
        guard cleaned.count == 6, let value = UInt64(cleaned, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }

    var body: some View {
        // Inner cassette box content
        let innerBox = Group {
            if let boxArt = cassetteBoxArtImage {
                // Custom box art replaces all inner content
                GeometryReader { geo in
                    Image(uiImage: boxArt)
                        .resizable()
                        .scaledToFill()
                        .frame(width: geo.size.width, height: geo.size.height)
                        .clipped()
                }
            } else {
                // Default layout: cover art | colored area with title/author/play
                HStack(spacing: 0) {
                    // Cover art — flush left, fully visible top to bottom
                    Group {
                        if let uiImage = coverImage {
                            Image(uiImage: uiImage)
                                .resizable()
                                .scaledToFit()
                        } else {
                            Image(systemName: "book.closed.fill")
                                .font(.system(size: 24))
                                .foregroundStyle(textColor.opacity(0.5))
                                .frame(maxHeight: .infinity)
                                .frame(width: 50)
                        }
                    }
                    .frame(maxHeight: .infinity)
                    .background(boxBackground)

                    // Colored middle: title, divider, author, play
                    HStack(spacing: 0) {
                        // Big title + optional subtitle
                        VStack(alignment: .leading, spacing: hasSubtitle ? 0 : 1) {
                            Text(book.title)
                                .font(.system(size: titleSize, weight: .bold))
                                .lineLimit(2)
                                .minimumScaleFactor(0.5)
                                .foregroundStyle(textColor)
                            if hasSubtitle {
                                Text(book.subtitle)
                                    .font(.system(size: subtitleSize, weight: .medium))
                                    .lineLimit(2)
                                    .minimumScaleFactor(0.5)
                                    .foregroundStyle(textColor.opacity(0.7))
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .layoutPriority(1)
                        .padding(.leading, 12)
                        .padding(.trailing, 8)

                        // Short divider
                        textColor.opacity(0.6)
                            .frame(width: lineWidth, height: 34)

                        // Author + play button
                        HStack(spacing: 0) {
                            // Author name centered between divider and play button
                            if !book.author.isEmpty {
                                VStack(alignment: .leading, spacing: 1) {
                                    ForEach(authorNameParts, id: \.self) { part in
                                        Text(part)
                                            .font(.system(size: 10, weight: .medium))
                                            .lineLimit(1)
                                            .minimumScaleFactor(0.7)
                                            .foregroundStyle(textColor.opacity(0.8))
                                    }
                                }
                                .frame(maxWidth: .infinity)
                            } else {
                                Spacer()
                            }

                            // Play button
                            Button {
                                onPlay()
                            } label: {
                                Image(systemName: "play.fill")
                                    .font(.system(size: 11))
                                    .foregroundStyle(textColor)
                                    .frame(width: 28, height: 28)
                                    .background(
                                        Circle()
                                            .strokeBorder(textColor.opacity(0.8), lineWidth: lineWidth)
                                    )
                            }
                            .buttonStyle(.plain)
                        }
                        .padding(.leading, 8)
                        .padding(.trailing, 8)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .background(boxBackground)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .aspectRatio(5.5, contentMode: .fit)
        .clipShape(Rectangle())
        .overlay(alignment: .topTrailing) {
            if !book.bookNumber.isEmpty {
                Text(book.bookNumber)
                    .font(.system(size: 9, weight: .semibold, design: .monospaced))
                    .foregroundStyle(textColor.opacity(0.7))
                    .padding(.horizontal, 5)
                    .padding(.vertical, 2)
            }
        }
        .overlay(
            Rectangle()
                .strokeBorder(lineColor.opacity(0.5), lineWidth: lineWidth)
        )

        // Outer box: black background with white border, inner box inset
        innerBox
            .padding(12)
            .background(colorScheme == .dark ? Color.black : Color.white)
            .overlay(
                // 3D depth line from inner box top-left corner, diagonally up-right
                GeometryReader { geo in
                    let inset: CGFloat = 12
                    let lineLen: CGFloat = 8
                    let opacity: Double = 0.35
                    Path { p in
                        // Top-left corner of outer box
                        p.move(to: CGPoint(x: 0, y: 0))
                        p.addLine(to: CGPoint(x: lineLen, y: -lineLen))
                        // Top-right corner of outer box
                        p.move(to: CGPoint(x: geo.size.width, y: 0))
                        p.addLine(to: CGPoint(x: geo.size.width + lineLen, y: -lineLen))
                        // Top-left corner of inner box
                        p.move(to: CGPoint(x: inset, y: inset))
                        p.addLine(to: CGPoint(x: inset + lineLen, y: inset - lineLen))
                        // Top-right corner of inner box
                        p.move(to: CGPoint(x: geo.size.width - inset, y: inset))
                        p.addLine(to: CGPoint(x: geo.size.width - inset + lineLen, y: inset - lineLen))
                        // Bottom-left corner of outer box
                        p.move(to: CGPoint(x: 0, y: geo.size.height))
                        p.addLine(to: CGPoint(x: lineLen, y: geo.size.height - lineLen))
                        // Bottom-right corner of outer box
                        p.move(to: CGPoint(x: geo.size.width, y: geo.size.height))
                        p.addLine(to: CGPoint(x: geo.size.width + lineLen, y: geo.size.height - lineLen))
                        // Bottom-right corner of inner box
                        p.move(to: CGPoint(x: geo.size.width - inset, y: geo.size.height - inset))
                        p.addLine(to: CGPoint(x: geo.size.width - inset + lineLen, y: geo.size.height - inset - lineLen))
                    }
                    .stroke(lineColor.opacity(opacity), lineWidth: 0.8)
                }
            )
            .overlay(
                Rectangle()
                    .strokeBorder(lineColor.opacity(0.6), lineWidth: lineWidth)
            )
            .onAppear {
                if let colors = ImageCache.coverColors(at: book.bestCoverArtURL(), intensity: colorIntensity) {
                    coverColors = colors
                }
            }
            .onChange(of: colorIntensity) {
                if let colors = ImageCache.coverColors(at: book.bestCoverArtURL(), intensity: colorIntensity) {
                    coverColors = colors
                }
            }
    }
}
