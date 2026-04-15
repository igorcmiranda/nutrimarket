import SwiftUI

struct ResetPasswordView: View {
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss

    @State private var email = ""
    @State private var sent = false

    var body: some View {
        NavigationStack {
            ZStack {
                Color(.systemGray6).ignoresSafeArea()

                VStack(spacing: 24) {

                    VStack(spacing: 12) {
                        Image(systemName: sent ? "checkmark.circle.fill" : "lock.rotation")
                            .font(.system(size: 52))
                            .foregroundStyle(sent ? .green : .orange)

                        Text(sent ? "Email enviado!" : "Redefinir senha")
                            .font(.title2).fontWeight(.bold)

                        Text(sent
                             ? "Verifique sua caixa de entrada e siga as instruções para redefinir sua senha."
                             : "Digite seu email e enviaremos um link para redefinir sua senha.")
                            .font(.subheadline).foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal)
                    }
                    .padding(.top, 32)

                    if !sent {
                        VStack(spacing: 16) {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Email")
                                    .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                                TextField("seu@email.com", text: $email)
                                    .keyboardType(.emailAddress)
                                    .autocapitalization(.none)
                                    .padding()
                                    .background(Color(.systemBackground))
                                    .clipShape(RoundedRectangle(cornerRadius: 12))
                                    .overlay(RoundedRectangle(cornerRadius: 12).stroke(Color(.systemGray4), lineWidth: 0.5))
                            }

                            if !authManager.errorMessage.isEmpty {
                                Text(authManager.errorMessage)
                                    .font(.caption).foregroundStyle(.red)
                            }

                            Button {
                                Task {
                                    let success = await authManager.resetPassword(email: email)
                                    if success { sent = true }
                                }
                            } label: {
                                Text("Enviar link de redefinição")
                                    .fontWeight(.medium)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color.orange)
                                    .foregroundStyle(.white)
                                    .clipShape(RoundedRectangle(cornerRadius: 14))
                            }
                            .disabled(email.isEmpty)
                            .opacity(email.isEmpty ? 0.6 : 1)
                        }
                        .padding(.horizontal)
                    } else {
                        Button {
                            dismiss()
                        } label: {
                            Text("Voltar ao login")
                                .fontWeight(.medium)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(LinearGradient(colors: [.green, .mint],
                                                           startPoint: .leading, endPoint: .trailing))
                                .foregroundStyle(.white)
                                .clipShape(RoundedRectangle(cornerRadius: 14))
                        }
                        .padding(.horizontal)
                    }

                    Spacer()
                }
            }
            .navigationTitle("Redefinir senha")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
        }
    }
}
