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

    private var streamSession: StreamSession?
    private var stateToken: Any?
    private var frameToken: Any?
    private var lastCaptureTime: Date = .distantPast
    private let captureInterval: TimeInterval = 4.0

    var onFrameCaptured: ((UIImage) -> Void)?

    func setup() {
        do {
            try Wearables.configure()
        } catch {
            statusMessage = "Erro ao configurar SDK: \(error)"
            return
        }
        Task {
            await startRegistration()
        }
    }

    func startRegistration() async {
        do {
            try await Wearables.shared.startRegistration()
            await observeDevices()
        } catch {
            statusMessage = "Erro no registro: \(error)"
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
        do {
            let status = try await Wearables.shared.checkPermissionStatus(.camera)
            if status != .granted {
                _ = try await Wearables.shared.requestPermission(.camera)
            }
        } catch {
            statusMessage = "Erro de permissão: \(error)"
            return
        }

        let config = StreamSessionConfig(
            videoCodec: .raw,
            resolution: .medium,
            frameRate: 7
        )
        let deviceSelector = AutoDeviceSelector(wearables: Wearables.shared)
        let session = StreamSession(
            streamSessionConfig: config,
            deviceSelector: deviceSelector
        )

        stateToken = session.statePublisher.listen { [weak self] state in
            Task { @MainActor in
                switch state {
                case .streaming:
                    self?.isStreaming = true
                    self?.statusMessage = "Câmera ativa"
                case .stopped, .stopping:
                    self?.isStreaming = false
                    self?.statusMessage = "Câmera pausada"
                case .waitingForDevice:
                    self?.statusMessage = "Aguardando óculos..."
                default:
                    break
                }
            }
        }

        frameToken = session.videoFramePublisher.listen { [weak self] frame in
            guard let self, let image = frame.makeUIImage() else { return }
            let now = Date()
            Task { @MainActor in
                guard now.timeIntervalSince(self.lastCaptureTime) >= self.captureInterval else { return }
                self.lastCaptureTime = now
                self.lastFrame = image
                self.onFrameCaptured?(image)
            }
        }

        streamSession = session
        await session.start()
    }

    func stopStream() {
        Task {
            await streamSession?.stop()
            isStreaming = false
        }
    }

    func handleURL(_ url: URL) async {
        try? await Wearables.shared.handleUrl(url)
    }
}
