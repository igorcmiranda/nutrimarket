import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @State private var showProfile = false
    @State private var showSubscription = false
    @State private var selectedTab = 0

    var planColor: Color { subscriptionManager.currentPlan.color }

    var body: some View {
        Group {
            if !profile.isComplete {
                NavigationStack {
                    ProfileView()
                        .environmentObject(profile)
                        .environmentObject(authManager)
                }
            } else {
                TabView(selection: $selectedTab) {
                    NavigationStack {
                        HomeView(showSubscription: $showSubscription)
                            .environmentObject(usageManager)
                            .toolbar {
                                ToolbarItem(placement: .topBarLeading) {
                                    Label(subscriptionManager.currentPlan.displayName,
                                          systemImage: subscriptionManager.currentPlan.icon)
                                        .font(.caption).fontWeight(.medium)
                                        .padding(.horizontal, 10).padding(.vertical, 4)
                                        .background(planColor.opacity(0.15))
                                        .foregroundStyle(planColor)
                                        .clipShape(Capsule())
                                }
                                ToolbarItem(placement: .topBarTrailing) {
                                    Button {
                                        showProfile = true
                                    } label: {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundStyle(planColor)
                                    }
                                }
                            }
                    }
                    .tabItem { Label("Início", systemImage: "house.fill") }
                    .tag(0)

                    NavigationStack {
                        DietPlanView(showSubscription: $showSubscription)
                            .environmentObject(profile)
                            .environmentObject(usageManager)
                    }
                    .tabItem { Label("Dieta", systemImage: "list.bullet.clipboard.fill") }
                    .tag(1)

                    NavigationStack {
                        BodyAnalysisView(showSubscription: $showSubscription)
                            .environmentObject(profile)
                            .environmentObject(usageManager)
                    }
                    .tabItem { Label("Corpo", systemImage: "figure.arms.open") }
                    .tag(2)
                    
                    NavigationStack {
                        WaterView()
                            .environmentObject(profile)
                    }
                    .tabItem { Label("Água", systemImage: "drop.fill") }
                    .tag(3)
                }
                .toolbarBackground(planColor.opacity(0.15), for: .navigationBar)
                .toolbarBackground(.visible, for: .navigationBar)
                .sheet(isPresented: $showProfile) {
                    ProfileView()
                        .environmentObject(profile)
                        .environmentObject(authManager)
                }
                .sheet(isPresented: $showSubscription) {
                    SubscriptionView()
                        .environmentObject(subscriptionManager)
                        .environmentObject(authManager)
                }
            }
        }
    }
}
