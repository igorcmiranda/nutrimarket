import SwiftUI

struct SubscriptionView: View {
    @EnvironmentObject var subscriptionManager: SubscriptionManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var selectedPlan: SubscriptionPlan = .standard
    @State private var showCheckout = false
    @State private var checkoutURL: URL?
    @State private var isLoadingCheckout = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 24) {

                        // Header
                        VStack(spacing: 8) {
                            Image(systemName: "crown.fill")
                                .font(.system(size: 44))
                                .foregroundStyle(
                                    LinearGradient(colors: [.yellow, .orange],
                                                   startPoint: .top, endPoint: .bottom)
                                )
                            Text("Escolha seu plano")
                                .font(.title2).fontWeight(.bold)
                            Text("Desbloqueie o poder da IA nutricional")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top)

                        // Cards dos planos
                        VStack(spacing: 12) {
                            ForEach([SubscriptionPlan.starter, .standard, .premium], id: \.rawValue) { plan in
                                PlanCard(
                                    plan: plan,
                                    isSelected: selectedPlan == plan,
                                    isCurrentPlan: subscriptionManager.currentPlan == plan
                                ) {
                                    selectedPlan = plan
                                }
                            }
                        }

                        // Features do plano selecionado
                        VStack(alignment: .leading, spacing: 10) {
                            Text("O que está incluído")
                                .font(.headline)

                            ForEach(selectedPlan.features) { feature in
                                HStack(spacing: 10) {
                                    Image(systemName: feature.included ? "checkmark.circle.fill" : "xmark.circle.fill")
                                        .foregroundStyle(feature.included ? .green : .red.opacity(0.4))
                                    Text(feature.name)
                                        .font(.subheadline)
                                        .foregroundStyle(feature.included ? .primary : .secondary)
                                }
                            }
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                        // Botão assinar
                        Button {
                            startCheckout()
                        } label: {
                            HStack {
                                Image(systemName: "creditcard.fill")
                                Text("Assinar \(selectedPlan.displayName) — \(selectedPlan.price)")
                                    .fontWeight(.medium)
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(
                                    colors: [selectedPlan.color, selectedPlan.color.opacity(0.7)],
                                    startPoint: .leading, endPoint: .trailing
                                )
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }
                        .disabled(subscriptionManager.currentPlan == selectedPlan)

                        Text("Pagamento processado com segurança pelo Mercado Pago. Cancele quando quiser.")
                            .font(.caption2)
                            .foregroundStyle(.tertiary)
                            .multilineTextAlignment(.center)
                            .padding(.bottom, 32)
                    }
                    .padding(.horizontal)
                }
            }
            .navigationTitle("Planos")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Fechar") { dismiss() }
                }
            }
            // Troque o sheet do checkout:
            .sheet(isPresented: $showCheckout) {
                if let url = checkoutURL {
                    StripeWebView(
                        url: url,
                        plan: selectedPlan,
                        onSuccess: { plan, sessionID in
                            print("🎯 onSuccess chamado — plano: \(plan.rawValue), sessionID: \(sessionID)")
                            Task {
                                print("💾 Chamando savePlan...")
                                await subscriptionManager.savePlan(plan, sessionID: sessionID)
                                print("✅ savePlan concluído — plano atual: \(subscriptionManager.currentPlan.rawValue)")
                                dismiss()
                            }
                        },
                        onDismiss: {
                            showCheckout = false
                        }
                    )
                }
            }
        }
    }

    func startCheckout() {
        checkoutURL = subscriptionManager.checkoutURL(for: selectedPlan)
        if checkoutURL != nil {
            showCheckout = true
        }
    }
}

struct PlanCard: View {
    let plan: SubscriptionPlan
    let isSelected: Bool
    let isCurrentPlan: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 14) {
                ZStack {
                    Circle()
                        .fill(plan.color.opacity(0.15))
                        .frame(width: 48, height: 48)
                    Image(systemName: plan.icon)
                        .foregroundStyle(plan.color)
                        .font(.title3)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack {
                        Text(plan.displayName)
                            .font(.headline).foregroundStyle(.primary)
                        if isCurrentPlan {
                            Text("Ativo")
                                .font(.caption).fontWeight(.medium)
                                .padding(.horizontal, 8).padding(.vertical, 2)
                                .background(plan.color.opacity(0.15))
                                .foregroundStyle(plan.color)
                                .clipShape(Capsule())
                        }
                    }
                    Text(plan.price)
                        .font(.subheadline).foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? plan.color : .secondary)
                    .font(.title3)
            }
            .padding()
            .background(Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? plan.color : Color(.systemGray5), lineWidth: isSelected ? 2 : 0.5)
            )
            .shadow(color: isSelected ? plan.color.opacity(0.2) : .black.opacity(0.04), radius: 8, y: 2)
        }
        .buttonStyle(.plain)
    }
}
