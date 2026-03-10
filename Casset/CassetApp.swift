//
//  CassetApp.swift
//  Casset
//
//  Created by JJ vollum on 3/7/26.
//

import SwiftUI

@main
struct CassetApp: App {
    @State private var library = LibraryManager()
    @State private var player = AudioPlayerManager()

    var body: some Scene {
        WindowGroup {
            ContentView()
                .environment(library)
                .environment(player)
                .onReceive(
                    NotificationCenter.default.publisher(
                        for: UIApplication.didEnterBackgroundNotification
                    )
                ) { _ in
                    player.savePosition(to: library)
                }
        }
    }
}
