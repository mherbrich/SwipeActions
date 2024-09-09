import SwiftUI

public struct DisableMultitouchModifier: ViewModifier {
    public func body(content: Content) -> some View {
        content
            .overlay(DisableMultitouchViewRepresentable())
    }
}

public struct DisableMultitouchViewRepresentable: UIViewRepresentable {
    public func makeUIView(context: Context) -> UIView {
        let view = UIView()
        view.backgroundColor = .clear
        view.isMultipleTouchEnabled = false
        view.isExclusiveTouch = true
        return view
    }
    
    public func updateUIView(_ uiView: UIView, context: Context) {}
}

public extension View {
    @ViewBuilder
    func allowMultitouching(_ active: Bool = true) -> some View {
        if active {
            self
        } else {
            modifier(
                DisableMultitouchModifier()
            )
        }
    }
}
