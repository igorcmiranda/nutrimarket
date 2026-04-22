import SwiftUI
import FirebaseFirestore

struct UserProfileCardView: View {
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var feedManager: FeedManager
    @State private var userPosts: [Post] = []
    @State private var followersCount = 0
    @State private var isLoading = true
    @State private var selectedPost: Post? = nil
    @State private var showDeleteConfirm: Post? = nil
    @State private var showFollowers = false
    @State private var showFollowing = false

    private let db = Firestore.firestore()
    var uid: String { authManager.currentUser?.uid ?? "" }

    var body: some View {
        VStack(spacing: 12) {

            // Stats
            HStack(spacing: 0) {
                StatItem(value: userPosts.count, label: "Posts")
                Divider().frame(height: 30)
                Button {
                    showFollowers = true
                } label: {
                    StatItem(value: followersCount, label: "Seguidores")
                }
                .buttonStyle(.plain)
                Divider().frame(height: 30)
                Button {
                    showFollowing = true
                } label: {
                    StatItem(value: feedManager.followingIDs.count, label: "Seguindo")
                }
                .buttonStyle(.plain)
            }
            .sheet(isPresented: $showFollowers) {
                FollowListView(userID: uid, type: .followers)
                    .environmentObject(feedManager)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showFollowing) {
                FollowListView(userID: uid, type: .following)
                    .environmentObject(feedManager)
                    .environmentObject(authManager)
            }
            .padding(.vertical, 8)
            .background(Color(.systemGray6))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            if isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                    Spacer()
                }
            } else if userPosts.isEmpty {
                VStack(spacing: 8) {
                    Image(systemName: "photo.on.rectangle.angled")
                        .font(.system(size: 36)).foregroundStyle(.secondary)
                    Text("Nenhuma publicação ainda")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding()
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2),
                    GridItem(.flexible(), spacing: 2)
                ], spacing: 2) {
                    ForEach(userPosts) { post in
                        PostThumbnail(post: post) {
                            selectedPost = post
                        } onDelete: {
                            showDeleteConfirm = post
                        }
                    }
                }
            }
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
        .confirmationDialog(
            "Excluir publicação?",
            isPresented: Binding(
                get: { showDeleteConfirm != nil },
                set: { if !$0 { showDeleteConfirm = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("Excluir", role: .destructive) {
                if let post = showDeleteConfirm {
                    Task {
                        await feedManager.deletePost(post)
                        userPosts.removeAll { $0.id == post.id }
                        showDeleteConfirm = nil
                    }
                }
            }
        }
        .onAppear {
            Task { await loadUserData() }
        }
        .onChange(of: feedManager.posts) { _, newPosts in
            userPosts = newPosts.filter { $0.userID == uid }
        }
    }

    func loadUserData() async {
        isLoading = true
        userPosts = feedManager.posts.filter { $0.userID == uid }

        // Listener em tempo real dos seguidores
        db.collection("users").document(uid)
            .addSnapshotListener { snapshot, _ in
                Task { @MainActor in
                    self.followersCount = snapshot?.data()?["followersCount"] as? Int ?? 0
                    self.isLoading = false
                }
            }
    }
}

struct StatItem: View {
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

struct PostThumbnail: View {
    let post: Post
    let onTap: () -> Void
    let onDelete: () -> Void

    var thumbSize: CGFloat {
        (UIScreen.main.bounds.width - 32 - 4) / 3
    }

    var body: some View {
        Button(action: onTap) {
            ZStack(alignment: .bottom) {
                AsyncImage(url: URL(string: post.mediaURL)) { phase in
                    switch phase {
                    case .success(let image):
                        image.resizable().scaledToFill()
                    default:
                        Rectangle().fill(Color(.systemGray5))
                            .overlay(ProgressView())
                    }
                }
                .frame(width: thumbSize, height: thumbSize)
                .clipped()

                // Barra inferior com curtidas e comentários
                HStack(spacing: 8) {
                    HStack(spacing: 3) {
                        Image(systemName: "heart.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                        Text("\(post.likesCount)")
                            .font(.system(size: 11)).fontWeight(.medium)
                            .foregroundStyle(.white)
                    }

                    HStack(spacing: 3) {
                        Image(systemName: "bubble.right.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                        Text("\(post.commentsCount)")
                            .font(.system(size: 11)).fontWeight(.medium)
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    if post.mediaType == .video {
                        Image(systemName: "play.fill")
                            .font(.system(size: 10))
                            .foregroundStyle(.white)
                    }
                }
                .padding(.horizontal, 6).padding(.vertical, 4)
                .background(
                    LinearGradient(
                        colors: [.clear, .black.opacity(0.6)],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
            }
        }
        .buttonStyle(.plain)
    }
}

struct PostDetailView: View {
    let post: Post
    let onDelete: () -> Void
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showDeleteConfirm = false
    @State private var showInteractions = false
    @State private var isLikeAnimating = false

    var isOwnPost: Bool {
        post.userID == authManager.currentUser?.uid
    }

    // Pega o post atualizado do feedManager para refletir likes em tempo real
    var currentPost: Post {
        feedManager.posts.first { $0.id == post.id } ?? post
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 0) {

                    // Imagem
                    AsyncImage(url: URL(string: currentPost.mediaURL)) { phase in
                        switch phase {
                        case .success(let image):
                            image.resizable().scaledToFit()
                        default:
                            Rectangle().fill(Color(.systemGray5))
                                .frame(height: 300)
                                .overlay(ProgressView())
                        }
                    }

                    VStack(alignment: .leading, spacing: 16) {

                        // Ações — curtir e comentar
                        HStack(spacing: 20) {
                            Button {
                                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                                    isLikeAnimating = true
                                }
                                Task { await feedManager.toggleLike(post: currentPost) }
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                                    isLikeAnimating = false
                                }
                                let impact = UIImpactFeedbackGenerator(style: .light)
                                impact.impactOccurred()
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: currentPost.isLiked ? "heart.fill" : "heart")
                                        .font(.system(size: 22))
                                        .foregroundStyle(currentPost.isLiked ? .red : .primary)
                                        .scaleEffect(isLikeAnimating ? 1.35 : 1.0)
                                    Text("\(currentPost.likesCount)")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Button {
                                showInteractions = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "bubble.right")
                                        .font(.system(size: 22))
                                        .foregroundStyle(.primary)
                                    Text("\(currentPost.commentsCount)")
                                        .font(.subheadline).fontWeight(.medium)
                                        .foregroundStyle(.primary)
                                }
                            }
                            .buttonStyle(.plain)

                            Spacer()

                            Text(currentPost.createdAt.timeAgoDisplay())
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        .padding()
                        .background(Color(.systemGray6))
                        .clipShape(RoundedRectangle(cornerRadius: 12))

                        // Caption
                        if !currentPost.caption.isEmpty {
                            VStack(alignment: .leading, spacing: 4) {
                                HStack(spacing: 4) {
                                    Text(currentPost.userName)
                                        .font(.subheadline).fontWeight(.semibold)
                                    if currentPost.isVerified {
                                        VerifiedBadge(size: 12)
                                    }
                                }
                                Text(currentPost.caption)
                                    .font(.subheadline)
                            }
                        }

                        // Localização e data
                        HStack {
                            if !currentPost.city.isEmpty {
                                Label(currentPost.city, systemImage: "mappin.circle.fill")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Text(currentPost.createdAt, style: .date)
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Publicação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar") { dismiss() }
                }
                // Botão deletar SOMENTE para o dono do post
                if isOwnPost {
                    ToolbarItem(placement: .topBarTrailing) {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Image(systemName: "trash")
                                .foregroundStyle(.red)
                        }
                    }
                }
            }
            .confirmationDialog(
                "Excluir publicação?",
                isPresented: $showDeleteConfirm,
                titleVisibility: .visible
            ) {
                Button("Excluir", role: .destructive) {
                    onDelete()
                    dismiss()
                }
            }
            .sheet(isPresented: $showInteractions) {
                CommentsView(post: currentPost)
                    .environmentObject(feedManager)
                    .environmentObject(authManager)
            }
        }
    }
}
