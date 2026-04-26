import SwiftUI
import Firebase
import FirebaseFirestore
import Combine

struct NewChallengeView: View {
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var feedManager: FeedManager
    @Environment(\.dismiss) var dismiss

    @State private var isGroup = false
    @State private var challengeName = ""
    @State private var selectedUsers: [(id: String, name: String, avatar: String, isVerified: Bool)] = []
    @State private var isSending = false
    @State private var showSuccess = false
    @State private var createdChallengeID: String? = nil
    @State private var showShareSheet = false
    @State private var followingUsers: [(id: String, name: String, avatar: String, isVerified: Bool)] = []
    @State private var isLoadingUsers = false

    var canSend: Bool {
        !challengeName.trimmingCharacters(in: .whitespaces).isEmpty && !isSending
    }

    var inviteMessage: String {
        guard let cid = createdChallengeID else { return "" }
        return DeepLinkRouter.inviteMessage(challengeName: challengeName, challengeID: cid)
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {

                // ── Nome do desafio ───────────────────────────────
                VStack(alignment: .leading, spacing: 6) {
                    Label("Nome do desafio *", systemImage: "trophy.fill")
                        .font(.caption).fontWeight(.semibold)
                        .foregroundStyle(.orange)
                        .padding(.horizontal)

                    TextField(
                        isGroup ? "Ex: Verão Sarado 2025 🔥" : "Ex: Duelo dos Titãs 💪",
                        text: $challengeName
                    )
                    .padding(12)
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 12))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(
                                challengeName.isEmpty ? Color(.systemGray4) : Color.orange,
                                lineWidth: challengeName.isEmpty ? 0.5 : 1.5
                            )
                    )
                    .padding(.horizontal)

