import Foundation

struct UsageCounters: Codable {
    var mealAnalysesToday: Int
    var dietPlansThisMonth: Int
    var bodyAnalysesThisMonth: Int
    var lastMealReset: Date
    var lastMonthlyReset: Date

    init() {
        self.mealAnalysesToday = 0
        self.dietPlansThisMonth = 0
        self.bodyAnalysesThisMonth = 0
        self.lastMealReset = Date()
        self.lastMonthlyReset = Date()
    }
}

struct UsageLimits {
    static let maxMealsPerDay = 6
    static let maxDietPlansPerMonth = 1
    static let maxBodyAnalysesPerMonth = 2
}
