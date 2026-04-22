import Foundation
import SwiftUI

enum TrophyType: String, Codable {
    case challengeWinner    = "challenge_winner"
    case challengeLoser     = "challenge_participation"
    case cityFirst          = "city_first"
    case regionFirst        = "region_first"
    case countryFirst       = "country_first"
    case globalFirst        = "global_first"

    var displayName: String {
        switch self {
        case .challengeWinner:   return "Vencedor de Desafio"
        case .challengeLoser:    return "Participante"
        case .cityFirst:         return "Campeão da Cidade"
        case .regionFirst:       return "Campeão do Estado"
        case .countryFirst:      return "Campeão do País"
        case .globalFirst:       return "Campeão Global"
        }
    }

    var icon: String {
        switch self {
        case .challengeWinner:   return "trophy.fill"
        case .challengeLoser:    return "medal.fill"
        case .cityFirst:         return "building.2.fill"
        case .regionFirst:       return "map.fill"
        case .countryFirst:      return "flag.fill"
        case .globalFirst:       return "globe.americas.fill"
        }
    }

    var color: Color {
        switch self {
        case .challengeWinner:   return Color(hex: "FFD700")
        case .challengeLoser:    return Color(hex: "C0C0C0")
        case .cityFirst:         return Color(hex: "CD7F32")
        case .regionFirst:       return .blue
        case .countryFirst:      return .green
        case .globalFirst:       return Color(hex: "FFD700")
        }
    }

    var animationColor: [Color] {
        switch self {
        case .globalFirst, .challengeWinner:
            return [Color(hex: "FFD700"), Color(hex: "FFA500"), Color(hex: "FFD700")]
        case .countryFirst:
            return [.green, .mint, .green]
        case .regionFirst:
            return [.blue, .cyan, .blue]
        default:
            return [Color(hex: "CD7F32"), Color(hex: "D4A574"), Color(hex: "CD7F32")]
        }
    }
}

struct Trophy: Identifiable, Codable {
    var id: String
    var type: TrophyType
    var earnedAt: Date
    var description: String
    var opponentName: String?
    var points: Double
}
