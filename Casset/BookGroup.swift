//
//  BookGroup.swift
//  Casset
//
//  Created by JJ vollum on 3/8/26.
//

import Foundation

struct BookGroup: Codable, Identifiable {
    var id: UUID = UUID()
    var name: String
    var bookIDs: [UUID] = []
    var dateCreated: Date = Date()
}
