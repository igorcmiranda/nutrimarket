import Foundation
import SwiftUI

enum SubscriptionPlan: String, Codable {
    case none     = "none"
    case starter  = "starter"
    case standard = "standard"
    case premium  = "premium"

    var displayName: String {
        switch self {
        case .none:     return "Sem plano"
        case .starter:  return "Starter"
        case .standard: return "Standard"
        case .premium:  return "Premium"
        }
    }

    var price: String {
        switch self {
        case .none:     return "Grátis"
        case .starter:  return "R$ 19,97/mês"
        case .standard: return "R$ 29,97/mês"
        case .premium:  return "R$ 49,97/mês"
        }
    }

    var color: Color {
        switch self {
        case .none:     return .gray
        case .starter:  return .blue
        case .standard: return .green
        case .premium:  return .purple
        }
    }

    var icon: String {
        switch self {
        case .none:     return "person.circle"
        case .starter:  return "star"
        case .standard: return "star.leadinghalf.filled"
        case .premium:  return "crown.fill"
        }
    }

    var features: [PlanFeature] {
        switch self {
        case .none:
            return [
                PlanFeature(name: "Criar conta e perfil", included: true),
                PlanFeature(name: "Cadastrar dieta do dia a dia", included: true),
                PlanFeature(name: "Análise de refeição por foto", included: false),
                PlanFeature(name: "Dieta personalizada por IA", included: false),
                PlanFeature(name: "Análise corporal por IA", included: false),
                PlanFeature(name: "Plano de treino personalizado", included: false),
            ]
        case .starter:
            return [
                PlanFeature(name: "Criar conta e perfil", included: true),
                PlanFeature(name: "Cadastrar dieta do dia a dia", included: true),
                PlanFeature(name: "Análise de refeição por foto", included: true),
                PlanFeature(name: "Dieta personalizada por IA", included: false),
                PlanFeature(name: "Análise corporal por IA", included: false),
                PlanFeature(name: "Plano de treino personalizado", included: false),
            ]
        case .standard:
            return [
                PlanFeature(name: "Criar conta e perfil", included: true),
                PlanFeature(name: "Cadastrar dieta do dia a dia", included: true),
                PlanFeature(name: "Análise de refeição por foto", included: true),
                PlanFeature(name: "Dieta personalizada por IA", included: true),
                PlanFeature(name: "Análise corporal por IA", included: false),
                PlanFeature(name: "Plano de treino personalizado", included: false),
            ]
        case .premium:
            return [
                PlanFeature(name: "Criar conta e perfil", included: true),
                PlanFeature(name: "Cadastrar dieta do dia a dia", included: true),
                PlanFeature(name: "Análise de refeição por foto", included: true),
                PlanFeature(name: "Dieta personalizada por IA", included: true),
                PlanFeature(name: "Análise corporal por IA", included: true),
                PlanFeature(name: "Plano de treino personalizado", included: true),
            ]
        }
    }

    // MARK: - Permissões por plano

    /// Starter, Standard e Premium podem analisar refeições por foto
    var canAnalyzeMeals: Bool {
        self == .starter || self == .standard || self == .premium
    }

    /// Standard e Premium podem gerar dieta personalizada por IA
    var canGenerateDiet: Bool {
        self == .standard || self == .premium
    }

    /// Somente Premium pode fazer análise corporal
    var canAnalyzeBody: Bool {
        self == .premium
    }

    /// Somente Premium pode gerar plano de treino
    var canGenerateWorkout: Bool {
        self == .premium
    }
}

struct PlanFeature: Identifiable {
    let id = UUID()
    let name: String
    let included: Bool
}
