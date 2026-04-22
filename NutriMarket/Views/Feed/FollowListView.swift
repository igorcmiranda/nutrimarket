import SwiftUI
import FirebaseFirestore

enum FollowListType {
    case followers, following
}

struct FollowListView: View {
    let userID: String
    let type: FollowListType
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var users: [FollowUser] = []
    @State private var isLoading = true
    @State private var selectedUserID: String? = nil
    @State private var showProfile = false

    struct FollowUser: Identifiable {
        let id: String
        let name: String
        let username: String
        let avatarURL: String
        let isVerified: Bool
    }

    var title: String {
        type == .followers ? "Seguidores" : "Seguindo"
    }

    var body: some View {
        NavigationStack {
            Group {
                if isLoading {
                    ProgressView()
                } else if users.isEmpty {
                    emptyView
                } else {
                    userList
                }
            }
            .navigationTitle(title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .onAppear {
                Task { await loadUsers() }
            }
            .sheet(isPresented: $showProfile) {
                if let uid = selectedUserID {
                    PublicProfileView(userID: uid)
                        .environmentObject(feedManager)
                        .environmentObject(authManager)
                }
            }
        }
    }

    var emptyView: some View {
        VStack(spacing: 12) {
            Image(systemName: type == .followers ? "person.2" : "person.badge.plus")
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text(type == .followers ? "Nenhum seguidor ainda" : "Não segue ninguém ainda")
                .font(.headline)
        }
    }

    var userList: some View {
        List(users) { user in
            HStack(spacing: 12) {
                AvatarView(url: user.avatarURL, size: 46)

                VStack(alignment: .leading, spacing: 2) {
                    HStack(spacing: 4) {
                        Text(user.name)
                            .font(.subheadline).fontWeight(.medium)
                        if user.isVerified {
                            VerifiedBadge(size: 12)
                        }
                    }
                    Text("@\(user.username)")
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                if user.id != authManager.currentUser?.uid {
                    followButton(for: user)
                }
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedUserID = user.id
                showProfile = true
            }
        }
        .listStyle(.plain)
    }

    func followButton(for user: FollowUser) -> some View {
        let isFollowing = feedManager.isFollowing(user.id)
        return Button {
            Task { await feedManager.toggleFollow(targetID: user.id) }
        } label: {
            Text(isFollowing ? "Seguindo" : "Seguir")
                .font(.caption).fontWeight(.semibold)
                .padding(.horizontal, 14).padding(.vertical, 6)
                .background(isFollowing ? Color(.systemGray5) : Color.green)
                .foregroundStyle(isFollowing ? Color.secondary : Color.white)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    func loadUsers() async {
        let db = Firestore.firestore()
        isLoading = true
        var ids: [String] = []

        do {
            if type == .following {
                let snap = try await db.collection("follows")
                    .document(userID)
                    .collection("following")
                    .getDocuments()
                ids = snap.documents.map { $0.documentID }
            } else {
                // Tenta subcoleção followers primeiro
                let followersSnap = try await db.collection("users")
                    .document(userID)
                    .collection("followers")
                    .getDocuments()
                ids = followersSnap.documents.map { $0.documentID }

                // Se vazia, busca em todos os follows
                if ids.isEmpty {
                    let allFollowsSnap = try await db.collection("follows").getDocuments()
                    await withTaskGroup(of: String?.self) { group in
                        for followDoc in allFollowsSnap.documents {
                            let followerUID = followDoc.documentID
                            guard followerUID != userID else { continue }
                            group.addTask {
                                let snap = try? await db
                                    .collection("follows")
                                    .document(followerUID)
                                    .collection("following")
                                    .document(self.userID)
                                    .getDocument()
                                return snap?.exists == true ? followerUID : nil
                            }
                        }
                        for await result in group {
                            if let uid = result { ids.append(uid) }
                        }
                    }
                }
            }

            users = await fetchUsers(ids: ids, db: db)
        } catch {
            // print("Erro: \(error)")
        }

        isLoading = false
    }

    func fetchUsers(ids: [String], db: Firestore) async -> [FollowUser] {
        var result: [FollowUser] = []
        for id in ids {
            if let doc = try? await db.collection("users").document(id).getDocument(),
               let data = doc.data() {
                result.append(FollowUser(
                    id: id,
                    name: data["name"] as? String ?? "",
                    username: data["username"] as? String ?? "",
                    avatarURL: data["avatarURL"] as? String ?? "",
                    isVerified: data["isVerified"] as? Bool ?? false
                ))
            }
        }
        return result
    }
}

struct SelectedUser: Identifiable {
    let id: String
}
