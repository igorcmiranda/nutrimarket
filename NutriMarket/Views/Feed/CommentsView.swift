import SwiftUI
import FirebaseFirestore

struct CommentsView: View {
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    let post: Post
    @Environment(\.dismiss) var dismiss

    @State private var comments: [Comment] = []
    @State private var likers: [LikerUser] = []
    @State private var newComment = ""
    @State private var isLoading = true
    @State private var isSending = false
    @State private var selectedTab = 0
    @State private var commentToDelete: Comment? = nil

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Comentários (\(comments.count))").tag(0)
                    Text("Curtidas (\(likers.count))").tag(1)
                }
                .pickerStyle(.segmented)
                .padding()

                if isLoading {
                    Spacer()
                    ProgressView()
                    Spacer()
                } else {
                    if selectedTab == 0 {
                        commentsTab
                    } else {
                        likersTab
                    }
                }
            }
            .navigationTitle("Interações")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear { setupListeners() }
            .confirmationDialog(
                "Excluir comentário?",
                isPresented: Binding(
                    get: { commentToDelete != nil },
                    set: { if !$0 { commentToDelete = nil } }
                ),
                titleVisibility: .visible
            ) {
                Button("Excluir", role: .destructive) {
                    if let comment = commentToDelete {
                        Task { await deleteComment(comment) }
                    }
                }
            }
        }
    }

    // MARK: - Comentários

    var commentsTab: some View {
        VStack(spacing: 0) {
            if comments.isEmpty {
                Spacer()
                VStack(spacing: 8) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Nenhum comentário ainda")
                        .font(.subheadline).foregroundStyle(.secondary)
                }
                Spacer()
            } else {
                List(comments) { comment in
                    HStack(alignment: .top, spacing: 10) {
                        AvatarView(url: comment.userAvatarURL, size: 34)

                        VStack(alignment: .leading, spacing: 3) {
                            HStack {
                                Text(comment.userName)
                                    .font(.subheadline).fontWeight(.medium)
                                if comment.userID == post.userID {
                                    Text("autor")
                                        .font(.caption2).fontWeight(.medium)
                                        .padding(.horizontal, 6).padding(.vertical, 2)
                                        .background(Color.green.opacity(0.12))
                                        .foregroundStyle(.green)
                                        .clipShape(Capsule())
                                }
                                Spacer()
                                Text(comment.createdAt.timeAgoDisplay())
                                    .font(.caption2).foregroundStyle(.secondary)
                            }
                            Text(comment.text)
                                .font(.subheadline).foregroundStyle(.primary)
                        }
                    }
                    .padding(.vertical, 4)
                    .contentShape(Rectangle())
                    // Pressionar para apagar o próprio comentário
                    .onLongPressGesture {
                        if comment.userID == authManager.currentUser?.uid {
                            commentToDelete = comment
                        }
                    }
                    .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                        if comment.userID == authManager.currentUser?.uid {
                            Button(role: .destructive) {
                                commentToDelete = comment
                            } label: {
                                Label("Apagar", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }

            Divider()
            HStack(spacing: 10) {
                AvatarView(url: authManager.currentUser?.avatarURL ?? "", size: 32)
                TextField("Adicionar comentário...", text: $newComment, axis: .vertical)
                    .font(.subheadline).lineLimit(4)
                Button {
                    Task { await sendComment() }
                } label: {
                    Image(systemName: isSending ? "clock" : "paperplane.fill")
                        .foregroundStyle(newComment.isEmpty ? Color.secondary : Color.green)
                }
                .disabled(newComment.isEmpty || isSending)
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(Color(.systemBackground))
        }
    }

    // MARK: - Curtidas

    var likersTab: some View {
        Group {
            if likers.isEmpty {
                VStack(spacing: 8) {
                    Spacer()
                    Image(systemName: "heart")
                        .font(.system(size: 40)).foregroundStyle(.secondary)
                    Text("Nenhuma curtida ainda")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(likers) { liker in
                    HStack(spacing: 12) {
                        AvatarView(url: liker.avatarURL, size: 40)
                        VStack(alignment: .leading, spacing: 2) {
                            Text(liker.name)
                                .font(.subheadline).fontWeight(.medium)
                            if liker.userID == post.userID {
                                Text("autor da publicação")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                        Image(systemName: "heart.fill")
                            .foregroundStyle(.red).font(.caption)
                    }
                    .padding(.vertical, 4)
                }
                .listStyle(.plain)
            }
        }
    }

    // MARK: - Listeners

    func setupListeners() {
        let db = Firestore.firestore()

        // Listener comentários
        db.collection("posts").document(post.id)
            .collection("comments")
            .order(by: "createdAt", descending: false)
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    self.comments = docs.compactMap { doc in
                        var comment = try? doc.data(as: Comment.self)
                        comment?.id = doc.documentID
                        return comment
                    }
                    self.isLoading = false
                }
            }

        // Listener curtidas
        db.collection("posts").document(post.id)
            .collection("likes")
            .addSnapshotListener { snapshot, _ in
                guard let docs = snapshot?.documents else { return }
                Task { @MainActor in
                    var users: [LikerUser] = []
                    for doc in docs {
                        let uid = doc.documentID
                        if let userDoc = try? await db.collection("users").document(uid).getDocument(),
                           let data = userDoc.data() {
                            users.append(LikerUser(
                                userID: uid,
                                name: data["name"] as? String ?? "Usuário",
                                avatarURL: data["avatarURL"] as? String ?? ""
                            ))
                        }
                    }
                    self.likers = users
                    self.isLoading = false
                }
            }
    }

    // MARK: - Ações

    func sendComment() async {
        let text = newComment.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { return }
        isSending = true
        newComment = ""
        await feedManager.addComment(postID: post.id, text: text)
        isSending = false
    }

    func deleteComment(_ comment: Comment) async {
        let db = Firestore.firestore()
        do {
            try await db.collection("posts").document(post.id)
                .collection("comments").document(comment.id)
                .delete()

            // Garante mínimo 0 no contador
            let postDoc = try await db.collection("posts").document(post.id).getDocument()
            let currentCount = postDoc.data()?["commentsCount"] as? Int ?? 0
            if currentCount > 0 {
                try await db.collection("posts").document(post.id)
                    .updateData(["commentsCount": FieldValue.increment(Int64(-1))])
            }

            comments.removeAll { $0.id == comment.id }
            commentToDelete = nil
        } catch {
            // // print("Erro ao deletar comentário: \(error)")
        }
    }
}

struct LikerUser: Identifiable {
    var id: String { userID }
    let userID: String
    let name: String
    let avatarURL: String
}
