import Foundation

struct MealEntry: Identifiable, Codable {
    let id: UUID
    let date: Date
    let description: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let mealType: String

    init(id: UUID = UUID(), date: Date = Date(), description: String,
         calories: Int, protein: Double, carbs: Double, fat: Double, mealType: String) {
        self.id = id; self.date = date; self.description = description
        self.calories = calories; self.protein = protein
        self.carbs = carbs; self.fat = fat; self.mealType = mealType
    }

    static func todaysEntries(_ entries: [MealEntry]) -> [MealEntry] {
        let cal = Calendar.current
        return entries.filter { cal.isDateInToday($0.date) }
    }
}

// Resposta estruturada que pedimos ao Claude
struct NutritionResponse: Codable {
    let description: String
    let calories: Int
    let protein: Double
    let carbs: Double
    let fat: Double
    let fiber: Double
    let mealType: String
    let quality: String
    let tips: String
}
