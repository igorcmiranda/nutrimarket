import SwiftUI

struct BodyAnalysisView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var glasses: GlassesManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var usageManager: UsageManager
    @Binding var showSubscription: Bool

    @State private var isAnalyzing = false
    @State private var result: BodyAnalysisResult?
    @State private var showDisclaimer = true
    @State private var showCameraPicker = false
    @State private var cameraImage: UIImage?
    @State private var workoutPlan: WorkoutPlan?
    @State private var showWorkoutPlan = false
    @State private var isGeneratingWorkout = false
    @State private var showPaywall = false

    private let speech = SpeechManager()
    private let analyzer = BodyAnalyzer(apiKey: Secrets.claudeAPIKey)
    private let workoutGenerator = WorkoutPlanGenerator(apiKey: Secrets.claudeAPIKey)

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 20) {
                    if showDisclaimer {
                        disclaimerCard
                    } else {
                        instructionsCard
                        cameraCard
                        if let result {
                            resultCard(result)
                        }
                    }
                }
                .padding()
            }

            if isAnalyzing || isGeneratingWorkout {
                analyzingOverlay
            }
        }
        .navigationTitle("Análise corporal")
        .navigationBarTitleDisplayMode(.inline)
        .onAppear {
            glasses.onFrameCaptured = { image in
                Task { await handleFrame(image) }
            }
        }
        .sheet(isPresented: $showCameraPicker) {
            ImageSourcePickerView(image: $cameraImage) { image in
                Task { await handleFrame(image) }
            }
        }
        .sheet(isPresented: $showWorkoutPlan) {
            if let plan = workoutPlan {
                WorkoutPlanView(plan: plan)
            }
        }
        .sheet(isPresented: $showPaywall) {
            PaywallView(
                requiredPlan: .premium,
                featureName: "Análise corporal por IA",
                showSubscription: $showSubscription
            )
        }
    }

    // MARK: - Sub-views

    var disclaimerCard: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle.fill")
                .font(.system(size: 40))
                .foregroundStyle(.orange)

            Text("Aviso importante")
                .font(.title3).fontWeight(.bold)

            Text("Esta análise é uma estimativa visual aproximada baseada em inteligência artificial. Não substitui avaliação médica ou de profissional de educação física.")
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            Button {
                showDisclaimer = false
            } label: {
                Text("Entendi, continuar")
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.orange)
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 14))
            }
        }
        .padding(24)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var instructionsCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Como usar", systemImage: "info.circle.fill")
                .font(.headline)
                .foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                InstructionRow(number: "1", text: "Fique em frente a um espelho com boa iluminação")
                InstructionRow(number: "2", text: "Use roupas justas ou sem camisa para melhor precisão")
                InstructionRow(number: "3", text: "Use os óculos ou a câmera do celular para capturar")
                InstructionRow(number: "4", text: "Aguarde a IA analisar a imagem")
            }
        }
        .padding()
        .background(Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 16))
    }

    var cameraCard: some View {
        VStack(spacing: 12) {

            // Botão óculos
            Button {
                if subscriptionManager.currentPlan.canAnalyzeBody {
                    if glasses.isStreaming {
                        glasses.stopStream()
                    } else {
                        Task { await glasses.startStream() }
                    }
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(glasses.isStreaming ? Color.red.opacity(0.15) : Color.purple.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: glasses.isStreaming ? "stop.circle.fill" : "eyeglasses")
                            .font(.title2)
                            .foregroundStyle(glasses.isStreaming ? .red : .purple)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text(glasses.isStreaming ? "Parar câmera dos óculos" : "Usar óculos Meta")
                            .font(.headline).foregroundStyle(.primary)
                        Text(glasses.statusMessage)
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !subscriptionManager.currentPlan.canAnalyzeBody {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
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
                if subscriptionManager.currentPlan.canAnalyzeBody {
                    showCameraPicker = true
                } else {
                    showPaywall = true
                }
            } label: {
                HStack(spacing: 14) {
                    ZStack {
                        Circle()
                            .fill(Color.blue.opacity(0.15))
                            .frame(width: 48, height: 48)
                        Image(systemName: "camera.fill")
                            .font(.title2)
                            .foregroundStyle(.blue)
                    }
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Usar câmera do celular")
                            .font(.headline).foregroundStyle(.primary)
                        Text(subscriptionManager.currentPlan.canAnalyzeBody
                             ? "Foto agora ou da galeria"
                             : "Requer plano Premium")
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if !subscriptionManager.currentPlan.canAnalyzeBody {
                        Image(systemName: "lock.fill")
                            .foregroundStyle(.secondary)
                            .font(.caption)
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

    func resultCard(_ result: BodyAnalysisResult) -> some View {
        VStack(spacing: 16) {

            VStack(spacing: 8) {
                Text("Gordura corporal estimada")
                    .font(.subheadline).foregroundStyle(.secondary)
                HStack(alignment: .firstTextBaseline, spacing: 4) {
                    Text("\(result.fatPercentageLow)-\(result.fatPercentageHigh)")
                        .font(.system(size: 52, weight: .black, design: .rounded))
                        .foregroundStyle(fatColor(result.fatPercentageLow))
                    Text("%")
                        .font(.title).fontWeight(.bold)
                        .foregroundStyle(fatColor(result.fatPercentageLow))
                }
                Text(result.fatCategory)
                    .font(.subheadline).fontWeight(.medium)
                    .padding(.horizontal, 16).padding(.vertical, 6)
                    .background(fatColor(result.fatPercentageLow).opacity(0.12))
                    .foregroundStyle(fatColor(result.fatPercentageLow))
                    .clipShape(Capsule())
            }
            .frame(maxWidth: .infinity)
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 20))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 12) {
                Label("Músculos para priorizar", systemImage: "figure.strengthtraining.traditional")
                    .font(.headline)
                ForEach(result.muscleGroups, id: \.name) { muscle in
                    MuscleRow(muscle: muscle)
                }
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

            VStack(alignment: .leading, spacing: 8) {
                Label("Recomendação", systemImage: "lightbulb.fill")
                    .font(.headline).foregroundStyle(.yellow)
                Text(result.recommendation)
                    .font(.subheadline).foregroundStyle(.secondary)
            }
            .padding()
            .background(Color.yellow.opacity(0.08))
            .clipShape(RoundedRectangle(cornerRadius: 16))

            Button {
                showWorkoutPlan = true
            } label: {
                HStack {
                    Image(systemName: "dumbbell.fill")
                    Text("Ver plano de treino")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(
                    LinearGradient(
                        colors: [.purple, .blue],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .foregroundStyle(.white)
                .clipShape(RoundedRectangle(cornerRadius: 16))
            }
            .disabled(workoutPlan == nil)

            Text("Estimativa aproximada — consulte um profissional para avaliação precisa.")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .multilineTextAlignment(.center)
        }
    }

    var analyzingOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                ProgressView().scaleEffect(1.5).tint(.white)
                Text(isGeneratingWorkout ? "Gerando plano de treino..." : "Analisando composição corporal...")
                    .font(.headline).foregroundStyle(.white)
                Text(isGeneratingWorkout ? "Criando exercícios personalizados" : "Isso pode levar alguns segundos")
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

        guard usageManager.canAnalyzeBody else {
            speech.speak("Você atingiu o limite de 2 análises corporais este mês.")
            return
        }

        isAnalyzing = true
        glasses.stopStream()

        do {
            let analysisResult = try await analyzer.analyze(image: image, profile: profile)
            result = analysisResult
            isAnalyzing = false

            let audio = "Gordura corporal estimada entre \(analysisResult.fatPercentageLow) e \(analysisResult.fatPercentageHigh) por cento. Categoria: \(analysisResult.fatCategory). \(analysisResult.recommendation)"
            speech.speak(audio)

            await usageManager.incrementBodyAnalysis()

            isGeneratingWorkout = true
            let plan = try await workoutGenerator.generate(bodyResult: analysisResult, profile: profile)
            workoutPlan = plan
            isGeneratingWorkout = false

        } catch {
            // // print("Erro na análise: \(error)")
            isAnalyzing = false
            isGeneratingWorkout = false
        }
    }

    func fatColor(_ percentage: Int) -> Color {
        switch percentage {
        case ..<10: return .blue
        case 10..<20: return .green
        case 20..<30: return .orange
        default: return .red
        }
    }
}

// MARK: - Subcomponents

struct InstructionRow: View {
    let number: String
    let text: String

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Text(number)
                .font(.caption).fontWeight(.bold)
                .foregroundStyle(.white)
                .frame(width: 20, height: 20)
                .background(Color.blue)
                .clipShape(Circle())
            Text(text)
                .font(.subheadline).foregroundStyle(.primary)
        }
    }
}

struct MuscleRow: View {
    let muscle: MuscleGroup

    var priorityColor: Color {
        switch muscle.priority {
        case "Alta":  return .red
        case "Média": return .orange
        default:      return .blue
        }
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: muscle.icon)
                .foregroundStyle(priorityColor)
                .frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(muscle.name)
                    .font(.subheadline).fontWeight(.medium)
                Text(muscle.tip)
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            Text(muscle.priority)
                .font(.caption).fontWeight(.medium)
                .padding(.horizontal, 8).padding(.vertical, 3)
                .background(priorityColor.opacity(0.12))
                .foregroundStyle(priorityColor)
                .clipShape(Capsule())
        }
        .padding(.vertical, 4)
    }
}
