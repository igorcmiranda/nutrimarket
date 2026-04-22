import SwiftUI

struct DietPlanView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @Binding var showSubscription: Bool

    @State private var dietPlan = DietPlan()
    @State private var isGenerating = false
    @State private var selectedTab = 0
    @State private var newLikedFood = ""
    @State private var newDislikedFood = ""
    @State private var showingMealEditor: MealSlot?
    @State private var showPaywall = false

    private let generator = DietPlanGenerator(apiKey: Secrets.claudeAPIKey)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Picker("", selection: $selectedTab) {
                    Text("Minha dieta").tag(0)
                    Text("Preferências").tag(1)
                    Text("Plano IA").tag(2)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0: myDietTab
                        case 1: preferencesTab
                        default: generatedPlanTab
                        }
                    }
                    .padding(.horizontal)
                    .padding(.bottom, 100)
                }
            }

            VStack {
                Spacer()
                generateButton
                    .padding()
                    .background(.ultraThinMaterial)
            }

            if isGenerating {
                generatingOverlay
            }
        }
        .navigationTitle("Minha dieta")
        .navigationBarTitleDisplayMode(.inline)
        .sheet(item: $showingMealEditor) { slot in
            MealEditorView(slot: slot) { updatedSlot in
                if let index = dietPlan.mealSlots.firstIndex(where: { $0.id == updatedSlot.id }) {
                    dietPlan.mealSlots[index] = updatedSlot
                    saveDietPlan()
                }
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                requiredPlan: .standard,
                featureName: "Dieta personalizada por IA",
                showSubscription: $showSubscription
            )
        }
        .onAppear { loadDietPlan() }
    }

    // MARK: - Tab 1: Minha dieta

    var myDietTab: some View {
        VStack(spacing: 12) {
            HStack(spacing: 10) {
                Image(systemName: "info.circle.fill")
                    .foregroundStyle(.blue)
                Text("Adicione o que você costuma comer em cada refeição. A IA vai ajustar as quantidades para o seu objetivo.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.blue.opacity(0.06))
            .clipShape(RoundedRectangle(cornerRadius: 12))

            ForEach($dietPlan.mealSlots) { $slot in
                MealSlotCard(slot: slot) {
                    showingMealEditor = slot
                }
            }
        }
    }

    // MARK: - Tab 2: Preferências

    var preferencesTab: some View {
        VStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 12) {
                Label("Alimentos que gosto", systemImage: "heart.fill")
                    .font(.headline).foregroundStyle(.green)

                HStack {
                    TextField("Ex: frango, arroz, banana...", text: $newLikedFood)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addLikedFood() }
                    Button("Adicionar", action: addLikedFood)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }

                if dietPlan.likedFoods.isEmpty {
                    Text("Nenhum alimento adicionado ainda")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    FlowLayout(items: dietPlan.likedFoods) { food in
                        HStack(spacing: 4) {
                            Text(food).font(.caption)
                            Button {
                                dietPlan.likedFoods.removeAll { $0 == food }
                                saveDietPlan()
                            } label: {
                                Image(systemName: "xmark").font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.green.opacity(0.12))
                        .foregroundStyle(.green)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 12) {
                Label("Não gosto ou tenho restrição", systemImage: "xmark.circle.fill")
                    .font(.headline).foregroundStyle(.red)

                HStack {
                    TextField("Ex: brócolis, leite, amendoim...", text: $newDislikedFood)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addDislikedFood() }
                    Button("Adicionar", action: addDislikedFood)
                        .buttonStyle(.borderedProminent)
                        .tint(.red)
                }

                if dietPlan.dislikedFoods.isEmpty {
                    Text("Nenhuma restrição adicionada ainda")
                        .font(.caption).foregroundStyle(.secondary)
                } else {
                    FlowLayout(items: dietPlan.dislikedFoods) { food in
                        HStack(spacing: 4) {
                            Text(food).font(.caption)
                            Button {
                                dietPlan.dislikedFoods.removeAll { $0 == food }
                                saveDietPlan()
                            } label: {
                                Image(systemName: "xmark").font(.caption2)
                            }
                        }
                        .padding(.horizontal, 10).padding(.vertical, 5)
                        .background(Color.red.opacity(0.12))
                        .foregroundStyle(.red)
                        .clipShape(Capsule())
                    }
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
        }
    }

    // MARK: - Tab 3: Plano gerado

    var generatedPlanTab: some View {
        VStack(spacing: 16) {
            if let plan = dietPlan.generatedPlan {
                VStack(spacing: 12) {
                    HStack {
                        Text("Total do dia").font(.headline)
                        Spacer()
                        Text("\(plan.totalCalories) kcal")
                            .font(.headline).foregroundStyle(.green)
                    }
                    HStack(spacing: 12) {
                        MacroChip(label: "Proteína", value: plan.totalProtein, color: .blue)
                        MacroChip(label: "Carbs",    value: plan.totalCarbs,   color: .orange)
                        MacroChip(label: "Gordura",  value: plan.totalFat,     color: .pink)
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                HStack(alignment: .top, spacing: 10) {
                    Image(systemName: "brain.head.profile").foregroundStyle(.purple)
                    Text(plan.summary).font(.subheadline).foregroundStyle(.secondary)
                }
                .padding()
                .background(Color.purple.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 16))

                ForEach(plan.meals) { meal in
                    GeneratedMealCard(meal: meal)
                }

                VStack(alignment: .leading, spacing: 10) {
                    Label("Dicas do nutricionista", systemImage: "lightbulb.fill")
                        .font(.headline).foregroundStyle(.yellow)
                    ForEach(plan.tips, id: \.self) { tip in
                        HStack(alignment: .top, spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green).font(.caption).padding(.top, 2)
                            Text(tip).font(.subheadline).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
                .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                if let date = dietPlan.lastGenerated {
                    Text("Gerado em \(date.formatted(date: .abbreviated, time: .shortened))")
                        .font(.caption2).foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            } else {
                VStack(spacing: 16) {
                    Image(systemName: "brain.head.profile")
                        .font(.system(size: 48))
                        .foregroundStyle(.purple.opacity(0.5))
                    Text("Nenhum plano gerado ainda").font(.headline)
                    Text("Preencha sua dieta e preferências nas outras abas, depois toque em \"Gerar plano\".")
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding(32)
                .frame(maxWidth: .infinity)
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
        }
    }

    // MARK: - Botão gerar

    var generateButton: some View {
        VStack(spacing: 8) {
            if !usageManager.canGenerateDiet {
                HStack(spacing: 6) {
                    Image(systemName: "exclamationmark.circle.fill")
                        .foregroundStyle(.orange)
                    Text("Limite mensal de geração de dieta atingido")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding(.horizontal)
            }

            Button {
                if subscriptionManager.currentPlan.canGenerateDiet {
                    if usageManager.canGenerateDiet {
                        Task { await generatePlan() }
                    }
                } else {
                    showPaywall = true
                }
            } label: {
                HStack {
                    Image(systemName: "brain.head.profile")
                    Text(dietPlan.generatedPlan == nil ? "Gerar plano alimentar" : "Regenerar plano")
                        .fontWeight(.medium)
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    (!subscriptionManager.currentPlan.canGenerateDiet || !usageManager.canGenerateDiet)
                    ? LinearGradient(colors: [.gray.opacity(0.5), .gray.opacity(0.3)], startPoint: .leading, endPoint: .trailing)
                    : LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(isGenerating || !usageManager.canGenerateDiet)
        }
    }

    var generatingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text("Criando seu plano alimentar...")
                    .font(.headline).foregroundStyle(.white)
                Text("A IA está calculando as quantidades ideais")
                    .font(.caption).foregroundStyle(.white.opacity(0.8))
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 20))
        }
    }

    // MARK: - Lógica

    func addLikedFood() {
        let food = newLikedFood.trimmingCharacters(in: .whitespaces)
        guard !food.isEmpty, !dietPlan.likedFoods.contains(food) else { return }
        dietPlan.likedFoods.append(food)
        newLikedFood = ""
        saveDietPlan()
    }

    func addDislikedFood() {
        let food = newDislikedFood.trimmingCharacters(in: .whitespaces)
        guard !food.isEmpty, !dietPlan.dislikedFoods.contains(food) else { return }
        dietPlan.dislikedFoods.append(food)
        newDislikedFood = ""
        saveDietPlan()
    }

    func generatePlan() async {
        guard usageManager.canGenerateDiet else {
            // // print("Limite de dietas atingido")
            return
        }

        isGenerating = true
        do {
            let plan = try await generator.generate(dietPlan: dietPlan, profile: profile)
            dietPlan.generatedPlan = plan
            dietPlan.lastGenerated = Date()
            saveDietPlan()
            await usageManager.incrementDietPlan()
            selectedTab = 2
        } catch {
            // // print("Erro ao gerar plano: \(error)")
        }
        isGenerating = false
    }

    func saveDietPlan() {
        if let data = try? JSONEncoder().encode(dietPlan) {
            UserDefaults.standard.set(data, forKey: "dietPlan")
        }
    }

    func loadDietPlan() {
        if let data = UserDefaults.standard.data(forKey: "dietPlan"),
           let saved = try? JSONDecoder().decode(DietPlan.self, from: data) {
            dietPlan = saved
        }
    }
}

// MARK: - Sub-components

struct MealSlotCard: View {
    let slot: MealSlot
    let onTap: () -> Void

    var mealType: MealType? { MealType(rawValue: slot.mealType) }

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: mealType?.icon ?? "fork.knife")
                        .foregroundStyle(.green)
                }
                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(slot.mealType).font(.subheadline).fontWeight(.medium)
                        Spacer()
                        Text(mealType?.suggestedTime ?? "").font(.caption).foregroundStyle(.secondary)
                    }
                    Text(slot.foods.isEmpty ? "Toque para adicionar alimentos" : slot.foods.joined(separator: ", "))
                        .font(.caption).foregroundStyle(.secondary).lineLimit(2)
                }
                Image(systemName: "chevron.right").font(.caption).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 14))
            .shadow(color: .black.opacity(0.05), radius: 6, y: 2)
        }
        .buttonStyle(.plain)
    }
}

