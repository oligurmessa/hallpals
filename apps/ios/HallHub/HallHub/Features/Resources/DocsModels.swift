import Foundation
import FirebaseFirestore

struct DocMeta: Codable, Identifiable, Hashable {
    @DocumentID var id: String?
    let title: String
    let slug: String
    let category: String
    let isPublished: Bool?  // Optional to handle docs without this field
    let updatedAt: Date?

    enum CodingKeys: String, CodingKey {
        case id
        case title
        case slug
        case category
        case isPublished
        case updatedAt
    }

    /// Whether this doc is published (defaults to true if not set)
    var published: Bool {
        isPublished ?? true
    }

    // Hashable conformance
    func hash(into hasher: inout Hasher) {
        hasher.combine(id)
        hasher.combine(slug)
    }

    static func == (lhs: DocMeta, rhs: DocMeta) -> Bool {
        lhs.id == rhs.id && lhs.slug == rhs.slug
    }
}

/// Source reference for a doc entry
struct DocSource: Codable, Equatable {
    let sourceDocId: String?
    let path: String?
    let location: String?

    enum CodingKeys: String, CodingKey {
        case sourceDocId = "source_doc_id"
        case path
        case location
    }
}

struct DocEntry: Codable, Identifiable, Equatable {
    @DocumentID var id: String?
    let order: Int?  // Optional to handle missing fields
    let topic: String?
    let section: String?
    let text: String
    let sources: [DocSource]?  // Array of source objects, not strings
    let updatedAt: Date?
    let updatedBy: String?

    enum CodingKeys: String, CodingKey {
        case id
        case order
        case topic
        case section
        case text
        case sources
        case updatedAt
        case updatedBy
    }

    /// Order value for sorting (defaults to 0 if not set)
    var sortOrder: Int {
        order ?? 0
    }
}
