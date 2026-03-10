//
//  Book.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import Foundation

struct Bookmark: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var timestamp: TimeInterval
    var name: String
    var createdAt: Date = Date()
}

struct Chapter: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var title: String
    var startTime: TimeInterval
    var endTime: TimeInterval
}

struct Book: Codable, Identifiable {
    var id: UUID = UUID()
    var title: String
    var author: String
    var filename: String
    var coverImageData: Data?
    var duration: TimeInterval
    var currentPosition: TimeInterval = 0
    var playbackRate: Float = 1.0
    var chapters: [Chapter] = []
    var bookmarks: [Bookmark] = []
    var dateAdded: Date = Date()

    var fileURL: URL {
        let booksDir = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
            .appendingPathComponent("Books")
        return booksDir.appendingPathComponent(filename)
    }

    var progress: Double {
        guard duration > 0 else { return 0 }
        return currentPosition / duration
    }

    var currentChapter: Chapter? {
        chapters.last { $0.startTime <= currentPosition }
    }

    func formattedTime(_ time: TimeInterval) -> String {
        let totalSeconds = Int(max(0, time))
        let hours = totalSeconds / 3600
        let minutes = (totalSeconds % 3600) / 60
        let seconds = totalSeconds % 60
        if hours > 0 {
            return String(format: "%d:%02d:%02d", hours, minutes, seconds)
        } else {
            return String(format: "%d:%02d", minutes, seconds)
        }
    }
}
