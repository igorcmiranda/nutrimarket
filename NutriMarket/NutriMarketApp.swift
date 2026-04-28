import SwiftUI
import Firebase
import FirebaseMessaging
import UserNotifications
import SDWebImage
import SDWebImageSwiftUI

@main
struct NutriMarketApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var glasses = GlassesManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var usageManager = UsageManager()
    @StateObject private var feedManager = FeedManager()
    @StateObject private var challengeManager = ChallengeManager()
    @StateObject private var healthKit = HealthKitManager()
    @StateObject private var notificationManager = NotificationManager()
    @StateObject private var trophyManager = TrophyManager()
    @StateObject private var messagesManager = MessagesManager()
    @StateObject private var languageManager = LanguageManager()
    
    @UIApplicationDelegateAdaptor(AppDelegate.self) var appDelegate
    
    init() {
        FirebaseApp.configure()
        let settings = FirestoreSettings()
        settings.cacheSettings = PersistentCacheSettings(sizeBytes: 50 * 1024 * 1024 as NSNumber)
        Firestore.firestore().settings = settings
        SDImageCache.shared.config.maxDiskSize = 500 * 1024 * 1024
        SDImageCache.shared.config.maxMemoryCost = 100 * 1024 * 1024
        SDWebImageDownloader.shared.config.maxConcurrentDownloads = 6
        SDWebImageDownloader.shared.config.downloadTimeout = 10
        UITabBar.appearance().tintColor = UIColor.systemGreen
    }
    
    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(glasses)
                .environmentObject(subscriptionManager)
                .environmentObject(usageManager)
                .environmentObject(feedManager)
                .environmentObject(challengeManager)
                .environmentObject(healthKit)
                .environmentObject(notificationManager)
                .environmentObject(trophyManager)
                .environmentObject(messagesManager)
                .environmentObject(languageManager)
                .environment(\.locale, Locale(identifier: languageManager.selectedLanguage.rawValue))
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.didBecomeActiveNotification)
                ) { _ in
                    messagesManager.setOnline()
                }
                .onReceive(NotificationCenter.default.publisher(
                    for: UIApplication.willResignActiveNotification)
                ) { _ in
                    messagesManager.setOffline()
                }
                .onOpenURL { url in
                    Task { await glasses.handleURL(url) }
                    DeepLinkRouter.handle(url: url)  // ← falta isso

                }
                .onAppear {
                    Task {
                        await subscriptionManager.loadSubscription()
                        await usageManager.loadCounters()
                    }
                }
        }
    }
}
