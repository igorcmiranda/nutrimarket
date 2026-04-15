import Foundation

struct MealSlot: Identifiable, Codable {
    let id: UUID
    var mealType: String
    var foods: [String]
    var notes: String

    init(id: UUID = UUID(), mealType: String, foods: [String] = [], notes: String = "") {
        self.id = id
        self.mealType = mealType
        self.foods = foods
        self.notes = notes
    }
}

struct DietPlan: Codable {
    var mealSlots: [MealSlot]
    var likedFoods: [String]
    var dislikedFoods: [String]
    var generatedPlan: GeneratedDietPlan?
    var lastGenerated: Date?

    init() {
        self.mealSlots = MealType.allCases.map { MealSlot(mealType: $0.rawValue) }
        self.likedFoods = []
        self.dislikedFoods = []
    }
}

enum MealType: String, CaseIterable, Codable {
    case breakfast    = "Café da manhã"
    case morningSnack = "Lanche da manhã"
    case lunch        = "Almoço"
    case afternoonCoffee = "Café da tarde"
    case afternoonSnack  = "Lanche da tarde"
    case dinner       = "Jantar"
    case supper       = "Ceia"

    var icon: String {
        switch self {
        case .breakfast:       return "sunrise.fill"
        case .morningSnack:    return "cup.and.saucer.fill"
        case .lunch:           return "fork.knife"
        case .afternoonCoffee: return "mug.fill"
        case .afternoonSnack:  return "frying.pan"
        case .dinner:          return "moon.fill"
        case .supper:          return "zzz"
        }
    }

    var suggestedTime: String {
        switch self {
        case .breakfast:       return "07:00"
        case .morningSnack:    return "10:00"
        case .lunch:           return "12:30"
        case .afternoonCoffee: return "15:00"
        case .afternoonSnack:  return "16:30"
        case .dinner:          return "19:00"
        case .supper:          return "21:30"
        }
    }
}

struct GeneratedDietPlan: Codable {
    let meals: [GeneratedMeal]
    let totalCalories: Int
    let totalProtein: Double
    let totalCarbs: Double
    let totalFat: Double
    let summary: String
    let tips: [String]
}

struct GeneratedMeal: Codable, Identifiable {
    var id: UUID = UUID()
    let mealType: String
    let time: String
    let foods: [GeneratedFood]
    let totalCalories: Int

    enum CodingKeys: String, CodingKey {
        case mealType, time, foods, totalCalories
    }
}

struct GeneratedFood: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let quantity: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double

    enum CodingKeys: String, CodingKey {
        case name, quantity, calories, protein, carbs, fat
    }
}
