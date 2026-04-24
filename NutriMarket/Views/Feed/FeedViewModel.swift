import SwiftUI
import Combine

class FeedViewModel: ObservableObject {
    @Published var currentlyPlayingPostID: String? = nil
    @Published var currentlyPlayingVideoIndex: Int? = nil
    
    func setCurrentlyPlaying(postID: String, videoIndex: Int?) {
        currentlyPlayingPostID = postID
        currentlyPlayingVideoIndex = videoIndex
    }
    
    func isCurrentlyPlaying(postID: String, videoIndex: Int? = nil) -> Bool {
        if let currentPostID = currentlyPlayingPostID {
            if currentPostID == postID {
                if let currentIndex = currentlyPlayingVideoIndex,
                   let checkIndex = videoIndex {
                    return currentIndex == checkIndex
                }
                return videoIndex == nil
            }
        }
        return false
    }
}
