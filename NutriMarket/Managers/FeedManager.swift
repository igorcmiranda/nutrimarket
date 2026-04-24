    // Filtro de feed: global, país, estado, cidade
    @MainActor
    func applyFeedFilter(_ filter: FeedFilter, user: UserProfile?, location: CLLocation?) async {
        isLoading = true
        var query: Query = db.collection("posts").order(by: "createdAt", descending: true).limit(to: pageSize)
        switch filter {
        case .global:
            // Sem filtro
            break
        case .country:
            if let country = user?.country {
                query = query.whereField("country", isEqualTo: country)
            }
        case .state:
            if let region = user?.region {
                query = query.whereField("region", isEqualTo: region)
            }
        case .city:
            if let city = user?.city {
                query = query.whereField("city", isEqualTo: city)
            }
        }
        do {
            let snapshot = try await query.getDocuments()
            await processPosts(from: snapshot.documents, append: false)
        } catch {
            posts = []
        }
        isLoading = false
    }
import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import CoreLocation

enum FeedFilter: String, CaseIterable, Identifiable {
    case global = "GLOBAL"
    case country = "PAÍS"
    case state = "ESTADO"
    case city = "CIDADE"
    var id: String { rawValue }
}

@MainActor
class FeedManager: ObservableObject {
        // Filtro de feed: global, país, estado, cidade
        @MainActor
        func applyFeedFilter(_ filter: FeedFilter, user: UserProfile?, location: CLLocation?) async {
            isLoading = true
            var query: Query = db.collection("posts").order(by: "createdAt", descending: true).limit(to: pageSize)
            switch filter {
            case .global:
                // Sem filtro
                break
            case .country:
                if let country = user?.country {
                    query = query.whereField("country", isEqualTo: country)
                }
            case .state:
                if let region = user?.region {
                    query = query.whereField("region", isEqualTo: region)
                }
            case .city:
                if let city = user?.city {
                    query = query.whereField("city", isEqualTo: city)
                }
            }
            do {
                let snapshot = try await query.getDocuments()
                await processPosts(from: snapshot.documents, append: false)
            } catch {
                posts = []
            }
            isLoading = false
        }
    @Published var posts: [Post] = []
    @Published var isLoading = false
    @Published var isUploading = false
    @Published var uploadProgress: Double = 0
    @Published var followingIDs: Set<String> = []
    @Published var errorMessage = ""
    @Published var hasMore = true
    @Published var isLoadingMore = false
    private var lastDocument: DocumentSnapshot?
    private let pageSize = 15
    private let db = Firestore.firestore()
    private let storage = Storage.storage()
    private var postsListener: ListenerRegistration?
    private var userLocation: CLLocation?
    private let pinnedConfigRef = Firestore.firestore().collection("appConfig").document("feedPinnedPost")

    deinit {
        postsListener?.remove()
    }

    // MARK: - Listener em tempo real

    func startListening(userLocation: CLLocation?) {
        self.userLocation = userLocation
        postsListener?.remove()
        posts = []
        lastDocument = nil
        hasMore = true

        // Carrega apenas os 15 primeiros
        postsListener = db.collection("posts")
            .order(by: "createdAt", descending: true)
            .limit(to: pageSize)
            .addSnapshotListener { [weak self] snapshot, error in
                guard let self, let snapshot else { return }
                Task { @MainActor in
                    self.lastDocument = snapshot.documents.last
                    self.hasMore = snapshot.documents.count == self.pageSize
                    await self.processPosts(from: snapshot.documents)
                }
            }
    }
    
    func loadMorePosts() async {
        guard hasMore, !isLoadingMore, let last = lastDocument else { return }
        isLoadingMore = true

        do {
            let snapshot = try await db.collection("posts")
                .order(by: "createdAt", descending: true)
                .start(afterDocument: last)
                .limit(to: pageSize)
                .getDocuments()

            lastDocument = snapshot.documents.last
            hasMore = snapshot.documents.count == pageSize
            await processPosts(from: snapshot.documents, append: true)
        } catch {
            // // print("Erro ao carregar mais posts: \(error)")
        }

        isLoadingMore = false
    }
    
