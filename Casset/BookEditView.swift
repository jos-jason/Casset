import SwiftUI

struct BookEditView: View {
    @EnvironmentObject var libraryManager: LibraryManager
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var title: String
    @State private var author: String
    @State private var series: String
    @State private var genre: String

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
                            genre: genre
                        )
                        dismiss()
                    }
                    .disabled(title.isEmpty)
                }
            }
        }
    }
}
