import UIKit
import Firebase
import FirebaseMessaging
import UserNotifications
import FirebaseAuth

@objc class AppDelegate: NSObject, UIApplicationDelegate {

    func application(
        _ application: UIApplication,
        didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]? = nil
    ) -> Bool {
        UNUserNotificationCenter.current().delegate = self
        Messaging.messaging().delegate = self

        UNUserNotificationCenter.current().requestAuthorization(
            options: [.alert, .badge, .sound]
        ) { granted, _ in
            guard granted else { return }
            DispatchQueue.main.async {
                UIApplication.shared.registerForRemoteNotifications()
            }
        }
        return true
    }

    // CRÍTICO — passa o token APNs para o Firebase manualmente
    func application(
        _ application: UIApplication,
        didRegisterForRemoteNotificationsWithDeviceToken deviceToken: Data
    ) {
        Messaging.messaging().apnsToken = deviceToken
        // print("✅ APNs token registrado")
    }

    func application(
        _ application: UIApplication,
        didFailToRegisterForRemoteNotificationsWithError error: Error
    ) {
        // print("❌ Falha APNs: \(error)")
    }
}

extension AppDelegate: MessagingDelegate {
    func messaging(_ messaging: Messaging, didReceiveRegistrationToken fcmToken: String?) {
        guard let token = fcmToken else { return }
        // print("✅ FCM Token: \(token)")
        Task { await saveFCMToken(token) }
    }

    func saveFCMToken(_ token: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await Firestore.firestore()
            .collection("users").document(uid)
            .updateData(["fcmToken": token])
        // print("✅ FCM Token salvo no Firestore para uid: \(uid)")
    }
}

extension AppDelegate: UNUserNotificationCenterDelegate {
    // Notificação recebida com app em foreground
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        willPresent notification: UNNotification,
        withCompletionHandler completionHandler: @escaping (UNNotificationPresentationOptions) -> Void
    ) {
        let userInfo = notification.request.content.userInfo
        
        // Posta notificação local para o ChatView atualizar
        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: NSNotification.Name("NewMessageReceived"),
                object: nil,
                userInfo: userInfo as? [String: Any]
            )
        }
        
        completionHandler([.banner, .sound, .badge])
    }

    // Notificação recebida com app em background/fechado
    func userNotificationCenter(
        _ center: UNUserNotificationCenter,
        didReceive response: UNNotificationResponse,
        withCompletionHandler completionHandler: @escaping () -> Void
    ) {
        let userInfo = response.notification.request.content.userInfo
        NotificationCenter.default.post(
            name: NSNotification.Name("NewMessageReceived"),
            object: nil,
            userInfo: userInfo
        )
        completionHandler()
    }
}
