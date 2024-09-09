import SwiftUI

// internal api
// For debugging views:
struct Measurements: View {

    @State private var size: CGSize = .zero

    let showSize: Bool
    let color: Color
    
    var body: some View {
        label.measureSize { size = $0 }
    }

    var label: some View {
        ZStack(alignment: .topTrailing) {
            Rectangle()
                .strokeBorder(
                    color,
                    lineWidth: 1
                )
            
            Text("H:\(size.height.formatted) W:\(size.width.formatted)")
                .foregroundColor(.black)
                .font(.system(size: 8))
                .opacity(showSize ? 1 : 0)
        }
    }
}

// internal api
// For debugging views:
extension View {
    func measured(_ showSize: Bool = true, _ color: Color = Color.red) -> some View {
        self
            .overlay(Measurements(showSize: showSize, color: color))
    }
}
