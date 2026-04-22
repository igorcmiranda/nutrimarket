import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class SubscriptionManager: ObservableObject {
    @Published var currentPlan: SubscriptionPlan = .none
    @Published var isLoading = false
    @Published var subscriptionEndDate: Date?

    private let db = Firestore.firestore()

    // Publishable key do Stripe (só para referência — não usamos direto no app)
    // A cobrança acontece pelo Payment Link

    // Payment Links de TESTE
    let starterURL  = "https://buy.stripe.com/8x2fZjgGcbx457B35FcQU01"
    let standardURL = "https://buy.stripe.com/aFaaEZgGc7gO43x9u3cQU02"
    let premiumURL  = "https://buy.stripe.com/test_28E9AT4o905z1Dw9JN7ok00"

    func loadSubscription() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        do {
            let doc = try await db.collection("subscriptions").document(uid).getDocument()
            if let data = doc.data(),
               let planRaw = data["plan"] as? String,
               let plan = SubscriptionPlan(rawValue: planRaw) {

                let endDate = (data["endDate"] as? Timestamp)?.dateValue()

                if let end = endDate, end < Date() {
                    currentPlan = .none
                    try? await db.collection("subscriptions").document(uid).updateData(["plan": "none"])
                } else {
                    currentPlan = plan
                    subscriptionEndDate = endDate
                }
            }
        } catch {
            // // print("Erro ao carregar assinatura: \(error)")
        }
        isLoading = false
    }

    func savePlan(_ plan: SubscriptionPlan, sessionID: String) async {
        // // print("💾 Tentando salvar plano: \(plan.rawValue)")
        
        guard let uid = Auth.auth().currentUser?.uid else {
            // // print("❌ Erro: usuário não autenticado")
            return
        }
        
        // // print("👤 UID do usuário: \(uid)")
        
        let endDate = Calendar.current.date(byAdding: .month, value: 1, to: Date()) ?? Date()

        do {
            try await db.collection("subscriptions").document(uid).setData([
                "plan": plan.rawValue,
                "stripeSessionID": sessionID,
                "startDate": Timestamp(date: Date()),
                "endDate": Timestamp(date: endDate),
                "updatedAt": Timestamp(date: Date())
            ])
            // // print("✅ Plano salvo no Firestore com sucesso!")
            currentPlan = plan
            subscriptionEndDate = endDate
        } catch {
            // // print("❌ Erro ao salvar no Firestore: \(error)")
        }
    }
    
    func cancelSubscription() async -> Bool {
        guard let uid = Auth.auth().currentUser?.uid else { return false }

        do {
            // Busca o ID da assinatura no Firestore
            let doc = try await db.collection("subscriptions").document(uid).getDocument()
            guard let data = doc.data(),
                  let sessionID = data["stripeSessionID"] as? String else {
                // Se não tem ID do Stripe, apenas limpa o plano local
                currentPlan = .none
                try await db.collection("subscriptions").document(uid).updateData([
                    "plan": "none",
                    "cancelledAt": Timestamp(date: Date())
                ])
                return true
            }

            // Atualiza no Firestore
            currentPlan = .none
            subscriptionEndDate = nil
            try await db.collection("subscriptions").document(uid).updateData([
                "plan": "none",
                "cancelledAt": Timestamp(date: Date())
            ])
            return true
        } catch {
            // // print("Erro ao cancelar assinatura: \(error)")
            return false
        }
    }

    func checkoutURL(for plan: SubscriptionPlan) -> URL? {
        switch plan {
        case .starter:  return URL(string: starterURL)
        case .standard: return URL(string: standardURL)
        case .premium:  return URL(string: premiumURL)
        case .none:     return nil
        }
    }
}
