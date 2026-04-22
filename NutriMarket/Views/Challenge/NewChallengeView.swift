import SwiftUI

struct NewChallengeView: View {
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var feedManager: FeedManager
    @Environment(\.dismiss) var dismiss

    @State private var isGroup = false
    @State private var selectedUsers: [(id: String, name: String, avatar: String, isVerified: Bool)] = []
    @State private var isSending = false
    @State private var showSuccess = false

    var followingUsers: [(id: String, name: String, avatar: String, isVerified: Bool)] {
        let following = feedManager.followingIDs
        var seen = Set<String>()
        return feedManager.posts.compactMap { post in
            guard following.contains(post.userID),
                  post.userID != authManager.currentUser?.uid,
                  seen.insert(post.userID).inserted else { return nil }
            return (post.userID, post.userName, post.userAvatarURL, post.isVerified)
        }
    }

    var canSend: Bool {
        !selectedUsers.isEmpty && !isSending
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // Toggle 1x1 ou grupo
                Picker("Tipo", selection: $isGroup) {
                    Text("Duelo 1x1").tag(false)
                    Text("Competição em grupo").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()

                if isGroup {
                    Text("Selecione até 19 pessoas (você + 19 = 20 participantes)")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal)
                }

                if followingUsers.isEmpty {
                    Spacer()
                    VStack(spacing: 16) {
                        Image(systemName: "person.2.slash")
                            .font(.system(size: 44)).foregroundStyle(.secondary)
                        Text("Você não segue ninguém ainda")
                            .font(.headline)
                        Text("Siga outras pessoas no feed para poder desafiá-las!")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center).padding(.horizontal)
                    }
                    Spacer()
                } else {
                    List(followingUsers, id: \.id) { user in
                        HStack(spacing: 12) {
                            AvatarView(url: user.avatar, size: 42)
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Text(user.name).font(.subheadline).fontWeight(.medium)
                                    if user.isVerified { VerifiedBadge(size: 12) }
                                }
                            }
                            Spacer()

                            // Para 1x1 — seleção única
                            // Para grupo — seleção múltipla
                            if isGroup {
                                let isSelected = selectedUsers.contains(where: { $0.id == user.id })
                                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle(isSelected ? .green : .secondary)
                                    .font(.title3)
                            } else {
                                if selectedUsers.first?.id == user.id {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundStyle(.green).font(.title3)
                                }
                            }
                        }
                        .contentShape(Rectangle())
                        .onTapGesture {
                            if isGroup {
                                if let index = selectedUsers.firstIndex(where: { $0.id == user.id }) {
                                    selectedUsers.remove(at: index)
                                } else if selectedUsers.count < 19 {
                                    selectedUsers.append(user)
                                }
                            } else {
                                selectedUsers = [user]
                            }
                        }
                    }
                    .listStyle(.plain)
                }

                // Botão enviar
                if !selectedUsers.isEmpty {
                    VStack(spacing: 8) {
                        if isGroup {
                            Text("\(selectedUsers.count) pessoa(s) selecionada(s)")
                                .font(.caption).foregroundStyle(.secondary)
                        } else {
                            Text("Desafiar **\(selectedUsers.first?.name ?? "")** por 1 mês")
                                .font(.subheadline)
                        }

                        Button {
                            Task { await send() }
                        } label: {
                            HStack {
                                if isSending {
                                    ProgressView().tint(.white).scaleEffect(0.8)
                                }
                                Image(systemName: isGroup ? "person.3.fill" : "trophy.fill")
                                Text(isGroup ? "Criar competição em grupo" : "Enviar desafio!")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity).padding()
                            .background(LinearGradient(
                                colors: isGroup ? [.orange, .red] : [.purple, .blue],
                                startPoint: .leading, endPoint: .trailing
                            ))
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(!canSend)
                        .buttonStyle(.plain)
                    }
                    .padding()
                    .background(.ultraThinMaterial)
                }
            }
            .navigationTitle(isGroup ? "Nova competição" : "Novo desafio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert(isGroup ? "Competição criada! 🏆" : "Desafio enviado! 🏆",
                   isPresented: $showSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text(isGroup
                     ? "Os convidados receberão uma notificação. Quem aceitar entra na competição!"
                     : "\(selectedUsers.first?.name ?? "") receberá uma notificação do seu desafio.")
            }
            .onChange(of: isGroup) { _, _ in selectedUsers = [] }
        }
    }

    func send() async {
        guard let user = authManager.currentUser else { return }
        isSending = true

        if isGroup {
            await challengeManager.createGroupChallenge(
                targetUserIDs: selectedUsers.map { $0.id },
                targetUsers: selectedUsers.map { (id: $0.id, name: $0.name, avatar: $0.avatar) },
                senderName: user.name,
                senderAvatar: user.avatarURL
            )
        } else if let target = selectedUsers.first {
            await challengeManager.createChallenge(
                targetUserID: target.id,
                targetName: target.name,
                targetAvatar: target.avatar,
                senderName: user.name,
                senderAvatar: user.avatarURL
            )
        }

        isSending = false
        showSuccess = true
    }
}
