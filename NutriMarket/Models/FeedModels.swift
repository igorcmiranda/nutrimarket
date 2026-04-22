import Foundation
import FirebaseFirestore
import CoreLocation

struct Post: Identifiable, Codable, Equatable {
    var id: String
    var userID: String
    var userName: String
    var username: String  // novo
    var userAvatarURL: String
    var isVerified: Bool = false  // adicione esta linha
    var mediaURL: String
    var mediaURLs: [String] = []  // novo: array de URLs para múltiplas mídias
    var mediaType: MediaType
    var mediaTypes: [MediaType] = []  // novo: array de tipos de mídia
    var caption: String
    var city: String
    var region: String
    var latitude: Double
    var longitude: Double
    var likesCount: Int
    var commentsCount: Int
    var createdAt: Date
    var isLiked: Bool = false
    var distanceKm: Double? = nil
    var isPinned: Bool = false
    

    enum MediaType: String, Codable {
        case photo, video
    }

    enum CodingKeys: String, CodingKey {
            case id, userID, userName, username, userAvatarURL, isVerified, mediaURL, mediaURLs, mediaType, mediaTypes
            case caption, city, region, latitude, longitude
            case likesCount, commentsCount, createdAt
    }

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id &&
        lhs.likesCount == rhs.likesCount &&
        lhs.commentsCount == rhs.commentsCount &&
        lhs.isLiked == rhs.isLiked &&
        lhs.isPinned == rhs.isPinned
    }
    
    // Helper para verificar se há múltiplas mídias
    var hasMultipleMedia: Bool {
        !mediaURLs.isEmpty
    }
    
    // Retorna a contagem total de mídias
    var mediaCount: Int {
        if mediaURLs.isEmpty {
            return mediaURL.isEmpty ? 0 : 1
        }
        return mediaURLs.count
    }
}

struct Comment: Identifiable, Codable {
    var id: String
    var userID: String
    var userName: String
    var userAvatarURL: String
    var text: String
    var createdAt: Date
}

struct Follow: Codable {
    var targetID: String
    var createdAt: Date
}

