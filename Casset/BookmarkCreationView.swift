//
//  BookmarkCreationView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct BookmarkCreationView: View {
    @Environment(LibraryManager.self) private var library
    @Environment(AudioPlayerManager.self) private var player
    @Environment(\.dismiss) private var dismiss

    let book: Book

    @State private var bookmarkName: String = ""

    private var timestamp: TimeInterval { player.currentTime }

    var body: some View {
        NavigationStack {
            Form {
                Section("Position") {
                    HStack {
                        Image(systemName: "clock")
                            .foregroundStyle(.secondary)
                        Text(formattedTime(timestamp))
                            .font(.body.monospacedDigit())
                    }
                }

                Section("Name") {
                    TextField("Bookmark name", text: $bookmarkName)
                }
            }
            .navigationTitle("Add Bookmark")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let name = bookmarkName.trimmingCharacters(in: .whitespaces)
                        library.addBookmark(
                            name: name.isEmpty ? "Bookmark at \(formattedTime(timestamp))" : name,
                            to: book,
                            at: timestamp
                        )
                        dismiss()
                    }
                }
            }
            .onAppear {
                bookmarkName = "Bookmark at \(formattedTime(timestamp))"
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
