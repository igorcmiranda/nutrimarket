import SwiftUI

struct UsageBadgeView: View {
    let remaining: Int
    let total: Int
    let label: String
    let color: Color

    var progress: Double {
        guard total > 0 else { return 0 }
        return Double(remaining) / Double(total)
    }

    var body: some View {
        VStack(spacing: 4) {
            HStack(spacing: 4) {
                Text("\(remaining)")
                    .font(.title3).fontWeight(.bold)
                    .foregroundStyle(remaining == 0 ? .red : color)
                Text("/ \(total)")
                    .font(.caption).foregroundStyle(.secondary)
            }
            Text(label)
                .font(.caption2).foregroundStyle(.secondary)
                .multilineTextAlignment(.center)

            GeometryReader { geo in
                ZStack(alignment: .leading) {
                    RoundedRectangle(cornerRadius: 3)
                        .fill(Color(.systemGray5))
                        .frame(height: 4)
                    RoundedRectangle(cornerRadius: 3)
                        .fill(remaining == 0 ? Color.red : color)
                        .frame(width: geo.size.width * progress, height: 4)
                }
            }
            .frame(height: 4)
        }
        .frame(maxWidth: .infinity)
        .padding(10)
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 12))
        .shadow(color: .black.opacity(0.05), radius: 4, y: 2)
    }
}
