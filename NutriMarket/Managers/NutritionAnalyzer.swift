#if canImport(UIKit)
import UIKit

class NutritionAnalyzer {
    private let apiKey: String
    
    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyze(image: UIImage, userProfile: UserProfile) async throws -> NutritionResponse {
        guard let imageData = image.jpegData(compressionQuality: 0.75) else {
            throw AnalyzerError.imageConversionFailed
        }
        let base64 = imageData.base64EncodedString()

        let prompt = """
        Você é um nutricionista especialista em análise visual de alimentos.
        
        Perfil do usuário:
        - Peso: \(userProfile.weight)kg, Altura: \(userProfile.height)cm, Idade: \(userProfile.age) anos
        - Sexo: \(userProfile.sex), Objetivo: \(userProfile.goal)
        - Meta calórica diária: \(userProfile.dailyCalorieGoal) kcal
        
        Analise a imagem e responda APENAS com JSON válido, sem texto antes ou depois, sem markdown, sem backticks:
        {"description":"descrição do que você vê (máx 20 palavras)","calories":número inteiro estimado de kcal,"protein":gramas de proteína,"carbs":gramas de carboidratos,"fat":gramas de gordura,"fiber":gramas de fibra,"mealType":"Café da manhã ou Almoço ou Jantar ou Lanche ou Produto","quality":"Excelente ou Boa ou Regular ou Ruim","tips":"dica personalizada curta (máx 20 palavras)"}
        
        Se não conseguir identificar alimentos, retorne: {"description":"Não foi possível identificar alimentos","calories":0,"protein":0,"carbs":0,"fat":0,"fiber":0,"mealType":"Lanche","quality":"Regular","tips":"Tente fotografar mais de perto"}
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 400,
            "messages": [[
                "role": "user",
                "content": [
                    ["type": "image", "source": [
                        "type": "base64",
                        "media_type": "image/jpeg",
                        "data": base64
                    ]],
                    ["type": "text", "text": prompt]
                ]
            ]]
        ]

        guard let url = URL(string: "https://api.anthropic.com/v1/messages"),
              let bodyData = try? JSONSerialization.data(withJSONObject: body) else {
            throw AnalyzerError.requestFailed
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(apiKey, forHTTPHeaderField: "x-api-key")
        request.setValue("2023-06-01", forHTTPHeaderField: "anthropic-version")
        request.httpBody = bodyData

        let (data, response) = try await URLSession.shared.data(for: request)

        // Log para debug
        if let httpResponse = response as? HTTPURLResponse {
            // // print("Status HTTP: \(httpResponse.statusCode)")
        }
        if let rawString = String(data: data, encoding: .utf8) {
            // // print("Resposta bruta: \(rawString)")
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let text = content.first?["text"] as? String else {
            throw AnalyzerError.parseFailed
        }

        // // print("Texto do Claude: \(text)")

        // Remove markdown se vier
        let cleanText = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        // Tenta extrair JSON se vier com texto em volta
        let jsonText: String
        if let start = cleanText.firstIndex(of: "{"),
           let end = cleanText.lastIndex(of: "}") {
            jsonText = String(cleanText[start...end])
        } else {
            jsonText = cleanText
        }

        // // print("JSON limpo: \(jsonText)")

        guard let jsonData = jsonText.data(using: .utf8),
              let result = try? JSONDecoder().decode(NutritionResponse.self, from: jsonData) else {
            throw AnalyzerError.parseFailed
        }

        return result
    }

    enum AnalyzerError: Error {
        case imageConversionFailed, requestFailed, parseFailed
    }
}
#endif
