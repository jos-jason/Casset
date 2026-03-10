//
//  BookmarksChaptersView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct BookmarksChaptersView: View {
    @Environment(LibraryManager.self) private var library
    @Environment(AudioPlayerManager.self) private var player
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var selectedTab: Int = 0
    @State private var showAddBookmark = false

    private var currentBook: Book {
        library.books.first { $0.id == book.id } ?? book
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                // Timeline
                BookmarkTimelineView(book: currentBook) { time in
                    player.seek(to: time)
                }
                .padding(.vertical, 12)

                Divider()

                // Tab picker
                Picker("Section", selection: $selectedTab) {
                    Text("Bookmarks").tag(0)
                    Text("Chapters").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if selectedTab == 0 {
                    bookmarksList
                } else {
                    chaptersList
                }
            }
            .navigationTitle("Bookmarks & Chapters")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showAddBookmark = true
                    } label: {
                        Image(systemName: "bookmark.badge.plus")
                    }
                }
            }
            .sheet(isPresented: $showAddBookmark) {
                BookmarkCreationView(book: currentBook)
            }
        }
    }

    private var bookmarksList: some View {
        Group {
            if currentBook.bookmarks.isEmpty {
                ContentUnavailableView(
                    "No Bookmarks",
                    systemImage: "bookmark",
                    description: Text("Tap the bookmark button to save your position.")
                )
            } else {
                List {
                    ForEach(currentBook.bookmarks) { bookmark in
                        Button {
                            player.seek(to: bookmark.timestamp)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "bookmark.fill")
                                    .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(bookmark.name)
                                        .font(.headline)
                                    Text(formattedTime(bookmark.timestamp))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                Image(systemName: "arrow.right.circle")
                                    .foregroundStyle(.tertiary)
                            }
                        }
                        .buttonStyle(.plain)
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                library.removeBookmark(bookmark, from: currentBook)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
    }

    private var chaptersList: some View {
        Group {
            if currentBook.chapters.isEmpty {
                ContentUnavailableView(
                    "No Chapters",
                    systemImage: "list.number",
                    description: Text("This audiobook has no embedded chapter markers.")
                )
            } else {
                List {
                    ForEach(currentBook.chapters) { chapter in
                        Button {
                            player.seek(to: chapter.startTime)
                            dismiss()
                        } label: {
                            HStack {
                                Image(systemName: "play.circle")
                                    .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(chapter.title)
                                        .font(.headline)
                                    Text(formattedTime(chapter.startTime))
                                        .font(.caption.monospacedDigit())
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                                if player.currentChapter()?.id == chapter.id {
                                    Image(systemName: "speaker.wave.2.fill")
                                        .foregroundStyle(Color(red: 0.9, green: 0.5, blue: 0.1))
                                        .font(.caption)
                                }
                            }
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func formattedTime(_ time: TimeInterval) -> String {
        let t = Int(max(0, time))
        let h = t / 3600
        let m = (t % 3600) / 60
        let s = t % 60
        return h > 0 ? String(format: "%d:%02d:%02d", h, m, s) : String(format: "%d:%02d", m, s)
    }
}
