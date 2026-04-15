import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showResetPassword = false
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ZStack {
                LinearGradient(
                    colors: [Color(.systemBackground), Color(.systemGray6)],
                    startPoint: .top, endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {

                        // Logo
                        VStack(spacing: 12) {
                            ZStack {
                                Circle()
                                    .fill(LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    ))
                                    .frame(width: 90, height: 90)
                                Image(systemName: "fork.knife")
                                    .font(.system(size: 40))
                                    .foregroundStyle(.white)
                            }
                            Text("Nutri-Market")
                                .font(.title).fontWeight(.bold)
                            Text("Seu assistente nutricional inteligente")
                                .font(.subheadline).foregroundStyle(.secondary)
                        }
                        .padding(.top, 48)

                        // Formulário
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                TextField("seu@email.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Senha")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(.secondary)
                                SecureField("••••••••", text: $password)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(.systemGray4), lineWidth: 0.5)
                                    )
                            }

                            // Esqueceu a senha
                            HStack {
                                Spacer()
                                Button("Esqueceu a senha?") {
                                    showResetPassword = true
                                }
                                .font(.caption)
                                .foregroundStyle(.green)
                            }

                            // Erro
                            if !authManager.errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(authManager.errorMessage)
                                        .font(.caption)
                                        .foregroundStyle(.red)
                                }
                                .padding()
                                .background(Color.red.opacity(0.08))
                                .clipShape(RoundedRectangle(cornerRadius: 10))
                            }

                            // Botão entrar
                            Button {
                                Task { await authManager.login(email: email, password: password) }
                            } label: {
                                HStack {
                                    if authManager.isLoading {
                                        ProgressView().tint(.white).scaleEffect(0.8)
                                    }
                                    Text("Entrar")
                                        .fontWeight(.medium)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [.green, .mint],
                                        startPoint: .leading, endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                        }
                        .padding(.horizontal)

                        // Cadastro
                        VStack(spacing: 8) {
                            Divider()
                            Button {
                                showRegister = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Novo por aqui?")
                                        .foregroundStyle(.secondary)
                                    Text("Cadastre-se")
                                        .fontWeight(.medium)
                                        .foregroundStyle(.green)
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.bottom, 32)
                    }
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
            }
        }
    }
}
