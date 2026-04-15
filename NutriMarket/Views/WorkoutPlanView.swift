import SwiftUI

struct WorkoutPlanView: View {
    let plan: WorkoutPlan
    @Environment(\.dismiss) var dismiss
    @State private var selectedDay: WorkoutDay?

    var difficultyColor: Color {
        switch plan.difficulty {
        case "Iniciante":     return .green
        case "Intermediário": return .orange
        default:              return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header
                    VStack(spacing: 12) {
                        HStack(spacing: 12) {
                            InfoPill(label: plan.difficulty, color: difficultyColor, icon: "speedometer")
                            InfoPill(label: plan.estimatedDuration, color: .blue, icon: "clock.fill")
                        }
                        Text(plan.summary)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // Músculos alvo
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Músculos em foco", systemImage: "figure.strengthtraining.traditional")
                            .font(.headline)
                        LazyVGrid(columns: [GridItem(.adaptive(minimum: 100))], spacing: 8) {
                            ForEach(plan.targetMuscles, id: \.self) { muscle in
                                Text(muscle)
                                    .font(.caption).fontWeight(.medium)
                                    .padding(.horizontal, 12).padding(.vertical, 6)
                                    .background(Color.purple.opacity(0.1))
                                    .foregroundStyle(.purple)
                                    .clipShape(Capsule())
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // Semana
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Semana de treinos")
                            .font(.headline)

                        ForEach(plan.weeklySchedule) { day in
                            WorkoutDayCard(day: day)
                        }
                    }

                    // Dicas gerais
                    VStack(alignment: .leading, spacing: 10) {
                        Label("Dicas importantes", systemImage: "lightbulb.fill")
                            .font(.headline).foregroundStyle(.yellow)
                        ForEach(plan.generalTips, id: \.self) { tip in
                            HStack(alignment: .top, spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green).font(.caption)
                                    .padding(.top, 2)
                                Text(tip)
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                        }
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
                .padding(.horizontal)
                .padding(.bottom, 32)
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Plano de treino")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}

struct WorkoutDayCard: View {
    let day: WorkoutDay
    @State private var isExpanded = false

    var dayColor: Color {
        day.restDay ? .gray : .purple
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Button {
                if !day.restDay {
                    withAnimation(.spring(duration: 0.3)) {
                        isExpanded.toggle()
                    }
                }
            } label: {
                HStack {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(day.dayName)
                            .font(.subheadline).fontWeight(.medium)
                            .foregroundStyle(.primary)
                        Text(day.focus)
                            .font(.caption).foregroundStyle(dayColor)
                    }
                    Spacer()
                    if day.restDay {
                        Text("Descanso")
                            .font(.caption).fontWeight(.medium)
                            .padding(.horizontal, 10).padding(.vertical, 4)
                            .background(Color.gray.opacity(0.12))
                            .foregroundStyle(.gray)
                            .clipShape(Capsule())
                    } else {
                        HStack(spacing: 4) {
                            Text("\(day.exercises.count) exercícios")
                                .font(.caption).foregroundStyle(.secondary)
                            Image(systemName: isExpanded ? "chevron.up" : "chevron.down")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                    }
                }
                .padding()
            }
            .buttonStyle(.plain)

            if isExpanded && !day.restDay {
                Divider().padding(.horizontal)
                ForEach(day.exercises) { exercise in
                    ExerciseRow(exercise: exercise)
                    if exercise.id != day.exercises.last?.id {
                        Divider().padding(.horizontal)
                    }
                }
            }
        }
        .background(Color(.systemBackground))
        .clipShape(RoundedRectangle(cornerRadius: 16))
        .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
    }
}

struct ExerciseRow: View {
    let exercise: Exercise

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(exercise.name)
                    .font(.subheadline).fontWeight(.medium)
                Spacer()
                Text(exercise.muscleGroup)
                    .font(.caption)
                    .padding(.horizontal, 8).padding(.vertical, 3)
                    .background(Color.purple.opacity(0.1))
                    .foregroundStyle(.purple)
                    .clipShape(Capsule())
            }

            HStack(spacing: 16) {
                ExerciseStat(icon: "repeat", label: "\(exercise.sets) séries")
                ExerciseStat(icon: "number", label: exercise.reps + " reps")
                ExerciseStat(icon: "timer", label: exercise.rest)
            }

            if !exercise.tips.isEmpty {
                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "lightbulb.fill")
                        .font(.caption2).foregroundStyle(.yellow)
                    Text(exercise.tips)
                        .font(.caption).foregroundStyle(.secondary)
                }
            }
        }
        .padding()
    }
}

struct ExerciseStat: View {
    let icon: String
    let label: String

    var body: some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2).foregroundStyle(.secondary)
            Text(label)
                .font(.caption).foregroundStyle(.secondary)
        }
    }
}

struct InfoPill: View {
    let label: String
    let color: Color
    let icon: String

    var body: some View {
        Label(label, systemImage: icon)
            .font(.caption).fontWeight(.medium)
            .padding(.horizontal, 12).padding(.vertical, 6)
            .background(color.opacity(0.1))
            .foregroundStyle(color)
            .clipShape(Capsule())
    }
}
