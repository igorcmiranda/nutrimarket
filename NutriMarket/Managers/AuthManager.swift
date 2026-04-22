import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage

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
    
    func uploadAvatar(image: UIImage) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let data = image.jpegData(compressionQuality: 0.7) else { return }

        let ref = Storage.storage().reference().child("avatars/\(uid)/avatar.jpg")
        let metadata = StorageMetadata()
        metadata.contentType = "image/jpeg"

        do {
            _ = try await ref.putDataAsync(data, metadata: metadata)
            let url = try await ref.downloadURL()

            try await Firestore.firestore().collection("users").document(uid).updateData([
                "avatarURL": url.absoluteString
            ])

            if var user = currentUser {
                currentUser = AppUser(
                    uid: user.uid,
                    name: user.name,
                    email: user.email,
                    avatarURL: url.absoluteString,
                    username: user.username,
                    isAdmin: user.isAdmin,
                    isVerified: user.isVerified,
                    createdAt: user.createdAt
                )
            }
        } catch {
            errorMessage = "Erro ao atualizar foto: \(error.localizedDescription)"
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
                    avatarURL: data["avatarURL"] as? String ?? "",
                    username: data["username"] as? String ?? "",
                    isAdmin: data["isAdmin"] as? Bool ?? false,
                    isVerified: data["isVerified"] as? Bool ?? false,
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

        var loginEmail = email.trimmingCharacters(in: .whitespacesAndNewlines)

        // Se não contém @, trata como username e busca o email
        if !loginEmail.contains("@") {
            if let fetchedEmail = await fetchEmailByUsername(loginEmail) {
                loginEmail = fetchedEmail
            } else {
                errorMessage = "Usuário não encontrado"
                isLoading = false
                return
            }
        }

        do {
            try await Auth.auth().signIn(withEmail: loginEmail, password: password)
            if let uid = Auth.auth().currentUser?.uid {
                await fetchUserProfile(uid: uid)
            }
        } catch {
            errorMessage = friendlyError(error)
            isLoading = false
        }
    }

    func register(name: String, email: String, password: String,
                  username: String, referralCode: String? = nil) async {
        isLoading = true
        errorMessage = ""
        do {
            let result = try await Auth.auth().createUser(withEmail: email, password: password)
            let uid = result.user.uid

            var userData: [String: Any] = [
                "name": name,
                "email": email,
                "username": username,
                "isAdmin": false,
                "isVerified": false,
                "createdAt": Timestamp(date: Date()),
                "weight": 0,
                "height": 0,
                "age": 0,
                "sex": "Masculino",
                "goal": "Manter peso",
                "avatarURL": "",
                "followersCount": 0,
                "showOnLeaderboard": false
            ]

            // Salva indicação se válida
            if let code = referralCode {
                userData["referredBy"] = code
            }

            try await db.collection("users").document(uid).setData(userData)
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
    
    func fetchEmailByUsername(_ username: String) async -> String? {
        let snapshot = try? await db.collection("users")
            .whereField("username", isEqualTo: username.lowercased())
            .limit(to: 1)
            .getDocuments()
        return snapshot?.documents.first?.data()["email"] as? String
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
    let avatarURL: String
    let username: String  // novo
    let isAdmin: Bool
    let isVerified: Bool
    let createdAt: Date
}
