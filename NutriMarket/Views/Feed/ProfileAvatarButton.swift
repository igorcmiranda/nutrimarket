import SwiftUI
import PhotosUI

struct ProfileAvatarButton: View {
    @EnvironmentObject var authManager: AuthManager
    @State private var selectedItem: PhotosPickerItem?
    @State private var isUploading = false

    var body: some View {
        PhotosPicker(selection: $selectedItem, matching: .images) {
            ZStack {
                AvatarView(url: authManager.currentUser?.avatarURL ?? "", size: 52)
                if isUploading {
                    Circle()
                        .fill(Color.black.opacity(0.4))
                        .frame(width: 52, height: 52)
                    ProgressView().tint(.white).scaleEffect(0.8)
                } else {
                    Circle()
                        .fill(Color.black.opacity(0.2))
                        .frame(width: 52, height: 52)
                        .overlay(
                            Image(systemName: "camera.fill")
                                .font(.caption)
                                .foregroundStyle(.white)
                        )
                }
            }
        }
        .onChange(of: selectedItem) { _, newItem in
            Task { await uploadAvatar(from: newItem) }
        }
    }

    func uploadAvatar(from item: PhotosPickerItem?) async {
        guard let item,
              let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else { return }
        isUploading = true
        await authManager.uploadAvatar(image: image)
        isUploading = false
    }
}
