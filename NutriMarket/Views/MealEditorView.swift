import SwiftUI

struct MealEditorView: View {
    @State var slot: MealSlot
    let onSave: (MealSlot) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var newFood = ""

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                List {
                    Section {
                        if slot.foods.isEmpty {
                            Text("Nenhum alimento adicionado")
                                .foregroundStyle(.secondary)
                        } else {
                            ForEach(slot.foods, id: \.self) { food in
                                HStack {
                                    Image(systemName: "circle.fill")
                                        .font(.caption2).foregroundStyle(.green)
                                    Text(food)
                                }
                            }
                            .onDelete { indices in
                                slot.foods.remove(atOffsets: indices)
                            }
                        }
                    } header: {
                        Text("Alimentos desta refeição")
                    } footer: {
                        Text("Deslize para remover um alimento")
                    }

                    Section("Anotações") {
                        TextField("Ex: prefiro light, sem glúten...", text: $slot.notes, axis: .vertical)
                            .lineLimit(3)
                    }
                }

                // Campo de adicionar fixo no fundo
                HStack(spacing: 8) {
                    TextField("Adicionar alimento...", text: $newFood)
                        .textFieldStyle(.roundedBorder)
                        .onSubmit { addFood() }
                    Button("Adicionar", action: addFood)
                        .buttonStyle(.borderedProminent)
                        .tint(.green)
                }
                .padding()
                .background(.ultraThinMaterial)
            }
            .navigationTitle(slot.mealType)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salvar") {
                        onSave(slot)
                        dismiss()
                    }
                    .fontWeight(.medium)
                }
            }
        }
    }

    func addFood() {
        let food = newFood.trimmingCharacters(in: .whitespaces)
        guard !food.isEmpty else { return }
        slot.foods.append(food)
        newFood = ""
    }
}
