import SwiftUI
import CoreLocation

// MARK: - Scroll Offset Preference Key

struct ScrollOffsetPreferenceKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = nextValue()
    }
}

// MARK: - FeedView

struct FeedView: View {
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var locationManager = FeedLocationManager()
    @EnvironmentObject var feedViewModel: FeedViewModel
    @State private var showNewPost = false
    @State private var showPaywall = false
    @Binding var showSubscription: Bool
    @State private var selectedFilter: FeedFilter = .global
    @State private var showFilterMenu = false
    
    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()
            
            if feedManager.isLoading {
                loadingView
            } else if feedManager.posts.isEmpty {
                emptyView
            } else {
                VStack(spacing: 0) {
                    ScrollView {
                        LazyVStack(spacing: 0) {
                            ForEach(feedManager.posts) { post in
                                PostCardView(post: post, showSubscription: $showSubscription)
                                    .environmentObject(feedManager)
                                    .environmentObject(authManager)
                                    //.environmentObject(feedViewModel)
                                    .background(
                                        GeometryReader { geometry in
                                            Color.clear.preference(
                                                key: ScrollOffsetPreferenceKey.self,
                                                value: geometry.frame(in: .named("scroll")).minY
                                            )
                                        }
                                    )
                                Rectangle()
                                    .fill(Color(.systemGray6))
                                    .frame(height: 8)
                                    .onAppear {
                                        // Carrega mais quando chegar nos últimos 3 posts
                                        if post.id == feedManager.posts.suffix(3).first?.id {
                                            Task { await feedManager.loadMorePosts() }
                                        }
                                    }
                            }
                            
                            if feedManager.isLoadingMore {
                                ProgressView()
                                    .padding()
                            }
                        }
                    }
                    .coordinateSpace(name: "scroll")
                    .background(Color(.systemGray6))
                    .refreshable {
                        await feedManager.loadFeed(userLocation: locationManager.lastLocation)
                    }
                    .onPreferenceChange(ScrollOffsetPreferenceKey.self) { offset in
                        // Atualiza o post atualmente visível baseado na posição de scroll
                        
                    }
                }
            }
            
            // Botão novo post
            VStack {
                Spacer()
                HStack {
                    Spacer()
                    Button {
                        if subscriptionManager.currentPlan != .none {
                            showNewPost = true
                        } else {
                            showPaywall = true
                        }
                    } label: {
                        Image(systemName: "plus")
                            .font(.title2).fontWeight(.bold)
                            .foregroundStyle(.white)
                            .frame(width: 56, height: 56)
                            .background(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                )
                            )
                            .clipShape(Circle())
                            .shadow(color: .green.opacity(0.4), radius: 8, y: 4)
                    }
                    .padding()
                }
            }
            
            if feedManager.isUploading {
                uploadingOverlay
            }
        }
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .principal) {
                Button(action: { showFilterMenu.toggle() }) {
                    HStack(alignment: .lastTextBaseline, spacing: 2) {
                        Text("Feed")
                            .font(.title2).fontWeight(.bold)
                        Text(selectedFilter.rawValue)
                            .font(.caption).fontWeight(.bold)
                            .foregroundColor(.accentColor)
                    }
                }
                .buttonStyle(.plain)
                .popover(isPresented: $showFilterMenu, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        ForEach(FeedFilter.allCases) { filter in
                            Button(action: {
                                selectedFilter = filter
                                showFilterMenu = false
                                Task { await feedManager.applyFeedFilter(filter, user: authManager.currentUser, location: locationManager.lastLocation) }
                            }) {
                                HStack {
                                    Text(filter.rawValue)
                                        .font(.headline)
                                        .foregroundColor(selectedFilter == filter ? .accentColor : .primary)
                                    if selectedFilter == filter {
                                        Image(systemName: "checkmark")
                                    }
                                }
                                .padding(.vertical, 8)
                            }
                        }
                    }
                    .padding()
                }
            }
            ToolbarItem(placement: .topBarTrailing) {
                NavigationLink {
                    MessagesView()
                        .environmentObject(authManager)
                } label: {
                    Image(systemName: "paperplane")
                        .font(.system(size: 18))
                }
            }
        }
        .sheet(isPresented: $showNewPost) {
            NewPostView(showSubscription: $showSubscription)
                .environmentObject(feedManager)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                requiredPlan: .starter,
                featureName: "Publicar no feed",
                showSubscription: $showSubscription
            )
        }
        .onAppear {
            locationManager.requestLocation()
            Task {
                await feedManager.loadFeed(userLocation: locationManager.lastLocation)
            }
        }
    }
    
    var loadingView: some View {
        VStack(spacing: 16) {
            Spacer()
            ProgressView().scaleEffect(1.5)
            Text("Carregando feed...")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    var emptyView: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "photo.on.rectangle.angled")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Nenhuma publicação ainda")
                .font(.headline)
            Text("Seja o primeiro a compartilhar!")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }
    
    var uploadingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView(value: feedManager.uploadProgress)
                    .progressViewStyle(.circular)
                    .scaleEffect(1.5)
                    .tint(.white)
                Text("Publicando... \(Int(feedManager.uploadProgress * 100))%")
                    .font(.headline).foregroundStyle(.white)
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // A FUNÇÃO SOLICITADA
private func updateCurrentlyVisiblePost(scrollOffset: CGFloat) {
        // Exemplo simples: pega o índice baseado no offset
        let postHeight: CGFloat = 300 // altura aproximada de cada PostCardView
        let index = max(0, min(feedManager.posts.count - 1, Int(scrollOffset / postHeight)))
        
        if feedManager.posts.indices.contains(index) {
            let visiblePost = feedManager.posts[index]
            //feedViewModel.currentlyVisiblePost = visiblePost
        }
    }
}
