import SwiftUI

struct HistoryView: View {
    let entries: [MealEntry]
    @Environment(\.dismiss) var dismiss

    var groupedEntries: [(String, [MealEntry])] {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.locale = Locale(identifier: "pt_BR")
        let grouped = Dictionary(grouping: entries) { formatter.string(from: $0.date) }
        return grouped.sorted { $0.key > $1.key }
    }

    var body: some View {
        NavigationStack {
            List {
                if entries.isEmpty {
                    Text("Nenhuma refeição registrada ainda.")
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity)
                        .padding()
                } else {
                    ForEach(groupedEntries, id: \.0) { date, dayEntries in
                        Section {
                            ForEach(dayEntries) { entry in
                                VStack(alignment: .leading, spacing: 4) {
                                    HStack {
                                        Text(entry.mealType)
                                            .font(.caption)
                                            .foregroundStyle(.secondary)
                                        Spacer()
                                        Text("\(entry.calories) kcal")
                                            .font(.subheadline)
                                            .fontWeight(.medium)
                                            .foregroundStyle(.green)
                                    }
                                    Text(entry.description)
                                        .font(.subheadline)
                                    HStack(spacing: 12) {
                                        Text("P: \(Int(entry.protein))g")
                                        Text("C: \(Int(entry.carbs))g")
                                        Text("G: \(Int(entry.fat))g")
                                    }
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                }
                                .padding(.vertical, 2)
                            }
                        } header: {
                            let total = dayEntries.reduce(0) { $0 + $1.calories }
                            HStack {
                                Text(date)
                                Spacer()
                                Text("Total: \(total) kcal")
                                    .foregroundStyle(.green)
                            }
                        }
                    }
                }
            }
            .navigationTitle("Histórico")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Fechar") { dismiss() }
                }
            }
        }
    }
}
