import SwiftUI
import Observation

@Observable
final class ViewStore {
    var node: ViewNode?

    var onEvent: ((String, String) -> Void)?

    func setRoot(_ newNode: ViewNode?) {
        node = newNode
    }
}
