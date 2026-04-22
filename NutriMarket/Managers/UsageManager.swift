import Foundation
import Combine
import FirebaseFirestore
import FirebaseAuth

@MainActor
class UsageManager: ObservableObject {
    @Published var counters = UsageCounters()
    @Published var isLoading = false

    private let db = Firestore.firestore()

    // MARK: - Limites restantes

    var remainingMealsToday: Int {
        max(0, UsageLimits.maxMealsPerDay - counters.mealAnalysesToday)
    }

    var remainingDietPlansThisMonth: Int {
        max(0, UsageLimits.maxDietPlansPerMonth - counters.dietPlansThisMonth)
    }

    var remainingBodyAnalysesThisMonth: Int {
        max(0, UsageLimits.maxBodyAnalysesPerMonth - counters.bodyAnalysesThisMonth)
    }

    // MARK: - Verificações

    var canAnalyzeMeal: Bool { remainingMealsToday > 0 }
    var canGenerateDiet: Bool { remainingDietPlansThisMonth > 0 }
    var canAnalyzeBody: Bool { remainingBodyAnalysesThisMonth > 0 }

    // MARK: - Carregar contadores

    func loadCounters() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        isLoading = true

        do {
            let doc = try await db.collection("usage").document(uid).getDocument()

            if let data = doc.data() {
                // Lê os valores diretamente do dicionário — sem JSONSerialization
                var saved = UsageCounters()
                saved.mealAnalysesToday   = data["mealAnalysesToday"]   as? Int ?? 0
                saved.dietPlansThisMonth  = data["dietPlansThisMonth"]  as? Int ?? 0
                saved.bodyAnalysesThisMonth = data["bodyAnalysesThisMonth"] as? Int ?? 0

                // Converte Timestamps para Date
                saved.lastMealReset    = (data["lastMealReset"]    as? Timestamp)?.dateValue() ?? Date()
                saved.lastMonthlyReset = (data["lastMonthlyReset"] as? Timestamp)?.dateValue() ?? Date()

                // Verifica reset diário
                if !Calendar.current.isDateInToday(saved.lastMealReset) {
                    saved.mealAnalysesToday = 0
                    saved.lastMealReset = Date()
                }

                // Verifica reset mensal
                let now = Date()
                let cal = Calendar.current
                if cal.component(.month, from: saved.lastMonthlyReset) != cal.component(.month, from: now) ||
                   cal.component(.year,  from: saved.lastMonthlyReset) != cal.component(.year,  from: now) {
                    saved.dietPlansThisMonth    = 0
                    saved.bodyAnalysesThisMonth = 0
                    saved.lastMonthlyReset = now
                }

                counters = saved
                await saveCounters()

            } else {
                // Primeiro acesso
                counters = UsageCounters()
                await saveCounters()
            }
        } catch {
            // // print("Erro ao carregar contadores: \(error)")
        }

        isLoading = false
    }

    // MARK: - Incrementar uso

    func incrementMealAnalysis() async {
        counters.mealAnalysesToday += 1
        await saveCounters()
    }

    func incrementDietPlan() async {
        counters.dietPlansThisMonth += 1
        await saveCounters()
    }

    func incrementBodyAnalysis() async {
        counters.bodyAnalysesThisMonth += 1
        await saveCounters()
    }

    // MARK: - Salvar no Firestore

    func saveCounters() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            // Usa Timestamp do Firebase diretamente — não JSONSerialization
            let data: [String: Any] = [
                "mealAnalysesToday":      counters.mealAnalysesToday,
                "dietPlansThisMonth":     counters.dietPlansThisMonth,
                "bodyAnalysesThisMonth":  counters.bodyAnalysesThisMonth,
                "lastMealReset":          Timestamp(date: counters.lastMealReset),
                "lastMonthlyReset":       Timestamp(date: counters.lastMonthlyReset)
            ]
            try await db.collection("usage").document(uid).setData(data)
        } catch {
            // // print("Erro ao salvar contadores: \(error)")
        }
    }
}
