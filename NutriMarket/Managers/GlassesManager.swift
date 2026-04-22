import Foundation
import Combine
import MWDATCore
import MWDATCamera
import UIKit

@MainActor
class GlassesManager: ObservableObject {

    @Published var isConnected = false
    @Published var isStreaming = false
    @Published var statusMessage = "Aguardando conexão..."
    @Published var isAnalyzing = false
    @Published var lastFrame: UIImage?
    var isConfigured = false

    private var deviceSession: DeviceSession?
    private var stateToken: Any?
    private var frameToken: Any?
    private var lastCaptureTime: Date = .distantPast
    private let captureInterval: TimeInterval = 4.0

    var onFrameCaptured: ((UIImage) -> Void)?

    func setup() {
        guard !isConfigured else { return }
        do {
            try Wearables.configure()
            isConfigured = true
            startRegistration()
        } catch {
            statusMessage = "Erro ao configurar SDK: \(error)"
        }
    }

    func startRegistration() {
        Task { @MainActor in
            do {
                try await Wearables.shared.startRegistration()
                await self.observeDevices()
            } catch {
                self.statusMessage = "Erro no registro: \(error)"
            }
        }
    }

    func observeDevices() async {
        for await devices in Wearables.shared.devicesStream() {
            isConnected = !devices.isEmpty
            statusMessage = devices.isEmpty
                ? "Óculos não encontrado"
                : "Óculos conectado"
        }
    }

    func startStream() async {
        // Stream não disponível nesta versão da SDK
        // StreamSession não tem inicializador público
        statusMessage = "Stream não suportado nesta versão da SDK"
        // print("⚠️ StreamSession não tem inicializador público na SDK atual")
    }

    func stopStream() {
        deviceSession?.stop()
        isStreaming = false
        statusMessage = "Câmera pausada"
    }

    func handleURL(_ url: URL) async {
        try? await Wearables.shared.handleUrl(url)
    }
}
