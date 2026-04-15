import SwiftUI
import Firebase

@main
struct NutriMarketApp: App {
    @StateObject private var authManager = AuthManager()
    @StateObject private var glasses = GlassesManager()
    @StateObject private var subscriptionManager = SubscriptionManager()
    @StateObject private var usageManager = UsageManager()

    init() {
        FirebaseApp.configure()
    }

    var body: some Scene {
        WindowGroup {
            RootView()
                .environmentObject(authManager)
                .environmentObject(glasses)
                .environmentObject(subscriptionManager)
                .environmentObject(usageManager)
                .onOpenURL { url in
                    Task {
                        await glasses.handleURL(url)
                    }
                }
                .onAppear {
                    glasses.setup()
                    Task {
                        await subscriptionManager.loadSubscription()
                        await usageManager.loadCounters()
                    }
                }
        }
    }
}
