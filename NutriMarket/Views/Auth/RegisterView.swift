import SwiftUI
import FirebaseFirestore
import FirebaseAuth

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var username = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordMismatch = false
    @State private var usernameStatus: UsernameStatus = .idle
    @State private var usernameCheckTask: Task<Void, Never>? = nil
    @State private var referralCode = ""
    @State private var referralStatus: ReferralStatus = .idle
    @State private var emailStatus: EmailStatus = .idle
    @State private var emailCheckTask: Task<Void, Never>? = nil

    enum EmailStatus {
        case idle, checking, available, taken
        var message: String {
            switch self {
            case .idle:      return ""
            case .checking:  return "Verificando email..."
            case .available: return "Email disponível!"
            case .taken:     return "Conta já existente, não é possível usar esse email novamente."
            }
        }
        var color: Color {
            switch self {
            case .available: return .green
            case .taken:     return .red
            default:         return .secondary
            }
        }
    }

    enum ReferralStatus {
        case idle, checking, valid, invalid
        var message: String {
            switch self {
            case .idle:     return ""
            case .checking: return "Verificando código..."
            case .valid:    return "Código válido! ✓"
            case .invalid:  return "Código não encontrado"
            }
        }
        var color: Color {
            switch self {
            case .valid:   return .green
            case .invalid: return .red
            default:       return .secondary
            }
        }
    }

    enum UsernameStatus {
        case idle, checking, available, taken, invalid
        var message: String {
            switch self {
            case .idle:      return ""
            case .checking:  return "Verificando..."
            case .available: return "@ disponível!"
            case .taken:     return "@ já está em uso"
            case .invalid:   return "Apenas letras minúsculas, números, _ e &. Máx 12 caracteres."
            }
        }
        var color: Color {
            switch self {
            case .available: return .green
            case .taken, .invalid: return .red
            default: return .secondary
            }
        }
    }

    // Regex atualizado — aceita letras minúsculas, números, _, & e .
    var isUsernameValid: Bool {
        let regex = "^[a-z0-9_.&]{1,12}$"
        return username.range(of: regex, options: .regularExpression) != nil
    }

    var canRegister: Bool {
        !name.isEmpty && !email.isEmpty && !password.isEmpty &&
        usernameStatus == .available &&
        emailStatus == .available &&
        !authManager.isLoading
    }

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()
                ScrollView {
                    VStack(spacing: 24) {
                        VStack(spacing: 8) {
                            Text("Criar conta")
                                .font(.title2).fontWeight(.bold)
                            Text("Preencha seus dados para começar")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 8)

                        VStack(spacing: 16) {
                            inputField(label: "Nome completo", placeholder: "Seu nome", text: $name)

                            // Campo @
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Nome de usuário (@)")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                HStack {
                                    Text("@")
                                        .fontWeight(.medium).foregroundStyle(.secondary)
                                    TextField("seuusuario", text: $username)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .onChange(of: username) { _, newValue in
                                            let filtered = newValue.lowercased()
                                                .filter { "abcdefghijklmnopqrstuvwxyz0123456789_&.".contains($0) }
                                                .prefix(12)
                                            if username != String(filtered) {
                                                username = String(filtered)
                                                return
                                            }
                                            checkUsername()
                                        }
                                    Spacer()
                                    if usernameStatus == .checking {
                                        ProgressView().scaleEffect(0.7)
                                    } else if usernameStatus == .available {
                                        Image(systemName: "checkmark.circle.fill")
                                            .foregroundStyle(.green)
                                    } else if usernameStatus == .taken || usernameStatus == .invalid {
                                        Image(systemName: "xmark.circle.fill")
                                            .foregroundStyle(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(usernameStatus == .available ? Color.green :
                                                usernameStatus == .taken || usernameStatus == .invalid ? Color.red :
                                                Color(.systemGray4), lineWidth: 1)
                                )

                                if usernameStatus != .idle {
                                    Text(usernameStatus.message)
                                        .font(.caption)
                                        .foregroundStyle(usernameStatus.color)
                                }
                                Text("Máx. 12 caracteres. Use letras minúsculas, números, _, & e .")
                                    .font(.caption2).foregroundStyle(.secondary)
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                HStack {
                                    TextField("seu@email.com", text: $email)
                                        .keyboardType(.emailAddress)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .onChange(of: email) { _, _ in
                                            checkEmail()
                                        }
                                    if emailStatus == .checking {
                                        ProgressView().scaleEffect(0.7)
                                    } else if emailStatus == .available {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if emailStatus == .taken {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            emailStatus == .available ? Color.green :
                                            emailStatus == .taken ? Color.red :
                                            Color(.systemGray4),
                                            lineWidth: emailStatus == .idle ? 0.5 : 1
                                        )
                                )

                                if emailStatus != .idle {
                                    Text(emailStatus.message)
                                        .font(.caption)
                                        .foregroundStyle(emailStatus.color)
                                        .fixedSize(horizontal: false, vertical: true)
                                }
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Senha")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                SecureField("Mínimo 6 caracteres", text: $password)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(.systemGray4), lineWidth: 0.5))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirmar senha")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                SecureField("Repita a senha", text: $confirmPassword)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12)
                                        .stroke(passwordMismatch ? Color.red : Color(.systemGray4),
                                                lineWidth: passwordMismatch ? 1 : 0.5))
                                if passwordMismatch {
                                    Text("As senhas não coincidem")
                                        .font(.caption).foregroundStyle(.red)
                                }
                            }

                            if !authManager.errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill").foregroundStyle(.red)
                                    Text(authManager.errorMessage).font(.caption).foregroundStyle(.red)
                                }
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }
                            
                            // Campo de indicação
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Código de indicação (opcional)")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                HStack {
                                    TextField("Código de quem te indicou", text: $referralCode)
                                        .autocapitalization(.none)
                                        .autocorrectionDisabled()
                                        .onChange(of: referralCode) { _, _ in
                                            checkReferral()
                                        }
                                    if referralStatus == .checking {
                                        ProgressView().scaleEffect(0.7)
                                    } else if referralStatus == .valid {
                                        Image(systemName: "checkmark.circle.fill").foregroundStyle(.green)
                                    } else if referralStatus == .invalid {
                                        Image(systemName: "xmark.circle.fill").foregroundStyle(.red)
                                    }
                                }
                                .padding()
                                .background(Color(.systemBackground))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(
                                            referralStatus == .valid ? Color.green :
                                            referralStatus == .invalid ? Color.red :
                                            Color(.systemGray4),
                                            lineWidth: referralStatus == .idle ? 0.5 : 1
                                        )
                                )

                                if referralStatus != .idle {
                                    Text(referralStatus.message)
                                        .font(.caption)
                                        .foregroundStyle(referralStatus.color)
                                }
                            }

                            Button {
                                guard password == confirmPassword else {
                                        passwordMismatch = true
                                        return
                                    }
                                    passwordMismatch = false
                                    Task {
                                        await authManager.register(
                                            name: name,
                                            email: email,
                                            password: password,
                                            username: username,
                                            referralCode: referralCode.isEmpty ? nil : referralCode.lowercased()
                                        )
                                    }
                            } label: {
                                HStack {
                                    if authManager.isLoading { ProgressView().tint(.white).scaleEffect(0.8) }
                                    Text("Criar conta").fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity).padding()
                                .background(
                                    LinearGradient(colors: [.green, .mint],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(!canRegister)
                            .opacity(canRegister ? 1 : 0.6)
                        }
                        .padding(.horizontal)
                    }
                    .padding(.bottom, 32)
                }
            }
            .navigationTitle("Cadastro")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }

    func checkUsername() {
        usernameCheckTask?.cancel()
        guard !username.isEmpty else { usernameStatus = .idle; return }
        guard isUsernameValid else { usernameStatus = .invalid; return }
        usernameStatus = .checking

        usernameCheckTask = Task {
            try? await Task.sleep(nanoseconds: 500_000_000) // 0.5s debounce
            guard !Task.isCancelled else { return }

            let db = Firestore.firestore()
            let snapshot = try? await db.collection("users")
                .whereField("username", isEqualTo: username)
                .getDocuments()

            await MainActor.run {
                if Task.isCancelled { return }
                usernameStatus = (snapshot?.documents.isEmpty ?? true) ? .available : .taken
            }
        }
    }
    
    func checkReferral() {
        guard !referralCode.isEmpty else {
            referralStatus = .idle
            return
        }
        referralStatus = .checking

        Task {
            let db = Firestore.firestore()
            let snapshot = try? await db.collection("referralCodes")
                .document(referralCode.lowercased())
                .getDocument()

            await MainActor.run {
                referralStatus = (snapshot?.exists ?? false) ? .valid : .invalid
            }
        }
    }
    
    func checkEmail() {
        emailCheckTask?.cancel()
        guard !email.isEmpty, email.contains("@") else {
            emailStatus = .idle
            return
        }
        emailStatus = .checking

        emailCheckTask = Task {
            try? await Task.sleep(nanoseconds: 600_000_000) // 0.6s debounce
            guard !Task.isCancelled else { return }

            do {
                let methods = try await Auth.auth().fetchSignInMethods(forEmail: email)
                await MainActor.run {
                    if Task.isCancelled { return }
                    emailStatus = methods.isEmpty ? .available : .taken
                }
            } catch {
                await MainActor.run {
                    emailStatus = .idle
                }
            }
        }
    }

    func inputField(label: String, placeholder: String, text: Binding<String>,
                    keyboard: UIKeyboardType = .default, autocap: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label).font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocapitalization(autocap ? .words : .none)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12)
                    .stroke(Color(.systemGray4), lineWidth: 0.5))
        }
    }
}
