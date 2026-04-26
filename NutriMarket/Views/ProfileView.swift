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
    @State private var showExercisePicker = false
    @State private var showMixedSchedule = false

    let goals      = ["Perder peso", "Manter peso", "Ganhar massa"]
    let sexOptions = ["Masculino", "Feminino"]

    var body: some View {
        NavigationStack {
            Form {
                // ── Dados pessoais ────────────────────────────────
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

                // ── Medidas ───────────────────────────────────────
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

                // ── Objetivo ──────────────────────────────────────
                Section("Objetivo") {
                    Picker("Meu objetivo", selection: $profile.goal) {
                        ForEach(goals, id: \.self) { Text($0) }
                    }
                    .pickerStyle(.segmented)
                }

                // ── Atividade física ──────────────────────────────
                Section {
                    Button {
                        showExercisePicker = true
                    } label: {
                        HStack(spacing: 12) {
                            ZStack {
                                RoundedRectangle(cornerRadius: 8)
                                    .fill(Color.purple.opacity(0.15))
                                    .frame(width: 34, height: 34)
                                Image(systemName: profile.exerciseType.icon)
                                    .foregroundStyle(.purple)
                                    .font(.system(size: 16))
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                Text(profile.exerciseType.rawValue)
                                    .foregroundStyle(.primary)
                                    .fontWeight(.medium)
                                Text(profile.exerciseType.description)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }

                    if profile.exerciseType == .misto {
                        Button {
                            showMixedSchedule = true
                        } label: {
                            HStack {
                                Image(systemName: "calendar")
                                    .foregroundStyle(.orange)
                                Text("Configurar dias de cada modalidade")
                                    .foregroundStyle(.primary)
                                Spacer()
                                if profile.mixedSchedule.isEmpty {
                                    Text("Não configurado")
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                } else {
                                    Text("\(profile.mixedSchedule.count) dias")
                                        .font(.caption)
                                        .foregroundStyle(.green)
                                }
                                Image(systemName: "chevron.right")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                } header: {
                    Text("Atividade física")
                } footer: {
                    Text("Usado pela IA para personalizar seu plano de treino.")
                }

                // ── Meta calórica ─────────────────────────────────
                Section {
                    HStack {
                        Text("Meta calórica calculada")
                        Spacer()
                        Text("\(profile.dailyCalorieGoal) kcal/dia")
                            .fontWeight(.medium)
                            .foregroundStyle(.green)
                    }
                }

                // ── Logout ────────────────────────────────────────
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

                // ── Verificação ───────────────────────────────────
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
            // ── Dialogs & sheets ──────────────────────────────────
            .confirmationDialog(
                "Solicitar verificação",
                isPresented: $showVerificationRequest,
                titleVisibility: .visible
            ) {
                Button("Enviar solicitação") { Task { await requestVerification() } }
                Button("Cancelar", role: .cancel) {}
            } message: {
                Text("Seus dados serão enviados para análise. O processo pode levar alguns dias.")
            }
            .sheet(isPresented: $showExercisePicker) {
                ExercisePickerView(selected: $profile.exerciseType)
            }
            .sheet(isPresented: $showMixedSchedule) {
                MixedScheduleView(schedule: $profile.mixedSchedule)
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
            .onAppear { Task { await checkVerificationStatus() } }
            .confirmationDialog(
                "Deseja sair da conta?",
                isPresented: $showLogoutConfirm,
                titleVisibility: .visible
            ) {
                Button("Sair", role: .destructive) { authManager.logout() }
                Button("Cancelar", role: .cancel) {}
            }
        }
    }

    // MARK: - Helpers (unchanged from original)
    func checkVerificationStatus() async {
        guard let user = authManager.currentUser else { return }
        let db = Firestore.firestore()
        let doc = try? await db.collection("verificationRequests").document(user.uid).getDocument()
        guard let data = doc?.data(), let status = data["status"] as? String else { return }
        await MainActor.run {
            if status == "pending" || status == "approved" {
                verificationRequestSent = true
            } else if status == "denied" {
                if let deniedAt = (data["requestedAt"] as? Timestamp)?.dateValue() {
                    let months = Calendar.current.dateComponents([.month], from: deniedAt, to: Date()).month ?? 0
                    verificationCooldown = months < 6
                }
            }
        }
    }

    func requestVerification() async {
        guard let user = authManager.currentUser else { return }
        let db = Firestore.firestore()
        let requestDoc = try? await db.collection("verificationRequests").document(user.uid).getDocument()
        if let data = requestDoc?.data(), let status = data["status"] as? String {
            if status == "pending" || status == "approved" { await MainActor.run { verificationRequestSent = true }; return }
            if status == "denied", let deniedAt = (data["requestedAt"] as? Timestamp)?.dateValue() {
                let monthsSince = Calendar.current.dateComponents([.month], from: deniedAt, to: Date()).month ?? 0
                if monthsSince < 6 { await MainActor.run { verificationCooldown = true }; return }
            }
        }
        await MainActor.run { verificationRequestSent = true }
        try? await db.collection("verificationRequests").document(user.uid).setData([
            "userID": user.uid, "userName": user.name, "email": user.email,
            "username": user.username, "avatarURL": user.avatarURL,
            "requestedAt": Timestamp(date: Date()), "status": "pending"
        ])
        await sendVerificationEmail(user: user)
    }

    func sendVerificationEmail(user: AppUser) async {
        guard let url = URL(string: "https://us-central1-nutrimarket.cloudfunctions.net/sendVerificationRequest") else { return }
        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        let body: [String: Any] = ["userName": user.name, "username": user.username,
                                   "userEmail": user.email, "userId": user.uid, "avatarURL": user.avatarURL]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)
        try? await URLSession.shared.data(for: request)
    }
}

// MARK: - Exercise Picker Sheet

struct ExercisePickerView: View {
    @Binding var selected: ExerciseType
    @Environment(\.dismiss) var dismiss

    let columns = [GridItem(.flexible()), GridItem(.flexible())]

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVGrid(columns: columns, spacing: 12) {
                    ForEach(ExerciseType.allCases) { type in
                        ExerciseTypeCard(type: type, isSelected: selected == type) {
                            selected = type
                            // Auto-dismiss after a short delay unless misto
                            if type != .misto {
                                DispatchQueue.main.asyncAfter(deadline: .now() + 0.25) { dismiss() }
                            }
                        }
                    }
                }
                .padding()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Tipo de exercício")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pronto") { dismiss() }
                        .fontWeight(.medium)
                }
            }
        }
    }
}

