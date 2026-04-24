import SwiftUI
import AVKit
import FirebaseFirestore
import SDWebImage
import SDWebImageSwiftUI

struct PostCardView: View, Equatable {
    static func == (lhs: PostCardView, rhs: PostCardView) -> Bool {
            lhs.post.id == rhs.post.id &&
            lhs.post.likesCount == rhs.post.likesCount &&
            lhs.post.commentsCount == rhs.post.commentsCount &&
            lhs.post.isLiked == rhs.post.isLiked
    }
    @EnvironmentObject var feedManager: FeedManager
    @EnvironmentObject var authManager: AuthManager
    @EnvironmentObject var feedViewModel: FeedViewModel
    let post: Post
    @Binding var showSubscription: Bool
    
    @State private var showComments = false
    @State private var showDeleteConfirm = false
    @State private var showPinConfirm = false
    @State private var showPublicProfile = false
    @State private var isLikeAnimating = false
    @State private var showFullCaption = false
    @State private var isVerifiedLive: Bool = false
    @State private var currentMediaIndex = 0
    @State private var isVisible: Bool = false
    @State private var currentVideoIndex: Int? = nil
    @State private var isMuted: Bool = false
    @State private var isPaused: Bool = false

    // No onAppear, busca o isVerified atualizado
    var isOwnPost: Bool {
        post.userID == authManager.currentUser?.uid
    }
    
