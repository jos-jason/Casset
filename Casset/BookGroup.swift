import Foundation

struct BookGroup: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var bookIDs: [UUID] = []
}

