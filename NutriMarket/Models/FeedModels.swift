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
    var mediaType: MediaType
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

    enum MediaType: String, Codable {
        case photo, video
    }

    enum CodingKeys: String, CodingKey {
            case id, userID, userName, username, userAvatarURL, isVerified, mediaURL, mediaType
            case caption, city, region, latitude, longitude
            case likesCount, commentsCount, createdAt
    }

    static func == (lhs: Post, rhs: Post) -> Bool {
        lhs.id == rhs.id &&
        lhs.likesCount == rhs.likesCount &&
        lhs.commentsCount == rhs.commentsCount &&
        lhs.isLiked == rhs.isLiked
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