    // Calcula o total de mídias no post
    var totalMediaCount: Int {
        if post.mediaURLs.isEmpty {
            return post.mediaURL.isEmpty ? 0 : 1
        }
        return post.mediaURLs.count
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            headerRow
            mediaView
            actionsRow
            captionRow
        }
        .background(Color(.systemBackground))
        .overlay(
            RoundedRectangle(cornerRadius: 18)
                .stroke(post.isPinned ? Color.yellow : Color.clear, lineWidth: post.isPinned ? 4 : 0)
        )
        .clipShape(RoundedRectangle(cornerRadius: 18))
        // Sheets ficam no body, não dentro de sub-views
        .sheet(isPresented: $showComments) {
            CommentsView(post: post)
                .environmentObject(feedManager)
                .environmentObject(authManager)
        }
        .sheet(isPresented: $showPublicProfile) {
            PublicProfileView(userID: post.userID)
                .environmentObject(feedManager)
                .environmentObject(authManager)
        }
        .confirmationDialog("Excluir publicação?",
                            isPresented: $showDeleteConfirm,
                            titleVisibility: .visible) {
            Button("Excluir", role: .destructive) {
                Task { await feedManager.deletePost(post) }
            }
        }
        .confirmationDialog("Fixar publicação para todos por 1 hora?",
                            isPresented: $showPinConfirm,
                            titleVisibility: .visible) {
            Button("Fixar para usuários") {
                Task { await feedManager.pinPostForUsers(post) }
            }
            Button("Cancelar", role: .cancel) { }
        }
        .onAppear {
            isVerifiedLive = post.isVerified
            // Busca em tempo real
            let db = Firestore.firestore()
            db.collection("users").document(post.userID)
                .addSnapshotListener { snapshot, _ in
                    if let data = snapshot?.data() {
                        isVerifiedLive = data["isVerified"] as? Bool ?? false
                    }
                }
        }
    }
    
    // MARK: - Header
    
    var headerRow: some View {
        HStack(spacing: 10) {
            // Avatar clicável
            Button {
                showPublicProfile = true
            } label: {
                AvatarView(url: post.userAvatarURL, size: 40)
                    .overlay(
                        Circle().stroke(
                            post.isPinned ? LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing) : LinearGradient(colors: [.green, .mint], startPoint: .topLeading, endPoint: .bottomTrailing),
                            lineWidth: post.isPinned ? 3.5 : 2
                        )
                    )
            }
            .buttonStyle(.plain)
            
            // Nome clicável
            Button {
                showPublicProfile = true
            } label: {
                VStack(alignment: .leading, spacing: 1) {
                    HStack(spacing: 4) {
                        Text(post.username.isEmpty ? post.userName : post.username)
                            .font(.subheadline).fontWeight(.semibold)
                            .foregroundStyle(post.isPinned ? .orange : .primary)
                        if isVerifiedLive{
                            VerifiedBadge(size: 13)
                        }
                    }
                    if post.isPinned {
                        Text("📌 Fixado")
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(.orange)
                    }
                    HStack(spacing: 4) {
                        if !post.city.isEmpty {
                            Image(systemName: "mappin.fill")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                            Text(post.city)
                                .font(.caption).foregroundStyle(.secondary)
                            if let dist = post.distanceKm {
                                Text("· \(formatDistance(dist))")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            HStack(spacing: 10) {
                // Botão seguir — só para posts de outros
                if !isOwnPost {
                    Button {
                        Task { await feedManager.toggleFollow(targetID: post.userID) }
                    } label: {
                        if feedManager.isFollowing(post.userID) {
                            Text("Seguindo")
                                .font(.caption).fontWeight(.medium)
                                .foregroundStyle(.secondary)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Color(.systemGray5))
                                .clipShape(Capsule())
                        } else {
                            Text("+ Seguir")
                                .font(.caption).fontWeight(.semibold)
                                .foregroundStyle(.white)
                                .padding(.horizontal, 14).padding(.vertical, 6)
                                .background(Color.green)
                                .clipShape(Capsule())
                        }
                    }
                    .buttonStyle(.plain)
                }
                
                // Menu
                Menu {
                    if authManager.currentUser?.isAdmin == true {
                        Button {
                            showPinConfirm = true
                        } label: {
                            Label("Fixar para usuários", systemImage: "pin.fill")
                        }
                    }

                    if isOwnPost {
                        Button(role: .destructive) {
                            showDeleteConfirm = true
                        } label: {
                            Label("Excluir post", systemImage: "trash")
                        }
                    } else {
                        Button { } label: {
                            Label("Denunciar", systemImage: "flag")
                        }
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .foregroundStyle(.primary)
                        .frame(width: 32, height: 32)
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }
    
    // MARK: - Mídia (com suporte a múltiplas mídias)
    
    @ViewBuilder
    var mediaView: some View {
        let mediaURLs = post.mediaURLs.isEmpty ? [post.mediaURL] : post.mediaURLs
        let mediaTypes = post.mediaTypes.isEmpty ? [post.mediaType] : post.mediaTypes
        
        if mediaURLs.first?.isEmpty ?? true {
            // Sem mídia
            Rectangle()
                .fill(Color(.systemGray5))
                .frame(maxWidth: .infinity)
                .frame(height: UIScreen.main.bounds.width * 1.25)
                .overlay(
                    Image(systemName: "photo")
                        .font(.largeTitle)
                        .foregroundStyle(.secondary)
                )
        } else if mediaURLs.count == 1 {
            // Uma única mídia
            mediaContentView(url: mediaURLs[0], type: mediaTypes[0])
        } else {
            // Múltiplas mídias - Carousel
            ZStack(alignment: .bottom) {
                TabView(selection: $currentMediaIndex) {
                    ForEach(Array(mediaURLs.enumerated()), id: \.offset) { index, url in
                        mediaContentView(url: url, type: mediaTypes[index])
                            .tag(index)
                    }
                }
                .tabViewStyle(.page(indexDisplayMode: .never))
                
                // Indicadores de página (pontos cinza)
                if mediaURLs.count > 1 {
                    HStack(spacing: 6) {
                        ForEach(0..<mediaURLs.count, id: \.self) { index in
                            Circle()
                                .fill(index == currentMediaIndex ? Color.white : Color.gray.opacity(0.6))
                                .frame(width: 8, height: 8)
                                .shadow(radius: 1)
                        }
                    }
                    .padding(.bottom, 8)
                }
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.width * 1.25)
            .clipped()
        }
    }
    
    @ViewBuilder
    func mediaContentView(url: String, type: Post.MediaType) -> some View {
        if type == .video {
            ZStack(alignment: .bottomTrailing) {
                VideoPlayerView(url: URL(string: url)!, isAutoPlay: isVisible && !isPaused, isLoop: true, isMuted: $isMuted, isPaused: $isPaused)
                    .frame(maxWidth: .infinity)
                    .frame(height: UIScreen.main.bounds.width * 1.25)
                    .clipped()
                    .onAppear {
                        isVisible = true
                    }
                    .onDisappear {
                        isVisible = false
                    }
                
                // Overlay invisível para capturar toques e pausar/play
                Color.clear
                    .contentShape(Rectangle())
                    .onTapGesture {
                        isPaused.toggle()
                    }
                
                // Botão de mute no canto inferior direito
                Button {
                    isMuted.toggle()
                } label: {
                    Image(systemName: isMuted ? "speaker.slash.fill" : "speaker.wave.2.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white)
                        .padding(8)
                        .background(Color.black.opacity(0.5))
                        .clipShape(Circle())
                        .padding(12)
                }
                .buttonStyle(.plain)
            }
        } else {
            WebImage(url: URL(string: url)) { image in
                image.resizable().scaledToFill()
            } placeholder: {
                Rectangle()
                    .fill(Color(.systemGray5))
                    .overlay(ProgressView())
            }
            .frame(maxWidth: .infinity)
            .frame(height: UIScreen.main.bounds.width * 1.25)
            .clipped()
        }
    }
    
    // MARK: - Ações
    
    var actionsRow: some View {
        HStack(spacing: 18) {
            Button {
                withAnimation(.spring(response: 0.3, dampingFraction: 0.5)) {
                    isLikeAnimating = true
                }
                Task { await feedManager.toggleLike(post: post) }
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                    isLikeAnimating = false
                }
                let impact = UIImpactFeedbackGenerator(style: .light)
                impact.impactOccurred()
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: post.isLiked ? "heart.fill" : "heart")
                        .font(.system(size: 22))
                        .foregroundStyle(post.isLiked ? .red : .primary)
                        .scaleEffect(isLikeAnimating ? 1.35 : 1.0)
                    Text("\(post.likesCount)")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            
            Button {
                showComments = true
            } label: {
                HStack(spacing: 5) {
                    Image(systemName: "bubble.right")
                        .font(.system(size: 22))
                        .foregroundStyle(.primary)
                    Text("\(post.commentsCount)")
                        .font(.subheadline).fontWeight(.medium)
                        .foregroundStyle(.primary)
                }
            }
            .buttonStyle(.plain)
            
            Spacer()
            
            Text(post.createdAt.timeAgoDisplay())
                .font(.caption).foregroundStyle(.secondary)
        }
        .padding(.horizontal, 12)
        .padding(.top, 10)
        .padding(.bottom, 6)
    }
    
    // MARK: - Caption
    
    @ViewBuilder
    var captionRow: some View {
        if !post.caption.isEmpty {
            HStack(alignment: .top, spacing: 0) {
                Text(post.username.isEmpty ? post.userName : post.username)
                    .font(.subheadline).fontWeight(.semibold)
                    .foregroundStyle(post.isPinned ? .orange : .primary)
                Text(" ")
                if showFullCaption {
                    Text(post.caption)
                        .font(.subheadline)
                        .foregroundStyle(post.isPinned ? .orange : .primary)
                } else {
                    Text(String(post.caption.prefix(80)))
                        .font(.subheadline)
                        .foregroundStyle(post.isPinned ? .orange : .primary)
                    if post.caption.count > 80 {
                        Text("... mais").font(.subheadline).foregroundColor(.secondary)
                    }
                }
            }
            .onTapGesture {
                if post.caption.count > 80 {
                    withAnimation { showFullCaption.toggle() }
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 14)
        } else {
            Color.clear.frame(height: 8)
        }
    }
    
    func formatDistance(_ km: Double) -> String {
        if km < 1 { return "< 1km" }
        if km < 100 { return "\(Int(km))km" }
        return "\(Int(km / 100) * 100)km+"
    }
}
    
    // MARK: - Componentes auxiliares

    struct VideoPlayerView: UIViewControllerRepresentable {
        let url: URL
        var isAutoPlay: Bool = false
        var isLoop: Bool = true
        @Binding var isMuted: Bool
        @Binding var isPaused: Bool
        
        func makeUIViewController(context: Context) -> AVPlayerViewController {
            let controller = AVPlayerViewController()
            let player = AVPlayer(url: url)
            player.actionAtItemEnd = .none
            player.isMuted = isMuted
            context.coordinator.player = player
            
            // Configura loop
            if isLoop {
                NotificationCenter.default.addObserver(
                    context.coordinator,
                    selector: #selector(Coordinator.playerDidFinishPlaying),
                    name: .AVPlayerItemDidPlayToEndTime,
                    object: player.currentItem
                )
            }
            
            controller.player = player
            controller.showsPlaybackControls = false
            
            if isAutoPlay && !isPaused {
                player.play()
            }
            
            return controller
        }
        
        func updateUIViewController(_ uiViewController: AVPlayerViewController, context: Context) {
            uiViewController.player?.isMuted = isMuted
            if isAutoPlay && !isPaused {
                uiViewController.player?.play()
            } else {
                uiViewController.player?.pause()
            }
        }
        
        func makeCoordinator() -> Coordinator {
            Coordinator(self)
        }
        
        class Coordinator: NSObject {
            var parent: VideoPlayerView
            var player: AVPlayer?
            
            init(_ parent: VideoPlayerView) {
                self.parent = parent
            }
            
            @objc func playerDidFinishPlaying() {
                // Recomeça o vídeo do início quando terminar, se não estiver pausado
                if !parent.isPaused {
                    player?.seek(to: .zero)
                    player?.play()
                }
            }
        }
    }

struct AvatarView: View {
    let url: String
    let size: CGFloat

    var body: some View {
        Group {
            if url.isEmpty {
                Circle()
                    .fill(LinearGradient(
                        colors: [.green, .mint],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .overlay(
                        Image(systemName: "person.fill")
                            .foregroundStyle(.white)
                            .font(.system(size: size * 0.45))
                    )
            } else {
                WebImage(url: URL(string: url)) { image in
                    image.resizable().scaledToFill()
                } placeholder: {
                    Circle().fill(Color(.systemGray5))
                }
                .clipShape(Circle())
            }
        }
        .frame(width: size, height: size)
    }
}

    extension Date {
        func timeAgoDisplay() -> String {
            let now = Date()
            let components = Calendar.current.dateComponents(
                [.minute, .hour, .day, .weekOfYear],
                from: self, to: now
            )
            if let weeks = components.weekOfYear, weeks > 0 { return "\(weeks)s" }
            if let days = components.day, days > 0 { return "\(days)d" }
            if let hours = components.hour, hours > 0 { return "\(hours)h" }
            if let minutes = components.minute, minutes > 0 { return "\(minutes)m" }
            return "agora"
        }
    }