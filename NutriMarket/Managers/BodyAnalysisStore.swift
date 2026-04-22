import Foundation
import UIKit
import FirebaseAuth
import FirebaseFirestore
import FirebaseStorage
import Combine

struct SavedBodyAnalysis: Codable {
    let result: BodyAnalysisResult
    let workoutPlan: WorkoutPlan
    let imageURL: String
    let createdAt: Date
}

struct BodyAnalysisHistoryItem: Identifiable {
    let id: String
    let analysis: SavedBodyAnalysis
}

@MainActor
final class BodyAnalysisStore: ObservableObject {
    @Published var latest: SavedBodyAnalysis?
    @Published var history: [BodyAnalysisHistoryItem] = []

    private let db = Firestore.firestore()
    private let storage = Storage.storage()

    func loadLatest() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let doc = try await db.collection("users")
                .document(uid)
                .collection("bodyAnalysis")
                .document("latest")
                .getDocument()

            guard let data = doc.data(),
                  let blob = data["payload"] as? String,
                  let createdAtTs = data["createdAt"] as? Timestamp,
                  let jsonData = Data(base64Encoded: blob) else { return }

            let decoded = try JSONDecoder().decode(SavedBodyAnalysis.self, from: jsonData)
            latest = SavedBodyAnalysis(
                result: decoded.result,
                workoutPlan: decoded.workoutPlan,
                imageURL: decoded.imageURL,
                createdAt: createdAtTs.dateValue()
            )
        } catch {
            // Mantém a tela sem bloquear em caso de falha de leitura.
        }
    }

    func loadHistory(limit: Int = 20) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await db.collection("users")
                .document(uid)
                .collection("bodyAnalysis")
                .order(by: "createdAt", descending: true)
                .limit(to: limit)
                .getDocuments()

            history = snapshot.documents.compactMap { doc in
                guard doc.documentID != "latest",
                      let data = doc.data() as [String: Any]?,
                      let blob = data["payload"] as? String,
                      let createdAtTs = data["createdAt"] as? Timestamp,
                      let jsonData = Data(base64Encoded: blob),
                      let decoded = try? JSONDecoder().decode(SavedBodyAnalysis.self, from: jsonData) else {
                    return nil
                }

                let enriched = SavedBodyAnalysis(
                    result: decoded.result,
                    workoutPlan: decoded.workoutPlan,
                    imageURL: decoded.imageURL,
                    createdAt: createdAtTs.dateValue()
                )
                return BodyAnalysisHistoryItem(id: doc.documentID, analysis: enriched)
            }
        } catch {
            history = []
        }
    }

    func save(image: UIImage, result: BodyAnalysisResult, workoutPlan: WorkoutPlan) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let imageData = image.jpegData(compressionQuality: 0.78) else { return }
        do {
            let imagePath = "bodyAnalysis/\(uid)/latest.jpg"
            let imageRef = storage.reference().child(imagePath)
            let metadata = StorageMetadata()
            metadata.contentType = "image/jpeg"
            _ = try await imageRef.putDataAsync(imageData, metadata: metadata)
            let downloadURL = try await imageRef.downloadURL()

            let payload = SavedBodyAnalysis(
                result: result,
                workoutPlan: workoutPlan,
                imageURL: downloadURL.absoluteString,
                createdAt: Date()
            )
            let encoded = try JSONEncoder().encode(payload)
            let base64 = encoded.base64EncodedString()

            try await db.collection("users")
                .document(uid)
                .collection("bodyAnalysis")
                .document("latest")
                .setData([
                    "payload": base64,
                    "imageURL": downloadURL.absoluteString,
                    "createdAt": Timestamp(date: Date())
                ], merge: true)

            let historyDocID = "analysis-\(Int(Date().timeIntervalSince1970 * 1000))"
            try await db.collection("users")
                .document(uid)
                .collection("bodyAnalysis")
                .document(historyDocID)
                .setData([
                    "payload": base64,
                    "imageURL": downloadURL.absoluteString,
                    "createdAt": Timestamp(date: Date())
                ], merge: true)

            latest = payload
            history.insert(
                BodyAnalysisHistoryItem(id: historyDocID, analysis: payload),
                at: 0
            )
        } catch {
            // Não interrompe o fluxo principal se persistência falhar.
        }
    }
}
