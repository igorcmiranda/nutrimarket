import SwiftUI
import SDWebImageSwiftUI

// Substitui AsyncImage por versão com cache
struct CachedImage: View {
    let url: String
    let width: CGFloat?
    let height: CGFloat?
    let contentMode: ContentMode

    init(url: String, width: CGFloat? = nil, height: CGFloat? = nil,
         contentMode: ContentMode = .fill) {
        self.url = url
        self.width = width
        self.height = height
        self.contentMode = contentMode
    }

    var body: some View {
        WebImage(url: URL(string: url)) { image in
            image
                .resizable()
                .aspectRatio(contentMode: contentMode)
        } placeholder: {
            Rectangle()
                .fill(Color(.systemGray5))
                .overlay(ProgressView().scaleEffect(0.6))
        }
        .frame(width: width, height: height)
    }
}
