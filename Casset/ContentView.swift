//
//  ContentView.swift
//  Casset
//
//  Created by JJ vollum on 3/7/26.
//

import SwiftUI

struct ContentView: View {
    @Environment(LibraryManager.self) private var library
    @Environment(AudioPlayerManager.self) private var player
    @State private var selectedTab: Int = 0

    var body: some View {
        TabView(selection: $selectedTab) {
            Tab("Library", systemImage: "books.vertical.fill", value: 0) {
                GroupsView()
            }
            Tab("Now Playing", systemImage: "cassette.fill", value: 1) {
                if player.currentBook != nil {
                    PlayerView()
                } else {
                    NothingPlayingView()
                }
            }
            Tab("Settings", systemImage: "gearshape.fill", value: 2) {
                SettingsView()
            }
        }
        .tint(Color(red: 0.9, green: 0.5, blue: 0.1))
    }
}

private struct NothingPlayingView: View {
    var body: some View {
        VStack(spacing: 16) {
            Image(systemName: "cassette")
                .font(.system(size: 64))
                .foregroundStyle(.secondary)
            Text("No book selected")
                .font(.title2)
                .foregroundStyle(.secondary)
            Text("Pick a book from your Library to start listening.")
                .font(.subheadline)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }
}

#Preview {
    ContentView()
        .environment(LibraryManager())
        .environment(AudioPlayerManager())
}
