//
//  GroupsView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI
import UniformTypeIdentifiers

struct GroupsView: View {
    @Environment(LibraryManager.self) private var library
    @Environment(AudioPlayerManager.self) private var player

    @State private var showFileImporter = false
    @State private var showNewGroupAlert = false
    @State private var newGroupName = ""
    @State private var importError: String?
    @State private var showImportError = false
    @State private var navigateToPlayer = false

    var body: some View {
        NavigationStack {
            List {
                // Groups
                ForEach(library.groups) { group in
                    Section(group.name) {
                        let booksInGroup = library.books(in: group)
                        if booksInGroup.isEmpty {
                            Text("No books in this group")
                                .foregroundStyle(.secondary)
                                .font(.subheadline)
                        } else {
                            ForEach(booksInGroup) { book in
                                BookRowView(book: book) {
                                    player.load(book: book, library: library)
                                    player.play()
                                    navigateToPlayer = true
                                }
                                .contextMenu {
                                    Button(role: .destructive) {
                                        library.removeBook(book, from: group)
                                    } label: {
                                        Label("Remove from Group", systemImage: "folder.badge.minus")
                                    }
                                    Button(role: .destructive) {
                                        library.removeBook(book)
                                    } label: {
                                        Label("Delete Book", systemImage: "trash")
                                    }
                                }
                            }
                        }
                    }
                }

                // Ungrouped books
                let ungrouped = library.ungroupedBooks()
                if !ungrouped.isEmpty {
                    Section(library.groups.isEmpty ? "All Books" : "Ungrouped") {
                        ForEach(ungrouped) { book in
                            BookRowView(book: book) {
                                player.load(book: book, library: library)
                                player.play()
                                navigateToPlayer = true
                            }
                            .contextMenu {
                                ForEach(library.groups) { group in
                                    Button {
                                        library.addBook(book, to: group)
                                    } label: {
                                        Label("Add to \(group.name)", systemImage: "folder.badge.plus")
                                    }
                                }
                                Button(role: .destructive) {
                                    library.removeBook(book)
                                } label: {
                                    Label("Delete Book", systemImage: "trash")
                                }
                            }
                        }
                    }
                }

                if library.books.isEmpty {
                    ContentUnavailableView(
                        "No Books Yet",
                        systemImage: "cassette",
                        description: Text("Tap + to import an audiobook file.")
                    )
                    .listRowBackground(Color.clear)
                }
            }
            .navigationTitle("Library")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button {
                        showNewGroupAlert = true
                    } label: {
                        Image(systemName: "folder.badge.plus")
                    }
                    Button {
                        showFileImporter = true
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .fileImporter(
                isPresented: $showFileImporter,
                allowedContentTypes: [.audio, UTType.mpeg4Audio, .mp3, .aiff],
                allowsMultipleSelection: false
            ) { result in
                switch result {
                case .success(let urls):
                    guard let url = urls.first else { return }
                    Task {
                        await library.importBook(from: url)
                        if let err = library.importError {
                            importError = err
                            showImportError = true
                        }
                    }
                case .failure(let error):
                    importError = error.localizedDescription
                    showImportError = true
                }
            }
            .alert("New Group", isPresented: $showNewGroupAlert) {
                TextField("Group name", text: $newGroupName)
                Button("Create") {
                    if !newGroupName.trimmingCharacters(in: .whitespaces).isEmpty {
                        library.addGroup(name: newGroupName)
                        newGroupName = ""
                    }
                }
                Button("Cancel", role: .cancel) { newGroupName = "" }
            } message: {
                Text("Enter a name for the new group.")
            }
            .alert("Import Failed", isPresented: $showImportError) {
                Button("OK", role: .cancel) {}
            } message: {
                Text(importError ?? "Unknown error")
            }
            .overlay {
                if library.isImporting {
                    ProgressView("Importing…")
                        .padding(24)
                        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 12))
                }
            }
            .navigationDestination(isPresented: $navigateToPlayer) {
                PlayerView()
            }
        }
    }
}

// MARK: - Book Row

struct BookRowView: View {
    let book: Book
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                coverThumbnail
                VStack(alignment: .leading, spacing: 4) {
                    Text(book.title)
                        .font(.headline)
                        .lineLimit(1)
                    Text(book.author)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                    ProgressView(value: book.progress)
                        .tint(Color(red: 0.9, green: 0.5, blue: 0.1))
                    Text("\(book.formattedTime(book.currentPosition)) / \(book.formattedTime(book.duration))")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var coverThumbnail: some View {
        Group {
            if let data = book.coverImageData, let image = UIImage(data: data) {
                Image(uiImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
            } else {
                ZStack {
                    Color(red: 0.2, green: 0.15, blue: 0.1)
                    Image(systemName: "cassette")
                        .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                }
            }
        }
        .frame(width: 56, height: 56)
        .clipShape(RoundedRectangle(cornerRadius: 8))
    }
}

#Preview {
    GroupsView()
        .environment(LibraryManager())
        .environment(AudioPlayerManager())
}
