import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class ChallengeManager: ObservableObject {
    @Published var activeChallenges: [Challenge] = []
    @Published var pendingChallenges: [Challenge] = []
    @Published var leaderboard: [LeaderboardEntry] = []
    @Published var isLoading = false
    @Published var showOnLeaderboard = false

    private let db = Firestore.firestore()
    private var challengesListener: ListenerRegistration?


    func loadAll() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true
        await withTaskGroup(of: Void.self) { group in
            group.addTask { await self.loadChallenges(uid: uid) }
            group.addTask { await self.loadLeaderboard(filter: .global) }
            group.addTask { await self.loadLeaderboardPreference(uid: uid) }
        }
        isLoading = false
    }
    
    func startChallengesListener() {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        challengesListener?.remove()

        // Listener para desafios como criador
        let db = Firestore.firestore()
        db.collection("challenges")
            .whereField("challengerID", isEqualTo: uid)
            .addSnapshotListener { [weak self] _, _ in
                Task { @MainActor in await self?.loadChallenges(uid: uid) }
            }

        // Listener para desafios como convidado
        db.collection("challenges")
            .whereField("invitedIDs", arrayContains: uid)
            .addSnapshotListener { [weak self] _, _ in
                Task { @MainActor in await self?.loadChallenges(uid: uid) }
            }

        // Listener para desafios 1x1 como desafiado
        db.collection("challenges")
            .whereField("challengedID", isEqualTo: uid)
            .addSnapshotListener { [weak self] _, _ in
                Task { @MainActor in await self?.loadChallenges(uid: uid) }
            }
    }

    func stopChallengesListener() {
        challengesListener?.remove()
    }

    func loadChallenges(uid: String) async {
        do {
            // Desafios onde é o criador
            let s1 = try await db.collection("challenges")
                .whereField("challengerID", isEqualTo: uid)
                .getDocuments()

            // Desafios 1x1 onde foi desafiado
            let s2 = try await db.collection("challenges")
                .whereField("challengedID", isEqualTo: uid)
                .getDocuments()

            // Desafios em grupo onde foi convidado
            let s3 = try await db.collection("challenges")
                .whereField("invitedIDs", arrayContains: uid)
                .getDocuments()

            var seen = Set<String>()
            var all: [Challenge] = []

            for doc in (s1.documents + s2.documents + s3.documents) {
                guard seen.insert(doc.documentID).inserted else { continue }
                if var c = try? doc.data(as: Challenge.self) {
                    c.id = doc.documentID
                    all.append(c)
                }
            }

            activeChallenges = all.filter { $0.status == .active }
            pendingChallenges = all.filter {
                $0.status == .pending &&
                ($0.challengedID == uid || $0.invitedIDs.contains(uid)) &&
                $0.challengerID != uid
            }
        } catch {
            // // print("Erro ao carregar desafios: \(error)")
        }
    }

    // MARK: - Criar desafio 1x1

    func createChallenge(
        targetUserID: String,
        targetName: String,
        targetAvatar: String,
        senderName: String,
        senderAvatar: String
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let challengeID = UUID().uuidString
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        let challenge = Challenge(
            id: challengeID,
            challengerID: uid,
            challengerName: senderName,
            challengerAvatarURL: senderAvatar,
            challengedID: targetUserID,
            challengedName: targetName,
            challengedAvatarURL: targetAvatar,
            status: .pending,
            startDate: now,
            endDate: endDate,
            createdAt: now,
            isGroup: false,
            maxParticipants: 2,
            invitedIDs: [targetUserID],
            acceptedIDs: [uid]
        )

        do {
            try db.collection("challenges").document(challengeID).setData(from: challenge)
            try await db.collection("challenges").document(challengeID)
                .collection("participants").document(uid).setData([
                    "userName": senderName,
                    "avatarURL": senderAvatar,
                    "totalPoints": 0,
                    "todayPoints": 0,
                    "isVerified": false
                ])

            await NotificationManager.send(
                toUserID: targetUserID,
                type: .challengeReceived,
                fromUserID: uid,
                fromUserName: senderName,
                fromUserAvatar: senderAvatar,
                challengeID: challengeID,
                message: "\(senderName) te desafiou para um duelo de 1 mês! 🏆"
            )
        } catch {
            // // print("Erro ao criar desafio: \(error)")
        }
    }

    // MARK: - Criar desafio em grupo

    func createGroupChallenge(
        targetUserIDs: [String],
        targetUsers: [(id: String, name: String, avatar: String)],
        senderName: String,
        senderAvatar: String
    ) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let challengeID = UUID().uuidString
        let now = Date()
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: now) ?? now

        let challenge = Challenge(
            id: challengeID,
            challengerID: uid,
            challengerName: senderName,
            challengerAvatarURL: senderAvatar,
            challengedID: "",
            challengedName: "",
            challengedAvatarURL: "",
            status: .active, // começa imediatamente para quem aceitou
            startDate: now,
            endDate: endDate,
            createdAt: now,
            isGroup: true,
            maxParticipants: 20,
            invitedIDs: targetUserIDs,
            acceptedIDs: [uid]
        )

        do {
            try db.collection("challenges").document(challengeID).setData(from: challenge)

            // Criador já entra como participante
            try await db.collection("challenges").document(challengeID)
                .collection("participants").document(uid).setData([
                    "userName": senderName,
                    "avatarURL": senderAvatar,
                    "totalPoints": 0,
                    "todayPoints": 0,
                    "isVerified": false
                ])

            // Notifica todos os convidados
            for user in targetUsers {
                await NotificationManager.send(
                    toUserID: user.id,
                    type: .challengeReceived,
                    fromUserID: uid,
                    fromUserName: senderName,
                    fromUserAvatar: senderAvatar,
                    challengeID: challengeID,
                    message: "\(senderName) te convidou para uma competição em grupo! 🏆"
                )
            }
        } catch {
            // // print("Erro ao criar desafio em grupo: \(error)")
        }
    }

    // MARK: - Aceitar desafio

    func acceptChallenge(_ challenge: Challenge, userProfile: UserProfile) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            // Adiciona participante
            try await db.collection("challenges").document(challenge.id)
                .collection("participants").document(uid).setData([
                    "userName": challenge.isGroup ? userProfile.name : challenge.challengedName,
                    "avatarURL": challenge.isGroup ? "" : challenge.challengedAvatarURL,
                    "totalPoints": 0,
                    "todayPoints": 0,
                    "isVerified": false
                ])

            // Atualiza acceptedIDs e status
            var updateData: [String: Any] = [
                "acceptedIDs": FieldValue.arrayUnion([uid])
            ]

            // Para 1x1, muda status para active
            if !challenge.isGroup {
                updateData["status"] = "active"
            }

            try await db.collection("challenges").document(challenge.id)
                .updateData(updateData)

            // Notifica criador
            await NotificationManager.send(
                toUserID: challenge.challengerID,
                type: .challengeAccepted,
                fromUserID: uid,
                fromUserName: userProfile.name,
                fromUserAvatar: "",
                challengeID: challenge.id,
                message: challenge.isGroup
                    ? "\(userProfile.name) entrou na sua competição em grupo! 🔥"
                    : "\(userProfile.name) aceitou seu desafio! 🔥"
            )

            await loadChallenges(uid: uid)
        } catch {
            // // print("Erro ao aceitar desafio: \(error)")
        }
    }

    func declineChallenge(_ challenge: Challenge) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            if challenge.isGroup {
                try await db.collection("challenges").document(challenge.id)
                    .updateData(["invitedIDs": FieldValue.arrayRemove([uid])])
            } else {
                try await db.collection("challenges").document(challenge.id)
                    .updateData(["status": "declined"])
            }
            await loadChallenges(uid: uid)
        } catch {
            // // print("Erro ao recusar: \(error)")
        }
    }

    // MARK: - Progresso

    func updateDailyProgress(challengeID: String, caloriesBurned: Double, dailyGoal: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let points = PointsCalculator.calculate(caloriesBurned: caloriesBurned, dailyGoal: dailyGoal)
        let today = todayKey()

        let db = Firestore.firestore()
        let progressRef = db.collection("challenges").document(challengeID)
            .collection("participants").document(uid)
            .collection("dailyProgress").document(today)

        let participantRef = db.collection("challenges").document(challengeID)
            .collection("participants").document(uid)

        do {
            // Verifica se já tem progresso hoje
            let existing = try await progressRef.getDocument()
            let previousPoints = existing.data()?["pointsEarned"] as? Double ?? 0
            let pointsDiff = points - previousPoints

            // Salva progresso do dia
            try await progressRef.setData([
                "date": today,
                "caloriesBurned": caloriesBurned,
                "pointsEarned": points,
                "goalAtTime": dailyGoal
            ])

            // Atualiza total com incremento (muito mais rápido que re-somar tudo)
            try await participantRef.updateData([
                "totalPoints": FieldValue.increment(pointsDiff),
                "todayPoints": points,
                "todayCaloriesBurned": caloriesBurned
            ])

            await updateLeaderboardPoints(points: points)
        } catch {
            // // print("Erro ao atualizar progresso: \(error)")
        }
    }

    // MARK: - Leaderboard

    enum LeaderboardFilter { case global, country, region, city }

    func loadLeaderboard(filter: LeaderboardFilter, location: String = "") async {
        // // print("🔍 Carregando leaderboard...")
        do {
            let snapshot = try await db.collection("leaderboard")
                .whereField("showOnLeaderboard", isEqualTo: true)
                .getDocuments()

            // // print("📊 Documentos encontrados: \(snapshot.documents.count)")

            var entries = snapshot.documents.compactMap { doc -> LeaderboardEntry? in
                let data = doc.data()
                // // print("👤 \(doc.documentID): \(data)")
                guard let userName = data["userName"] as? String else { return nil }
                return LeaderboardEntry(
                    id: doc.documentID,
                    userName: userName,
                    avatarURL: data["avatarURL"] as? String ?? "",
                    isVerified: data["isVerified"] as? Bool ?? false,
                    totalPoints: data["totalPoints"] as? Double ?? 0,
                    city: data["city"] as? String ?? "",
                    region: data["region"] as? String ?? "",
                    country: data["country"] as? String ?? "",
                    showOnLeaderboard: data["showOnLeaderboard"] as? Bool ?? false
                )
            }

            // Filtra por localização no app
            switch filter {
            case .city:    entries = entries.filter { $0.city == location }
            case .region:  entries = entries.filter { $0.region == location }
            case .country: entries = entries.filter { $0.country == location }
            case .global:  break
            }

            // Ordena no app — sem precisar de índice composto
            entries.sort { $0.totalPoints > $1.totalPoints }
            for i in entries.indices { entries[i].rank = i + 1 }

            leaderboard = entries
            // // print("✅ Leaderboard final: \(entries.count) usuários")
        } catch {
            // // print("❌ Erro leaderboard: \(error)")
        }
    }

    func toggleLeaderboardVisibility(uid: String, userName: String, avatarURL: String,
                                     isVerified: Bool, city: String, region: String) async {
        showOnLeaderboard.toggle()
        let ref = db.collection("leaderboard").document(uid)
        if showOnLeaderboard {
            try? await ref.setData([
                "userName": userName, "avatarURL": avatarURL, "isVerified": isVerified,
                "totalPoints": 0, "city": city, "region": region,
                "country": "Brasil", "showOnLeaderboard": true
            ])
        } else {
            try? await ref.updateData(["showOnLeaderboard": false])
        }
        try? await db.collection("users").document(uid).updateData(["showOnLeaderboard": showOnLeaderboard])
    }

    func updateLeaderboardPoints(points: Double) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        try? await db.collection("leaderboard").document(uid).updateData(["totalPoints": points])
    }

    func loadLeaderboardPreference(uid: String) async {
        let doc = try? await db.collection("users").document(uid).getDocument()
        showOnLeaderboard = doc?.data()?["showOnLeaderboard"] as? Bool ?? false
    }

    func sendPushNotification(toUserID: String, title: String, body: String) async {
        await NotificationManager.send(
            toUserID: toUserID,
            type: .challengeReceived,
            fromUserID: Auth.auth().currentUser?.uid ?? "",
            fromUserName: "",
            fromUserAvatar: "",
            message: body
        )
    }

    func todayKey() -> String {
        let f = DateFormatter()
        f.dateFormat = "yyyy-MM-dd"
        return f.string(from: Date())
    }
}
