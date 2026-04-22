import SwiftUI
import PhotosUI
import CoreLocation

struct NewPostView: View {
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) var dismiss
    @Binding var showSubscription: Bool

    @State private var selectedItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var selectedVideoURL: URL?
    @State private var mediaType: Post.MediaType = .photo
    @State private var caption = ""
    @State private var city = ""
    @State private var region = ""
    @State private var isResolvingLocation = false
    @StateObject private var locationManager = FeedLocationManager()
    
    var hasMedia: Bool { selectedImage != nil || selectedVideoURL != nil }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {

                    // Seletor de mídia
                    PhotosPicker(
                        selection: $selectedItem,
                        matching: .any(of: [.images, .videos])
                    ) {
                        ZStack {
                            RoundedRectangle(cornerRadius: 16)
                                .fill(Color(.systemGray6))
                                .frame(height: 280)

                            if let image = selectedImage {
                                Image(uiImage: image)
                                    .resizable()
                                    .scaledToFill()
                                    .frame(maxWidth: .infinity)
                                    .frame(height: 280)
                                    .clipShape(RoundedRectangle(cornerRadius: 16))
                            } else {
                                VStack(spacing: 12) {
                                    Image(systemName: "photo.badge.plus")
                                        .font(.system(size: 44))
                                        .foregroundStyle(.green)
                                    Text("Toque para selecionar foto ou vídeo")
                                        .font(.subheadline).foregroundStyle(.secondary)
                                    Text("Vídeos até 60 segundos")
                                        .font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .onChange(of: selectedItem) { _, newItem in
                        Task { await loadMedia(from: newItem) }
                    }

                    // Caption
                    VStack(alignment: .leading, spacing: 6) {
                        Text("Legenda")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)
                        TextField("Compartilhe algo sobre sua saúde...", text: $caption, axis: .vertical)
                            .font(.subheadline)
                            .lineLimit(5)
                            .padding()
                            .background(Color(.systemBackground))
                            .clipShape(RoundedRectangle(cornerRadius: 12))
                            .overlay(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color(.systemGray4), lineWidth: 0.5)
                            )
                    }

                    // Localização
                    VStack(alignment: .leading, spacing: 6) {
                        Label("Localização", systemImage: "mappin.circle.fill")
                            .font(.caption).fontWeight(.medium).foregroundStyle(.secondary)

                        HStack {
                            if isResolvingLocation {
                                ProgressView().scaleEffect(0.8)
                                Text("Detectando localização...")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            } else if !city.isEmpty {
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                                Text("\(city)\(region.isEmpty ? "" : ", \(region)")")
                                    .font(.subheadline)
                            } else {
                                Text("Localização não disponível")
                                    .font(.subheadline).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Button("Detectar") {
                                resolveLocation()
                            }
                            .font(.caption).foregroundStyle(.green)
                        }
                        .padding()
                        .background(Color(.systemBackground))
                        .clipShape(RoundedRectangle(cornerRadius: 12))
                        .overlay(
                            RoundedRectangle(cornerRadius: 12)
                                .stroke(Color(.systemGray4), lineWidth: 0.5)
                        )
                    }

                    // Botão publicar
                    Button {
                        Task { await publish() }
                    } label: {
                        HStack {
                            Image(systemName: "paperplane.fill")
                            Text("Publicar")
                                .fontWeight(.medium)
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(
                            hasMedia
                            ? LinearGradient(colors: [.green, .mint], startPoint: .leading, endPoint: .trailing)
                            : LinearGradient(colors: [.gray.opacity(0.4)], startPoint: .leading, endPoint: .trailing)
                        )
                        .foregroundStyle(.white)
                        .clipShape(RoundedRectangle(cornerRadius: 16))
                    }
                    .disabled(!hasMedia)
                }
                .padding()
            }
            .background(Color(.systemGray6).ignoresSafeArea())
            .navigationTitle("Nova publicação")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancelar") { dismiss() }
                }
            }
            .onAppear {
                locationManager.requestLocation()
                resolveLocation()
            }
        }
    }

    func loadMedia(from item: PhotosPickerItem?) async {
        guard let item else { return }

        if let data = try? await item.loadTransferable(type: Data.self) {
            if let image = UIImage(data: data) {
                selectedImage = image
                selectedVideoURL = nil
                mediaType = .photo
            }
        }
    }

    func resolveLocation() {
        guard let location = locationManager.lastLocation else { return }
        isResolvingLocation = true
        Task {
            let result = await CityResolver.resolve(location: location)
            city = result.city
            region = result.region
            isResolvingLocation = false
        }
    }

    func publish() async {
        var mediaData: Data?

        if let image = selectedImage {
            mediaData = image.jpegData(compressionQuality: 0.8)
        }

        guard let data = mediaData else { return }

        await feedManager.uploadPost(
            mediaData: data,
            mediaType: mediaType,
            caption: caption,
            location: locationManager.lastLocation,
            city: city,
            region: region
        )

        dismiss()
    }
}
