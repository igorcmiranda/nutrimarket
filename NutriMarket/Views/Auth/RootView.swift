import SwiftUI

struct RootView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var glasses: GlassesManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var trophyManager: TrophyManager
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
                    .environmentObject(feedManager)
                    .environmentObject(challengeManager)
                    .environmentObject(healthKit)
                    .environmentObject(notificationManager)
                    .environmentObject(trophyManager)
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
                    // Tudo em paralelo — não espera um terminar para começar o outro
                    async let sub: () = subscriptionManager.loadSubscription()
                    async let usage: () = usageManager.loadCounters()
                    async let trophies: () = trophyManager.loadTrophies()
                    async let challenges: () = challengeManager.loadAll()
                    _ = await (sub, usage, trophies, challenges)
                    notificationManager.startListening()
                    challengeManager.startChallengesListener()
                }
            } else {
                subscriptionManager.currentPlan = .none
                usageManager.counters = UsageCounters()
                notificationManager.stopListening()
            }
        }
    }

    var splashView: some View {
        ZStack {
            LinearGradient(
                colors: [Color(hex: "0A0A1A"), Color(hex: "0D0D2B"), Color(hex: "0A0A1A")],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 24) {
                Image("AppLogo")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 120, height: 120)
                    .clipShape(RoundedRectangle(cornerRadius: 26))
                    .shadow(color: Color(hex: "4A6FE8").opacity(0.6), radius: 20)

                Text("Vyro")
                    .font(.system(size: 42, weight: .black, design: .rounded))
                    .foregroundStyle(
                        LinearGradient(
                            colors: [Color(hex: "A78BFA"), Color(hex: "60A5FA")],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )

                ProgressView().tint(Color(hex: "60A5FA")).scaleEffect(1.2)
            }
        }
    }

    func syncProfileFromFirestore() {
        guard let user = authManager.currentUser else { return }
        profile.name = user.name
    }
}
