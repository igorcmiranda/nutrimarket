import SwiftUI
import FirebaseFirestore

struct MessagesView: View {
    @EnvironmentObject var authManager: AuthManager
    @StateObject private var messagesManager = MessagesManager()
    @State private var searchQuery = ""
    @State private var searchResults: [SearchUser] = []
    @State private var isSearching = false
    @State private var selectedConversation: Conversation? = nil
    @State private var selectedNewUserID: String? = nil
    @State private var selectedNewUserName: String = ""
    @State private var selectedNewUserAvatar: String = ""
    @State private var showChat = false

    struct SearchUser: Identifiable {
        let id: String
        let name: String
        let username: String
        let avatarURL: String
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                searchBar
                
                if isSearching && !searchQuery.isEmpty {
                    searchResultsList
                } else {
                    conversationsList
                }
            }
            .navigationTitle("Mensagens")
            .navigationBarTitleDisplayMode(.inline)
            .onAppear {
                messagesManager.startListeningConversations()
            }
            .onDisappear {
                messagesManager.stopListening()
            }
            .navigationDestination(isPresented: $showChat) {
                if let conv = selectedConversation {
                    ChatView(
                        conversation: conv,
                        messagesManager: messagesManager
                    )
                    .environmentObject(authManager)
                } else if let userID = selectedNewUserID {
                    ChatView(
                        newChatUserID: userID,
                        newChatUserName: selectedNewUserName,
                        newChatUserAvatar: selectedNewUserAvatar,
                        messagesManager: messagesManager
                    )
                    .environmentObject(authManager)
                }
            }
        }
    }

    var searchBar: some View {
        HStack(spacing: 10) {
            Image(systemName: "magnifyingglass").foregroundStyle(.secondary)
            TextField("Buscar por @usuário...", text: $searchQuery)
                .autocapitalization(.none)
                .autocorrectionDisabled()
                .onChange(of: searchQuery) { _, newValue in
                    Task { await search(query: newValue) }
                }
            if !searchQuery.isEmpty {
                Button { searchQuery = ""; searchResults = [] } label: {
                    Image(systemName: "xmark.circle.fill").foregroundStyle(.secondary)
                }
            }
        }
        .padding(12)
        .background(Color(.systemGray6))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .padding()
    }

    var conversationsList: some View {
        Group {
            if messagesManager.conversations.isEmpty {
                VStack(spacing: 16) {
                    Spacer()
                    Image(systemName: "paperplane")
                        .font(.system(size: 52)).foregroundStyle(.secondary)
                    Text("Nenhuma conversa")
                        .font(.headline)
                    Text("Busque pelo @ de alguém para começar")
                        .font(.subheadline).foregroundStyle(.secondary)
                    Spacer()
                }
            } else {
                List(messagesManager.conversations) { conv in
                    conversationRow(conv)
                        .onTapGesture {
                            selectedConversation = conv
                            selectedNewUserID = nil
                            showChat = true
                        }
                        .listRowSeparator(.hidden)
                        .listRowInsets(EdgeInsets(top: 4, leading: 16, bottom: 4, trailing: 16))
                }
                .listStyle(.plain)
            }
        }
    }

    func conversationRow(_ conv: Conversation) -> some View {
        let uid = authManager.currentUser?.uid ?? ""
        let unread = conv.unreadCount[uid] ?? 0

        return HStack(spacing: 12) {
            AvatarView(url: conv.otherUserAvatar, size: 52)

            VStack(alignment: .leading, spacing: 3) {
                Text(conv.otherUserName)
                    .font(.subheadline).fontWeight(unread > 0 ? .bold : .medium)
                Text(conv.lastMessage)
                    .font(.caption).foregroundStyle(.secondary)
                    .lineLimit(1)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(conv.lastMessageAt.timeAgoDisplay())
                    .font(.caption2).foregroundStyle(.secondary)
                if unread > 0 {
                    Text("\(unread)")
                        .font(.caption2).fontWeight(.bold)
                        .foregroundStyle(.white)
                        .padding(.horizontal, 6).padding(.vertical, 2)
                        .background(Color.blue)
                        .clipShape(Capsule())
                }
            }
        }
        .padding(.vertical, 4)
    }

    var searchResultsList: some View {
        List(searchResults) { user in
            HStack(spacing: 12) {
                AvatarView(url: user.avatarURL, size: 46)
                VStack(alignment: .leading, spacing: 2) {
                    Text(user.name).font(.subheadline).fontWeight(.medium)
                    Text("@\(user.username)").font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
                Image(systemName: "paperplane.fill")
                    .foregroundStyle(.blue)
            }
            .contentShape(Rectangle())
            .onTapGesture {
                selectedConversation = nil
                selectedNewUserID = user.id
                selectedNewUserName = user.name
                selectedNewUserAvatar = user.avatarURL
                searchQuery = ""
                searchResults = []
                showChat = true
            }
            .listRowSeparator(.hidden)
        }
        .listStyle(.plain)
    }

    func search(query: String) async {
        let q = query.lowercased().trimmingCharacters(in: .whitespaces)
        guard !q.isEmpty else { searchResults = []; isSearching = false; return }
        isSearching = true

        let snap = try? await Firestore.firestore().collection("users")
            .whereField("username", isGreaterThanOrEqualTo: q)
            .whereField("username", isLessThanOrEqualTo: q + "\u{f8ff}")
            .limit(to: 10)
            .getDocuments()

        searchResults = snap?.documents.compactMap { doc -> SearchUser? in
            let data = doc.data()
            guard let name = data["name"] as? String,
                  let username = data["username"] as? String else { return nil }
            return SearchUser(
                id: doc.documentID,
                name: name,
                username: username,
                avatarURL: data["avatarURL"] as? String ?? ""
            )
        } ?? []
    }
}
