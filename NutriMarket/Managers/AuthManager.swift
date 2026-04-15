import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

@MainActor
class AuthManager: ObservableObject {
    @Published var currentUser: AppUser?
    @Published var isLoading = true
    @Published var errorMessage = ""

    private let db = Firestore.firestore()
    private var authStateListener: AuthStateDidChangeListenerHandle?

    init() {
        listenToAuthChanges()
    }

    func listenToAuthChanges() {
        authStateListener = Auth.auth().addStateDidChangeListener { [weak self] _, firebaseUser in
            Task { @MainActor in
                if let firebaseUser {
                    await self?.fetchUserProfile(uid: firebaseUser.uid)
                } else {
                    self?.currentUser = nil
                    self?.isLoading = false
                }
            }
        }
    }

    func fetchUserProfile(uid: String) async {
        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            if let data = doc.data() {
                currentUser = AppUser(
                    uid: uid,
                    name: data["name"] as? String ?? "",
                    email: data["email"] as? String ?? "",
                    isAdmin: data["isAdmin"] as? Bool ?? false,
                    createdAt: (data["createdAt"] as? Timestamp)?.dateValue() ?? Date()
                )
            }
        } catch {
            errorMessage = "Erro ao carregar perfil: \(error.localizedDescription)"
        }
        isLoading = false
    }

    func login(email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        do {
            try await Auth.auth().signIn(withEmail: email, password: password)
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
        }
    }

    func register(name: String, email: String, password: String) async {
        isLoading = true
        errorMessage = ""
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            try await db.collection("users").document(uid).setData([
                "name": name,
                "email": email,
                "isAdmin": false,
                "createdAt": Timestamp(date: Date()),
                "weight": 0,
                "height": 0,
                "age": 0,
                "sex": "Masculino",
                "goal": "Manter peso"
            ])

            await fetchUserProfile(uid: uid)
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
        }
    }

    func logout() {
        try? Auth.auth().signOut()
        currentUser = nil
    }

    func resetPassword(email: String) async -> Bool {
        do {
            try await Auth.auth().sendPasswordReset(withEmail: email)
            return true
        } catch {
            errorMessage = friendlyError(error)
            return false
        }
    }

    func updateProfile(_ profile: UserProfile) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "name": profile.name,
                "weight": profile.weight,
                "height": profile.height,
                "age": profile.age,
                "sex": profile.sex,
                "goal": profile.goal
            ])
        } catch {
            errorMessage = "Erro ao salvar perfil: \(error.localizedDescription)"
        }
    }

    var isLoggedIn: Bool { currentUser != nil }

    private func friendlyError(_ error: Error) -> String {
        let nsError = error as NSError
        let code = nsError.code
        switch code {
        case 17007: return "Este email já está cadastrado."
        case 17008: return "Email inválido."
        case 17026: return "Senha muito fraca. Use ao menos 6 caracteres."
        case 17009: return "Senha incorreta."
        case 17011: return "Usuário não encontrado."
        case 17020: return "Sem conexão com a internet."
        default:    return "Erro: \(error.localizedDescription)"
        }
    }

    deinit {
        if let listener = authStateListener {
            Auth.auth().removeStateDidChangeListener(listener)
        }
    }
}

struct AppUser {
    let uid: String
    let name: String
    let email: String
    let isAdmin: Bool
    let createdAt: Date
}
