import SwiftUI

struct ShareChallengeResultView: View {
    let result: TrophyManager.CompletedChallengeResult
    let onDismiss: () -> Void
    @Environment(\.dismiss) var dismiss

    var sortedParticipants: [(id: String, name: String, avatar: String, points: Double, trophy: TrophyType)] {
        result.participants.sorted { $0.points > $1.points }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {

                    // Troféu animado
                    VStack(spacing: 8) {
                        Text("🏆")
                            .font(.system(size: 64))
                        Text("Desafio encerrado!")
                            .font(.title2).fontWeight(.black)
                        Text(result.isGroup ? "Competição finalizada!" : "Duelo finalizado!")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .padding(.top, 8)

                    // Card com participantes
                    VStack(spacing: 16) {
                        if result.isGroup {
                            // Grupo — lista rankeada
                            VStack(spacing: 8) {
                                ForEach(Array(sortedParticipants.enumerated()), id: \.element.id) { index, p in
                                    HStack(spacing: 12) {
                                        // Posição
                                        Text(index == 0 ? "🥇" : index == 1 ? "🥈" : index == 2 ? "🥉" : "\(index + 1).")
                                            .font(.title3)
                                            .frame(width: 36)

                                        AvatarView(url: p.avatar, size: 44)

                                        VStack(alignment: .leading, spacing: 2) {
                                            Text(p.name)
                                                .font(.subheadline).fontWeight(.medium)
                                                .lineLimit(1)
                                            Text(p.trophy.displayName)
                                                .font(.caption).foregroundStyle(.secondary)
                                        }

                                        Spacer()

                                        VStack(alignment: .trailing, spacing: 2) {
                                            Text("\(Int(p.points))")
                                                .font(.title3).fontWeight(.black)
                                                .foregroundStyle(index == 0 ? Color(hex: "FFD700") : .primary)
                                            Text("pts")
                                                .font(.caption2).foregroundStyle(.secondary)
                                        }
                                    }
                                    .padding(.horizontal, 12).padding(.vertical, 8)
                                    .background(index == 0 ? Color(hex: "FFD700").opacity(0.08) : Color(.systemGray6))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                }
                            }
                        } else {
                            // Duelo 1x1
                            HStack(spacing: 0) {
                                ForEach(sortedParticipants.prefix(2), id: \.id) { p in
                                    VStack(spacing: 10) {
                                        AvatarView(url: p.avatar, size: 70)
                                            .overlay(
                                                Circle().stroke(
                                                    p.name == result.winnerName
                                                        ? Color(hex: "FFD700")
                                                        : Color(.systemGray4),
                                                    lineWidth: p.name == result.winnerName ? 3 : 1.5
                                                )
                                            )

                                        Text(p.name)
                                            .font(.subheadline).fontWeight(.medium)
                                            .lineLimit(1)
                                            .frame(maxWidth: 130)

                                        Text("\(Int(p.points)) pts")
                                            .font(.title3).fontWeight(.black)
                                            .foregroundStyle(p.name == result.winnerName
                                                             ? Color(hex: "FFD700") : .secondary)

                                        Image(systemName: p.trophy.icon)
                                            .font(.title2)
                                            .foregroundStyle(p.trophy.color)
                                    }
                                    .frame(maxWidth: .infinity)
                                }
                            }
                            .padding()
                            .background(Color(.systemGray6))
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                        }

                        // Vencedor destaque
                        HStack(spacing: 8) {
                            Text("👑")
                            Text("\(result.winnerName) venceu com \(Int(result.winnerPoints)) pontos!")
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .padding()
                        .frame(maxWidth: .infinity)
                        .background(Color(hex: "FFD700").opacity(0.1))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // Dica de print
                    HStack(spacing: 10) {
                        Image(systemName: "camera.viewfinder")
                            .font(.title3)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Quer compartilhar?")
                                .font(.subheadline).fontWeight(.medium)
                            Text("Tire um print e poste no feed para compartilhar com seus amigos!")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                    .padding()
                    .background(Color.purple.opacity(0.06))
                    .clipShape(RoundedRectangle(cornerRadius: 14))

                    Button {
                        onDismiss()
                        dismiss()
                    } label: {
                        Text("Fechar")
                            .fontWeight(.medium)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color(.systemGray5))
                            .foregroundStyle(.primary)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .buttonStyle(.plain)
                    .padding(.bottom, 16)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Resultado")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
