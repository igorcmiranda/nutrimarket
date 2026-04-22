import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct NotificationsView: View {
    @EnvironmentObject var notificationManager: NotificationManager
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var trophyManager: TrophyManager
    @State private var selectedPost: Post? = nil
    @State private var navigateToChallenge = false
    @State private var selectedChallengeID: String? = nil
    @Binding var selectedTab: Int

    var body: some View {
        ZStack {
            Color(.systemGray6).ignoresSafeArea()

            if notificationManager.isLoading {
                ProgressView()
            } else if notificationManager.notifications.isEmpty {
                emptyView
            } else {
                List {
                    ForEach(notificationManager.notifications) { notif in
                        NotificationRow(
                            notification: notif,
                            onTap: { handleTap(notif) }
                        )
                        .environmentObject(challengeManager)
                        .environmentObject(profile)
                        .listRowInsets(EdgeInsets())
                        .listRowSeparator(.hidden)
                        .swipeActions(edge: .trailing, allowsFullSwipe: true) {
                            Button(role: .destructive) {
                                Task { await deleteNotification(notif) }
                            } label: {
                                Label("Excluir", systemImage: "trash")
                            }
                        }
                    }
                }
                .listStyle(.plain)
            }
        }
        .navigationTitle("Notificações")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if notificationManager.unreadCount > 0 {
                    Button("Marcar todas como lidas") {
                        Task { await notificationManager.markAllAsRead() }
                    }
                    .font(.caption)
                }
            }
        }
        .alert("Desafio recebido!", isPresented: $navigateToChallenge) {
            Button("OK") { navigateToChallenge = false }
        } message: {
            Text("Vá para a aba Desafio para aceitar ou recusar.")
        }
        .onAppear {
            notificationManager.startListening()
        }
        .sheet(item: $trophyManager.completedChallengeToShare) { result in
            ShareChallengeResultView(
                result: result,
                onDismiss: {
                    trophyManager.completedChallengeToShare = nil
                }
            )
            .environmentObject(feedManager)
            .environmentObject(authManager)
        }
    }

    var emptyView: some View {
        VStack(spacing: 16) {
            Image(systemName: "bell.slash")
                .font(.system(size: 52)).foregroundStyle(.secondary)
            Text("Nenhuma notificação")
                .font(.headline)
            Text("Quando alguém curtir, comentar ou te seguir, você verá aqui.")
                .font(.subheadline).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal)
        }
    }

    func handleTap(_ notif: AppNotification) {
        Task { await notificationManager.markAsRead(notif.id) }

        // Post
        if let postID = notif.postID,
           let post = feedManager.posts.first(where: { $0.id == postID }) {
            selectedPost = post
            return
        }

        // Desafio recebido — vai pra aba desafio
        if notif.type == .challengeReceived {
            selectedTab = 2
            return
        }

        // Desafio encerrado — mostra tela de resultado
        if notif.type == .challengeAccepted,
               let challengeID = notif.challengeID,
               (notif.message.contains("Competição encerrada") ||
                notif.message.contains("Você venceu") ||
                notif.message.contains("venceu com")) {
                Task {
                    await loadAndShowResult(challengeID: challengeID)
                }
                return
        }
    }
    
    func deleteNotification(_ notif: AppNotification) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await Firestore.firestore()
            .collection("notifications").document(uid)
            .collection("items").document(notif.id)
            .delete()
        notificationManager.notifications.removeAll { $0.id == notif.id }
        notificationManager.unreadCount = notificationManager.notifications.filter { !$0.read }.count
    }
    
    func loadAndShowResult(challengeID: String) async {
        let db = Firestore.firestore()
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let challengeDoc = try await db.collection("challenges")
                .document(challengeID).getDocument()
            guard let data = challengeDoc.data() else { return }
            let isGroup = data["isGroup"] as? Bool ?? false

            let participantsSnapshot = try await db.collection("challenges")
                .document(challengeID).collection("participants").getDocuments()

            var participantList: [(id: String, name: String, avatar: String, points: Double)] = []
            for pDoc in participantsSnapshot.documents {
                let pData = pDoc.data()
                participantList.append((
                    id: pDoc.documentID,
                    name: pData["userName"] as? String ?? "",
                    avatar: pData["avatarURL"] as? String ?? "",
                    points: pData["totalPoints"] as? Double ?? 0
                ))
            }

            let sorted = participantList.sorted { $0.points > $1.points }
            guard let winner = sorted.first else { return }

            let resultParticipants = sorted.enumerated().map { index, p in
                (id: p.id, name: p.name, avatar: p.avatar, points: p.points,
                 trophy: index == 0 ? TrophyType.challengeWinner : TrophyType.challengeLoser)
            }

            await MainActor.run {
                trophyManager.completedChallengeToShare = TrophyManager.CompletedChallengeResult(
                    challengeID: challengeID,
                    isGroup: isGroup,
                    participants: resultParticipants,
                    winnerName: winner.name,
                    winnerPoints: winner.points
                )
            }
        } catch {
            // // print("Erro ao carregar resultado: \(error)")
        }
    }
}

