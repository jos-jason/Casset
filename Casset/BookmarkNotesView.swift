import SwiftUI

struct BookmarkNotesView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText = ""
    @State private var selectedColorFilter: String? = nil
    @State private var showExportSheet = false
    @State private var exportText = ""
    
    let colorFilters: [(name: String, color: Color)] = [
        ("default", Color.primary),
        ("red", .red),
        ("orange", .orange),
        ("yellow", .yellow),
        ("green", .green),
        ("blue", .blue),
        ("purple", .purple),
        ("pink", .pink)
    ]
    
    var filteredBookmarks: [Bookmark] {
        var bookmarks = playerManager.bookmarks.sorted { $0.time < $1.time }
        
        // Filter by color if selected
        if let colorFilter = selectedColorFilter {
            bookmarks = bookmarks.filter { $0.colorName == colorFilter }
        }
        
        // Filter by search text
        if !searchText.isEmpty {
            bookmarks = bookmarks.filter { bookmark in
                bookmark.label.localizedCaseInsensitiveContains(searchText) ||
                bookmark.note.localizedCaseInsensitiveContains(searchText)
            }
        }
        
        return bookmarks
    }
    
    var body: some View {
        NavigationStack {
            List {
                ForEach(filteredBookmarks) { bookmark in
                    BookmarkNoteCard(
                        bookmark: bookmark,
                        colorScheme: colorScheme,
                        onUpdate: { updatedBookmark in
                            playerManager.updateBookmark(
                                bookmark,
                                label: updatedBookmark.label,
                                note: updatedBookmark.note
                            )
                        }
                    )
                }
            }
            .searchable(text: $searchText, prompt: "Search notes...")
            .navigationTitle("Bookmark Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Menu {
                        Button {
                            selectedColorFilter = nil
                        } label: {
                            Label("All Colors", systemImage: selectedColorFilter == nil ? "checkmark" : "")
                        }
                        
                        Divider()
                        
                        ForEach(colorFilters, id: \.name) { item in
                            Button {
                                selectedColorFilter = item.name
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(item.name == "default"
                                                       ? (colorScheme == .dark ? Color.white : Color.black)
                                                       : item.color)
                                    Text(item.name.capitalized)
                                    if selectedColorFilter == item.name {
                                        Spacer()
                                        Image(systemName: "checkmark")
                                    }
                                }
                            }
                        }
                    } label: {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        generateExportText()
                        showExportSheet = true
                    } label: {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
                
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showExportSheet) {
                ExportNotesView(exportText: exportText)
            }
        }
    }
    
    private func generateExportText() {
        var text = "Bookmark Notes\n"
        text += "================\n\n"
        
        for bookmark in filteredBookmarks {
            text += "[\(playerManager.formatTime(bookmark.time))] \(bookmark.label)\n"
            if !bookmark.note.isEmpty {
                text += "\(bookmark.note)\n"
            }
            text += "\n"
        }
        
        exportText = text
    }
}

struct BookmarkNoteCard: View {
    @State var bookmark: Bookmark
    let colorScheme: ColorScheme
    let onUpdate: (Bookmark) -> Void
    
    @State private var isEditing = false
    @FocusState private var isFocused: Bool
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Header with timestamp and color
            HStack {
                Image(systemName: "bookmark.fill")
                    .foregroundStyle(bookmarkColor(bookmark.colorName))
                    .font(.system(size: 16))
                
                Text(bookmark.label)
                    .font(.headline)
                    .foregroundStyle(bookmarkColor(bookmark.colorName))
                
                Spacer()
                
                HStack(spacing: 4) {
                    Image(systemName: "clock")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(formatTime(bookmark.time))
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            
            // Note content
            if isEditing {
                TextField("Add a note...", text: $bookmark.note, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(3...10)
                    .focused($isFocused)
                    .padding(8)
                    .background(Color.secondary.opacity(0.1))
                    .cornerRadius(8)
            } else {
                if !bookmark.note.isEmpty {
                    Text(bookmark.note)
                        .font(.body)
                        .foregroundStyle(.primary)
                } else {
                    Text("No note added")
                        .font(.body)
                        .foregroundStyle(.secondary)
                        .italic()
                }
            }
            
            // Edit button
            HStack {
                Spacer()
                Button {
                    if isEditing {
                        onUpdate(bookmark)
                    }
                    isEditing.toggle()
                } label: {
                    Text(isEditing ? "Done" : "Edit")
                        .font(.caption)
                        .foregroundStyle(.blue)
                }
            }
        }
        .padding(.vertical, 8)
    }
    
    private func formatTime(_ seconds: Double) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        return h > 0
            ? String(format: "%d:%02d:%02d", h, m, s)
            : String(format: "%d:%02d", m, s)
    }
    
    private func bookmarkColor(_ name: String) -> Color {
        switch name {
        case "red":    return .red
        case "orange": return .orange
        case "yellow": return .yellow
        case "green":  return .green
        case "blue":   return .blue
        case "purple": return .purple
        case "pink":   return .pink
        default:       return colorScheme == .dark ? .white : .black
        }
    }
}

struct ExportNotesView: View {
    let exportText: String
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            ScrollView {
                Text(exportText)
                    .font(.system(.body, design: .monospaced))
                    .padding()
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .navigationTitle("Export Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportText) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
