import SwiftUI

struct QuickNavView: View {
    @Binding var showDiet: Bool
    @Binding var showBody: Bool
    @Binding var showWater: Bool
    @Binding var showUsage: Bool

    var body: some View {
        HStack(spacing: 10) {
            QuickNavButton(
                icon: "list.bullet.clipboard.fill",
                label: "Dieta",
                color: .green
            ) { showDiet = true }

            QuickNavButton(
                icon: "figure.arms.open",
                label: "Corpo",
                color: .purple
            ) { showBody = true }

            QuickNavButton(
                icon: "drop.fill",
                label: "Água",
                color: .blue
            ) { showWater = true }

            QuickNavButton(
                icon: "chart.bar.fill",
                label: "Meu uso",
                color: .orange
            ) { showUsage = true }
        }
        .padding(.horizontal, 4)
    }
}

struct QuickNavButton: View {
    let icon: String
    let label: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(spacing: 6) {
                ZStack {
                    RoundedRectangle(cornerRadius: 12)
                        .fill(color.opacity(0.12))
                        .frame(height: 52)
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(color)
                }
                Text(label)
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundStyle(.primary)
            }
            .frame(maxWidth: .infinity)
        }
        .buttonStyle(.plain)
    }
}
