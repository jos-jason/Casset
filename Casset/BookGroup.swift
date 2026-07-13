import Foundation

enum AutoGroupType: String, Codable {
    case none
    case series
    case author
}

struct BookGroup: Identifiable, Codable {
    var id: UUID = UUID()
    var name: String
    var bookIDs: [UUID] = []
    /// Indicates whether this group was auto-created from a shared series or author tag.
    var autoGroupType: AutoGroupType = .none

    // Backwards compatibility: decode old `isAutoSeries` into the new enum.
    enum CodingKeys: String, CodingKey {
        case id, name, bookIDs, autoGroupType, isAutoSeries
    }

    init(id: UUID = UUID(), name: String, bookIDs: [UUID] = [], autoGroupType: AutoGroupType = .none) {
        self.id = id
        self.name = name
        self.bookIDs = bookIDs
        self.autoGroupType = autoGroupType
    }

    init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        id = try c.decodeIfPresent(UUID.self, forKey: .id) ?? UUID()
        name = try c.decode(String.self, forKey: .name)
        bookIDs = try c.decodeIfPresent([UUID].self, forKey: .bookIDs) ?? []
        if let type = try? c.decode(AutoGroupType.self, forKey: .autoGroupType) {
            autoGroupType = type
        } else if let legacy = try? c.decode(Bool.self, forKey: .isAutoSeries), legacy {
            autoGroupType = .series
        } else {
            autoGroupType = .none
        }
    }

    func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(name, forKey: .name)
        try c.encode(bookIDs, forKey: .bookIDs)
        try c.encode(autoGroupType, forKey: .autoGroupType)
    }
}

