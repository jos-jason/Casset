import SwiftUI

struct BookmarkNotesView: View {
    @ObservedObject var playerManager: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var searchText = ""
    @State private var selectedColorFilter: String? = nil
    @State private var showExportSheet = false
    @State private var exportText = ""
    @State private var exportFormat: ExportFormat = .markdown
    
    enum ExportFormat: String, CaseIterable {
        case plainText = "Plain Text"
        case markdown = "Markdown"
        case richText = "Rich Text"
        
        var fileExtension: String {
            switch self {
            case .plainText: return "txt"
            case .markdown: return "md"
            case .richText: return "rtf"
            }
        }
    }
    
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
                        
                        Button {
                            selectedColorFilter = "default"
                        } label: {
                            if selectedColorFilter == "default" {
                                Label("Default", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Default")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(colorScheme == .dark ? .white : .black, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "red"
                        } label: {
                            if selectedColorFilter == "red" {
                                Label("Red", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Red")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.red, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "orange"
                        } label: {
                            if selectedColorFilter == "orange" {
                                Label("Orange", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Orange")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.orange, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "yellow"
                        } label: {
                            if selectedColorFilter == "yellow" {
                                Label("Yellow", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Yellow")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.yellow, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "green"
                        } label: {
                            if selectedColorFilter == "green" {
                                Label("Green", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Green")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.green, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "blue"
                        } label: {
                            if selectedColorFilter == "blue" {
                                Label("Blue", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Blue")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.blue, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "purple"
                        } label: {
                            if selectedColorFilter == "purple" {
                                Label("Purple", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Purple")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.purple, .clear)
                                }
                            }
                        }
                        
                        Button {
                            selectedColorFilter = "pink"
                        } label: {
                            if selectedColorFilter == "pink" {
                                Label("Pink", systemImage: "checkmark")
                            } else {
                                Label {
                                    Text("Pink")
                                } icon: {
                                    Image(systemName: "bookmark.fill")
                                        .symbolRenderingMode(.palette)
                                        .foregroundStyle(.pink, .clear)
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
                ExportNotesView(exportText: exportText, exportFormat: $exportFormat)
            }
        }
    }
    
    private func generateExportText() {
        switch exportFormat {
        case .plainText:
            exportText = generatePlainText()
        case .markdown:
            exportText = generateMarkdown()
        case .richText:
            exportText = generateRichText()
        }
    }
    
    private func generatePlainText() -> String {
        var text = "Bookmark Notes\n"
        text += "================\n\n"
        
        for bookmark in filteredBookmarks {
            let colorEmoji = bookmarkEmoji(bookmark.colorName)
            text += "\(colorEmoji) [\(playerManager.formatTime(bookmark.time))] \(bookmark.label)\n"
            if !bookmark.note.isEmpty {
                text += "\(bookmark.note)\n"
            }
            text += "\n"
        }
        
        return text
    }
    
    private func generateMarkdown() -> String {
        var text = "# Bookmark Notes\n\n"
        
        for bookmark in filteredBookmarks {
            let colorEmoji = bookmarkEmoji(bookmark.colorName)
            text += "## \(colorEmoji) \(bookmark.label)\n\n"
            text += "**Time:** `\(playerManager.formatTime(bookmark.time))`  \n"
            text += "**Color:** \(bookmark.colorName.capitalized)\n\n"
            
            if !bookmark.note.isEmpty {
                text += "\(bookmark.note)\n\n"
            }
            
            text += "---\n\n"
        }
        
        return text
    }
    
    private func generateRichText() -> String {
        var rtf = "{\\rtf1\\ansi\\deff0\n"
        rtf += "{\\fonttbl{\\f0 Helvetica;}{\\f1 Courier;}}\n"
        rtf += "{\\colortbl;\\red255\\green0\\blue0;\\red255\\green165\\blue0;\\red255\\green255\\blue0;\\red0\\green255\\blue0;\\red0\\green0\\blue255;\\red128\\green0\\blue128;\\red255\\green192\\blue203;\\red0\\green0\\blue0;}\n"
        
        rtf += "\\f0\\fs28\\b Bookmark Notes\\b0\\fs24\\par\n"
        rtf += "\\par\n"
        
        for bookmark in filteredBookmarks {
            let colorIndex = rtfColorIndex(bookmark.colorName)
            let colorEmoji = bookmarkEmoji(bookmark.colorName)
            
            rtf += "\\cf\(colorIndex)\\b \\fs26 \(colorEmoji) \(escapeRTF(bookmark.label))\\b0\\fs24\\par\n"
            rtf += "\\cf8 Time: \(playerManager.formatTime(bookmark.time))\\par\n"
            
            if !bookmark.note.isEmpty {
                rtf += "\\par\n"
                rtf += "\(escapeRTF(bookmark.note))\\par\n"
            }
            
            rtf += "\\par\n"
        }
        
        rtf += "}"
        return rtf
    }
    
    private func rtfColorIndex(_ colorName: String) -> Int {
        switch colorName {
        case "red":    return 1
        case "orange": return 2
        case "yellow": return 3
        case "green":  return 4
        case "blue":   return 5
        case "purple": return 6
        case "pink":   return 7
        default:       return 8
        }
    }
    
    private func escapeRTF(_ text: String) -> String {
        text
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "{", with: "\\{")
            .replacingOccurrences(of: "}", with: "\\}")
            .replacingOccurrences(of: "\n", with: "\\par\n")
    }
    
    private func bookmarkEmoji(_ colorName: String) -> String {
        switch colorName {
        case "red":    return "🔴"
        case "orange": return "🟠"
        case "yellow": return "🟡"
        case "green":  return "🟢"
        case "blue":   return "🔵"
        case "purple": return "🟣"
        case "pink":   return "🩷"
        default:       return "⚪️"
        }
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
            TextField("Add a note...", text: $bookmark.note, axis: .vertical)
                .textFieldStyle(.plain)
                .lineLimit(3...10)
                .focused($isFocused)
                .font(.body)
                .onChange(of: bookmark.note) { oldValue, newValue in
                    onUpdate(bookmark)
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
    @Binding var exportFormat: BookmarkNotesView.ExportFormat
    @Environment(\.dismiss) var dismiss
    
    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Format picker
                Picker("Format", selection: $exportFormat) {
                    ForEach(BookmarkNotesView.ExportFormat.allCases, id: \.self) { format in
                        Text(format.rawValue).tag(format)
                    }
                }
                .pickerStyle(.segmented)
                .padding()
                
                Divider()
                
                // Preview
                ScrollView {
                    Text(exportText)
                        .font(.system(.body, design: exportFormat == .richText ? .default : .monospaced))
                        .padding()
                        .frame(maxWidth: .infinity, alignment: .leading)
                }
            }
            .navigationTitle("Export Notes")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    ShareLink(item: exportText, preview: SharePreview(
                        "Bookmark Notes",
                        image: Image(systemName: "bookmark.fill")
                    )) {
                        Image(systemName: "square.and.arrow.up")
                    }
                }
            }
        }
    }
}
