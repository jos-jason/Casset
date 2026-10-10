import SwiftUI

struct BookmarksChaptersView: View {
    var playerManager: AudioPlayerManager
    @Environment(\.dismiss) var dismiss
    @Environment(\.colorScheme) var colorScheme
    
    @State private var editingBookmark: Bookmark?
    @State private var editedText: String = ""
    @State private var editedNote: String = ""
    @State private var showEditSheet = false
    @State private var showNotesView = false

    var body: some View {
        NavigationStack {
            List {
                Section("Bookmarks") {
                    if playerManager.bookmarks.isEmpty {
                        Text("No bookmarks yet — tap the bookmark button while playing")
                            .foregroundStyle(.secondary)
                            .font(.subheadline)
                    } else {
                        ForEach(playerManager.bookmarks) { bookmark in
                            Button {
                                playerManager.seekTo(bookmark.time)
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "bookmark.fill")
                                        .foregroundStyle(bookmarkColor(bookmark.colorName))
                                    VStack(alignment: .leading, spacing: 4) {
                                        Text(bookmark.label)
                                            .foregroundStyle(bookmarkColor(bookmark.colorName))
                                        if !bookmark.note.isEmpty {
                                            Text(bookmark.note)
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .lineLimit(2)
                                        }
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                            .contextMenu {
                                Button {
                                    editingBookmark = bookmark
                                    editedText = bookmark.label
                                    editedNote = bookmark.note
                                    showEditSheet = true
                                } label: {
                                    Label("Edit Bookmark", systemImage: "pencil")
                                }
                                
                                Button {
                                    showNotesView = true
                                } label: {
                                    Label {
                                        Text("View Notes")
                                    } icon: {
                                        QuillInkwellIcon(size: 16)
                                    }
                                }
                            }
                        }
                        .onDelete(perform: playerManager.removeBookmark)
                    }
                }

                if !playerManager.chapters.isEmpty {
                    Section("Chapters") {
                        ForEach(playerManager.chapters) { chapter in
                            Button {
                                playerManager.seekTo(chapter.startTime)
                                if !playerManager.isPlaying {
                                    playerManager.togglePlayPause()
                                }
                                dismiss()
                            } label: {
                                HStack {
                                    Image(systemName: "text.book.closed.fill")
                                        .foregroundStyle(.primary)
                                    VStack(alignment: .leading) {
                                        Text(chapter.title)
                                            .foregroundStyle(.primary)
                                        Text(playerManager.formatTime(chapter.startTime))
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                    }
                                    Spacer()
                                }
                                .contentShape(Rectangle())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
            }
            .navigationTitle("Bookmarks & Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showNotesView = true
                    } label: {
                        QuillInkwellIcon(size: 22)
                    }
                    .disabled(playerManager.bookmarks.isEmpty)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .sheet(isPresented: $showEditSheet) {
                BookmarkEditView(
                    bookmark: editingBookmark ?? Bookmark(time: 0, label: "", colorName: "default", note: ""),
                    label: $editedText,
                    note: $editedNote,
                    onSave: {
                        if let bookmark = editingBookmark {
                            playerManager.updateBookmark(bookmark, label: editedText, note: editedNote)
                        }
                        showEditSheet = false
                        editingBookmark = nil
                    },
                    onCancel: {
                        showEditSheet = false
                        editingBookmark = nil
                    },
                    onViewNotes: {
                        showEditSheet = false
                        showNotesView = true
                    }
                )
                .presentationDetents([.medium, .large])
            }
            .sheet(isPresented: $showNotesView) {
                BookmarkNotesView(playerManager: playerManager)
            }
        }
    }
    
    private struct BookmarkEditView: View {
        let bookmark: Bookmark
        @Binding var label: String
        @Binding var note: String
        let onSave: () -> Void
        let onCancel: () -> Void
        let onViewNotes: () -> Void
        
        @Environment(\.colorScheme) var colorScheme
        
        var body: some View {
            NavigationStack {
                Form {
                    Section {
                        TextField("Bookmark label", text: $label)
                    } header: {
                        Text("Label")
                    }
                    
                    Section {
                        TextField("Add a note about this bookmark...", text: $note, axis: .vertical)
                            .lineLimit(5...10)
                    } header: {
                        Text("Note")
                    }
                    
                    Section {
                        HStack {
                            Image(systemName: "clock.fill")
                                .foregroundStyle(.secondary)
                            Text("Time: \(formatTime(bookmark.time))")
                                .foregroundStyle(.secondary)
                        }
                        
                        HStack {
                            Image(systemName: "bookmark.fill")
                                .foregroundStyle(bookmarkColor(bookmark.colorName))
                            Text("Color: \(bookmark.colorName.capitalized)")
                                .foregroundStyle(.secondary)
                        }
                        
                        Button {
                            onViewNotes()
                        } label: {
                            HStack {
                                QuillInkwellIcon(size: 16)
                                Text("View All Notes")
                                    .foregroundStyle(.blue)
                                Spacer()
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.tertiary)
                            }
                        }
                    } header: {
                        Text("Bookmark Info")
                    }
                }
                .navigationTitle("Edit Bookmark")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .cancellationAction) {
                        Button("Cancel") {
                            onCancel()
                        }
                    }
                    ToolbarItem(placement: .confirmationAction) {
                        Button("Save") {
                            onSave()
                        }
                    }
                }
            }
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

