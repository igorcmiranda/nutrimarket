import SwiftUI

struct UsageDetailView: View {
    @EnvironmentObject var usageManager: UsageManager
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var showUpgrade = false
    @State private var showCancelConfirm = false
    @State private var isCancelling = false
    @State private var showCancelSuccess = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 8) {
                        Image(systemName: "chart.bar.fill")
                            .font(.system(size: 40))
                            .foregroundStyle(.orange)
                        Text("Meu uso")
                            .font(.title2).fontWeight(.bold)

                        // Plano atual
                        HStack(spacing: 6) {
                            Image(systemName: subscriptionManager.currentPlan.icon)
                            Text("Plano \(subscriptionManager.currentPlan.displayName)")
                                .fontWeight(.medium)
                        }
                        .font(.subheadline)
                        .padding(.horizontal, 16).padding(.vertical, 6)
                        .background(subscriptionManager.currentPlan.color.opacity(0.12))
                        .foregroundStyle(subscriptionManager.currentPlan.color)
                        .clipShape(Capsule())

                        // Botão upgrade
                        if subscriptionManager.currentPlan != .none {
                            Button {
                                showUpgrade = true
                            } label: {
                                HStack(spacing: 6) {
                                    Image(systemName: "arrow.up.circle.fill")
                                    Text("Deseja fazer um upgrade no plano? Toque aqui!")
                                        .font(.caption).fontWeight(.medium)
                                }
                                .foregroundStyle(.white)
                                .padding(.horizontal, 16).padding(.vertical, 8)
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .clipShape(Capsule())
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.top)

                    // Cards de uso
                    UsageDetailCard(
                        icon: "fork.knife",
                        title: "Análises de refeição",
                        subtitle: "Limite diário — reseta à meia-noite",
                        remaining: usageManager.remainingMealsToday,
                        total: UsageLimits.maxMealsPerDay,
                        color: .green
                    )

                    UsageDetailCard(
                        icon: "brain.head.profile",
                        title: "Geração de dieta por IA",
                        subtitle: "Limite mensal — reseta todo mês",
                        remaining: usageManager.remainingDietPlansThisMonth,
                        total: UsageLimits.maxDietPlansPerMonth,
                        color: .orange
                    )

                    UsageDetailCard(
                        icon: "figure.arms.open",
                        title: "Análises corporais",
                        subtitle: "Limite mensal — reseta todo mês",
                        remaining: usageManager.remainingBodyAnalysesThisMonth,
                        total: UsageLimits.maxBodyAnalysesPerMonth,
                        color: .purple
                    )

                    // Info
                    VStack(alignment: .leading, spacing: 8) {
                        Label("Sobre os limites", systemImage: "info.circle.fill")
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.blue)
                        Text("Os limites existem para garantir uma experiência de qualidade para todos os usuários. Cada análise consome créditos de IA pagos pela plataforma.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color.blue.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    // Cancelar assinatura
                    if subscriptionManager.currentPlan != .none {
                        VStack(spacing: 8) {
                            Divider()
                            Button {
                                showCancelConfirm = true
                            } label: {
                                Text("Quer desistir da vida saudável? Cancele sua assinatura aqui.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                                    .underline()
                            }
                            .buttonStyle(.plain)
                            .padding(.bottom, 8)
                        }
                    }
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Uso")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
            .sheet(isPresented: $showUpgrade) {
                SubscriptionView()
                    .environmentObject(subscriptionManager)
                    .environmentObject(authManager)
            }
            .confirmationDialog(
                "Cancelar assinatura?",
                isPresented: $showCancelConfirm,
                titleVisibility: .visible
            ) {
                Button("Cancelar assinatura", role: .destructive) {
                    Task { await cancelSubscription() }
                }
                Button("Manter assinatura", role: .cancel) {}
            } message: {
                Text("Você perderá acesso às funcionalidades premium ao final do período atual. Esta ação não pode ser desfeita.")
            }
            .alert("Assinatura cancelada", isPresented: $showCancelSuccess) {
                Button("OK") { dismiss() }
            } message: {
                Text("Sua assinatura foi cancelada com sucesso. Você não será cobrado nas próximas mensalidades.")
            }
            .overlay {
                if isCancelling {
                    ZStack {
                        Color.black.opacity(0.3).ignoresSafeArea()
                        VStack(spacing: 12) {
                            ProgressView().tint(.white)
                            Text("Cancelando assinatura...")
                                .font(.subheadline).foregroundStyle(.white)
                        }
                        .padding(24)
                        .background(.ultraThinMaterial)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                }
            }
        }
    }

    func cancelSubscription() async {
        isCancelling = true
        let success = await subscriptionManager.cancelSubscription()
        isCancelling = false
        if success {
            showCancelSuccess = true
        }
    }
}

struct UsageDetailCard: View {
    let icon: String
    let title: String
    let subtitle: String
    let remaining: Int
    let total: Int
    let color: Color

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(color.opacity(0.12))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline).fontWeight(.medium)
                    Text(subtitle)
                        .font(.caption).foregroundStyle(.secondary)
                }

                Spacer()

                VStack(alignment: .trailing, spacing: 2) {
                    Text("\(remaining)")
                        .font(.title2).fontWeight(.bold)
                        .foregroundStyle(remaining == 0 ? .red : color)
                    Text("de \(total)")
                        .font(.caption).foregroundStyle(.secondary)
                }
            }

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 4)
                        .fill(Color(.systemGray5))
                        .frame(height: 8)
                    RoundedRectangle(cornerRadius: 4)
                        .fill(remaining == 0 ? Color.red : color)
                        .frame(width: geo.size.width * progress, height: 8)
                        .animation(.spring(), value: progress)
                }
            }
            .frame(height: 8)
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}
