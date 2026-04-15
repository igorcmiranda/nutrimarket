import SwiftUI

struct WaterView: View {
    @EnvironmentObject var profile: UserProfile
    @State private var consumed: Double = 0
    @State private var animateWave = false
    @State private var showCelebration = false

    var dailyGoal: Double {
        guard profile.weight > 0 else { return 2000 }
        // Fórmula: 35ml por kg de peso, ajustada por idade
        var base = profile.weight * 35
        if profile.age > 55 { base *= 0.9 }
        if profile.age < 18 { base *= 1.1 }
        return min(max(base, 1500), 4000) // entre 1.5L e 4L
    }

    var progress: Double {
        min(consumed / dailyGoal, 1.0)
    }

    var progressPercent: Int { Int(progress * 100) }

    var remainingML: Double { max(dailyGoal - consumed, 0) }

    var statusMessage: String {
        switch progress {
        case 0:         return "Vamos começar! Beba água regularmente."
        case ..<0.25:   return "Bom começo! Continue se hidratando."
        case ..<0.5:    return "Indo bem! Você está no caminho certo."
        case ..<0.75:   return "Ótimo progresso! Mais um pouco."
        case ..<1.0:    return "Quase lá! Falta pouco para a meta."
        default:        return "🎉 Meta atingida! Excelente hidratação!"
        }
    }

    var waterColor: Color {
        switch progress {
        case ..<0.3:  return .blue.opacity(0.6)
        case ..<0.6:  return .blue.opacity(0.8)
        default:      return .blue
        }
    }