    func processPosts(from documents: [QueryDocumentSnapshot], append: Bool = false) async {
        var loaded = documents.compactMap { doc -> Post? in
            var post = try? doc.data(as: Post.self)
            post?.id = doc.documentID
            return post
        }

        if let location = userLocation {
            for i in loaded.indices {
                let postLocation = CLLocation(
                    latitude: loaded[i].latitude,
                    longitude: loaded[i].longitude
                )
                loaded[i].distanceKm = location.distance(from: postLocation) / 1000
            }
        }

        if let uid = Auth.auth().currentUser?.uid {
            await withTaskGroup(of: (Int, Bool).self) { group in
                for (i, post) in loaded.enumerated() {
                    group.addTask {
                        let likeDoc = try? await Firestore.firestore()
                            .collection("posts").document(post.id)
                            .collection("likes").document(uid)
                            .getDocument()
                        return (i, likeDoc?.exists ?? false)
                    }
                }
                for await (i, isLiked) in group {
                    loaded[i].isLiked = isLiked
                }
            }
        }

        let sorted = sortPosts(loaded)
        let withPinnedFirst = await applyPinnedPostIfNeeded(in: sorted)
        if append {
            let existingIDs = Set(posts.map(\.id))
            let unique = withPinnedFirst.filter { !existingIDs.contains($0.id) }
            posts.append(contentsOf: unique)
        } else {
            posts = withPinnedFirst
        }
        isLoading = false
    }

    func loadFeed(userLocation: CLLocation?) async {
        isLoading = true
        await loadFollowing()
        startListening(userLocation: userLocation)
    }

    func sortPosts(_ posts: [Post]) -> [Post] {
        let following = followingIDs
        return posts.sorted { a, b in
            let aFollowed = following.contains(a.userID)
            let bFollowed = following.contains(b.userID)
            if aFollowed != bFollowed { return aFollowed }
            if let da = a.distanceKm, let db = b.distanceKm { return da < db }
            return a.createdAt > b.createdAt
        }
    }

    private func applyPinnedPostIfNeeded(in sortedPosts: [Post]) async -> [Post] {
        guard var pinned = await fetchActivePinnedPost() else {
            return sortedPosts.map { post in
                var mutable = post
                mutable.isPinned = false
                return mutable
            }
        }

        pinned.isPinned = true
        var reordered = sortedPosts.filter { $0.id != pinned.id }.map { post in
            var mutable = post
            mutable.isPinned = false
            return mutable
        }
        reordered.insert(pinned, at: 0)
        return reordered
    }

    private func fetchActivePinnedPost() async -> Post? {
        do {
            let configDoc = try await pinnedConfigRef.getDocument()
            guard let data = configDoc.data(),
                  let postID = data["postID"] as? String,
                  let expiresTimestamp = data["expiresAt"] as? Timestamp else {
                return nil
            }

            let expiresAt = expiresTimestamp.dateValue()
            guard expiresAt > Date() else {
                try? await pinnedConfigRef.delete()
                return nil
            }

            if let alreadyLoaded = posts.first(where: { $0.id == postID }) {
                return alreadyLoaded
            }

            let postDoc = try await db.collection("posts").document(postID).getDocument()
            guard postDoc.exists else { return nil }

            var post = try postDoc.data(as: Post.self)
            post.id = postDoc.documentID

            if let location = userLocation {
                let postLocation = CLLocation(latitude: post.latitude, longitude: post.longitude)
                post.distanceKm = location.distance(from: postLocation) / 1000
            }

            if let uid = Auth.auth().currentUser?.uid {
                let likeDoc = try? await db.collection("posts")
                    .document(post.id)
                    .collection("likes")
                    .document(uid)
                    .getDocument()
                post.isLiked = likeDoc?.exists ?? false
            }

            return post
        } catch {
            return nil
        }
    }

    // MARK: - Upload de post (múltiplas mídias)

