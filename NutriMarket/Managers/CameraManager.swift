import SwiftUI
import AVFoundation
import Combine

@MainActor
class CameraManager: NSObject, ObservableObject {
    @Published var capturedImage: UIImage?
    @Published var isShowingCamera = false

    var onImageCaptured: ((UIImage) -> Void)?
}

struct CameraPickerView: UIViewControllerRepresentable {
    @Binding var image: UIImage?
    let sourceType: UIImagePickerController.SourceType
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    func makeUIViewController(context: Context) -> UIImagePickerController {
        let picker = UIImagePickerController()
        picker.sourceType = sourceType
        picker.delegate = context.coordinator
        if sourceType == .camera {
            picker.cameraCaptureMode = .photo
        }
        return picker
    }

    func updateUIViewController(_ uiViewController: UIImagePickerController, context: Context) {}

    func makeCoordinator() -> Coordinator {
        Coordinator(self)
    }

    class Coordinator: NSObject, UIImagePickerControllerDelegate, UINavigationControllerDelegate {
        let parent: CameraPickerView

        init(_ parent: CameraPickerView) {
            self.parent = parent
        }

        func imagePickerController(_ picker: UIImagePickerController,
                                   didFinishPickingMediaWithInfo info: [UIImagePickerController.InfoKey: Any]) {
            if let image = info[.originalImage] as? UIImage {
                parent.image = image
                parent.onCapture(image)
            }
            parent.dismiss()
        }

        func imagePickerControllerDidCancel(_ picker: UIImagePickerController) {
            parent.dismiss()
        }
    }
}

struct ImageSourcePickerView: View {
    @Binding var image: UIImage?
    let onCapture: (UIImage) -> Void
    @Environment(\.dismiss) var dismiss

    @State private var showCamera = false
    @State private var showGallery = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 20) {

                Text("Como deseja adicionar a foto?")
                    .font(.headline)
                    .padding(.top, 32)

                Button {
                    showCamera = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.blue.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "camera.fill")
                                .font(.title2)
                                .foregroundStyle(.blue)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Tirar foto agora")
                                .font(.headline).foregroundStyle(.primary)
                            Text("Abre a câmera do celular")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
                .buttonStyle(.plain)

                Button {
                    showGallery = true
                } label: {
                    HStack(spacing: 16) {
                        ZStack {
                            Circle()
                                .fill(Color.purple.opacity(0.12))
                                .frame(width: 56, height: 56)
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.title2)
                                .foregroundStyle(.purple)
                        }
                        VStack(alignment: .leading, spacing: 3) {
                            Text("Escolher da galeria")
                                .font(.headline).foregroundStyle(.primary)
                            Text("Selecione uma foto existente")
                                .font(.caption).foregroundStyle(.secondary)
                        }
                        Spacer()
                        Image(systemName: "chevron.right")
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .background(Color(.systemBackground))
                    .clipShape(RoundedRectangle(cornerRadius: 16))
                    .shadow(color: .black.opacity(0.06), radius: 8, y: 2)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal)
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Adicionar foto")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .sheet(isPresented: $showCamera) {
                CameraPickerView(image: $image, sourceType: .camera) { img in
                    onCapture(img)
                    dismiss()
                }
            }
            .sheet(isPresented: $showGallery) {
                CameraPickerView(image: $image, sourceType: .photoLibrary) { img in
                    onCapture(img)
                    dismiss()
                }
            }
        }
    }
}
