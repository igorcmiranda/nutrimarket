import SwiftUI
import FirebaseFirestore

struct HomeView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var glasses: GlassesManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var trophyManager: TrophyManager
    @Binding var showSubscription: Bool

    @State private var entries: [MealEntry] = []
    @State private var showAnalysis = false
    @State private var isAnalyzing = false
    @State private var currentResult: NutritionResponse?
    @State private var showHistory = false
    @State private var showCameraPicker = false
    @State private var cameraImage: UIImage?
    @State private var showPaywall = false
    
    @State private var showDiet = false
    @State private var showBody = false
    @State private var showWater = false
    @State private var showUsage = false

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
                    quickNavBar
                    progressCard
                    macrosSummaryCard
                    cameraCard
                    myPostsCard
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
        .navigationTitle("Perfil")
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
        .sheet(isPresented: $showDiet) {
            NavigationStack {
                DietPlanView(showSubscription: $showSubscription)
                    .environmentObject(profile)
                    .environmentObject(usageManager)
                    .environmentObject(subscriptionManager)
            }
        }
        .sheet(isPresented: $showBody) {
            NavigationStack {
                BodyAnalysisView(showSubscription: $showSubscription)
                    .environmentObject(profile)
                    .environmentObject(usageManager)
                    .environmentObject(subscriptionManager)
            }
        }
        .sheet(isPresented: $showWater) {
            NavigationStack {
                WaterView()
                    .environmentObject(profile)
            }
        }
        .sheet(isPresented: $showUsage) {
            UsageDetailView()
                .environmentObject(usageManager)
                .environmentObject(subscriptionManager)
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
            ProfileAvatarButton()
                .environmentObject(authManager)
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
    
    var quickNavBar: some View {
        HStack(spacing: 10) {
            QuickNavButton(icon: "list.bullet.clipboard.fill", label: "Dieta", color: .green) {
                showDiet = true
            }
            QuickNavButton(icon: "figure.arms.open", label: "Corpo", color: .purple) {
                showBody = true
            }
            QuickNavButton(icon: "drop.fill", label: "Água", color: .blue) {
                showWater = true
            }
            QuickNavButton(icon: "chart.bar.fill", label: "Meu uso", color: .orange) {
                showUsage = true
            }
        }
        .padding(.horizontal, 4)
    }

    var cameraCard: some View {
        VStack(spacing: 16) {

            // Header explicativo
            VStack(spacing: 8) {
                HStack(spacing: 10) {
                    ZStack {
                        Circle()
                            .fill(LinearGradient(
                                colors: [.green, .mint],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ))
                            .frame(width: 48, height: 48)
                        Image(systemName: "camera.viewfinder")
                            .font(.title2)
                            .foregroundStyle(.white)
                    }
                    VStack(alignment: .leading, spacing: 3) {
                        Text("Analisar refeição")
                            .font(.headline)
                        Text("Aponte para o prato e a IA identifica as macros e calorias automaticamente")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(2)
                    }
                }

                // Como funciona
                HStack(spacing: 12) {
                    StepBadge(number: "1", text: "Aponte a câmera", icon: "camera")
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                    StepBadge(number: "2", text: "IA analisa", icon: "brain")
                    Image(systemName: "chevron.right")
                        .font(.caption2).foregroundStyle(.secondary)
                    StepBadge(number: "3", text: "Veja as macros", icon: "chart.pie")
                }
            }
            .padding()
            .background(Color.green.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            // Botões de ação
            VStack(spacing: 10) {
                // Óculos Meta
                Button {
                    if subscriptionManager.currentPlan.canAnalyzeMeals {
                        if glasses.isStreaming {
                            glasses.stopStream()
                            speech.stop()
                        } else {
                            if !glasses.isConfigured { glasses.setup() }
                            Task { await glasses.startStream() }
                        }
                    } else {
                        showPaywall = true
                    }
                } label: {
                    HStack(spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(glasses.isStreaming
                                      ? Color.red.opacity(0.15)
                                      : Color.green.opacity(0.15))
                                .frame(width: 44, height: 44)
                            Image(systemName: glasses.isStreaming
                                  ? "stop.circle.fill" : "eyeglasses")
                                .font(.title3)
                                .foregroundStyle(glasses.isStreaming ? .red : .green)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text(glasses.isStreaming ? "Parar análise" : "Usar óculos Meta")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                if !subscriptionManager.currentPlan.canAnalyzeMeals {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(subscriptionManager.currentPlan.canAnalyzeMeals
                                 ? (glasses.isConnected ? "Óculos conectado" : glasses.statusMessage)
                                 : "Requer plano Starter ou superior")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        if glasses.isConnected && subscriptionManager.currentPlan.canAnalyzeMeals {
                            Circle().fill(.green).frame(width: 8, height: 8)
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(glasses.isStreaming ? Color.red.opacity(0.3) : Color.green.opacity(0.2),
                                    lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)

                // Câmera do celular
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
                                .font(.title3).foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 2) {
                            HStack(spacing: 6) {
                                Text("Fotografar refeição")
                                    .font(.subheadline).fontWeight(.medium)
                                    .foregroundStyle(.primary)
                                if !subscriptionManager.currentPlan.canAnalyzeMeals {
                                    Image(systemName: "lock.fill")
                                        .font(.caption2).foregroundStyle(.secondary)
                                }
                            }
                            Text(subscriptionManager.currentPlan.canAnalyzeMeals
                                 ? "Tire uma foto ou escolha da galeria"
                                 : "Requer plano Starter ou superior")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 14))
                    .overlay(
                        RoundedRectangle(cornerRadius: 14)
                            .stroke(Color.blue.opacity(0.2), lineWidth: 1)
                    )
                }
                .buttonStyle(.plain)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var myPostsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Meu perfil", systemImage: "person.crop.rectangle.stack.fill")
                .font(.headline)

            UserProfileCardView()
                .environmentObject(authManager)
                .environmentObject(feedManager)
            TrophiesView(trophies: trophyManager.trophies)
                .environmentObject(trophyManager)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
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
                await usageManager.incrementMealAnalysis()
            }
        } catch {
            // // print("Erro na análise: \(error)")
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

struct StepBadge: View {
    let number: String
    let text: String
    let icon: String

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.green)
            Text(text)
                .font(.system(size: 10))
                .fontWeight(.medium)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }
}
