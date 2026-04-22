import SwiftUI
import FirebaseFirestore

struct PublicProfileView: View {
    let userID: String
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var userName = ""
    @State private var userAvatarURL = ""
    @State private var isVerified = false
    @State private var followersCount = 0
    @State private var followingCount = 0
    @State private var userPosts: [Post] = []
    @State private var isLoading = true
    @State private var selectedPost: Post? = nil
    @State private var trophies: [Trophy] = []
    @State private var showFollowers = false
    @State private var showFollowing = false

    private let db = Firestore.firestore()

    var isOwnProfile: Bool {
        userID == authManager.currentUser?.uid
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {
                    profileHeader
                    Divider()
                    if !trophies.isEmpty {
                        TrophiesView(trophies: trophies)
                            .padding(.horizontal)
                            .padding(.vertical, 12)
                        Divider()
                    }
                    postsGrid
                }
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        dismiss()
                    } label: {
                        Image(systemName: "chevron.left")
                            .foregroundStyle(.primary)
                    }
                }
                ToolbarItem(placement: .principal) {
                    HStack(spacing: 4) {
                        Text(userName).font(.headline)
                        if isVerified { VerifiedBadge(size: 14) }
                    }
                }
            }
            .onAppear {
                Task { await loadProfile() }
            }
            .sheet(item: $selectedPost) { post in
                PostDetailView(
                    post: post,
                    onDelete: {
                        Task {
                            await feedManager.deletePost(post)
                            userPosts.removeAll { $0.id == post.id }
                            selectedPost = nil
                        }
                    }
                )
                .environmentObject(feedManager)
                .environmentObject(authManager)
            }
        }
    }

    // MARK: - Header

    var profileHeader: some View {
        VStack(spacing: 16) {
            // Avatar + stats
            HStack(spacing: 0) {
                AvatarView(url: userAvatarURL, size: 80)
                    .overlay(
                        Circle()
                            .stroke(
                                LinearGradient(
                                    colors: [.green, .mint],
                                    startPoint: .topLeading,
                                    endPoint: .bottomTrailing
                                ),
                                lineWidth: 2.5
                            )
                    )
                    .padding(.trailing, 20)

                VStack(spacing: 8) {
                    HStack(spacing: 0) {
                        ProfileStat(value: userPosts.count, label: "Posts")
                        Button { showFollowers = true } label: {
                            ProfileStat(value: followersCount, label: "Seguidores")
                        }.buttonStyle(.plain)
                        Button { showFollowing = true } label: {
                            ProfileStat(value: followingCount, label: "Seguindo")
                        }.buttonStyle(.plain)
                    }
                    .sheet(isPresented: $showFollowers) {
                        FollowListView(userID: userID, type: .followers)
                            .environmentObject(feedManager)
                            .environmentObject(authManager)
                    }
                    .sheet(isPresented: $showFollowing) {
                        FollowListView(userID: userID, type: .following)
                            .environmentObject(feedManager)
                            .environmentObject(authManager)
                    }
                }
            }
            .padding(.horizontal)

            // Nome e verificação
            HStack(spacing: 6) {
                Text(userName)
                    .font(.subheadline).fontWeight(.semibold)
                if isVerified {
                    VerifiedBadge(size: 14)
                }
                Spacer()
            }
            .padding(.horizontal)

            // Botão seguir
            if !isOwnProfile {
                Button {
                    Task { await feedManager.toggleFollow(targetID: userID) }
                } label: {
                    HStack {
                        Image(systemName: feedManager.isFollowing(userID)
                              ? "person.badge.minus"
                              : "person.badge.plus")
                        Text(feedManager.isFollowing(userID) ? "Parar de seguir" : "Seguir")
                            .fontWeight(.medium)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 8)
                    .background(
                        feedManager.isFollowing(userID)
                        ? Color(.systemGray5)
                        : Color.green
                    )
                    .foregroundStyle(
                        feedManager.isFollowing(userID) ? Color.primary : Color.white
                    )
                    .clipShape(RoundedRectangle(cornerRadius: 10))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .padding(.vertical, 16)
    }

    // MARK: - Grid de posts

    @ViewBuilder
    var postsGrid: some View {
        if isLoading {
            ProgressView().padding(40)
        } else if userPosts.isEmpty {
            VStack(spacing: 12) {
                Image(systemName: "photo.on.rectangle.angled")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Nenhuma publicação ainda")
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity)
            .padding(40)
        } else {
            LazyVGrid(columns: [
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1),
                GridItem(.flexible(), spacing: 1)
            ], spacing: 1) {
                ForEach(userPosts) { post in
                    PostThumbnail(post: post) {
                        selectedPost = post
                    } onDelete: {
                        Task {
                            await feedManager.deletePost(post)
                            userPosts.removeAll { $0.id == post.id }
                        }
                    }
                }
            }
        }
    }

    // MARK: - Carregar dados

    func loadProfile() async {
        isLoading = true

        // Dados do usuário
        db.collection("users").document(userID)
            .addSnapshotListener { snapshot, _ in
                guard let data = snapshot?.data() else { return }
                Task { @MainActor in
                    self.userName = data["name"] as? String ?? ""
                    self.userAvatarURL = data["avatarURL"] as? String ?? ""
                    self.isVerified = data["isVerified"] as? Bool ?? false
                    self.followersCount = data["followersCount"] as? Int ?? 0
                }
            }

        // Seguindo count
        if let snapshot = try? await db.collection("follows")
            .document(userID).collection("following").getDocuments() {
            followingCount = snapshot.documents.count
        }
        // Carrega troféus
        if let snapshot = try? await db.collection("users").document(userID)
            .collection("trophies")
            .order(by: "earnedAt", descending: true)
            .getDocuments() {
            trophies = snapshot.documents.compactMap { doc -> Trophy? in
                var data = doc.data()
                data["id"] = doc.documentID
                if let ts = data["earnedAt"] as? Timestamp {
                    data["earnedAt"] = ts.dateValue()
                }
                guard let typeRaw = data["type"] as? String,
                      let type = TrophyType(rawValue: typeRaw),
                      let desc = data["description"] as? String,
                      let points = data["points"] as? Double,
                      let earnedAt = data["earnedAt"] as? Date else { return nil }
                return Trophy(
                    id: doc.documentID,
                    type: type,
                    earnedAt: earnedAt,
                    description: desc,
                    opponentName: data["opponentName"] as? String,
                    points: points
                )
            }
        }

        // Posts do usuário
        userPosts = feedManager.posts.filter { $0.userID == userID }
        isLoading = false
    }
}

struct ProfileStat: View {
    let value: Int
    let label: String

    var body: some View {
        VStack(spacing: 2) {
            Text("\(value)")
                .font(.title3).fontWeight(.bold)
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