struct GeneratedMealCard: View {
    let meal: GeneratedMeal
    @State private var isExpanded = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                withAnimation(.spring(duration: 0.3)) { isExpanded.toggle() }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(meal.mealType).font(.subheadline).fontWeight(.medium).foregroundStyle(.primary)
                        Text(meal.time).font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Text("\(meal.totalCalories) kcal").font(.subheadline).fontWeight(.medium).foregroundStyle(.green)
                    Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                        .font(.caption).foregroundStyle(.secondary).padding(.leading, 4)
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded {
                Divider().padding(.horizontal)
                ForEach(meal.foods) { food in
                    HStack {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(food.name).font(.subheadline)
                            Text(food.quantity).font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        VStack(alignment: .trailing, spacing: 2) {
                            Text("\(food.calories) kcal").font(.caption).fontWeight(.medium)
                            HStack(spacing: 6) {
                                Text("P:\(Int(food.protein))g")
                                Text("C:\(Int(food.carbs))g")
                                Text("G:\(Int(food.fat))g")
                            }
                            .font(.caption2).foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal).padding(.vertical, 8)
                    Divider().padding(.horizontal)
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

struct MacroChip: View {
    let label: String
    let value: Double
    let color: Color

    var body: some View {
        VStack(spacing: 2) {
            Text("\(Int(value))g").font(.subheadline).fontWeight(.bold).foregroundStyle(color)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .background(color.opacity(0.08))
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }
}

struct FlowLayout<Content: View>: View {
    let items: [String]
    let content: (String) -> Content

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 80))], alignment: .leading, spacing: 6) {
            ForEach(items, id: \.self) { item in content(item) }
        }
    }
}
