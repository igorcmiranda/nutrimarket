import Foundation

struct WorkoutPlan: Codable {
    let targetMuscles: [String]
    let weeklySchedule: [WorkoutDay]
    let generalTips: [String]
    let estimatedDuration: String
    let difficulty: String
    let summary: String
}

struct WorkoutDay: Codable, Identifiable {
    var id: UUID = UUID()
    let dayName: String
    let focus: String
    let exercises: [Exercise]
    let restDay: Bool

    enum CodingKeys: String, CodingKey {
        case dayName, focus, exercises, restDay
    }
}

struct Exercise: Codable, Identifiable {
    var id: UUID = UUID()
    let name: String
    let sets: Int
    let reps: String
    let rest: String
    let tips: String
    let muscleGroup: String

    enum CodingKeys: String, CodingKey {
        case name, sets, reps, rest, tips, muscleGroup
    }
}
