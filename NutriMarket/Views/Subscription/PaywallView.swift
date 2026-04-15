import SwiftUI

struct PaywallView: View {
    let requiredPlan: SubscriptionPlan
    let featureName: String
    @Binding var showSubscription: Bool
    @Environment(\.dismiss) var dismiss

    var body: some View {
        VStack(spacing: 24) {
            Spacer()

            VStack(spacing: 12) {
                Image(systemName: "lock.fill")
                    .font(.system(size: 48))
                    .foregroundStyle(requiredPlan.color)

                Text("Funcionalidade Premium")
                    .font(.title2).fontWeight(.bold)

                Text("\"\(featureName)\" requer o plano \(requiredPlan.displayName) ou superior.")
                    .font(.subheadline).foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
            }

            VStack(spacing: 12) {
                Button {
                    dismiss()
                    showSubscription = true
                } label: {
                    HStack {
                        Image(systemName: "crown.fill")
                        Text("Ver planos de assinatura")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(
                        LinearGradient(
                            colors: [requiredPlan.color, requiredPlan.color.opacity(0.7)],
                            startPoint: .leading, endPoint: .trailing
                        )
                    )
                    .foregroundStyle(.white)
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                }

                Button("Agora não") { dismiss() }
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal)

            Spacer()
        }
        .presentationDetents([.medium])
    }
}
