import SwiftUI

struct HapticFeedbackTypeKey: EnvironmentKey {
    static let defaultValue: HapticFeedbackType? = nil
}

public extension EnvironmentValues {

    var fullSwipeHapticFeedback: HapticFeedbackType? {
        get { self[HapticFeedbackTypeKey.self] }
        set { self[HapticFeedbackTypeKey.self] = newValue }
    }
}

public extension View {
    func fullSwipeHapticFeedback(_ type: HapticFeedbackType = .heavy()) -> some View {
        environment(\.fullSwipeHapticFeedback, type)
    }
}
