import UIKit

// MARK: - Models

struct BodyAnalysisResult: Codable {
    let fatPercentageLow: Int
    let fatPercentageHigh: Int
    let fatCategory: String
    let muscleGroups: [MuscleGroup]
    let recommendation: String
}

struct MuscleGroup: Codable {
    let name: String
    let priority: String
    let tip: String
    let icon: String
}


// MARK: - Analyzer

class BodyAnalyzer {

    private let apiKey: String

    init(apiKey: String) {
        self.apiKey = apiKey
    }

    func analyze(image: UIImage, profile: UserProfile) async throws -> BodyAnalysisResult {

        guard let imageData = image.jpegData(compressionQuality: 0.8) else {
            throw AnalyzerError.imageConversionFailed
        }

        let base64 = imageData.base64EncodedString()

        let prompt = """
        Você é um personal trainer e especialista em composição corporal.

        Perfil:
        - Sexo: \(profile.sex), Idade: \(profile.age) anos
        - Peso: \(profile.weight)kg, Altura: \(profile.height)cm
        - Objetivo: \(profile.goal)

        Analise a imagem e retorne APENAS JSON válido, sem markdown, sem ```json, sem explicações:

        {
          "fatPercentageLow": número inteiro,
          "fatPercentageHigh": número inteiro,
          "fatCategory": "Atlético" ou "Fitness" ou "Aceitável" ou "Obesidade",
          "muscleGroups": [
            {
              "name": "grupo muscular",
              "priority": "Alta" ou "Média" ou "Baixa",
              "tip": "dica curta",
              "icon": "SF Symbol"
            }
          ],
          "recommendation": "até 30 palavras"
        }

        Liste entre 3 e 4 grupos musculares.
        """

        let body: [String: Any] = [
            "model": "claude-sonnet-4-20250514",
            "max_tokens": 600,
            "messages": [[
                "role": "user",
                "content": [
                    [
                        "type": "image",
                        "source": [
                            "type": "base64",
                            "media_type": "image/jpeg",
                            "data": base64
                        ]
                    ],
                    [
                        "type": "text",
                        "text": prompt
                    ]
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

        let (data, _) = try await URLSession.shared.data(for: request)

        // DEBUG: ver resposta crua
        if let rawResponse = String(data: data, encoding: .utf8) {
            // // print("🔎 Resposta API:\n", rawResponse)
        }

        guard let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              let content = json["content"] as? [[String: Any]],
              let rawText = content.first?["text"] as? String else {
            throw AnalyzerError.parseFailed
        }

        let cleanedJSON = extractJSON(from: rawText)

        guard let jsonData = cleanedJSON.data(using: .utf8) else {
            throw AnalyzerError.parseFailed
        }

        do {
            let result = try JSONDecoder().decode(BodyAnalysisResult.self, from: jsonData)
            return result
        } catch {
            // // print("❌ Erro ao decodificar:", error)
            // // print("JSON recebido:", cleanedJSON)
            throw AnalyzerError.parseFailed
        }
    }

    // MARK: - JSON Cleaner

    private func extractJSON(from text: String) -> String {

        let cleaned = text
            .replacingOccurrences(of: "```json", with: "")
            .replacingOccurrences(of: "```", with: "")
            .trimmingCharacters(in: .whitespacesAndNewlines)

        guard let start = cleaned.firstIndex(of: "{"),
              let end = cleaned.lastIndex(of: "}") else {
            return cleaned
        }

        return String(cleaned[start...end])
    }

    // MARK: - Errors

    enum AnalyzerError: Error {
        case imageConversionFailed
        case requestFailed
        case parseFailed
    }
}
