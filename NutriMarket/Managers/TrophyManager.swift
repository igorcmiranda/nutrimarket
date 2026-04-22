import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth
import SwiftUI

@MainActor
class TrophyManager: ObservableObject {
    @Published var trophies: [Trophy] = []
    @Published var pendingTrophy: Trophy? = nil
    @Published var showTrophyAnimation = false
    @Published var completedChallengeToShare: CompletedChallengeResult? = nil

    private let db = Firestore.firestore()

    struct CompletedChallengeResult: Identifiable {
        var id: String { challengeID }
        let challengeID: String
        let isGroup: Bool
        let participants: [(id: String, name: String, avatar: String, points: Double, trophy: TrophyType)]
        let winnerName: String
        let winnerPoints: Double
    }

    func loadTrophies() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await db.collection("users").document(uid)
                .collection("trophies")
                .order(by: "earnedAt", descending: true)
                .getDocuments()
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
        } catch {
            // // print("Erro ao carregar troféus: \(error)")
        }
    }

    func awardTrophy(
        toUserID: String,
        type: TrophyType,
        description: String,
        opponentName: String? = nil,
        points: Double
    ) async {
        let trophyID = UUID().uuidString
        var data: [String: Any] = [
            "type": type.rawValue,
            "description": description,
            "points": points,
            "earnedAt": Timestamp(date: Date())
        ]
        if let opponentName { data["opponentName"] = opponentName }

        try? await db.collection("users").document(toUserID)
            .collection("trophies").document(trophyID).setData(data)

        await NotificationManager.send(
            toUserID: toUserID,
            type: .challengeAccepted,
            fromUserID: "system",
            fromUserName: "Vyro",
            fromUserAvatar: "",
            message: "Você ganhou um troféu: \(type.displayName)! 🏆"
        )

        if toUserID == Auth.auth().currentUser?.uid {
            pendingTrophy = Trophy(
                id: trophyID,
                type: type,
                earnedAt: Date(),
                description: description,
                opponentName: opponentName,
                points: points
            )
            showTrophyAnimation = true
        }
    }

    func checkExpiredChallenges() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        let now = Date()

        do {
            let snapshot = try await db.collection("challenges")
                .whereField("status", isEqualTo: "active")
                .getDocuments()

            for doc in snapshot.documents {
                let data = doc.data()
                guard let endTs = data["endDate"] as? Timestamp,
                      endTs.dateValue() <= now else { continue }

                let challengeID = doc.documentID
                let isGroup = data["isGroup"] as? Bool ?? false

                // Busca todos os participantes
                let participantsSnapshot = try? await db.collection("challenges")
                    .document(challengeID)
                    .collection("participants")
                    .getDocuments()

                guard let participantDocs = participantsSnapshot?.documents,
                      !participantDocs.isEmpty else { continue }

                // Monta lista de participantes com pontos
                var participantList: [(id: String, name: String, avatar: String, points: Double)] = []
                for pDoc in participantDocs {
                    let pData = pDoc.data()
                    participantList.append((
                        id: pDoc.documentID,
                        name: pData["userName"] as? String ?? "",
                        avatar: pData["avatarURL"] as? String ?? "",
                        points: pData["totalPoints"] as? Double ?? 0
                    ))
                }

                // Ordena por pontos
                let sorted = participantList.sorted { $0.points > $1.points }
                guard let winner = sorted.first else { continue }

                // Marca como completo
                try? await db.collection("challenges").document(challengeID)
                    .updateData(["status": "completed"])

                // Dá troféus a todos
                for (index, participant) in sorted.enumerated() {
                    let trophyType: TrophyType = index == 0 ? .challengeWinner : .challengeLoser
                    let desc = index == 0
                        ? "Venceu a competição com \(Int(participant.points)) pontos!"
                        : "Participou da competição. Vencedor: \(winner.name) com \(Int(winner.points)) pts."

                    await awardTrophy(
                        toUserID: participant.id,
                        type: trophyType,
                        description: desc,
                        opponentName: index == 0 ? nil : winner.name,
                        points: participant.points
                    )

                    // Notifica todos
                    let msg = index == 0
                        ? "🏆 Você venceu a competição com \(Int(participant.points)) pontos!"
                        : "Competição encerrada! \(winner.name) venceu com \(Int(winner.points)) pontos."

                    await NotificationManager.send(
                        toUserID: participant.id,
                        type: .challengeAccepted,
                        fromUserID: "system",
                        fromUserName: "Vyro",
                        fromUserAvatar: "",
                        challengeID: challengeID,
                        message: msg
                    )
                }

                // Prepara resultado para compartilhar (só para quem está logado)
                // Prepara resultado para compartilhar
                if participantList.contains(where: { $0.id == uid }) {
                    let resultParticipants = sorted.enumerated().map { index, p in
                        (
                            id: p.id,
                            name: p.name,
                            avatar: p.avatar,
                            points: p.points,
                            trophy: index == 0 ? TrophyType.challengeWinner : TrophyType.challengeLoser
                        )
                    }

                    completedChallengeToShare = CompletedChallengeResult(
                        challengeID: challengeID,
                        isGroup: isGroup,
                        participants: resultParticipants,
                        winnerName: winner.name,
                        winnerPoints: winner.points
                    )
                }
            }
        } catch {
            // // print("Erro ao verificar desafios expirados: \(error)")
        }
    }
}
