import SwiftUI

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

    static let genreOptions = [
        "", "Fantasy", "Sci-Fi", "Romance", "Thriller",
        "Non-Fiction", "Horror", "Mystery", "Biography",
        "Historical", "Comedy"
    ]

    init(book: Book) {
        self.book = book
        _title = State(initialValue: book.title)
        _author = State(initialValue: book.author)
        _series = State(initialValue: book.series)
        _genre = State(initialValue: book.genre)
        _useCustomColor = State(initialValue: book.customColorHex != nil)
        _customColor = State(initialValue: Self.color(from: book.customColorHex) ?? Color(white: 0.3))
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
            }
            .navigationTitle("Edit Book")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        libraryManager.updateBookDetails(
                            bookID: book.id,
                            title: title,
                            author: author,
                            series: series,
                            genre: genre,
                            customColorHex: useCustomColor ? Self.hexString(from: customColor) : nil
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
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
