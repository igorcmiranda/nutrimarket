import Foundation

class WorkoutPlanGenerator {
    private let apiKey: String

    init(apiKey: String) { self.apiKey = apiKey }

    func generate(bodyResult: BodyAnalysisResult, profile: UserProfile) async throws -> WorkoutPlan {

        let muscles = bodyResult.muscleGroups.map { "\($0.name) (prioridade: \($0.priority))" }.joined(separator: ", ")

        let prompt = """
        Você é um personal trainer experiente especializado em musculação.
        
        Perfil do usuário:
        - Sexo: \(profile.sex), Idade: \(profile.age) anos
        - Peso: \(profile.weight)kg, Altura: \(profile.height)cm
        - Objetivo: \(profile.goal)
        - Gordura corporal estimada: \(bodyResult.fatPercentageLow)-\(bodyResult.fatPercentageHigh)%
        - Categoria: \(bodyResult.fatCategory)
        
        Músculos que precisam de mais atenção:
        \(muscles)
        
        Crie um plano de treino semanal de academia e retorne APENAS JSON válido:
        {
          "targetMuscles": ["músculo1", "músculo2"],
          "summary": "resumo do plano em 2 frases explicando a estratégia",
          "estimatedDuration": "duração estimada por sessão (ex: 60-70 minutos)",
          "difficulty": "Iniciante" ou "Intermediário" ou "Avançado",
          "weeklySchedule": [
            {
              "dayName": "Segunda-feira",
              "focus": "grupo muscular do dia",
              "restDay": false,
              "exercises": [
                {
                  "name": "nome do exercício",
                  "muscleGroup": "músculo trabalhado",
                  "sets": número de séries,
                  "reps": "repetições (ex: 8-12 ou 15)",
                  "rest": "tempo de descanso (ex: 60s)",
                  "tips": "dica de execução curta (máx 15 palavras)"
                }
              ]
            }
          ],
          "generalTips": ["dica geral 1", "dica geral 2", "dica geral 3"]
        }
        
        Regras:
        - Crie 7 dias (Segunda a Domingo)
        - Inclua pelo menos 2 dias de descanso (restDay: true, exercises: [])
        - Para dias de descanso, focus deve ser "Descanso e recuperação"
        - Priorize os músculos identificados na análise corporal
        - Para ganho de massa: 3-4 séries, 8-12 reps, descanso maior
        - Para perda de peso: 3 séries, 12-15 reps, menos descanso, mais cardio
        - Para manter: equilibre força e resistência
        - Entre 4-6 exercícios por dia de treino
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 3000,
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
              let result = try? JSONDecoder().decode(WorkoutPlan.self, from: cleanData) else {
            throw GeneratorError.parseFailed
        }

        return result
    }

    enum GeneratorError: Error {
        case requestFailed, parseFailed
    }
}