struct ExerciseTypeCard: View {
    let type: ExerciseType
    let isSelected: Bool
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(spacing: 10) {
                ZStack {
                    Circle()
                        .fill(isSelected ? Color.purple : Color.purple.opacity(0.1))
                        .frame(width: 52, height: 52)
                    Image(systemName: type.icon)
                        .font(.title2)
                        .foregroundStyle(isSelected ? .white : .purple)
                }
                Text(type.rawValue)
                    .font(.subheadline).fontWeight(.medium)
                    .foregroundStyle(.primary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
                Text(type.description)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .lineLimit(2)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 130)
            .background(isSelected ? Color.purple.opacity(0.08) : Color(.systemBackground))
            .clipShape(RoundedRectangle(cornerRadius: 16))
            .overlay(
                RoundedRectangle(cornerRadius: 16)
                    .stroke(isSelected ? Color.purple : Color(.systemGray5),
                            lineWidth: isSelected ? 2 : 0.5)
            )
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Mixed Schedule View

struct MixedScheduleView: View {
    @Binding var schedule: [MixedScheduleDay]
    @Environment(\.dismiss) var dismiss

    let weekdays = ["Segunda", "Terça", "Quarta", "Quinta", "Sexta", "Sábado", "Domingo"]
    // Exclude .misto and .nenhum from day choices
    let dayOptions = ExerciseType.allCases.filter { $0 != .misto }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Configure qual modalidade você pratica em cada dia da semana.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }

                ForEach(0..<7, id: \.self) { dayIndex in
                    let dayName = weekdays[dayIndex]
                    let binding = scheduleBinding(for: dayIndex)

                    HStack(spacing: 12) {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(dayName)
                                .font(.subheadline).fontWeight(.medium)
                        }
                        .frame(width: 70, alignment: .leading)

                        Picker("", selection: binding) {
                            ForEach(dayOptions) { type in
                                Label(type.rawValue, systemImage: type.icon).tag(type)
                            }
                        }
                        .pickerStyle(.menu)
                        .frame(maxWidth: .infinity, alignment: .trailing)
                    }
                }
            }
            .navigationTitle("Agenda semanal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Pronto") { dismiss() }
                        .fontWeight(.medium)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Limpar") {
                        schedule = []
                    }
                    .foregroundStyle(.red)
                }
            }
        }
    }

    private func scheduleBinding(for dayIndex: Int) -> Binding<ExerciseType> {
        Binding(
            get: {
                schedule.first(where: { $0.weekday == dayIndex })?.exerciseType ?? .nenhum
            },
            set: { newType in
                if let idx = schedule.firstIndex(where: { $0.weekday == dayIndex }) {
                    if newType == .nenhum {
                        schedule.remove(at: idx)
                    } else {
                        schedule[idx].exerciseType = newType
                    }
                } else if newType != .nenhum {
                    schedule.append(MixedScheduleDay(weekday: dayIndex, exerciseType: newType))
                    schedule.sort { $0.weekday < $1.weekday }
                }
            }
        )
    }
}