    func uploadPost(
        mediaDataArray: [(Data, Post.MediaType)],
        caption: String,
        location: CLLocation?,
        city: String,
        region: String
    ) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let user = try? await db.collection("users").document(uid).getDocument(),
              let userData = user.data() else { return }

        isUploading = true
        uploadProgress = 0

        let postID = UUID().uuidString
        let name = userData["name"] as? String ?? "Usuário"
        let avatar = userData["avatarURL"] as? String ?? ""
        let isVerified = userData["isVerified"] as? Bool ?? false
        let username = userData["username"] as? String ?? ""

        // Upload de múltiplas mídias
        var mediaURLs: [String] = []
        var mediaTypes: [Post.MediaType] = []
        
        for (index, (mediaData, mediaType)) in mediaDataArray.enumerated() {
            let ext = mediaType == .photo ? "jpg" : "mp4"
            let ref = storage.reference().child("posts/\(uid)/\(postID)_\(index).\(ext)")
            let metadata = StorageMetadata()
            metadata.contentType = mediaType == .photo ? "image/jpeg" : "video/mp4"

            do {
                _ = try await ref.putDataAsync(mediaData, metadata: metadata)
                let downloadURL = try await ref.downloadURL()
                mediaURLs.append(downloadURL.absoluteString)
                mediaTypes.append(mediaType)
            } catch {
                errorMessage = "Erro ao fazer upload: \(error.localizedDescription)"
                continue
            }
        }

        guard !mediaURLs.isEmpty else {
            isUploading = false
            return
        }

        // Usar a primeira mídia como mídia principal (para compatibility)
        let mainMediaURL = mediaURLs[0]
        let mainMediaType = mediaTypes[0]

        let post = Post(
            id: postID,
            userID: uid,
            userName: name,
            username: username,
            userAvatarURL: avatar,
            isVerified: isVerified,
            mediaURL: mainMediaURL,
            mediaURLs: mediaURLs,
            mediaType: mainMediaType,
            mediaTypes: mediaTypes,
            caption: caption,
            city: city,
            region: region,
            latitude: location?.coordinate.latitude ?? 0,
            longitude: location?.coordinate.longitude ?? 0,
            likesCount: 0,
            commentsCount: 0,
            createdAt: Date()
        )

        do {
            try db.collection("posts").document(postID).setData(from: post)

            // Notifica seguidores sobre novo post
            let followersSnapshot = try? await db.collectionGroup("following")
                .whereField("targetID", isEqualTo: uid)
                .getDocuments()

            for followerDoc in followersSnapshot?.documents ?? [] {
                let followerUID = followerDoc.reference.parent.parent?.documentID ?? ""
                guard !followerUID.isEmpty && followerUID != uid else { continue }
                await NotificationManager.send(
                    toUserID: followerUID,
                    type: .newPost,
                    fromUserID: uid,
                    fromUserName: name,
                    fromUserAvatar: avatar,
                    postID: postID,
                    postMediaURL: mainMediaURL,
                    message: "\(name) fez uma nova publicação"
                )
            }

        } catch {
            errorMessage = "Erro ao publicar: \(error.localizedDescription)"
        }

