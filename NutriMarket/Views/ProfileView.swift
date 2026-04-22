import SwiftUI
import FirebaseAuth
import FirebaseFirestore

struct ProfileView: View {
    @EnvironmentObject var profile: UserProfile
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @State private var showLogoutConfirm = false
    @State private var showVerificationRequest = false
    @State private var verificationRequestSent = false
    @State private var verificationCooldown = false

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
                // Pedido de verificação
                if !(authManager.currentUser?.isVerified == true) {
                    Section {
                        if verificationRequestSent {
                            HStack {
                                Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                Text("Solicitação enviada! Aguarde a análise.")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        } else if !verificationCooldown {
                            Button {
                                showVerificationRequest = true
                            } label: {
                                Text("Se considera uma pessoa importante? Clique aqui e peça seu verificado.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                    .multilineTextAlignment(.center)
                            }
                        }
                    }
                }
            }
            .confirmationDialog(
                "Solicitar verificação",
                isPresented: $showVerificationRequest,
                titleVisibility: .visible
            ) {
                Button("Enviar solicitação") {
                    Task { await requestVerification() }
                }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Seus dados serão enviados para análise. O processo pode levar alguns dias.")
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
            .onAppear {
                Task { await checkVerificationStatus() }
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
    
    func checkVerificationStatus() async {
        guard let user = authManager.currentUser else { return }
        let db = Firestore.firestore()

        let doc = try? await db.collection("verificationRequests")
            .document(user.uid).getDocument()

        guard let data = doc?.data(),
              let status = data["status"] as? String else { return }

        await MainActor.run {
            if status == "pending" || status == "approved" {
                verificationRequestSent = true
            } else if status == "denied" {
                if let deniedAt = (data["requestedAt"] as? Timestamp)?.dateValue() {
                    let months = Calendar.current.dateComponents(
                        [.month], from: deniedAt, to: Date()
                    ).month ?? 0
                    verificationCooldown = months < 6
                }
            }
        }
    }
    
    func requestVerification() async {
        guard let user = authManager.currentUser else { return }
        let db = Firestore.firestore()

        // Verifica cooldown no Firestore (mais confiável que UserDefaults)
        let requestDoc = try? await db.collection("verificationRequests")
            .document(user.uid).getDocument()

        if let data = requestDoc?.data(),
           let status = data["status"] as? String {
            if status == "pending" || status == "approved" {
                await MainActor.run { verificationRequestSent = true }
                return
            }
            if status == "denied",
               let deniedAt = (data["requestedAt"] as? Timestamp)?.dateValue() {
                let monthsSince = Calendar.current.dateComponents(
                    [.month], from: deniedAt, to: Date()
                ).month ?? 0
                if monthsSince < 6 {
                    await MainActor.run { verificationCooldown = true }
                    return
                }
            }
        }

        // Mostra confirmação imediatamente
        await MainActor.run { verificationRequestSent = true }

        // Salva no Firestore
        try? await db.collection("verificationRequests").document(user.uid).setData([
            "userID": user.uid,
            "userName": user.name,
            "email": user.email,
            "username": user.username,
            "avatarURL": user.avatarURL,
            "requestedAt": Timestamp(date: Date()),
            "status": "pending"
        ])

        // Envia email via Cloud Function
        await sendVerificationEmail(user: user)
    }

    func sendVerificationEmail(user: AppUser) async {
        guard let url = URL(string: "https://us-central1-nutrimarket.cloudfunctions.net/sendVerificationRequest") else { return }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")

        let body: [String: Any] = [
            "userName": user.name,
            "username": user.username,
            "userEmail": user.email,
            "userId": user.uid,
            "avatarURL": user.avatarURL
        ]

        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let httpResponse = response as? HTTPURLResponse {
                // print("📧 Email status: \(httpResponse.statusCode)")
            }
        } catch {
            // print("❌ Erro ao enviar email: \(error)")
        }
    }
}
