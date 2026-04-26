import Foundation
import FirebaseFirestore
import SwiftUI

// MARK: - Challenge Model (updated with name + inviteLink)

struct Challenge: Identifiable, Codable {
    var id: String
    var name: String                  // ← NEW: nome do desafio
    var challengerID: String
    var challengerName: String
    var challengerAvatarURL: String
    var challengedID: String
    var challengedName: String
    var challengedAvatarURL: String
    var status: ChallengeStatus
    var startDate: Date
    var endDate: Date
    var createdAt: Date
    var isGroup: Bool = false
    var maxParticipants: Int = 2
    var invitedIDs: [String] = []
    var acceptedIDs: [String] = []
    var inviteLink: String? = nil     // ← NEW: deep link para compartilhar

    enum ChallengeStatus: String, Codable {
        case pending   = "pending"
        case active    = "active"
        case completed = "completed"
        case declined  = "declined"
    }
}

// MARK: - Unchanged models

struct ChallengeParticipant: Identifiable, Codable {
    var id: String
    var userName: String
    var avatarURL: String
    var isVerified: Bool
    var totalPoints: Double
    var dailyCalorieGoal: Double
    var todayCaloriesBurned: Double
    var todayPoints: Double

    var todayProgress: Double {
        guard dailyCalorieGoal > 0 else { return 0 }
        return min(todayCaloriesBurned / dailyCalorieGoal, 1.0)
    }
}

struct DailyProgress: Codable {
    var date: String
    var caloriesBurned: Double
    var pointsEarned: Double
    var goalAtTime: Double
}

struct LeaderboardEntry: Identifiable, Codable {
    var id: String
    var userName: String
    var avatarURL: String
    var isVerified: Bool
    var totalPoints: Double
    var city: String
    var region: String
    var country: String
    var showOnLeaderboard: Bool
    var rank: Int = 0
}

struct PointsCalculator {
    static func calculate(caloriesBurned: Double, dailyGoal: Double) -> Double {
        guard dailyGoal > 0 else { return 0 }
        let percentage = min(caloriesBurned / dailyGoal, 1.0)
        return (percentage * 100).rounded(toPlaces: 1)
    }
}

extension Double {
    func rounded(toPlaces places: Int) -> Double {
        let divisor = pow(10.0, Double(places))
        return (self * divisor).rounded() / divisor
    }
}
