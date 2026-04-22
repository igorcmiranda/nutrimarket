import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class MessagesManager: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var onlineUsers: Set<String> = []

    private let db = Firestore.firestore()
    private var conversationsListener: ListenerRegistration?
    private var messagesListener: ListenerRegistration?
    private var presenceListener: ListenerRegistration?
    private var presenceRef: DocumentReference?

    func conversationID(uid1: String, uid2: String) -> String {
        [uid1, uid2].sorted().joined(separator: "_")
    }
    
    func setOnline() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        presenceRef = db.collection("presence").document(uid)
        Task {
            try? await presenceRef?.setData([
                "online": true,
                "lastSeen": Timestamp(date: Date())
            ])
        }
    }

    func setOffline() {
        Task {
            try? await presenceRef?.updateData([
                "online": false,
                "lastSeen": Timestamp(date: Date())
            ])
        }
    }

    func observePresence(userID: String) {
        presenceListener?.remove()
        presenceListener = db.collection("presence").document(userID)
            .addSnapshotListener { [weak self] snap, _ in
                guard let self, let data = snap?.data() else { return }
                Task { @MainActor in
                    let isOnline = data["online"] as? Bool ?? false
                    if isOnline {
                        self.onlineUsers.insert(userID)
                    } else {
                        self.onlineUsers.remove(userID)
                    }
                }
            }
    }

    func stopObservingPresence() {
        presenceListener?.remove()
    }

    func startListeningConversations() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        conversationsListener?.remove()

        conversationsListener = db.collection("conversations")
            .whereField("participantIDs", arrayContains: uid)
            .order(by: "lastMessageAt", descending: true)
            .addSnapshotListener { [weak self] snapshot, _ in
                guard let self, let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self.conversations = docs.compactMap { doc -> Conversation? in
                        let data = doc.data()
                        guard
                            let participantIDs = data["participantIDs"] as? [String],
                            let lastMessage = data["lastMessage"] as? String,
                            let ts = data["lastMessageAt"] as? Timestamp
                        else { return nil }

                        return Conversation(
                            id: doc.documentID,
                            participantIDs: participantIDs,
                            participantNames: data["participantNames"] as? [String: String] ?? [:],
                            participantAvatars: data["participantAvatars"] as? [String: String] ?? [:],
                            lastMessage: lastMessage,
                            lastMessageAt: ts.dateValue(),
                            unreadCount: data["unreadCount"] as? [String: Int] ?? [:]
                        )
                    }
                }
            }
    }

    func startListeningMessages(conversationID: String) {
            messagesListener?.remove()
            messages = []

        messagesListener = db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let docs = snapshot?.documents else { return }

                let parsed = docs.compactMap { doc -> Message? in
                    let data = doc.data()
                    guard let senderID = data["senderID"] as? String,
                          let text = data["text"] as? String,
                          let ts = data["createdAt"] as? Timestamp else { return nil }
                    return Message(
                        id: doc.documentID,
                        senderID: senderID,
                        senderName: data["senderName"] as? String ?? "",
                        text: text,
                        createdAt: ts.dateValue(),
                        read: data["read"] as? Bool ?? false
                    )
                }

                DispatchQueue.main.async {
                    self.messages = parsed
                }
            }
        }



    func parseDocs(_ docs: [QueryDocumentSnapshot]) -> [Message] {
        docs.compactMap { doc -> Message? in
            let data = doc.data()
            guard let senderID = data["senderID"] as? String,
                  let text = data["text"] as? String,
                  let ts = data["createdAt"] as? Timestamp else { return nil }
            return Message(
                id: doc.documentID,
                senderID: senderID,
                senderName: data["senderName"] as? String ?? "",
                text: text,
                createdAt: ts.dateValue(),
                read: data["read"] as? Bool ?? false
            )
        }
    }
    
    

    func sendMessage(
        toUserID: String,
        toUserName: String,
        toUserAvatar: String,
        text: String
    ) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let userDoc = try? await db.collection("users").document(uid).getDocument(),
              let userData = userDoc.data() else { return }

        let myName = userData["name"] as? String ?? ""
        let myAvatar = userData["avatarURL"] as? String ?? ""
        let convID = conversationID(uid1: uid, uid2: toUserID)
        let messageID = UUID().uuidString
        let now = Timestamp(date: Date())

        let messageData: [String: Any] = [
            "senderID": uid,
            "senderName": myName,
            "text": text,
            "createdAt": now,
            "read": false
        ]

        let convData: [String: Any] = [
            "participantIDs": [uid, toUserID],
            "participantNames": [uid: myName, toUserID: toUserName],
            "participantAvatars": [uid: myAvatar, toUserID: toUserAvatar],
            "lastMessage": text,
            "lastMessageAt": now,
            "unreadCount": [toUserID: FieldValue.increment(Int64(1))]
        ]

        do {
            try await db.collection("conversations")
                .document(convID)
                .collection("messages")
                .document(messageID)
                .setData(messageData)

            try await db.collection("conversations")
                .document(convID)
                .setData(convData, merge: true)

            // Envia notificação push
            await NotificationManager.send(
                toUserID: toUserID,
                type: .newMessage,
                fromUserID: uid,
                fromUserName: myName,
                fromUserAvatar: myAvatar,
                message: "\(myName): \(text.prefix(50))",
                extraData: [
                    "conversationID": convID,
                    "messageText": text,
                    "messageSenderID": uid,
                    "messageSenderName": myName
                ]
            )
        } catch {
            // print("Erro ao enviar mensagem: \(error)")
        }
    }

    func markMessagesAsRead(conversationID: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        // Zera contador da conversa
        try? await db.collection("conversations")
            .document(conversationID)
            .updateData(["unreadCount.\(uid)": 0])

        // Busca mensagens não lidas enviadas pelo outro
        let snap = try? await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .getDocuments()

        guard let docs = snap?.documents else { return }

        let batch = db.batch()
        var updated = false

        for doc in docs {
            let data = doc.data()
            let senderID = data["senderID"] as? String ?? ""
            let read = data["read"] as? Bool ?? false
            if senderID != uid && !read {
                batch.updateData(["read": true], forDocument: doc.reference)
                updated = true
            }
        }

        if updated {
            try? await batch.commit()
        }
    }

    func stopListening() {
        conversationsListener?.remove()
        messagesListener?.remove()
    }

    func findOrCreateConversation(withUserID: String) async -> String? {
        guard let uid = Auth.auth().currentUser?.uid else { return nil }
        return conversationID(uid1: uid, uid2: withUserID)
    }

    func totalUnread() -> Int {
        guard let uid = Auth.auth().currentUser?.uid else { return 0 }
        return conversations.reduce(0) { $0 + ($1.unreadCount[uid] ?? 0) }
    }
    
    func refreshMessages(conversationID: String) async {
        let snap = try? await db.collection("conversations")
            .document(conversationID)
            .collection("messages")
            .order(by: "createdAt", descending: false)
            .getDocuments()

        guard let docs = snap?.documents else { return }

        let refreshed = docs.compactMap { doc -> Message? in
            let data = doc.data()
            guard let senderID = data["senderID"] as? String,
                  let text = data["text"] as? String,
                  let ts = data["createdAt"] as? Timestamp else { return nil }
            return Message(
                id: doc.documentID,
                senderID: senderID,
                senderName: data["senderName"] as? String ?? "",
                text: text,
                createdAt: ts.dateValue(),
                read: data["read"] as? Bool ?? false
            )
        }

        DispatchQueue.main.async {
            // Substitui mensagens temporárias pelas reais
            self.messages = refreshed
        }
    }
}
