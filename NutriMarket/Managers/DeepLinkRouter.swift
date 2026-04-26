// ============================================================
// MARK: - Deep Link para Convite de Desafio
// SEM Firebase Dynamic Links (descontinuado)
// Estratégia: Cloud Function redirect + URL scheme nativo
// ============================================================

/*
 ──────────────────────────────────────────────────────────────
 COMO FUNCIONA:
 
 1. O link gerado é uma URL da sua Cloud Function:
    https://us-central1-nutrimarket.cloudfunctions.net/joinChallenge?id=<challengeID>

 2. Quando o destinatário clica:
    → App instalado: iOS abre pelo URL scheme "nutrimarket://"
    → App NÃO instalado: Cloud Function redireciona para App Store

 3. Ao abrir o app, o URL scheme é capturado pelo .onOpenURL
    e o DeepLinkRouter processa o challengeID.
 ──────────────────────────────────────────────────────────────
*/

import Foundation
import FirebaseFirestore
import FirebaseAuth

// MARK: - DeepLinkRouter

final class DeepLinkRouter {

    static var pendingChallengeID: String? = nil

    /// Gera o link de convite para um desafio
    /// Formato: https://us-central1-nutrimarket.cloudfunctions.net/joinChallenge?id=<id>
    static func inviteURL(for challengeID: String) -> URL? {
        var components = URLComponents()
        components.scheme = "https"
        components.host = "us-central1-nutrimarket.cloudfunctions.net"
        components.path = "/joinChallenge"
        components.queryItems = [URLQueryItem(name: "id", value: challengeID)]
        return components.url
    }

    /// Mensagem de convite completa para compartilhar
    static func inviteMessage(challengeName: String, challengeID: String) -> String {
        let url = inviteURL(for: challengeID)?.absoluteString ?? ""
        return """
        💪 Entrei no desafio "\(challengeName)" no Vyro!
        
        Baixe o app e aceite meu convite:
        \(url)
        """
    }

    /// Processa uma URL recebida via .onOpenURL ou application(_:open:options:)
    /// Suporta:
    ///   nutrimarket://challenge?id=xxx   (URL scheme direto)
    ///   https://.../joinChallenge?id=xxx (universal link / redirect)
    static func handle(url: URL) {
        let components = URLComponents(url: url, resolvingAgainstBaseURL: true)
        guard let challengeID = components?.queryItems?.first(where: { $0.name == "id" })?.value,
              !challengeID.isEmpty else { return }

        pendingChallengeID = challengeID

        DispatchQueue.main.async {
            NotificationCenter.default.post(
                name: .openChallengeInvite,
                object: nil,
                userInfo: ["challengeID": challengeID]
            )
        }
    }
}

extension Notification.Name {
    static let openChallengeInvite = Notification.Name("openChallengeInvite")
}

// MARK: - ChallengeManager extension (adicionar ao arquivo existente)

extension ChallengeManager {

    /// Chamado após login ou ao receber deep link para adicionar o usuário como convidado
    func processPendingDeepLink() async {
        guard let uid = Auth.auth().currentUser?.uid,
              let cid = DeepLinkRouter.pendingChallengeID else { return }

        DeepLinkRouter.pendingChallengeID = nil

        do {
            let doc = try await db.collection("challenges").document(cid).getDocument()
            guard doc.exists, let data = doc.data() else { return }

            let acceptedIDs = data["acceptedIDs"] as? [String] ?? []
            let invitedIDs  = data["invitedIDs"]  as? [String] ?? []

            // Não faz nada se já é participante ou já foi convidado
            guard !acceptedIDs.contains(uid), !invitedIDs.contains(uid) else {
                await loadChallenges(uid: uid)
                return
            }

            // Adiciona como convidado → vai aparecer em "pendentes"
            try await db.collection("challenges").document(cid).updateData([
                "invitedIDs": FieldValue.arrayUnion([uid])
            ])

            await loadChallenges(uid: uid)
        } catch {
            // Desafio não encontrado ou expirado — silencioso
        }
    }
}
