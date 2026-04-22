import Foundation
import Combine
import FirebaseAuth
import FirebaseFirestore

enum AppLanguage: String, CaseIterable, Identifiable {
    case pt = "pt-BR"
    case en = "en"
    case es = "es"
    case fr = "fr"
    case de = "de"
    case it = "it"
    case nl = "nl"
    case sv = "sv"
    case da = "da"
    case no = "no"
    case fi = "fi"
    case pl = "pl"
    case tr = "tr"
    case ru = "ru"
    case uk = "uk"
    case ar = "ar"
    case hi = "hi"
    case th = "th"
    case vi = "vi"
    case id = "id"
    case zhHans = "zh-Hans"
    case zhHant = "zh-Hant"
    case ja = "ja"
    case ko = "ko"

    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .pt: return "Português (Brasil)"
        case .en: return "English"
        case .es: return "Español"
        case .fr: return "Français"
        case .de: return "Deutsch"
        case .it: return "Italiano"
        case .nl: return "Nederlands"
        case .sv: return "Svenska"
        case .da: return "Dansk"
        case .no: return "Norsk"
        case .fi: return "Suomi"
        case .pl: return "Polski"
        case .tr: return "Türkçe"
        case .ru: return "Русский"
        case .uk: return "Українська"
        case .ar: return "العربية"
        case .hi: return "हिन्दी"
        case .th: return "ไทย"
        case .vi: return "Tiếng Việt"
        case .id: return "Bahasa Indonesia"
        case .zhHans: return "中文 (简体)"
        case .zhHant: return "中文 (繁體)"
        case .ja: return "日本語"
        case .ko: return "한국어"
        }
    }

    var flag: String {
        switch self {
        case .pt: return "🇧🇷"
        case .en: return "🇺🇸"
        case .es: return "🇪🇸"
        case .fr: return "🇫🇷"
        case .de: return "🇩🇪"
        case .it: return "🇮🇹"
        case .nl: return "🇳🇱"
        case .sv: return "🇸🇪"
        case .da: return "🇩🇰"
        case .no: return "🇳🇴"
        case .fi: return "🇫🇮"
        case .pl: return "🇵🇱"
        case .tr: return "🇹🇷"
        case .ru: return "🇷🇺"
        case .uk: return "🇺🇦"
        case .ar: return "🇸🇦"
        case .hi: return "🇮🇳"
        case .th: return "🇹🇭"
        case .vi: return "🇻🇳"
        case .id: return "🇮🇩"
        case .zhHans: return "🇨🇳"
        case .zhHant: return "🇹🇼"
        case .ja: return "🇯🇵"
        case .ko: return "🇰🇷"
        }
    }
}

@MainActor
final class LanguageManager: ObservableObject {
    @Published var selectedLanguage: AppLanguage

    static let userDefaultsKey = "preferredAppLanguage"
    private let db = Firestore.firestore()

    init() {
        let stored = UserDefaults.standard.string(forKey: Self.userDefaultsKey)
        selectedLanguage = AppLanguage(rawValue: stored ?? "") ?? .pt
    }

    func setLanguage(_ language: AppLanguage) {
        selectedLanguage = language
        UserDefaults.standard.set(language.rawValue, forKey: Self.userDefaultsKey)
    }

    func syncLanguageFromFirestoreIfNeeded() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        do {
            let doc = try await db.collection("users").document(uid).getDocument()
            guard let data = doc.data(),
                  let remoteCode = data["preferredLanguage"] as? String,
                  let remoteLanguage = AppLanguage(rawValue: remoteCode) else {
                return
            }

            if remoteLanguage != selectedLanguage {
                setLanguage(remoteLanguage)
            }
        } catch {
            // Mantém o idioma local em caso de erro.
        }
    }

    func persistLanguageToFirestoreIfLoggedIn() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            try await db.collection("users").document(uid).updateData([
                "preferredLanguage": selectedLanguage.rawValue
            ])
        } catch {
            // Não bloqueia UX se falhar a persistência remota.
        }
    }
}