        isUploading = false
    }

    // MARK: - Upload de post (única mídia - compatibility)

    func uploadPost(
        mediaData: Data,
        mediaType: Post.MediaType,
        caption: String,
        location: CLLocation?,
        city: String,
        region: String
    ) async {
        await uploadPost(
            mediaDataArray: [(mediaData, mediaType)],
            caption: caption,
            location: location,
            city: city,
            region: region
        )
    }

    // MARK: - Likes

    func toggleLike(post: Post) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        guard let index = posts.firstIndex(where: { $0.id == post.id }) else { return }

        let likeRef = db.collection("posts").document(post.id)
            .collection("likes").document(uid)
        let postRef = db.collection("posts").document(post.id)

        let wasLiked = posts[index].isLiked
        posts[index].isLiked = !wasLiked
        posts[index].likesCount = max(0, posts[index].likesCount + (wasLiked ? -1 : 1))

        do {
            if wasLiked {
                try await likeRef.delete()
                let doc = try await postRef.getDocument()
                let current = doc.data()?["likesCount"] as? Int ?? 0
                try await postRef.updateData(["likesCount": max(0, current - 1)])
            } else {
                try await likeRef.setData(["likedAt": Timestamp(date: Date())])
                try await postRef.updateData([
                    "likesCount": FieldValue.increment(Int64(1))
                ])

                // Notifica dono do post (se não for o próprio)
                if post.userID != uid,
                   let user = try? await db.collection("users").document(uid).getDocument(),
                   let userData = user.data() {
                    let name = userData["name"] as? String ?? "Alguém"
                    let avatar = userData["avatarURL"] as? String ?? ""
                    await NotificationManager.send(
                        toUserID: post.userID,
                        type: .newLike,
                        fromUserID: uid,
                        fromUserName: name,
                        fromUserAvatar: avatar,
                        postID: post.id,
                        postMediaURL: post.mediaURL,
                        message: "\(name) curtiu sua publicação"
                    )
                }
            }
        } catch {
            posts[index].isLiked = wasLiked
            posts[index].likesCount = max(0, posts[index].likesCount + (wasLiked ? 1 : -1))
        }
    }

    // MARK: - Comentários

    func loadComments(postID: String) async -> [Comment] {
        do {
            let snapshot = try await db.collection("posts").document(postID)
                .collection("comments")
                .order(by: "createdAt", descending: false)
                .getDocuments()
            return snapshot.documents.compactMap { doc in
                var comment = try? doc.data(as: Comment.self)
                comment?.id = doc.documentID
                return comment
            }
        } catch {
            return []
        }
    }

    func addComment(postID: String, text: String) async {
        guard let uid = Auth.auth().currentUser?.uid,
              let user = try? await db.collection("users").document(uid).getDocument(),
              let userData = user.data() else { return }

        let commentID = UUID().uuidString
        let name = userData["name"] as? String ?? "Usuário"
        let avatar = userData["avatarURL"] as? String ?? ""

        let comment = Comment(
            id: commentID,
            userID: uid,
            userName: name,
            userAvatarURL: avatar,
            text: text,
            createdAt: Date()
        )

        do {
            try db.collection("posts").document(postID)
                .collection("comments").document(commentID)
                .setData(from: comment)

            try await db.collection("posts").document(postID)
                .updateData(["commentsCount": FieldValue.increment(Int64(1))])

            if let index = posts.firstIndex(where: { $0.id == postID }) {
                posts[index].commentsCount += 1

                // Notifica dono do post
                let post = posts[index]
                if post.userID != uid {
                    await NotificationManager.send(
                        toUserID: post.userID,
                        type: .newComment,
                        fromUserID: uid,
                        fromUserName: name,
                        fromUserAvatar: avatar,
                        postID: postID,
                        postMediaURL: post.mediaURL,
                        message: "\(name) comentou: \"\(text.prefix(40))\""
                    )
                }
            }
        } catch {
            // // print("Erro ao comentar: \(error)")
        }
    }

    // MARK: - Seguir

    func toggleFollow(targetID: String) async {
        guard let uid = Auth.auth().currentUser?.uid else { return }

        let followRef = db.collection("follows").document(uid)
            .collection("following").document(targetID)
        let targetUserRef = db.collection("users").document(targetID)

        let wasFollowing = followingIDs.contains(targetID)

        // Otimistic update
        if wasFollowing {
            followingIDs.remove(targetID)
        } else {
            followingIDs.insert(targetID)
        }
        posts = sortPosts(posts)

        do {
            let userDoc = try await db.collection("users").document(uid).getDocument()
            let userData = userDoc.data()
            let name = userData?["name"] as? String ?? "Alguém"
            let avatar = userData?["avatarURL"] as? String ?? ""

            if wasFollowing {
                try await followRef.delete()

                // Remove da subcoleção followers do alvo
                try? await db.collection("users").document(targetID)
                    .collection("followers").document(uid).delete()

                let doc = try await targetUserRef.getDocument()
                let current = doc.data()?["followersCount"] as? Int ?? 0
                if current > 0 {
                    try await targetUserRef.updateData([
                        "followersCount": FieldValue.increment(Int64(-1))
                    ])
                }

                await NotificationManager.send(
                    toUserID: targetID,
                    type: .newFollower,
                    fromUserID: uid,
                    fromUserName: name,
                    fromUserAvatar: avatar,
                    message: "\(name) parou de te seguir"
                )
            } else {
                try await followRef.setData([
                    "targetID": targetID,
                    "createdAt": Timestamp(date: Date())
                ])

                // Salva na subcoleção followers do alvo
                try? await db.collection("users").document(targetID)
                    .collection("followers").document(uid).setData([
                        "uid": uid,
                        "createdAt": Timestamp(date: Date())
                    ])

                try await targetUserRef.updateData([
                    "followersCount": FieldValue.increment(Int64(1))
                ])

                await NotificationManager.send(
                    toUserID: targetID,
                    type: .newFollower,
                    fromUserID: uid,
                    fromUserName: name,
                    fromUserAvatar: avatar,
                    message: "\(name) começou a te seguir"
                )
            }
        } catch {
            // Reverte se falhar
            if wasFollowing {
                followingIDs.insert(targetID)
            } else {
                followingIDs.remove(targetID)
            }
            posts = sortPosts(posts)
        }
    }
    func loadFollowing() async {
        guard let uid = Auth.auth().currentUser?.uid else { return }
        do {
            let snapshot = try await db.collection("follows").document(uid)
                .collection("following").getDocuments()
            followingIDs = Set(snapshot.documents.map { $0.documentID })
        } catch {
            // // print("Erro ao carregar following: \(error)")
        }
    }

    func isFollowing(_ userID: String) -> Bool {
        followingIDs.contains(userID)
    }

    // MARK: - Deletar post

    func deletePost(_ post: Post) async {
        guard let uid = Auth.auth().currentUser?.uid,
              uid == post.userID else { return }

        do {
            try await db.collection("posts").document(post.id).delete()
            
            // Deletar todas as mídias associadas
            if post.mediaURLs.isEmpty {
                // Legacy: apenas uma mídia
                let ext = post.mediaType == .photo ? "jpg" : "mp4"
                let ref = storage.reference().child("posts/\(uid)/\(post.id).\(ext)")
                try? await ref.delete()
            } else {
                // Múltiplas mídias
                for (index, _) in post.mediaURLs.enumerated() {
                    let mediaType: Post.MediaType = (index < post.mediaTypes.count) ? post.mediaTypes[index] : post.mediaType
                    let ext = mediaType == .video ? "mp4" : "jpg"
                    let ref = storage.reference().child("posts/\(uid)/\(post.id)_\(index).\(ext)")
                    try? await ref.delete()
                }
            }
            posts.removeAll { $0.id == post.id }
        } catch {
            // // print("Erro ao deletar post: \(error)")
        }
    }

    func pinPostForUsers(_ post: Post) async {
        guard let currentUID = Auth.auth().currentUser?.uid else { return }
        do {
            let expiresAt = Date().addingTimeInterval(60 * 60)
            try await pinnedConfigRef.setData([
                "postID": post.id,
                "pinnedBy": currentUID,
                "pinnedAt": Timestamp(date: Date()),
                "expiresAt": Timestamp(date: expiresAt)
            ], merge: true)

            posts = posts.map { existing in
                var mutable = existing
                mutable.isPinned = false
                return mutable
            }
            var pinnedPost = post
            pinnedPost.isPinned = true
            posts.removeAll { $0.id == pinnedPost.id }
            posts.insert(pinnedPost, at: 0)
        } catch {
            errorMessage = String(
                format: NSLocalizedString("Erro ao fixar publicação: %@", comment: ""),
                error.localizedDescription
            )
        }
    }
}