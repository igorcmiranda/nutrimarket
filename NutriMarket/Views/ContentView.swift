import SwiftUI

struct ContentView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var healthKit: HealthKitManager
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var trophyManager: TrophyManager

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

                    // 1. Feed
                    NavigationStack {
                        FeedView(showSubscription: $showSubscription)
                            .environmentObject(feedManager)
                            .environmentObject(subscriptionManager)
                            .environmentObject(authManager)
                    }
                    .tabItem { Label("Feed", systemImage: "rectangle.stack.fill") }
                    .tag(0)

                    // 2. Perfil
                    NavigationStack {
                        HomeView(showSubscription: $showSubscription)
                            .environmentObject(usageManager)
                            .environmentObject(feedManager)
                            .environmentObject(subscriptionManager)
                            .environmentObject(authManager)
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
                                    Button { showProfile = true } label: {
                                        Image(systemName: "person.circle.fill")
                                            .foregroundStyle(planColor)
                                    }
                                }
                            }
                    }
                    .tabItem { Label("Perfil", systemImage: "person.fill") }
                    .tag(1)

                    // 3. Desafio
                    // 3. Desafio
                    NavigationStack {
                        if subscriptionManager.currentPlan == .none {
                            // Tela de bloqueio
                            VStack(spacing: 20) {
                                Image(systemName: "trophy.fill")
                                    .font(.system(size: 56))
                                    .foregroundStyle(Color(hex: "FFD700"))
                                Text("Recurso Premium")
                                    .font(.title2).fontWeight(.bold)
                                Text("Para participar de desafios, você precisa de pelo menos o plano Starter.")
                                    .font(.subheadline).foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .padding(.horizontal)
                                Button {
                                    showSubscription = true
                                } label: {
                                    Label("Ver planos", systemImage: "star.fill")
                                        .fontWeight(.medium)
                                        .frame(maxWidth: .infinity)
                                        .padding()
                                        .background(LinearGradient(
                                            colors: [Color(hex: "FFD700"), Color(hex: "FFA500")],
                                            startPoint: .leading, endPoint: .trailing
                                        ))
                                        .foregroundStyle(.white)
                                        .clipShape(RoundedRectangle(cornerRadius: 16))
                                        .padding(.horizontal)
                                }
                                .buttonStyle(.plain)
                            }
                            .navigationTitle("Desafio")
                        } else {
                            ChallengeView(showSubscription: $showSubscription)
                                .environmentObject(challengeManager)
                                .environmentObject(healthKit)
                                .environmentObject(authManager)
                                .environmentObject(feedManager)
                                .environmentObject(profile)
                                .environmentObject(subscriptionManager)
                                .environmentObject(trophyManager)
                        }
                    }
                    .tabItem { Label("Desafio", systemImage: "trophy.fill") }
                    .tag(2)

                    // 4. Busca
                    NavigationStack {
                        SearchView()
                            .environmentObject(feedManager)
                            .environmentObject(authManager)
                    }
                    .tabItem { Label("Buscar", systemImage: "magnifyingglass") }
                    .tag(4)

                    // 5. Notificações (muda de tag 3 para 4)
                    NavigationStack {
                        NotificationsView(selectedTab: $selectedTab)
                            .environmentObject(notificationManager)
                            .environmentObject(challengeManager)
                            .environmentObject(feedManager)
                            .environmentObject(authManager)
                            .environmentObject(profile)
                            .environmentObject(subscriptionManager)
                            .environmentObject(trophyManager)
                    }
                    .tabItem { Label("Avisos", systemImage: "bell.fill") }
                    .badge(notificationManager.unreadCount > 0 ? notificationManager.unreadCount : 0)
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
