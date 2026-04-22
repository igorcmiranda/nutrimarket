import SwiftUI
import PhotosUI
import CoreLocation
import AVKit
import UniformTypeIdentifiers

struct NewPostView: View {
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @Binding var showSubscription: Bool

    @State private var selectedItems: [PhotosPickerItem] = []
    @State private var selectedImages: [UIImage] = []
    @State private var selectedVideos: [VideoItem] = []
    @State private var caption = ""
    @State private var city = ""
    @State private var region = ""
    @State private var isResolvingLocation = false
    @State private var showVideoLimitAlert = false
    @State private var videoLimitMessage = ""
    @State private var currentMediaIndex = 0
    @StateObject private var locationManager = FeedLocationManager()
    
    var hasMedia: Bool { !selectedImages.isEmpty || !selectedVideos.isEmpty }
    var totalMediaCount: Int { selectedImages.count + selectedVideos.count }
    
    // Modelo para armazenar dados do vídeo
    struct VideoItem: Identifiable {
        let id = UUID()
        let data: Data
        let thumbnail: UIImage?
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    mediaSelector
                    removeButton
                    captionField
                    locationField
                    publishButton
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
        .alert("Vídeo não permitido", isPresented: $showVideoLimitAlert) {
            Button("OK", role: .cancel) { }
        } message: {
            Text(videoLimitMessage)
        }
    }
    
    // MARK: - Media Selector
    
    @ViewBuilder
    var mediaSelector: some View {
        PhotosPicker(
            selection: $selectedItems,
            maxSelectionCount: 10,
            matching: .any(of: [.images, .videos])
        ) {
            mediaPreview
        }
        .onChange(of: selectedItems) { _, newItems in
            Task { await loadMedia(from: newItems) }
        }
    }
    
    @ViewBuilder
    var mediaPreview: some View {
        ZStack {
            RoundedRectangle(cornerRadius: 16)
                .fill(Color(.systemGray6))
                .frame(height: 280)

            if hasMedia {
                mediaCarousel
            } else {
                mediaPlaceholder
            }
        }
    }
    
    @ViewBuilder
    var mediaCarousel: some View {
        TabView(selection: $currentMediaIndex) {
            imagesTabView
            videosTabView
        }
        .tabViewStyle(.page(indexDisplayMode: .never))
        .frame(height: 280)
        .clipShape(RoundedRectangle(cornerRadius: 16))
        
        pageIndicators
    }
    
    @ViewBuilder
    var imagesTabView: some View {
        ForEach(Array(selectedImages.enumerated()), id: \.offset) { index, image in
            Image(uiImage: image)
                .resizable()
                .scaledToFill()
                .frame(maxWidth: .infinity)
                .frame(height: 280)
                .clipped()
                .tag(index)
        }
    }
    
    @ViewBuilder
    var videosTabView: some View {
        ForEach(Array(selectedVideos.enumerated()), id: \.offset) { index, video in
            let videoIndex = selectedImages.count + index
            ZStack {
                if let thumbnail = video.thumbnail {
                    Image(uiImage: thumbnail)
                        .resizable()
                        .scaledToFill()
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                        .clipped()
                } else {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(maxWidth: .infinity)
                        .frame(height: 280)
                }
                
                Image(systemName: "play.circle.fill")
                    .font(.system(size: 50))
                    .foregroundStyle(.white.opacity(0.9))
            }
            .frame(maxWidth: .infinity)
            .frame(height: 280)
            .clipped()
            .tag(videoIndex)
        }
    }
    
    @ViewBuilder
    var pageIndicators: some View {
        if totalMediaCount > 1 {
            HStack(spacing: 6) {
                ForEach(0..<totalMediaCount, id: \.self) { index in
                    Circle()
                        .fill(index == currentMediaIndex ? Color.green : Color.gray.opacity(0.5))
                        .frame(width: 8, height: 8)
                }
            }
            .padding(.top, 8)
        }
    }
    
    @ViewBuilder
    var mediaPlaceholder: some View {
        VStack(spacing: 12) {
            Image(systemName: "photo.badge.plus")
                .font(.system(size: 44))
                .foregroundStyle(.green)
            Text("Toque para selecionar fotos ou vídeos")
                .font(.subheadline).foregroundStyle(.secondary)
            Text("Máximo 10 arquivos")
                .font(.caption).foregroundStyle(.secondary)
            Text("Vídeos até 60 segundos")
                .font(.caption).foregroundStyle(.secondary)
        }
    }
    
    // MARK: - Remove Button
    
