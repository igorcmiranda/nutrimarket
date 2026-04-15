import SwiftUI

struct HomeView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var glasses: GlassesManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @Binding var showSubscription: Bool

    @State private var entries: [MealEntry] = []
    @State private var showAnalysis = false
    @State private var isAnalyzing = false
    @State private var currentResult: NutritionResponse?
    @State private var showHistory = false
    @State private var showCameraPicker = false
    @State private var cameraImage: UIImage?
    @State private var showPaywall = false

    private let speech = SpeechManager()
    private let analyzer = NutritionAnalyzer(apiKey: Secrets.claudeAPIKey)

    var todayEntries: [MealEntry] { MealEntry.todaysEntries(entries) }
    var todayCalories: Int { todayEntries.reduce(0) { $0 + $1.calories } }
    var todayProtein: Double { todayEntries.reduce(0) { $0 + $1.protein } }
    var calorieProgress: Double {
        guard profile.dailyCalorieGoal > 0 else { return 0 }
        return min(Double(todayCalories) / Double(profile.dailyCalorieGoal), 1.0)
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    progressCard
                    macrosSummaryCard
                    usageCard
                    cameraCard
                    if !todayEntries.isEmpty {
                        recentMealsCard
                    }
                }
                .padding()
            }

            if isAnalyzing {
                analyzingOverlay
            }
        }
        .navigationTitle("Nutri-Market")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showHistory = true
                } label: {
                    Image(systemName: "clock.arrow.circlepath")
                }
            }
        }
        .sheet(isPresented: $showHistory) {
            HistoryView(entries: entries)
        }
        .sheet(isPresented: $showAnalysis) {
            if let result = currentResult {
                AnalysisView(result: result, onSave: { entry in
                    entries.append(entry)
                    saveEntries()
                    showAnalysis = false
                })
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            ImageSourcePickerView(image: $cameraImage) { image in
                Task { await handleFrame(image) }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                requiredPlan: .starter,
                featureName: "Análise de refeição",
                showSubscription: $showSubscription
            )
        }
        .onAppear {
            loadEntries()
            glasses.onFrameCaptured = { image in
                Task { await handleFrame(image) }
            }
        }
    }

    // MARK: - Cards

    var headerCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Olá, \(profile.name.isEmpty ? "usuário" : profile.name)!")
                    .font(.title2).fontWeight(.bold)
                Text(Date(), style: .date)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 48, height: 48)
                Image(systemName: "fork.knife")
                    .foregroundStyle(.white)
                    .font(.title3)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var progressCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Progresso calórico")
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Text("\(todayCalories) / \(profile.dailyCalorieGoal) kcal")
                    .font(.subheadline).foregroundStyle(.secondary)
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 6)
                        .fill(Color(.systemGray5))
                        .frame(height: 12)
                    RoundedRectangle(cornerRadius: 6)
                        .fill(LinearGradient(
                            colors: calorieProgress > 0.9 ? [.orange, .red] : [.green, .mint],
                            startPoint: .leading, endPoint: .trailing
                        ))
                        .frame(width: geo.size.width * calorieProgress, height: 12)
                        .animation(.spring(), value: calorieProgress)
                }
            }
            .frame(height: 12)

            HStack {
                Label("\(Int(calorieProgress * 100))% da meta", systemImage: "target")
                    .font(.caption).foregroundStyle(.secondary)
                Spacer()
                Text("\(profile.dailyCalorieGoal - todayCalories > 0 ? profile.dailyCalorieGoal - todayCalories : 0) kcal restantes")
                    .font(.caption).foregroundStyle(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var macrosSummaryCard: some View {
        HStack(spacing: 12) {
            MacroMiniCard(label: "Proteína", value: todayProtein, unit: "g", color: .blue)
            MacroMiniCard(label: "Carbs", value: todayEntries.reduce(0) { $0 + $1.carbs }, unit: "g", color: .orange)
            MacroMiniCard(label: "Gordura", value: todayEntries.reduce(0) { $0 + $1.fat }, unit: "g", color: .pink)
        }
    }
    
    var usageCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            Label("Uso hoje", systemImage: "chart.bar.fill")
                .font(.subheadline).fontWeight(.medium)

            HStack(spacing: 8) {
                UsageBadgeView(
                    remaining: usageManager.remainingMealsToday,
                    total: UsageLimits.maxMealsPerDay,
                    label: "Refeições\nhoje",
                    color: .green
                )
                UsageBadgeView(
                    remaining: usageManager.remainingDietPlansThisMonth,
                    total: UsageLimits.maxDietPlansPerMonth,
                    label: "Dietas\neste mês",
                    color: .orange
                )
                UsageBadgeView(
                    remaining: usageManager.remainingBodyAnalysesThisMonth,
                    total: UsageLimits.maxBodyAnalysesPerMonth,
                    label: "Análises\ncorporais",
                    color: .purple
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var cameraCard: some View {
        VStack(spacing: 12) {

            // Botão óculos
            Button {
                if subscriptionManager.currentPlan.canAnalyzeMeals {
                    if glasses.isStreaming {
                        glasses.stopStream()
                        speech.stop()
                    } else {
                        Task { await glasses.startStream() }
                    }
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(glasses.isStreaming ? Color.red.opacity(0.15) : Color.green.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: glasses.isStreaming ? "stop.circle.fill" : "eyeglasses")
                            .font(.title3)
                            .foregroundStyle(glasses.isStreaming ? .red : .green)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(glasses.isStreaming ? "Parar análise" : "Analisar com os óculos")
                            .font(.headline).foregroundStyle(.primary)
                        Text(subscriptionManager.currentPlan.canAnalyzeMeals
                             ? glasses.statusMessage
                             : "Requer plano Starter ou superior")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !subscriptionManager.currentPlan.canAnalyzeMeals {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary).font(.caption)
                    } else {
                        Circle()
                            .fill(glasses.isConnected ? Color.green : Color.gray)
                            .frame(width: 8, height: 8)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
            .buttonStyle(.plain)

            // Botão câmera do celular
            Button {
                if subscriptionManager.currentPlan.canAnalyzeMeals {
                    showCameraPicker = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 44, height: 44)
                        Image(systemName: "camera.fill")
                            .font(.title3)
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Analisar com a câmera")
                            .font(.headline).foregroundStyle(.primary)
                        Text(subscriptionManager.currentPlan.canAnalyzeMeals
                             ? "Foto agora ou da galeria"
                             : "Requer plano Starter ou superior")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !subscriptionManager.currentPlan.canAnalyzeMeals {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary).font(.caption)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
            }
            .buttonStyle(.plain)
        }
    }

    var recentMealsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Refeições de hoje")
                .font(.headline)

            ForEach(todayEntries.suffix(3).reversed()) { entry in
                HStack {
                    VStack(alignment: .leading, spacing: 2) {
                        Text(entry.mealType)
                            .font(.caption).foregroundStyle(.secondary)
                        Text(entry.description)
                            .font(.subheadline).lineLimit(1)
                    }
                    Spacer()
                    Text("\(entry.calories) kcal")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.green)
                }
                .padding(.vertical, 4)
                if entry.id != todayEntries.suffix(3).reversed().last?.id {
                    Divider()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Analisando refeição...")
                    .font(.headline).foregroundStyle(.white)
                Text("Claude está identificando os alimentos")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Lógica

    func handleFrame(_ image: UIImage) async {
        guard !isAnalyzing else { return }

        // Verifica limite de uso
        guard usageManager.canAnalyzeMeal else {
            speech.speak("Você atingiu o limite de 6 análises de refeição hoje. Volte amanhã!")
            return
        }

        isAnalyzing = true

        do {
            let result = try await analyzer.analyze(image: image, userProfile: profile)
            if result.calories > 0 {
                currentResult = result
                let audio = "\(result.description). Aproximadamente \(result.calories) calorias. Proteína: \(Int(result.protein)) gramas. \(result.tips)"
                speech.speak(audio)
                showAnalysis = true
                // Incrementa contador
                await usageManager.incrementMealAnalysis()
            }
        } catch {
            print("Erro na análise: \(error)")
        }

        isAnalyzing = false
    }

    func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: "mealEntries")
        }
    }

    func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: "mealEntries"),
           let saved = try? JSONDecoder().decode([MealEntry].self, from: data) {
            entries = saved
        }
    }
}

struct MacroMiniCard: View {
    let label: String
    let value: Double
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Text("\(Int(value))\(unit)")
                .font(.title3).fontWeight(.bold)
                .foregroundStyle(color)
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 12)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }
}
