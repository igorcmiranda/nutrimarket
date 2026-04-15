import SwiftUI

struct RegisterView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var name = ""
    @State private var email = ""
    @State private var password = ""
    @State private var confirmPassword = ""
    @State private var passwordMismatch = false

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

                            inputField(label: "Email", placeholder: "seu@email.com", text: $email,
                                       keyboard: .emailAddress, autocap: false)

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Senha")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                SecureField("Mínimo 6 caracteres", text: $password)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Confirmar senha")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                SecureField("Repita a senha", text: $confirmPassword)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(passwordMismatch ? Color.red : Color(.systemGray4), lineWidth: passwordMismatch ? 1 : 0.5)
                                    )
                                if passwordMismatch {
                                    Text("As senhas não coincidem")
                                        .font(.caption).foregroundStyle(.red)
                                }
                            }

                            if !authManager.errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(authManager.errorMessage)
                                        .font(.caption).foregroundStyle(.red)
                                }
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            Button {
                                guard password == confirmPassword else {
                                    passwordMismatch = true
                                    return
                                }
                                passwordMismatch = false
                                Task { await authManager.register(name: name, email: email, password: password) }
                            } label: {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    }
                                    Text("Criar conta")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(colors: [.green, .mint],
                                                   startPoint: .leading, endPoint: .trailing)
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(name.isEmpty || email.isEmpty || password.isEmpty || authManager.isLoading)
                            .opacity(name.isEmpty || email.isEmpty || password.isEmpty ? 0.6 : 1)
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

    func inputField(label: String, placeholder: String, text: Binding<String>,
                    keyboard: UIKeyboardType = .default, autocap: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(label)
                .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
            TextField(placeholder, text: text)
                .keyboardType(keyboard)
                .autocapitalization(autocap ? .words : .none)
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
        }
    }
}