struct NotificationRow: View {
    let notification: AppNotification
    let onTap: () -> Void
    @EnvironmentObject var challengeManager: ChallengeManager
    @EnvironmentObject var profile: UserProfile
    @State private var showChallengeActions = false

    var iconColor: Color {
        switch notification.type {
        case .newLike:              return .red
        case .newComment:           return .green
        case .newFollower:          return .purple
        case .newPost:              return .blue
        case .challengeReceived:    return .orange
        case .challengeAccepted:    return Color(hex: "FFD700")
        case .newMessage:           return .white
        }
    }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 12) {
                // Avatar do remetente
                ZStack(alignment: .bottomTrailing) {
                    AvatarView(url: notification.fromUserAvatar, size: 46)
                    ZStack {
                        Circle()
                            .fill(notification.iconColor)
                            .frame(width: 22, height: 22)
                        Image(systemName: notification.icon)
                            .font(.system(size: 11, weight: .semibold))
                            .foregroundStyle(.white)
                    }
                    .offset(x: 4, y: 4)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(notification.message)
                        .font(.subheadline)
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)
                        .lineLimit(2)

                    Text(notification.createdAt.timeAgoDisplay())
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    // Botões para desafio pendente
                    if notification.type == .challengeReceived,
                       let challengeID = notification.challengeID {
                        let challenge = challengeManager.pendingChallenges.first {
                            $0.id == challengeID
                        }
                        if let challenge {
                            HStack(spacing: 8) {
                                Button {
                                    Task {
                                        await challengeManager.acceptChallenge(
                                            challenge,
                                            userProfile: profile
                                        )
                                    }
                                } label: {
                                    Text("Aceitar")
                                        .font(.caption).fontWeight(.semibold)
                                        .padding(.horizontal, 16).padding(.vertical, 6)
                                        .background(Color.green)
                                        .foregroundStyle(.white)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)

                                Button {
                                    Task {
                                        await challengeManager.declineChallenge(challenge)
                                    }
                                } label: {
                                    Text("Recusar")
                                        .font(.caption).fontWeight(.medium)
                                        .padding(.horizontal, 16).padding(.vertical, 6)
                                        .background(Color(.systemGray5))
                                        .foregroundStyle(.primary)
                                        .clipShape(Capsule())
                                }
                                .buttonStyle(.plain)
                            }
                        }
                    }
                }

                Spacer()

                // Thumbnail do post se existir
                if let mediaURL = notification.postMediaURL {
                    AsyncImage(url: URL(string: mediaURL)) { phase in
                        if case .success(let image) = phase {
                            image.resizable().scaledToFill()
                                .frame(width: 44, height: 44)
                                .clipShape(RoundedRectangle(cornerRadius: 8))
                        }
                    }
                }

                // Indicador de não lido
                if !notification.read {
                    Circle()
                        .fill(Color.blue)
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.horizontal, 12).padding(.vertical, 10)
            .background(notification.read
                ? Color(.systemBackground)
                : Color.blue.opacity(0.05))
        }
        .buttonStyle(.plain)
    }
}
