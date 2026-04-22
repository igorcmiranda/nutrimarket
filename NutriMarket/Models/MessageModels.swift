import Foundation
import FirebaseFirestore
import FirebaseAuth

struct Conversation: Identifiable, Codable {
    var id: String
    var participantIDs: [String]
    var participantNames: [String: String]
    var participantAvatars: [String: String]
    var lastMessage: String
    var lastMessageAt: Date
    var unreadCount: [String: Int]

    var otherUserID: String {
        guard let uid = participantIDs.first(where: {
            $0 != currentUID
        }) else { return "" }
        return uid
    }

    var otherUserName: String {
        participantNames[otherUserID] ?? ""
    }

    var otherUserAvatar: String {
        participantAvatars[otherUserID] ?? ""
    }

    private var currentUID: String {
        FirebaseAuth.Auth.auth().currentUser?.uid ?? ""
    }
}

struct Message: Identifiable, Codable, Equatable {
    var id: String
    var senderID: String
    var senderName: String
    var text: String
    var createdAt: Date
    var read: Bool
}
