import Foundation
import Combine
import FirebaseFirestore
import FirebaseStorage
import FirebaseAuth
import CoreLocation

@MainActor
class FeedManager: ObservableObject {
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
        if append {
            posts.append(contentsOf: sorted)
        } else {
            posts = sorted
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

    // MARK: - Upload de post

    func uploadPost(
        mediaData: Data,
        mediaType: Post.MediaType,
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
        let ext = mediaType == .photo ? "jpg" : "mp4"
        let ref = storage.reference().child("posts/\(uid)/\(postID).\(ext)")
        let metadata = StorageMetadata()
        metadata.contentType = mediaType == .photo ? "image/jpeg" : "video/mp4"

        let name = userData["name"] as? String ?? "Usuário"
        let avatar = userData["avatarURL"] as? String ?? ""
        let isVerified = userData["isVerified"] as? Bool ?? false

        do {
            _ = try await ref.putDataAsync(mediaData, metadata: metadata)
            let downloadURL = try await ref.downloadURL()
            let username = userData["username"] as? String ?? ""


            let post = Post(
                id: postID,
                userID: uid,
                userName: name,
                username: username,  // novo
                userAvatarURL: avatar,
                isVerified: isVerified,
                mediaURL: downloadURL.absoluteString,
                mediaType: mediaType,
                caption: caption,
                city: city,
                region: region,
                latitude: location?.coordinate.latitude ?? 0,
                longitude: location?.coordinate.longitude ?? 0,
                likesCount: 0,
                commentsCount: 0,
                createdAt: Date()
            )

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
                    postMediaURL: downloadURL.absoluteString,
                    message: "\(name) fez uma nova publicação"
                )
            }

        } catch {
            errorMessage = "Erro ao publicar: \(error.localizedDescription)"
        }

        isUploading = false
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
            let ext = post.mediaType == .photo ? "jpg" : "mp4"
            let ref = storage.reference().child("posts/\(uid)/\(post.id).\(ext)")
            try? await ref.delete()
            posts.removeAll { $0.id == post.id }
        } catch {
            // // print("Erro ao deletar post: \(error)")
        }
    }
}
