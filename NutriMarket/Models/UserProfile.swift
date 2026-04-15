import Foundation
import Combine

class UserProfile: ObservableObject {
    @Published var name: String {
        didSet { UserDefaults.standard.set(name, forKey: "name") }
    }
    @Published var weight: Double {
        didSet { UserDefaults.standard.set(weight, forKey: "weight") }
    }
    @Published var height: Double {
        didSet { UserDefaults.standard.set(height, forKey: "height") }
    }
    @Published var age: Int {
        didSet { UserDefaults.standard.set(age, forKey: "age") }
    }
    @Published var sex: String {
        didSet { UserDefaults.standard.set(sex, forKey: "sex") }
    }
    @Published var goal: String {
        didSet { UserDefaults.standard.set(goal, forKey: "goal") }
    }

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

    init() {
        self.name   = UserDefaults.standard.string(forKey: "name") ?? ""
        self.weight = UserDefaults.standard.object(forKey: "weight") as? Double ?? 0
        self.height = UserDefaults.standard.object(forKey: "height") as? Double ?? 0
        self.age    = UserDefaults.standard.object(forKey: "age") as? Int ?? 0
        self.sex    = UserDefaults.standard.string(forKey: "sex")  ?? "Masculino"
        self.goal   = UserDefaults.standard.string(forKey: "goal") ?? "Manter peso"
    }

    var isComplete: Bool {
        !name.isEmpty && weight > 0 && height > 0 && age > 0
    }
}