    @ViewBuilder
    var removeButton: some View {
        if hasMedia {
            HStack {
                Button {
                    removeMedia(at: currentMediaIndex)
                } label: {
                    HStack {
                        Image(systemName: "trash")
                        Text("Remover")
                    }
                    .font(.subheadline)
                    .foregroundStyle(.red)
                }
                
                Spacer()
                
                if totalMediaCount > 1 {
                    Text("\(currentMediaIndex + 1) de \(totalMediaCount)")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.horizontal)
        }
    }
    
    // MARK: - Caption Field
    
    @ViewBuilder
    var captionField: some View {
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
    }
    
    // MARK: - Location Field
    
    @ViewBuilder
    var locationField: some View {
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
    }
    
    // MARK: - Publish Button
    
    @ViewBuilder
    var publishButton: some View {
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
    
    // MARK: - Functions
    
    func removeMedia(at index: Int) {
        let imageCount = selectedImages.count
        
        if index < imageCount {
            selectedImages.remove(at: index)
        } else {
            let videoIndex = index - imageCount
            if videoIndex < selectedVideos.count {
                selectedVideos.remove(at: videoIndex)
            }
        }
        
        if currentMediaIndex >= totalMediaCount && totalMediaCount > 0 {
            currentMediaIndex = max(0, totalMediaCount - 1)
        } else if totalMediaCount == 0 {
            currentMediaIndex = 0
        }
        
        selectedItems.removeAll()
    }

    func loadMedia(from items: [PhotosPickerItem]) async {
        guard !items.isEmpty else { return }
        
        selectedImages.removeAll()
        selectedVideos.removeAll()
        
        for item in items {
            // Primeiro tenta carregar como imagem
            if let data = try? await item.loadTransferable(type: Data.self),
               let image = UIImage(data: data) {
                selectedImages.append(image)
                continue
            }
            
            // Tenta carregar como vídeo usando itemProvider
            if item.itemIdentifier?.contains("video") == true || item.supportedContentTypes.contains(where: { $0.conforms(to: .movie) }) {
                await loadVideo(from: item)
            }
        }
    }
    
    func loadVideo(from item: PhotosPickerItem) async {
        // Tenta obter os dados do vídeo diretamente via loadTransferable
        guard let data = try? await item.loadTransferable(type: Data.self) else {
            // Se falhar, tenta usar a abordagem com itemIdentifier
            await loadVideoViaIdentifier(from: item)
            return
        }
        
        let duration = await videoDurationSeconds(from: data)
        guard duration <= 60 else {
            await MainActor.run {
                videoLimitMessage = "O vídeo selecionado tem \(Int(duration)) segundos. Escolha um vídeo de até 60 segundos."
                showVideoLimitAlert = true
            }
            return
        }
        
        // Gera thumbnail do vídeo
        let thumbnail = await generateThumbnail(from: data)
        
        await MainActor.run {
            selectedVideos.append(VideoItem(data: data, thumbnail: thumbnail))
        }
    }
    
    func loadVideoViaIdentifier(from item: PhotosPickerItem) async {
        // Fallback: tenta usar itemIdentifier se disponível
        guard let identifier = item.itemIdentifier else { return }
        
        // Verifica se é um tipo de vídeo
        let isVideo = item.supportedContentTypes.contains { $0.conforms(to: .movie) }
        guard isVideo else { return }
        
        // Para vídeos do Photos, tentamos carregar diretamente
        // Isso é um fallback limitado
        await MainActor.run {
            videoLimitMessage = "Não foi possível carregar o vídeo. Tente salvar o vídeo no app e adicionar novamente."
            showVideoLimitAlert = true
        }
    }
    
    func generateThumbnail(from videoData: Data) async -> UIImage? {
        // Salva temporariamente para gerar thumbnail
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        do {
            try videoData.write(to: tempURL)
            let asset = AVURLAsset(url: tempURL)
            let generator = AVAssetImageGenerator(asset: asset)
            generator.appliesPreferredTrackTransform = true
            generator.maximumSize = CGSize(width: 600, height: 600)
            
            let time = CMTime(seconds: 0, preferredTimescale: 600)
            let cgImage = try generator.copyCGImage(at: time, actualTime: nil)
            
            try? FileManager.default.removeItem(at: tempURL)
            
            return UIImage(cgImage: cgImage)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return nil
        }
    }
    
    func videoDurationSeconds(from data: Data) async -> Double {
        let tempURL = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString + ".mp4")
        
        do {
            try data.write(to: tempURL)
            let asset = AVURLAsset(url: tempURL)
            let duration = try await asset.load(.duration)
            try? FileManager.default.removeItem(at: tempURL)
            return CMTimeGetSeconds(duration)
        } catch {
            try? FileManager.default.removeItem(at: tempURL)
            return .infinity
        }
    }

    func videoDurationSeconds(for url: URL) async -> Double {
        let asset = AVURLAsset(url: url)
        do {
            let duration = try await asset.load(.duration)
            return CMTimeGetSeconds(duration)
        } catch {
            return .infinity
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
        var mediaDataArray: [(Data, Post.MediaType)] = []
        
        // Adiciona imagens
        for image in selectedImages {
            if let data = image.jpegData(compressionQuality: 0.8) {
                mediaDataArray.append((data, .photo))
            }
        }
        
        // Adiciona vídeos
        for video in selectedVideos {
            mediaDataArray.append((video.data, .video))
        }

        guard !mediaDataArray.isEmpty else { return }

        await feedManager.uploadPost(
            mediaDataArray: mediaDataArray,
            caption: caption,
            location: locationManager.lastLocation,
            city: city,
            region: region
        )

        dismiss()
    }
}




