import SwiftUI

public struct IdentifierKey: EnvironmentKey {
    public static let defaultValue: AnyHashable? = nil
}

public extension EnvironmentValues {
    var identifier: AnyHashable? {
        get { self[IdentifierKey.self] }
        set { self[IdentifierKey.self] = newValue }
    }
}

public extension View {

    func identifier<ID: Hashable>(_ id: ID) -> some View {
        self
            .environment(\.identifier, id)
            .id(id)
    }
}
