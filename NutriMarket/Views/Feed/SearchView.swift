import SwiftUI
import FirebaseFirestore

struct SearchView: View {
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @State private var query = ""
    @State private var results: [SearchUser] = []
    @State private var isSearching = false
    @State private var selectedUserID: String? = nil
    @State private var showProfile = false
    private let db = Firestore.firestore()

    struct SearchUser: Identifiable {
        let id: String
        let name: String
        let username: String
        let avatarURL: String
        let isVerified: Bool
        let followersCount: Int
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                resultContent
            }
            .navigationTitle("Buscar")
            .navigationBarTitleDisplayMode(.inline)
            .sheet(isPresented: $showProfile) {
                if let uid = selectedUserID {
                    PublicProfileView(userID: uid)
                        .environmentObject(feedManager)
                        .environmentObject(authManager)
                }
            }
        }
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass")
                .foregroundStyle(.secondary)
            TextField("Buscar por @usuário...", text: $query)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: query) { _, newValue in
                    Task { await search(query: newValue) }
                }
            if !query.isEmpty {
                Button {
                    query = ""
                    results = []
                } label: {
                    Image(systemName: "xmark.circle.fill")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    @ViewBuilder
    var resultContent: some View {
        if isSearching {
            ProgressView().padding()
            Spacer()
        } else if query.isEmpty {
            emptyState
        } else if results.isEmpty {
            notFoundState
        } else {
            resultList
        }
    }

    var emptyState: some View {
        VStack(spacing: 16) {
            Spacer()
            Image(systemName: "magnifyingglass")
                .font(.system(size: 52))
                .foregroundStyle(.secondary)
            Text("Buscar usuários")
                .font(.headline)
            Text("Digite o @ de quem você quer encontrar")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }

    var notFoundState: some View {
        VStack(spacing: 12) {
            Spacer()
            Image(systemName: "person.slash")
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Nenhum usuário encontrado")
                .font(.headline)
            Text("Tente outro @")
                .font(.subheadline).foregroundStyle(.secondary)
            Spacer()
        }
    }

    var resultList: some View {
        List(results) { user in
            HStack(spacing: 12) {
                AvatarView(url: user.avatarURL, size: 50)
                    .overlay(
                        Circle().stroke(
                            LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ),
                            lineWidth: 1.5
                        )
                    )

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 4) {
                        Text(user.name)
                            .font(.subheadline).fontWeight(.semibold)
                        if user.isVerified {
                            VerifiedBadge(size: 13)
                        }
                    }
                    Text("@\(user.username)")
                        .font(.caption).foregroundStyle(.secondary)
                    Text("\(user.followersCount) seguidores")
                        .font(.caption2).foregroundStyle(.secondary)
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
            .listRowSeparator(.hidden)
            .listRowInsets(EdgeInsets(top: 6, leading: 16, bottom: 6, trailing: 16))
        }
        .listStyle(.plain)
    }

    func followButton(for user: SearchUser) -> some View {
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

    func search(query: String) async {
        let q = query.lowercased().trimmingCharacters(in: .whitespacesAndNewlines)
        guard !q.isEmpty else { results = []; return }

        isSearching = true

        do {
            let snapshot = try await db.collection("users")
                .whereField("username", isGreaterThanOrEqualTo: q)
                .whereField("username", isLessThanOrEqualTo: q + "\u{f8ff}")
                .limit(to: 20)
                .getDocuments()

            results = snapshot.documents.compactMap { doc -> SearchUser? in
                let data = doc.data()
                guard let username = data["username"] as? String,
                      let name = data["name"] as? String else { return nil }
                return SearchUser(
                    id: doc.documentID,
                    name: name,
                    username: username,
                    avatarURL: data["avatarURL"] as? String ?? "",
                    isVerified: data["isVerified"] as? Bool ?? false,
                    followersCount: data["followersCount"] as? Int ?? 0
                )
            }
        } catch {
            // print("Erro na busca: \(error)")
        }

        isSearching = false
    }
}
