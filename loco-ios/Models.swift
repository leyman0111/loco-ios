//
//  Models.swift
//  loco-ios
//
//  Data models matching the backend API
//

import Foundation

// MARK: - Post Category

enum PostCategory: String, Codable, CaseIterable {
    case beauty = "BEAUTY"
    case interest = "INTEREST"
    case fact = "FACT"
    case together = "TOGETHER"
    case help = "HELP"
    
    var displayName: String {
        switch self {
        case .beauty: return "Beauty"
        case .interest: return "Interest"
        case .fact: return "Fact"
        case .together: return "Together"
        case .help: return "Help"
        }
    }
    
    var emoji: String {
        switch self {
        case .beauty: return "✏️"
        case .interest: return "💡"
        case .fact: return "📖"
        case .together: return "👥"
        case .help: return "✋"
        }
    }
    
    var color: String {
        switch self {
        case .beauty: return "FFB5C2"
        case .interest: return "F7D08A"
        case .fact: return "B8D4FF"
        case .together: return "B5E8C8"
        case .help: return "FF8A80"
        }
    }
}

// MARK: - Reaction Type

enum ReactionType: String, Codable, CaseIterable {
    case heart = "HEART"
    case cool = "COOL"
    case fire = "FIRE"
    case sad = "SAD"
    case cry = "CRY"
    
    var emoji: String {
        switch self {
        case .heart: return "❤️"
        case .cool: return "👍"
        case .fire: return "🔥"
        case .sad: return "😢"
        case .cry: return "😭"
        }
    }
}

// MARK: - Author

struct Author: Codable {
    let id: Int64?
    let username: String?
    let avatar: String?
}

// MARK: - Scope (request body for POST /posts/scope)

struct Scope: Codable {
    let latitude: Float
    let longitude: Float
    let distance: Int
    let categories: [String]?
}

// MARK: - PostMark (map marker)

struct PostMark: Codable, Identifiable {
    let id: Int64?
    let latitude: Float?
    let longitude: Float?
}

// MARK: - ReactionDto

struct ReactionDto: Codable, Identifiable {
    let id: Int64?
    let postId: Int64?
    let commentId: Int64?
    let author: Author?
    let type: ReactionType?
}

// MARK: - PostDto (create/publish post)

struct PostDto: Codable {
    let id: Int64?
    let author: Author?
    let created: String?
    let text: String?
    let category: String?
    let contents: [Int64]?
    let latitude: Float?
    let longitude: Float?
}

// MARK: - PostPreview (bottom sheet)

struct PostPreview: Codable {
    let created: String?
    let author: Author?
    let text: String?
    let category: PostCategory?
    let contents: [Int64]?
    let reactions: [ReactionDto]?
}
