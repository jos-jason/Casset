import Foundation
import Combine   // IMPORTANT

class PlayerScreenTracker: ObservableObject {
    @Published var isShowingPlayer: Bool = false
}
