//
//  GroupDetailView.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import SwiftUI

struct GroupDetailView: View {
    @Environment(LibraryManager.self) private var library
    @Environment(AudioPlayerManager.self) private var player

    let group: BookGroup

    @State private var navigateToPlayer = false
    @State private var editMode: EditMode = .inactive

    var books: [Book] { library.books(in: group) }

    var body: some View {
        List {
            if books.isEmpty {
                ContentUnavailableView(
                    "No Books",
                    systemImage: "cassette",
                    description: Text("Long-press books in the Library to add them to this group.")
                )
                .listRowBackground(Color.clear)
            } else {
                ForEach(books) { book in
                    BookRowView(book: book) {
                        player.load(book: book, library: library)
                        player.play()
                        navigateToPlayer = true
                    }
                    .swipeActions(edge: .trailing) {
                        Button(role: .destructive) {
                            library.removeBook(book, from: group)
                        } label: {
                            Label("Remove", systemImage: "folder.badge.minus")
                        }
                    }
                }
            }
        }
        .navigationTitle(group.name)
        .navigationBarTitleDisplayMode(.large)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                EditButton()
            }
        }
        .environment(\.editMode, $editMode)
        .navigationDestination(isPresented: $navigateToPlayer) {
            PlayerView()
        }
    }
}

#Preview {
    NavigationStack {
        GroupDetailView(group: BookGroup(name: "Sci-Fi"))
            .environment(LibraryManager())
            .environment(AudioPlayerManager())
    }
}
