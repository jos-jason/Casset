import SwiftUI
import PhotosUI

struct BookEditView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var title: String
    @State private var author: String
    @State private var series: String
    @State private var genre: String
    @State private var useCustomColor: Bool
    @State private var customColor: Color
    @State private var boxArtPrompt: String
    @State private var boxArtImage: UIImage?
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var showRemoveBoxArtConfirm = false
    @State private var squareCoverImage: UIImage?
    @State private var selectedSquareCoverItem: PhotosPickerItem?
    @State private var showRemoveSquareCoverConfirm = false
    @State private var cassetteCoverImage: UIImage?
    @State private var selectedCassetteCoverItem: PhotosPickerItem?
    @State private var showRemoveCassetteCoverConfirm = false

    static let genreOptions = [
        "", "Fantasy", "Sci-Fi", "Romance", "Thriller",
        "Non-Fiction", "Horror", "Mystery", "Biography",
        "Historical", "Comedy"
    ]

    /// The cassette box front face aspect ratio (width:height)
    /// Inner box is ~62pt tall; width varies by device (~311–366pt)
    static let boxArtAspectRatio: CGFloat = 340.0 / 62.0  // ~5.5:1

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _series = State(initialValue: book.series)
        _genre = State(initialValue: book.genre)
        _useCustomColor = State(initialValue: book.customColorHex != nil)
        _customColor = State(initialValue: Self.color(from: book.customColorHex) ?? Color(white: 0.3))
        _boxArtPrompt = State(initialValue: book.boxArtPrompt)
        if let url = book.cassetteBoxArtURL() {
            _boxArtImage = State(initialValue: UIImage(contentsOfFile: url.path))
        }
        if let url = book.customCoverArtURL() {
            _squareCoverImage = State(initialValue: UIImage(contentsOfFile: url.path))
        }
        if let url = book.customCassetteCoverArtURL() {
            _cassetteCoverImage = State(initialValue: UIImage(contentsOfFile: url.path))
        }
    }

    var body: some View {
        NavigationStack {
            Form {
                Section("Book Info") {
                    TextField("Title", text: $title)
                    TextField("Author", text: $author)
                    TextField("Series", text: $series)
                }

                Section("Genre") {
                    Picker("Genre", selection: $genre) {
                        Text("None").tag("")
                        ForEach(Self.genreOptions.dropFirst(), id: \.self) { g in
                            Text(g).tag(g)
                        }
                    }
                    .pickerStyle(.menu)
                }

                Section("Cassette Box Color") {
                    Toggle("Custom Color", isOn: $useCustomColor)
                    if useCustomColor {
                        ColorPicker("Box Color", selection: $customColor, supportsOpacity: false)
                    }
                }

                Section {
                    Text("Recommended aspect ratio: **1 : 1** (square, e.g. 1000 × 1000 px)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let img = squareCoverImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(width: 80, height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    PhotosPicker(selection: $selectedSquareCoverItem, matching: .images) {
                        Label(squareCoverImage == nil ? "Choose Cover Image" : "Replace Cover Image",
                              systemImage: "photo")
                    }

                    if squareCoverImage != nil {
                        Button(role: .destructive) {
                            showRemoveSquareCoverConfirm = true
                        } label: {
                            Label("Remove Cover Image", systemImage: "trash")
                        }
                        .confirmationDialog("Remove custom cover art?", isPresented: $showRemoveSquareCoverConfirm) {
                            Button("Remove", role: .destructive) {
                                squareCoverImage = nil
                                selectedSquareCoverItem = nil
                                libraryManager.removeCustomCoverArt(bookID: book.id)
                            }
                        }
                    }
                } header: {
                    Text("Cover Art (Square)")
                } footer: {
                    Text("Standard audiobook cover art. Used in the library and as the cassette background.")
                }

                Section {
                    Text("Recommended aspect ratio: **31 : 17** (e.g. 1240 × 680 px)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    if let img = cassetteCoverImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 80)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    PhotosPicker(selection: $selectedCassetteCoverItem, matching: .images) {
                        Label(cassetteCoverImage == nil ? "Choose Cassette Cover" : "Replace Cassette Cover",
                              systemImage: "rectangle")
                    }

                    if cassetteCoverImage != nil {
                        Button(role: .destructive) {
                            showRemoveCassetteCoverConfirm = true
                        } label: {
                            Label("Remove Cassette Cover", systemImage: "trash")
                        }
                        .confirmationDialog("Remove cassette cover art?", isPresented: $showRemoveCassetteCoverConfirm) {
                            Button("Remove", role: .destructive) {
                                cassetteCoverImage = nil
                                selectedCassetteCoverItem = nil
                                libraryManager.removeCustomCassetteCoverArt(bookID: book.id)
                            }
                        }
                    }
                } header: {
                    Text("Cover Art (Cassette)")
                } footer: {
                    Text("Sized to match the cassette drawn in the player view (310 × 170 pt).")
                }

                Section {
                    // Aspect ratio note
                    Text("Recommended aspect ratio: **5.5 : 1** (e.g. 1100 × 200 px)")
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Current box art preview or placeholder
                    if let img = boxArtImage {
                        Image(uiImage: img)
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .frame(height: 60)
                            .clipShape(RoundedRectangle(cornerRadius: 8))
                    }

                    // Photo picker
                    PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                        Label(boxArtImage == nil ? "Choose Box Art Image" : "Replace Box Art Image",
                              systemImage: "photo.on.rectangle.angled")
                    }

                    // Remove button
                    if boxArtImage != nil {
                        Button(role: .destructive) {
                            showRemoveBoxArtConfirm = true
                        } label: {
                            Label("Remove Box Art", systemImage: "trash")
                        }
                        .confirmationDialog("Remove custom box art?", isPresented: $showRemoveBoxArtConfirm) {
                            Button("Remove", role: .destructive) {
                                boxArtImage = nil
                                selectedPhotoItem = nil
                                libraryManager.removeCassetteBoxArt(bookID: book.id)
                            }
                        }
                    }
                } header: {
                    Text("Cassette Box Art")
                } footer: {
                    Text("Upload an image to use as the full cassette box background in your library.")
                }

                Section {
                    TextField("AI prompt used to generate art...", text: $boxArtPrompt, axis: .vertical)
                        .lineLimit(3...6)
                } header: {
                    Text("Box Art Prompt")
                } footer: {
                    Text("Save the prompt you used (or plan to use) to generate your box art with AI.")
                }
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        if let img = boxArtImage, book.cassetteBoxArtFilename == nil || selectedPhotoItem != nil {
                            libraryManager.saveCassetteBoxArt(bookID: book.id, image: img)
                        }
                        if let img = squareCoverImage, book.customCoverArtFilename == nil || selectedSquareCoverItem != nil {
                            libraryManager.saveCustomCoverArt(bookID: book.id, image: img)
                        }
                        if let img = cassetteCoverImage, book.customCassetteCoverArtFilename == nil || selectedCassetteCoverItem != nil {
                            libraryManager.saveCustomCassetteCoverArt(bookID: book.id, image: img)
                        }
                        libraryManager.updateBookDetails(
                            bookID: book.id,
                            title: title,
                            author: author,
                            series: series,
                            genre: genre,
                            customColorHex: useCustomColor ? Self.hexString(from: customColor) : nil,
                            boxArtPrompt: boxArtPrompt
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
            .onChange(of: selectedPhotoItem) {
                Task {
                    if let data = try? await selectedPhotoItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        boxArtImage = uiImage
                    }
                }
            }
            .onChange(of: selectedSquareCoverItem) {
                Task {
                    if let data = try? await selectedSquareCoverItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        squareCoverImage = uiImage
                    }
                }
            }
            .onChange(of: selectedCassetteCoverItem) {
                Task {
                    if let data = try? await selectedCassetteCoverItem?.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        cassetteCoverImage = uiImage
                    }
                }
            }
        }
    }

    // MARK: - Hex Helpers

    private static func hexString(from color: Color) -> String {
        let uiColor = UIColor(color)
        var r: CGFloat = 0; var g: CGFloat = 0; var b: CGFloat = 0; var a: CGFloat = 0
        uiColor.getRed(&r, green: &g, blue: &b, alpha: &a)
        return String(format: "#%02X%02X%02X", Int(r * 255), Int(g * 255), Int(b * 255))
    }

    private static func color(from hex: String?) -> Color? {
        guard let hex = hex?.trimmingCharacters(in: CharacterSet(charactersIn: "#")),
              hex.count == 6,
              let value = UInt64(hex, radix: 16) else { return nil }
        let r = Double((value >> 16) & 0xFF) / 255.0
        let g = Double((value >> 8) & 0xFF) / 255.0
        let b = Double(value & 0xFF) / 255.0
        return Color(red: r, green: g, blue: b)
    }
}
