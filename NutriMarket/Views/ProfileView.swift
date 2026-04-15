import SwiftUI

struct ProfileView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutConfirm = false

    let goals = ["Perder peso", "Manter peso", "Ganhar massa"]
    let sexOptions = ["Masculino", "Feminino"]

    var body: some View {
        NavigationStack {
            Form {
                Section("Dados pessoais") {
                    TextField("Nome", text: $profile.name)
                    Picker("Sexo", selection: $profile.sex) {
                        ForEach(sexOptions, id: \.self) { Text($0) }
                    }
                    HStack {
                        Text("Idade")
                        Spacer()
                        TextField("anos", value: $profile.age, format: .number)
                            .keyboardType(.numberPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(profile.age == 0 ? .secondary : .primary)
                    }
                }

                Section("Medidas") {
                    HStack {
                        Text("Peso")
                        Spacer()
                        TextField("kg", value: $profile.weight, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(profile.weight == 0 ? .secondary : .primary)
                    }
                    HStack {
                        Text("Altura")
                        Spacer()
                        TextField("cm", value: $profile.height, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .foregroundStyle(profile.height == 0 ? .secondary : .primary)
                    }
                }

                Section("Objetivo") {
                    Picker("Meu objetivo", selection: $profile.goal) {
                        ForEach(goals, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                Section {
                    HStack {
                        Text("Meta calórica calculada")
                        Spacer()
                        Text("\(profile.dailyCalorieGoal) kcal/dia")
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }

                Section {
                    Button(role: .destructive) {
                        showLogoutConfirm = true
                    } label: {
                        HStack {
                            Image(systemName: "rectangle.portrait.and.arrow.right")
                            Text("Sair da conta")
                        }
                    }
                }
            }
            .navigationTitle("Meu perfil")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Salvar") {
                        Task { await authManager.updateProfile(profile) }
                        dismiss()
                    }
                }
            }
            .confirmationDialog(
                "Deseja sair da conta?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sair", role: .destructive) {
                    authManager.logout()
                }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }
}
