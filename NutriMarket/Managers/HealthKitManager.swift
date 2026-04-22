import HealthKit
import Combine

@MainActor
class HealthKitManager: ObservableObject {
    @Published var todayCaloriesBurned: Double = 0
    @Published var todaySteps: Int = 0
    @Published var todayDistanceKm: Double = 0
    @Published var isAuthorized = false
    @Published var errorMessage = ""

    private let store = HKHealthStore()

    var readTypes: Set<HKObjectType> {
        [
            HKObjectType.quantityType(forIdentifier: .activeEnergyBurned)!,
            HKObjectType.quantityType(forIdentifier: .stepCount)!,
            HKObjectType.quantityType(forIdentifier: .distanceWalkingRunning)!,
            HKObjectType.workoutType()
        ]
    }

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else {
            errorMessage = "HealthKit não disponível neste dispositivo"
            return
        }

        do {
            try await store.requestAuthorization(toShare: [], read: readTypes)
            isAuthorized = true
            await loadTodayData()
        } catch {
            errorMessage = "Erro ao solicitar permissão: \(error.localizedDescription)"
        }
    }

    func loadTodayData() async {
        // Roda as 3 queries em paralelo
        async let cal = fetchTodayCalories()
        async let steps = fetchTodaySteps()
        async let dist = fetchTodayDistance()

        let (calories, stepCount, distance) = await (cal, steps, dist)

        todayCaloriesBurned = calories
        todaySteps = stepCount
        todayDistanceKm = distance
    }

    func fetchTodayCalories() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return 0 }
        return await fetchTodaySum(type: type, unit: .kilocalorie())
    }

    func fetchTodaySteps() async -> Int {
        guard let type = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return 0 }
        return Int(await fetchTodaySum(type: type, unit: .count()))
    }

    func fetchTodayDistance() async -> Double {
        guard let type = HKQuantityType.quantityType(forIdentifier: .distanceWalkingRunning) else { return 0 }
        let meters = await fetchTodaySum(type: type, unit: .meter())
        return (meters / 1000).rounded(toPlaces: 2)
    }

    private func fetchTodaySum(type: HKQuantityType, unit: HKUnit) async -> Double {
        await withCheckedContinuation { continuation in
            let now = Date()
            let startOfDay = Calendar.current.startOfDay(for: now)
            let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

            let query = HKStatisticsQuery(
                quantityType: type,
                quantitySamplePredicate: predicate,
                options: .cumulativeSum
            ) { _, result, _ in
                let value = result?.sumQuantity()?.doubleValue(for: unit) ?? 0
                continuation.resume(returning: value)
            }
            store.execute(query)
        }
    }
}