    let increments: [(label: String, ml: Double)] = [
        ("100ml", 100),
        ("250ml", 250),
        ("500ml", 500),
        ("1L", 1000)
    ]

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color(.systemBackground), Color(.systemGray6)],
                startPoint: .top, endPoint: .bottom
            )
            .ignoresSafeArea()

            ScrollView {
                VStack(spacing: 24) {
                    goalCard
                    waveProgressCard
                    incrementButtons
                    statusCard
                    historyCard
                }
                .padding()
            }
        }
        .navigationTitle("Hidratação")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    withAnimation(.spring()) {
                        consumed = 0
                        saveConsumed()
                    }
                } label: {
                    Image(systemName: "arrow.counterclockwise")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .onAppear { loadConsumed() }
        .onChange(of: consumed) { _, _ in
            if progress >= 1.0 && !showCelebration {
                showCelebration = true
            }
        }
        .overlay {
            if showCelebration {
                celebrationOverlay
            }
        }
    }

    // MARK: - Cards

    var goalCard: some View {
        HStack {
            VStack(alignment: .leading, spacing: 4) {
                Text("Meta diária")
                    .font(.subheadline).foregroundStyle(.secondary)
                Text("\(Int(dailyGoal))ml")
                    .font(.title2).fontWeight(.bold)
                Text("Baseada no seu perfil")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Spacer()
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.blue, .cyan],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 56, height: 56)
                Image(systemName: "drop.fill")
                    .font(.title2)
                    .foregroundStyle(.white)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var waveProgressCard: some View {
        VStack(spacing: 16) {
            // Copo animado com onda
            ZStack(alignment: .bottom) {
                // Copo (fundo)
                RoundedRectangle(cornerRadius: 20)
                    .stroke(Color.blue.opacity(0.3), lineWidth: 2)
                    .frame(width: 140, height: 200)

                // Água preenchendo
                GeometryReader { geo in
                    ZStack(alignment: .bottom) {
                        // Preenchimento base
                        Rectangle()
                            .fill(waterColor.opacity(0.3))
                            .frame(height: geo.size.height * progress)

                        // Onda animada
                        WaveShape(animating: animateWave)
                            .fill(waterColor.opacity(0.6))
                            .frame(height: 20)
                            .offset(y: -geo.size.height * progress + 10)
                            .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: animateWave)
                    }
                }
                .frame(width: 136, height: 196)
                .clipShape(RoundedRectangle(cornerRadius: 18))

                // Percentual no centro
                VStack(spacing: 2) {
                    Text("\(progressPercent)%")
                        .font(.system(size: 36, weight: .black, design: .rounded))
                        .foregroundStyle(progress > 0.4 ? .white : .blue)
                    Text("\(Int(consumed))ml")
                        .font(.caption).fontWeight(.medium)
                        .foregroundStyle(progress > 0.4 ? .white.opacity(0.9) : .blue.opacity(0.7))
                }
                .frame(width: 136, height: 196)
            }
            .frame(width: 140, height: 200)
            .onAppear { animateWave = true }

            // Barra de progresso linear
            VStack(spacing: 6) {
                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 8)
                            .fill(Color.blue.opacity(0.1))
                            .frame(height: 16)
                        RoundedRectangle(cornerRadius: 8)
                            .fill(LinearGradient(
                                colors: [.blue, .cyan],
                                startPoint: .leading,
                                endPoint: .trailing
                            ))
                            .frame(width: geo.size.width * progress, height: 16)
                            .animation(.spring(), value: progress)
                    }
                }
                .frame(height: 16)

                HStack {
                    Text("0ml")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("Faltam \(Int(remainingML))ml")
                        .font(.caption2).foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(dailyGoal))ml")
                        .font(.caption2).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 20))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var incrementButtons: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Adicionar água")
                .font(.headline)

            HStack(spacing: 10) {
                ForEach(increments, id: \.label) { item in
                    Button {
                        withAnimation(.spring(duration: 0.4)) {
                            consumed = min(consumed + item.ml, dailyGoal * 1.5)
                            saveConsumed()
                        }
                        let impact = UIImpactFeedbackGenerator(style: .light)
                        impact.impactOccurred()
                    } label: {
                        VStack(spacing: 6) {
                            Image(systemName: "drop.fill")
                                .font(.title3)
                                .foregroundStyle(.blue)
                            Text(item.label)
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(.primary)
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                        .background(Color.blue.opacity(0.08))
                        .clipShape(RoundedRectangle(cornerRadius: 14))
                        .overlay(
                            RoundedRectangle(cornerRadius: 14)
                                .stroke(Color.blue.opacity(0.2), lineWidth: 0.5)
                        )
                    }
                    .buttonStyle(.plain)
                }
            }

            // Botão remover último
            Button {
                withAnimation(.spring()) {
                    consumed = max(consumed - 250, 0)
                    saveConsumed()
                }
            } label: {
                HStack {
                    Image(systemName: "minus.circle.fill")
                        .foregroundStyle(.red.opacity(0.7))
                    Text("Remover 250ml")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(Color.red.opacity(0.06))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            }
            .buttonStyle(.plain)
            .disabled(consumed == 0)
            .opacity(consumed == 0 ? 0.4 : 1)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var statusCard: some View {
        HStack(spacing: 12) {
            Image(systemName: progress >= 1 ? "checkmark.circle.fill" : "drop.circle.fill")
                .font(.title2)
                .foregroundStyle(progress >= 1 ? .green : .blue)
            Text(statusMessage)
                .font(.subheadline)
                .foregroundStyle(.primary)
            Spacer()
        }
        .padding()
        .background(progress >= 1 ? Color.green.opacity(0.08) : Color.blue.opacity(0.06))
        .clipShape(RoundedRectangle(cornerRadius: 14))
    }

    var historyCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Dicas de hidratação", systemImage: "lightbulb.fill")
                .font(.headline).foregroundStyle(.blue)

            VStack(alignment: .leading, spacing: 8) {
                WaterTipRow(icon: "sun.rise.fill", tip: "Beba 500ml logo ao acordar")
                WaterTipRow(icon: "fork.knife", tip: "Beba antes e depois das refeições")
                WaterTipRow(icon: "figure.run", tip: "Aumente 500ml nos dias de treino")
                WaterTipRow(icon: "moon.fill", tip: "Evite beber muito antes de dormir")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }

    var celebrationOverlay: some View {
        ZStack {
            Color.black.opacity(0.4).ignoresSafeArea()
            VStack(spacing: 16) {
                Text("🎉")
                    .font(.system(size: 60))
                Text("Meta atingida!")
                    .font(.title2).fontWeight(.bold).foregroundStyle(.white)
                Text("Você bebeu \(Int(consumed))ml hoje.\nExcelente hidratação!")
                    .font(.subheadline).foregroundStyle(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                Button {
                    showCelebration = false
                } label: {
                    Text("Continuar")
                        .fontWeight(.medium)
                        .padding(.horizontal, 32).padding(.vertical, 12)
                        .background(Color.blue)
                        .foregroundStyle(.white)
                        .clipShape(Capsule())
                }
            }
            .padding(32)
            .background(.ultraThinMaterial)
            .clipShape(RoundedRectangle(cornerRadius: 24))
            .padding(32)
        }
        .onTapGesture { showCelebration = false }
    }

    // MARK: - Persistência

    func saveConsumed() {
        let key = "water_\(todayKey)"
        UserDefaults.standard.set(consumed, forKey: key)
    }

    func loadConsumed() {
        let key = "water_\(todayKey)"
        consumed = UserDefaults.standard.double(forKey: key)
    }

    var todayKey: String {
        let formatter = DateFormatter()
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: Date())
    }
}

// MARK: - Subcomponents

struct WaterTipRow: View {
    let icon: String
    let tip: String

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .foregroundStyle(.blue)
                .frame(width: 20)
            Text(tip)
                .font(.subheadline).foregroundStyle(.secondary)
        }
    }
}

struct WaveShape: Shape {
    var animating: Bool

    var animatableData: Double {
        get { animating ? 1 : 0 }
        set { }
    }

    func path(in rect: CGRect) -> Path {
        var path = Path()
        let width = rect.width
        let height = rect.height
        let midHeight = height / 2

        path.move(to: CGPoint(x: 0, y: midHeight))

        for x in stride(from: 0, through: width, by: 1) {
            let relX = x / width
            let sine = sin(relX * .pi * 2 + (animating ? .pi : 0))
            let y = midHeight + sine * (height / 3)
            path.addLine(to: CGPoint(x: x, y: y))
        }

        path.addLine(to: CGPoint(x: width, y: height))
        path.addLine(to: CGPoint(x: 0, y: height))
        path.closeSubpath()

        return path
    }
}
