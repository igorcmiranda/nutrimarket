import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class NotificationManager: ObservableObject {
    @Published var notifications: [AppNotification] = []
    @Published var unreadCount = 0
    @Published var isLoading = false

    private let db = Firestore.firestore()
    private var listener: ListenerRegistration?

    deinit { listener?.remove() }

    func startListening() {
        guard let uid = Auth.auth().currentUser?.uid else {
            // print("❌ NotificationManager: usuário não autenticado")
            return
        }

        // print("👂 Iniciando listener para uid: \(uid)")
        isLoading = true
        listener?.remove()

        listener = db.collection("notifications")
            .document(uid)
            .collection("items")
            .order(by: "createdAt", descending: true)
            .limit(to: 50)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self else { return }

                if let error {
                    // print("❌ Erro listener: \(error)")
                    Task { @MainActor in self.isLoading = false }
                    return
                }

                guard let docs = snapshot?.documents else {
                    // print("⚠️ Snapshot nil ou vazio")
                    Task { @MainActor in self.isLoading = false }
                    return
                }

                // print("📬 Documentos recebidos: \(docs.count)")
                for doc in docs {
                    // print("   📄 \(doc.documentID): \(doc.data())")
                }

                Task { @MainActor in
                    let parsed = docs.compactMap { doc -> AppNotification? in
                        let data = doc.data()

                        guard let typeStr = data["type"] as? String else {
                            // print("⚠️ Sem campo 'type' em \(doc.documentID)")
                            return nil
                        }
                        guard let notifType = AppNotification.NotificationType(rawValue: typeStr) else {
                            // print("⚠️ Tipo inválido '\(typeStr)' em \(doc.documentID)")
                            return nil
                        }

                        let fromUserID = data["fromUserID"] as? String ?? ""
                        let fromUserName = data["fromUserName"] as? String ?? ""
                        let fromUserAvatar = data["fromUserAvatar"] as? String ?? ""
                        let message = data["message"] as? String ?? ""
                        let read = data["read"] as? Bool ?? false
                        let createdAt = (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()

                        return AppNotification(
                            id: doc.documentID,
                            type: notifType,
                            fromUserID: fromUserID,
                            fromUserName: fromUserName,
                            fromUserAvatar: fromUserAvatar,
                            postID: data["postID"] as? String,
                            postMediaURL: data["postMediaURL"] as? String,
                            challengeID: data["challengeID"] as? String,
                            message: message,
                            read: read,
                            createdAt: createdAt
                        )
                    }

                    // print("✅ Notificações parseadas: \(parsed.count)")
                    self.notifications = parsed
                    self.unreadCount = parsed.filter { !$0.read }.count
                    self.isLoading = false
                }
            }
    }

    func stopListening() {
        listener?.remove()
        listener = nil
        notifications = []
        unreadCount = 0
    }

    func markAllAsRead() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let batch = db.batch()
        for notif in notifications where !notif.read {
            let ref = db.collection("notifications")
                .document(uid).collection("items").document(notif.id)
            batch.updateData(["read": true], forDocument: ref)
        }
        try? await batch.commit()
        notifications = notifications.map { var n = $0; n.read = true; return n }
        unreadCount = 0
    }

    func markAsRead(_ notificationID: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("notifications")
            .document(uid).collection("items").document(notificationID)
            .updateData(["read": true])
        if let index = notifications.firstIndex(where: { $0.id == notificationID }) {
            notifications[index].read = true
        }
        unreadCount = max(0, unreadCount - 1)
    }

    static func send(
        toUserID: String,
        type: AppNotification.NotificationType,
        fromUserID: String,
        fromUserName: String,
        fromUserAvatar: String,
        postID: String? = nil,
        postMediaURL: String? = nil,
        challengeID: String? = nil,
        message: String,
        extraData: [String: String] = [:]
    ) async {
        guard !toUserID.isEmpty, toUserID != fromUserID else { return }

        let db = Firestore.firestore()
        var data: [String: Any] = [
            "type": type.rawValue,
            "fromUserID": fromUserID,
            "fromUserName": fromUserName,
            "fromUserAvatar": fromUserAvatar,
            "message": message,
            "read": false,
            "createdAt": Timestamp(date: Date())
        ]

        if let postID { data["postID"] = postID }
        if let postMediaURL { data["postMediaURL"] = postMediaURL }
        if let challengeID { data["challengeID"] = challengeID }
        
        // Adiciona extraData
        for (key, value) in extraData { data[key] = value }

        do {
            try await db.collection("notifications")
                .document(toUserID)
                .collection("items")
                .document(UUID().uuidString)
                .setData(data)
        } catch {
            // print("❌ Erro ao enviar notificação: \(error)")
        }
    }
}
