import SwiftUI

struct HapticsEnabledKey: EnvironmentKey {
    static let defaultValue = true
}

public extension EnvironmentValues {

    var isFullSwipeHapticsEnabled: Bool {
        get { self[HapticsEnabledKey.self] }
        set { self[HapticsEnabledKey.self] = newValue }
    }
}

public extension View {
    func allowFullSwipeHaptics(_ active: Bool = true) -> some View {
        environment(\.isFullSwipeHapticsEnabled, active)
    }
}