                    if challengeName.isEmpty {
                        Text("Campo obrigatório — dê um nome criativo!")
                            .font(.caption2)
                            .foregroundStyle(.red.opacity(0.8))
                            .padding(.horizontal)
                    }
                }
                .padding(.vertical, 12)
                .background(Color(.systemGray6))

                // ── Tipo ──────────────────────────────────────────
                Picker("Tipo", selection: $isGroup) {
                    Text("Duelo 1x1").tag(false)
                    Text("Competição em grupo").tag(true)
                }
                .pickerStyle(.segmented)
                .padding()
                .background(Color(.systemGray6))

                if isGroup {
                    Text("Selecione até 19 pessoas ou compartilhe o link")
                        .font(.caption).foregroundStyle(.secondary)
                        .padding(.horizontal)
                        .background(Color(.systemGray6))
                }

                // ── Lista de seguidores ───────────────────────────
                if isLoadingUsers {
                    Spacer()
                    ProgressView("Carregando usuários...")
                    Spacer()
                } else if followingUsers.isEmpty {
                    Spacer()
                    noFollowingView
                    Spacer()
                } else {
                    List(followingUsers, id: \.id) { user in
                        userRow(user)
                    }
                    .listStyle(.plain)
                }

                // ── Barra inferior ────────────────────────────────
                bottomBar
            }
            .background(Color(.systemGray6))
            .navigationTitle(isGroup ? "Nova competição" : "Novo desafio")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .alert(
                isGroup ? "Competição criada! 🏆" : "Desafio enviado! 🏆",
                isPresented: $showSuccess
            ) {
                Button("Compartilhar link") { showShareSheet = true }
                Button("OK") { dismiss() }
            } message: {
                Text(
                    isGroup
                    ? "Convide mais pessoas pelo link do desafio!"
                    : "\(selectedUsers.first?.name ?? "") foi notificado. Compartilhe o link para convidar mais pessoas!"
                )
            }
            .sheet(isPresented: $showShareSheet) {
                ShareSheet(items: [inviteMessage])
            }
            .onChange(of: isGroup) { _, _ in selectedUsers = [] }
        }
        .task { await loadFollowingUsers() }
    }

    // MARK: - Sub-views

    var noFollowingView: some View {
        VStack(spacing: 16) {
            Image(systemName: "person.2.slash")
                .font(.system(size: 44)).foregroundStyle(.secondary)
            Text("Você não segue ninguém ainda")
                .font(.headline)
            Text("Use o link de convite para chamar qualquer pessoa — mesmo quem ainda não usa o Vyro!")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center).padding(.horizontal)

            if canSend {
                Button {
                    Task { await createAndShare() }
                } label: {
                    Label("Criar desafio e copiar link", systemImage: "link")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)
                .padding(.horizontal)
            }
        }
        .padding()
    }

    func userRow(_ user: (id: String, name: String, avatar: String, isVerified: Bool)) -> some View {
        HStack(spacing: 12) {
            AvatarView(url: user.avatar, size: 42)
            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 4) {
                    Text(user.name).font(.subheadline).fontWeight(.medium)
                    if user.isVerified { VerifiedBadge(size: 12) }
                }
            }
            Spacer()
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
                if let idx = selectedUsers.firstIndex(where: { $0.id == user.id }) {
                    selectedUsers.remove(at: idx)
                } else if selectedUsers.count < 19 {
                    selectedUsers.append(user)
                }
            } else {
                selectedUsers = [user]
            }
        }
    }

    @ViewBuilder
    var bottomBar: some View {
        VStack(spacing: 8) {

            // ── Após criação: botão de compartilhar ───────────────
            if createdChallengeID != nil {
                Button {
                    showShareSheet = true
                } label: {
                    Label("Compartilhar link do desafio", systemImage: "link")
                        .fontWeight(.medium)
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color.orange)
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                }
                .buttonStyle(.plain)

                Button("Fechar") { dismiss() }
                    .font(.subheadline).foregroundStyle(.secondary)

            } else {
                // ── Antes da criação ──────────────────────────────
                if !selectedUsers.isEmpty {
                    if isGroup {
                        Text("\(selectedUsers.count) pessoa(s) selecionada(s)")
                            .font(.caption).foregroundStyle(.secondary)
                    } else {
                        Text("Desafiar **\(selectedUsers.first?.name ?? "")** por 1 mês")
                            .font(.subheadline)
                    }
                }

                HStack(spacing: 10) {
                    // Botão principal: envia + abre share sheet
                    Button {
                        Task { await send() }
                    } label: {
                        HStack {
                            if isSending {
                                ProgressView().tint(.white).scaleEffect(0.8)
                            }
                            Image(systemName: isGroup ? "person.3.fill" : "trophy.fill")
                            Text(
                                selectedUsers.isEmpty
                                ? "Criar e compartilhar link"
                                : (isGroup ? "Criar competição" : "Enviar desafio!")
                            )
                            .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity).padding()
                        .background(
                            canSend
                            ? LinearGradient(
                                colors: isGroup ? [.orange, .red] : [.purple, .blue],
                                startPoint: .leading, endPoint: .trailing
                              )
                            : LinearGradient(
                                colors: [.gray.opacity(0.4)],
                                startPoint: .leading, endPoint: .trailing
                              )
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!canSend)
                    .buttonStyle(.plain)
                }
            }
        }
        .padding()
        .background(.ultraThinMaterial)
    }

    // MARK: - Actions

    /// Cria o desafio com usuários selecionados (se houver) e exibe o alert de sucesso
    func send() async {
        guard canSend else { return }
        isSending = true
        let trimmedName = challengeName.trimmingCharacters(in: .whitespaces)
        guard let user = authManager.currentUser else { isSending = false; return }

        if isGroup {
            createdChallengeID = await challengeManager.createGroupChallenge(
                name: trimmedName,
                targetUserIDs: selectedUsers.map { $0.id },
                targetUsers: selectedUsers.map { (id: $0.id, name: $0.name, avatar: $0.avatar) },
                senderName: user.name,
                senderAvatar: user.avatarURL
            )
        } else if let target = selectedUsers.first {
            createdChallengeID = await challengeManager.createChallenge(
                name: trimmedName,
                targetUserID: target.id,
                targetName: target.name,
                targetAvatar: target.avatar,
                senderName: user.name,
                senderAvatar: user.avatarURL
            )
        } else {
            // Sem usuário selecionado → cria como grupo aberto (só link)
            createdChallengeID = await challengeManager.createGroupChallenge(
                name: trimmedName,
                targetUserIDs: [],
                targetUsers: [],
                senderName: user.name,
                senderAvatar: user.avatarURL
            )
        }

        isSending = false
        if createdChallengeID != nil {
            showSuccess = true
        }
    }

    /// Cria o desafio e abre direto o share sheet (sem alert intermediário)
    func createAndShare() async {
        await send()
        // O alert vai mostrar botão "Compartilhar link"
    }

    func loadFollowingUsers() async {
        guard let uid = authManager.currentUser?.uid else { return }
        isLoadingUsers = true
        let following = Array(feedManager.followingIDs).filter { $0 != uid }
        guard !following.isEmpty else { followingUsers = []; isLoadingUsers = false; return }

        do {
            let db = Firestore.firestore()
            var allUsers: [(id: String, name: String, avatar: String, isVerified: Bool)] = []
            let chunks = stride(from: 0, to: following.count, by: 10).map {
                Array(following[$0..<min($0 + 10, following.count)])
            }
            for chunk in chunks {
                let snapshot = try await db.collection("users")
                    .whereField(FieldPath.documentID(), in: chunk)
                    .getDocuments()
                let users = snapshot.documents.compactMap { doc -> (id: String, name: String, avatar: String, isVerified: Bool)? in
                    let data = doc.data()
                    guard let name = data["name"] as? String else { return nil }
                    return (id: doc.documentID, name: name,
                            avatar: data["avatarURL"] as? String ?? "",
                            isVerified: data["isVerified"] as? Bool ?? false)
                }
                allUsers.append(contentsOf: users)
            }
            followingUsers = allUsers
        } catch { followingUsers = [] }
        isLoadingUsers = false
    }
}

// MARK: - ShareSheet

struct ShareSheet: UIViewControllerRepresentable {
    let items: [Any]

    func makeUIViewController(context: Context) -> UIActivityViewController {
        UIActivityViewController(activityItems: items, applicationActivities: nil)
    }

    func updateUIViewController(_ uiViewController: UIActivityViewController, context: Context) {}
}
