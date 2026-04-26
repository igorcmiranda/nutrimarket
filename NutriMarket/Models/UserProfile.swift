import Foundation
import Combine

// MARK: - Exercise Types

enum ExerciseType: String, CaseIterable, Codable, Identifiable {
    case musculacao    = "Musculação"
    case pilates       = "Pilates"
    case corrida       = "Corrida"
    case cardio        = "Cardio"
    case hiit          = "HIIT"
    case crossfit      = "CrossFit"
    case natacao       = "Natação"
    case ciclismo      = "Ciclismo"
    case yoga          = "Yoga"
    case futebol       = "Futebol"
    case artesMarciais = "Artes Marciais"
    case misto         = "Misto"
    case nenhum        = "Nenhum / Sedentário"

    var id: String { rawValue }

    var icon: String {
        switch self {
        case .musculacao:    return "dumbbell.fill"
        case .pilates:       return "figure.pilates"
        case .corrida:       return "figure.run"
        case .cardio:        return "heart.fill"
        case .hiit:          return "bolt.fill"
        case .crossfit:      return "figure.cross.training"
        case .natacao:       return "figure.pool.swim"
        case .ciclismo:      return "bicycle"
        case .yoga:          return "figure.mind.and.body"
        case .futebol:       return "soccerball"
        case .artesMarciais: return "figure.martial.arts"
        case .misto:         return "square.grid.2x2.fill"
        case .nenhum:        return "figure.stand"
        }
    }

    var description: String {
        switch self {
        case .musculacao:    return "Treino com pesos em academia"
        case .pilates:       return "Pilates solo ou com aparelhos"
        case .corrida:       return "Corrida ao ar livre ou esteira"
        case .cardio:        return "Exercícios aeróbicos em geral"
        case .hiit:          return "Treino intervalado de alta intensidade"
        case .crossfit:      return "Treino funcional de alta intensidade"
        case .natacao:       return "Natação em piscina"
        case .ciclismo:      return "Bicicleta ou spinning"
        case .yoga:          return "Yoga e flexibilidade"
        case .futebol:       return "Futebol e esportes coletivos"
        case .artesMarciais: return "Luta, boxe, jiu-jitsu, etc."
        case .misto:         return "Combina diferentes modalidades"
        case .nenhum:        return "Sem atividade física regular"
        }
    }
}

// MARK: - Mixed Schedule (for .misto type)

struct MixedScheduleDay: Codable {
    var weekday: Int          // 0 = Segunda ... 6 = Domingo
    var exerciseType: ExerciseType

    var weekdayName: String {
        let names = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
        return names[safe: weekday] ?? "?"
    }
}

extension Array {
    subscript(safe index: Int) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}

// MARK: - UserProfile (updated)

class UserProfile: ObservableObject {

    // ── Existing fields ──────────────────────────────────────────────
    @Published var country: String { didSet { UserDefaults.standard.set(country, forKey: "country") } }
    @Published var region: String  { didSet { UserDefaults.standard.set(region,  forKey: "region")  } }
    @Published var city: String    { didSet { UserDefaults.standard.set(city,    forKey: "city")    } }
    @Published var name: String    { didSet { UserDefaults.standard.set(name,    forKey: "name")    } }
    @Published var weight: Double  { didSet { UserDefaults.standard.set(weight,  forKey: "weight")  } }
    @Published var height: Double  { didSet { UserDefaults.standard.set(height,  forKey: "height")  } }
    @Published var age: Int        { didSet { UserDefaults.standard.set(age,     forKey: "age")     } }
    @Published var sex: String     { didSet { UserDefaults.standard.set(sex,     forKey: "sex")     } }
    @Published var goal: String    { didSet { UserDefaults.standard.set(goal,    forKey: "goal")    } }

    // ── New: exercise preferences ────────────────────────────────────
    @Published var exerciseType: ExerciseType {
        didSet { UserDefaults.standard.set(exerciseType.rawValue, forKey: "exerciseType") }
    }

    /// Only used when exerciseType == .misto
    @Published var mixedSchedule: [MixedScheduleDay] {
        didSet {
            if let data = try? JSONEncoder().encode(mixedSchedule) {
                UserDefaults.standard.set(data, forKey: "mixedSchedule")
            }
        }
    }

    // ── Computed ────────────────────────────────────────────────────
    var dailyCalorieGoal: Int {
        let bmr: Double
        if sex == "Masculino" {
            bmr = 88.36 + (13.4 * weight) + (4.8 * height) - (5.7 * Double(age))
        } else {
            bmr = 447.6 + (9.2 * weight) + (3.1 * height) - (4.3 * Double(age))
        }
        switch goal {
        case "Perder peso":  return Int(bmr * 1.2 * 0.85)
        case "Ganhar massa": return Int(bmr * 1.55 * 1.15)
        default:             return Int(bmr * 1.375)
        }
    }

    /// Human-readable summary for AI prompts
    var exerciseSummaryForAI: String {
        if exerciseType == .misto && !mixedSchedule.isEmpty {
            let days = mixedSchedule
                .map { "\($0.weekdayName): \($0.exerciseType.rawValue)" }
                .joined(separator: ", ")
            return "Misto — \(days)"
        }
        return exerciseType.rawValue
    }

    // ── Init ────────────────────────────────────────────────────────
    init() {
        self.name    = UserDefaults.standard.string(forKey: "name")   ?? ""
        self.weight  = UserDefaults.standard.object(forKey: "weight") as? Double ?? 0
        self.height  = UserDefaults.standard.object(forKey: "height") as? Double ?? 0
        self.age     = UserDefaults.standard.object(forKey: "age")    as? Int    ?? 0
        self.sex     = UserDefaults.standard.string(forKey: "sex")    ?? "Masculino"
        self.goal    = UserDefaults.standard.string(forKey: "goal")   ?? "Manter peso"
        self.country = UserDefaults.standard.string(forKey: "country") ?? ""
        self.region  = UserDefaults.standard.string(forKey: "region")  ?? ""
        self.city    = UserDefaults.standard.string(forKey: "city")    ?? ""

        let exRaw = UserDefaults.standard.string(forKey: "exerciseType") ?? ""
        self.exerciseType = ExerciseType(rawValue: exRaw) ?? .musculacao

        if let data = UserDefaults.standard.data(forKey: "mixedSchedule"),
           let schedule = try? JSONDecoder().decode([MixedScheduleDay].self, from: data) {
            self.mixedSchedule = schedule
        } else {
            self.mixedSchedule = []
        }
    }

    var isComplete: Bool {
        !name.isEmpty && weight > 0 && height > 0 && age > 0
    }
}
