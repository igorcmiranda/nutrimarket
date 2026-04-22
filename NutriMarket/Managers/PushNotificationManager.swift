import Foundation
import FirebaseFirestore
import FirebaseAuth

struct PushNotificationManager {

    // Envia push notification para um usuário
    static func send(
        toUserID: String,
        title: String,
        body: String,
        data: [String: String] = [:]
    ) async {
        let db = Firestore.firestore()

        // Busca o FCM token do usuário
        guard let userDoc = try? await db.collection("users").document(toUserID).getDocument(),
              let fcmToken = userDoc.data()?["fcmToken"] as? String,
              !fcmToken.isEmpty else {
            return
        }

        // Chama a Cloud Function que envia a notificação
        guard let url = URL(string: "https://us-central1-nutrimarket.cloudfunctions.net/sendPushNotification") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        var payload: [String: Any] = [
            "token": fcmToken,
            "title": title,
            "body": body
        ]
        if !data.isEmpty {
            payload["data"] = data
        }

        request.httpBody = try? JSONSerialization.data(withJSONObject: payload)
        try? await URLSession.shared.data(for: request)
    }
}
