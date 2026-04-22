import Foundation
import FirebaseFirestore
import SwiftUI
import Foundation

struct AppNotification: Identifiable, Codable {
    var id: String
    var type: NotificationType
    var fromUserID: String
    var fromUserName: String
    var fromUserAvatar: String
    var postID: String?
    var postMediaURL: String?
    var challengeID: String?
    var message: String
    var read: Bool
    var createdAt: Date

    enum NotificationType: String, Codable {
        case newPost       = "new_post"
        case newLike       = "new_like"
        case newComment    = "new_comment"
        case newFollower   = "new_follower"
        case challengeReceived = "challenge_received"
        case challengeAccepted = "challenge_accepted"
        case newMessage = "new_message"
    }

    var icon: String {
        switch type {
        case .newPost:              return "photo.fill"
        case .newLike:              return "heart.fill"
        case .newComment:           return "bubble.right.fill"
        case .newFollower:          return "person.fill.badge.plus"
        case .challengeReceived:    return "trophy.fill"
        case .challengeAccepted:    return "checkmark.seal.fill"
        case .newMessage: return "paperplane.fill"
        }
    }
    
    var iconColor: Color {
        switch type {
        case .newLike:           return .red
        case .newComment:        return .green
        case .newFollower:       return .purple
        case .newPost:           return .blue
        case .challengeReceived: return .orange
        case .challengeAccepted: return Color(hex: "FFD700")
        case .newMessage:        return .blue
        }
    }
}
