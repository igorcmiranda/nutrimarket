import SwiftUI

struct LoginView: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var email = ""
    @State private var password = ""
    @State private var showRegister = false
    @State private var showResetPassword = false

    var body: some View {
        NavigationStack {
            ZStack {
                // Fundo escuro
                LinearGradient(
                    colors: [
                        Color(hex: "080818"),
                        Color(hex: "0D0D2B"),
                        Color(hex: "080818")
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
                .ignoresSafeArea()

                ScrollView {
                    VStack(spacing: 32) {

                        // Logo e nome
                        VStack(spacing: 16) {
                            Image("AppLogo")
                                .resizable()
                                .scaledToFit()
                                .frame(width: 100, height: 100)
                                .clipShape(RoundedRectangle(cornerRadius: 22))
                                .shadow(color: Color(hex: "4A6FE8").opacity(0.7), radius: 24)
                                .padding(.top, 60)

                            Text("Vyro")
                                .font(.system(size: 38, weight: .black, design: .rounded))
                                .foregroundStyle(
                                    LinearGradient(
                                        colors: [Color(hex: "A78BFA"), Color(hex: "60A5FA")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )

                            Text("Melhore sua vida fitness!")
                                .font(.subheadline)
                                .foregroundStyle(Color(hex: "8B9CC8"))
                        }

                        // Formulário
                        VStack(alignment: .leading, spacing: 6) {
                            Text("Email ou @usuário")
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(Color(hex: "8B9CC8"))
                            TextField("seu@email.com ou @seuusuario", text: $email)
                                .keyboardType(.emailAddress)
                                .autocapitalization(.none)
                                .autocorrectionDisabled()
                                .foregroundStyle(.white)
                                .padding()
                                .background(Color(hex: "1A1A3E"))
                                .clipShape(RoundedRectangle(cornerRadius: 12))
                                .overlay(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color(hex: "3D4A8A"), lineWidth: 1)
                                )
                        }

                            VStack(alignment: .leading, spacing: 6) {
                                Text("Senha")
                                    .font(.caption).fontWeight(.medium)
                                    .foregroundStyle(Color(hex: "8B9CC8"))
                                SecureField("••••••••", text: $password)
                                    .foregroundStyle(.white)
                                    .padding()
                                    .background(Color(hex: "1A1A3E"))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color(hex: "3D4A8A"), lineWidth: 1)
                                    )
                            }

                            HStack {
                                Spacer()
                                Button("Esqueceu a senha?") {
                                    showResetPassword = true
                                }
                                .font(.caption)
                                .foregroundStyle(Color(hex: "60A5FA"))
                            }

                            // Erro
                            if !authManager.errorMessage.isEmpty {
                                HStack(spacing: 8) {
                                    Image(systemName: "exclamationmark.circle.fill")
                                        .foregroundStyle(.red)
                                    Text(authManager.errorMessage)
                                        .font(.caption).foregroundStyle(.red)
                                }
                                .padding()
                                .background(Color.red.opacity(0.1))
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
                                        .fontWeight(.bold)
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    LinearGradient(
                                        colors: [Color(hex: "4A6FE8"), Color(hex: "7B5FDC")],
                                        startPoint: .leading,
                                        endPoint: .trailing
                                    )
                                )
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                                .shadow(color: Color(hex: "4A6FE8").opacity(0.4), radius: 10, y: 4)
                            }
                            .disabled(email.isEmpty || password.isEmpty || authManager.isLoading)
                            .opacity(email.isEmpty || password.isEmpty ? 0.6 : 1)
                        }
                        .padding(.horizontal)

                        // Cadastro
                        VStack(spacing: 12) {
                            HStack {
                                Rectangle()
                                    .fill(Color(hex: "2A2A4A"))
                                    .frame(height: 1)
                                Text("ou")
                                    .font(.caption)
                                    .foregroundStyle(Color(hex: "8B9CC8"))
                                    .padding(.horizontal, 8)
                                Rectangle()
                                    .fill(Color(hex: "2A2A4A"))
                                    .frame(height: 1)
                            }

                            Button {
                                showRegister = true
                            } label: {
                                HStack(spacing: 4) {
                                    Text("Novo por aqui?")
                                        .foregroundStyle(Color(hex: "8B9CC8"))
                                    Text("Cadastre-se")
                                        .fontWeight(.bold)
                                        .foregroundStyle(Color(hex: "60A5FA"))
                                }
                                .font(.subheadline)
                            }
                        }
                        .padding(.horizontal)
                        .padding(.bottom, 40)
                    }
                }
            }
            .sheet(isPresented: $showRegister) {
                RegisterView()
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showResetPassword) {
                ResetPasswordView()
                    .environmentObject(authManager)
            }
        }
    }

