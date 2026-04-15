import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var glasses: GlassesManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @StateObject private var profile = UserProfile()

    var body: some View {
        Group {
            if authManager.isLoading {
                splashView
            } else if authManager.isLoggedIn {
                ContentView()
                    .environmentObject(profile)
                    .environmentObject(glasses)
                    .environmentObject(subscriptionManager)
                    .environmentObject(usageManager)
                    .onAppear {
                        syncProfileFromFirestore()
                    }
            } else {
                LoginView()
            }
        }
        .onChange(of: authManager.currentUser?.uid) { _, newUID in
            if newUID != nil {
                Task {
                    await subscriptionManager.loadSubscription()
                    await usageManager.loadCounters()
                }
            } else {
                subscriptionManager.currentPlan = .none
                usageManager.counters = UsageCounters()
            }
        }
    }

    var splashView: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 80, height: 80)
                Image(systemName: "fork.knife")
                    .font(.system(size: 36))
                    .foregroundStyle(.white)
            }
            Text("Nutri-Market")
                .font(.title).fontWeight(.bold)
            ProgressView().tint(.green)
        }
    }

    func syncProfileFromFirestore() {
        guard let user = authManager.currentUser else { return }
        profile.name = user.name
    }
}
