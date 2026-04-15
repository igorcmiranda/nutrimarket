import Foundation

class DietPlanGenerator {
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func generate(dietPlan: DietPlan, profile: UserProfile) async throws -> GeneratedDietPlan {

        let mealsText = dietPlan.mealSlots
            .filter { slot in !slot.foods.isEmpty }
            .map { slot in
                let foods = slot.foods.joined(separator: ", ")
                return "\(slot.mealType): \(foods)"
            }
            .joined(separator: "\n")

        let likedText = dietPlan.likedFoods.isEmpty
            ? "Nenhuma preferência informada"
            : dietPlan.likedFoods.joined(separator: ", ")

        let dislikedText = dietPlan.dislikedFoods.isEmpty
            ? "Nenhuma restrição informada"
            : dietPlan.dislikedFoods.joined(separator: ", ")

        let prompt = """
        Você é um nutricionista especialista em planejamento alimentar personalizado.
        
        Perfil do usuário:
        - Nome: \(profile.name)
        - Sexo: \(profile.sex), Idade: \(profile.age) anos
        - Peso: \(profile.weight)kg, Altura: \(profile.height)cm
        - Objetivo: \(profile.goal)
        - Meta calórica diária: \(profile.dailyCalorieGoal) kcal
        
        Refeições que o usuário costuma fazer:
        \(mealsText.isEmpty ? "Nenhuma informada ainda" : mealsText)
        
        Alimentos que o usuário GOSTA:
        \(likedText)
        
        Alimentos que o usuário NÃO GOSTA ou tem restrição:
        \(dislikedText)
        
        Crie um plano alimentar personalizado e retorne APENAS JSON válido:
        {
          "meals": [
            {
              "mealType": "nome da refeição",
              "time": "horário sugerido (ex: 07:00)",
              "foods": [
                {
                  "name": "nome do alimento",
                  "quantity": "quantidade com unidade (ex: 100g, 2 unidades, 1 xícara)",
                  "calories": número inteiro,
                  "protein": decimal em gramas,
                  "carbs": decimal em gramas,
                  "fat": decimal em gramas
                }
              ],
              "totalCalories": número inteiro total da refeição
            }
          ],
          "totalCalories": número inteiro total do dia,
          "totalProtein": decimal total em gramas,
          "totalCarbs": decimal total em gramas,
          "totalFat": decimal total em gramas,
          "summary": "resumo do plano em 2 frases, explicando por que é adequado para o objetivo",
          "tips": ["dica 1", "dica 2", "dica 3"]
        }
        
        Regras importantes:
        - Use alimentos que o usuário já come como base, ajustando quantidades
        - Evite completamente os alimentos que o usuário não gosta
        - Priorize alimentos que o usuário gosta quando possível
        - Ajuste as quantidades para bater com a meta calórica do objetivo
        - Para ganho de massa: superávit de ~300kcal, proteína alta (2g/kg)
        - Para perda de peso: déficit de ~400kcal, proteína alta para preservar músculo
        - Para manter: próximo da meta calculada
        - Inclua todas as refeições do dia (café, almoço, jantar e lanches)
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 2000,
            "messages": [[
                "role": "user",
                "content": prompt
            ]]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw GeneratorError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyData

        let (data, _) = try await URLSession.shared.data(for: request)

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw GeneratorError.parseFailed
        }

        let cleanText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let cleanData = cleanText.data(using: .utf8),
              let result = try? JSONDecoder().decode(GeneratedDietPlan.self, from: cleanData) else {
            throw GeneratorError.parseFailed
        }

        return result
    }

    enum GeneratorError: Error {
        case requestFailed, parseFailed
    }
}
