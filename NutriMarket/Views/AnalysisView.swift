import SwiftUI

struct AnalysisView: View {
    let result: NutritionResponse
    let onSave: (MealEntry) -> Void
    @Environment(\.dismiss) var dismiss

    var qualityColor: Color {
        switch result.quality {
        case "Excelente": return .green
        case "Boa":       return .mint
        case "Regular":   return .orange
        default:          return .red
        }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Header com qualidade
                    VStack(spacing: 8) {
                        Text(result.description)
                            .font(.title3).fontWeight(.bold)
                            .multilineTextAlignment(.center)
                        Label(result.quality, systemImage: "star.fill")
                            .font(.subheadline)
                            .foregroundStyle(qualityColor)
                            .padding(.horizontal, 12).padding(.vertical, 4)
                            .background(qualityColor.opacity(0.12))
                            .clipShape(Capsule())
                    }
                    .padding(.top)

                    // Card principal de calorias
                    VStack(spacing: 4) {
                        Text("\(result.calories)")
                            .font(.system(size: 64, weight: .black, design: .rounded))
                            .foregroundStyle(
                                LinearGradient(colors: [.green, .mint],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                        Text("kcal estimadas")
                            .font(.subheadline).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 20))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // Macros
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Macronutrientes")
                            .font(.headline)

                        MacroRow(name: "Proteína",     value: result.protein, unit: "g", color: .blue,   icon: "bolt.fill")
                        MacroRow(name: "Carboidratos", value: result.carbs,   unit: "g", color: .orange, icon: "flame.fill")
                        MacroRow(name: "Gorduras",     value: result.fat,     unit: "g", color: .pink,   icon: "drop.fill")
                        MacroRow(name: "Fibras",       value: result.fiber,   unit: "g", color: .green,  icon: "leaf.fill")
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)

                    // Dica personalizada
                    HStack(alignment: .top, spacing: 12) {
                        Image(systemName: "lightbulb.fill")
                            .foregroundStyle(.yellow)
                            .font(.title3)
                        Text(result.tips)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                    }
                    .padding()
                    .background(Color.yellow.opacity(0.08))
                    .clipShape(RoundedRectangle(cornerRadius: 16))

                    // Botão salvar
                    Button {
                        let entry = MealEntry(
                            description: result.description,
                            calories: result.calories,
                            protein: result.protein,
                            carbs: result.carbs,
                            fat: result.fat,
                            mealType: result.mealType
                        )
                        onSave(entry)
                    } label: {
                        Label("Salvar no histórico", systemImage: "checkmark.circle.fill")
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                LinearGradient(colors: [.green, .mint],
                                               startPoint: .leading, endPoint: .trailing)
                            )
                            .foregroundStyle(.white)
                            .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .padding(.bottom)
                }
                .padding(.horizontal)
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Análise nutricional")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Descartar") { dismiss() }
                }
            }
        }
    }
}

struct MacroRow: View {
    let name: String
    let value: Double
    let unit: String
    let color: Color
    let icon: String

    var body: some View {
        HStack {
            Image(systemName: icon)
                .foregroundStyle(color)
                .frame(width: 20)
            Text(name)
                .font(.subheadline)
            Spacer()
            Text("\(String(format: "%.1f", value))\(unit)")
                .font(.subheadline).fontWeight(.medium)
        }
        .padding(.vertical, 4)
    }
}
