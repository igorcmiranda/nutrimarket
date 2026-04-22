import SwiftUI

struct TrophiesView: View {
    let trophies: [Trophy]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Label("Troféus", systemImage: "trophy.fill")
                .font(.headline)
                .foregroundStyle(Color(hex: "FFD700"))

            if trophies.isEmpty {
                HStack {
                    Image(systemName: "trophy")
                        .foregroundStyle(.secondary)
                    Text("Nenhum troféu ainda. Participe de desafios!")
                        .font(.caption).foregroundStyle(.secondary)
                }
                .padding()
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color(.systemGray6))
                .clipShape(RoundedRectangle(cornerRadius: 12))
            } else {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 12) {
                    // Mostra até 7 troféus normalmente
                    ForEach(trophies.prefix(7)) { trophy in
                        TrophyBadge(trophy: trophy)
                    }

                    // 8ª posição
                    if trophies.count == 8 {
                        // Exatamente 8 — mostra o 8º normalmente
                        TrophyBadge(trophy: trophies[7])
                    } else if trophies.count > 8 {
                        // Mais de 8 — mostra +X no lugar do 8º
                        MoreTrophiesButton(
                            count: trophies.count - 7,
                            allTrophies: trophies
                        )
                    }
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

struct TrophyBadge: View {
    let trophy: Trophy
    @State private var showDetail = false

    var body: some View {
        Button {
            showDetail = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(trophy.type.color.opacity(0.15))
                        .frame(width: 52, height: 52)
                    Image(systemName: trophy.type.icon)
                        .font(.title2)
                        .foregroundStyle(trophy.type.color)
                }
                Text(trophy.type.displayName)
                    .font(.system(size: 9)).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showDetail) {
            TrophyDetailSheet(trophy: trophy)
        }
    }
}

struct MoreTrophiesButton: View {
    let count: Int
    let allTrophies: [Trophy]
    @State private var showAll = false

    var body: some View {
        Button {
            showAll = true
        } label: {
            VStack(spacing: 6) {
                ZStack {
                    Circle()
                        .fill(Color(.systemGray5))
                        .frame(width: 52, height: 52)
                    Text("+\(count)")
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                }
                Text("ver mais")
                    .font(.system(size: 9)).fontWeight(.medium)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .buttonStyle(.plain)
        .sheet(isPresented: $showAll) {
            AllTrophiesView(trophies: allTrophies)
        }
    }
}

struct AllTrophiesView: View {
    let trophies: [Trophy]
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: [
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible()),
                    GridItem(.flexible())
                ], spacing: 16) {
                    ForEach(trophies) { trophy in
                        TrophyBadge(trophy: trophy)
                    }
                }
                .padding()
            }
            .navigationTitle("Todos os troféus (\(trophies.count))")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct TrophyDetailSheet: View {
    let trophy: Trophy
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 24) {
                ZStack {
                    Circle()
                        .fill(trophy.type.color.opacity(0.15))
                        .frame(width: 120, height: 120)
                    Image(systemName: trophy.type.icon)
                        .font(.system(size: 56))
                        .foregroundStyle(
                            LinearGradient(
                                colors: trophy.type.animationColor,
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )
                }

                VStack(spacing: 8) {
                    Text(trophy.type.displayName)
                        .font(.title2).fontWeight(.bold)
                    Text(trophy.description)
                        .font(.subheadline).foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal)
                    Text("\(Int(trophy.points)) pontos")
                        .font(.headline).foregroundStyle(trophy.type.color)
                    Text(trophy.earnedAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption).foregroundStyle(.secondary)
                }
                Spacer()
            }
            .padding(.top, 32)
            .navigationTitle("Troféu")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
