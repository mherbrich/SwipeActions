import SwiftUI

public typealias Leading<V> = Group<V> where V:View
public typealias Trailing<V> = Group<V> where V:View

public enum MenuType {
    case slided /// hstacked
    case swiped /// zstacked
}

/// Full swipe main role:
public enum SwipeRole {
    case destructive /// for removing element
    case cancel
    case `default`
}

/// For opened cells auto-hiding during swiping anothers
public enum SwipeState: Equatable {
    case untouched
    case swiped(UUID)
}

private enum VisibleButton: Equatable {
    case none
    case left(UUID)
    case right(UUID)
}

private enum GestureStatus: Equatable {
    case idle
    case started
    case active
    case ended
    case cancelled
}

public struct SwipeAction<V1: View, V2: View>: ViewModifier {
    
    @Environment(\.layoutDirection) var layoutDirection
    
    @Binding private var state: SwipeState
    @State private var offset: CGFloat = 0
    @State private var oldOffset: CGFloat = 0
    @State private var visibleButton: VisibleButton = .none
    
    /**
     To detect if drag gesture is ended:
     https://forums.developer.apple.com/forums/thread/123034
     */
    @GestureState private var isDragging: Bool = false
    
    @State private var gestureState: GestureStatus = .idle
    
    @State private var maxLeadingOffset: CGFloat = .zero
    @State private var minTrailingOffset: CGFloat = .zero
    
    @State private var contentWidth: CGFloat = .zero
    @State private var isDeletedRow: Bool = false
    /**
     For lazy views: because of measuring size occurred every onAppear
     */
    @State private var maxLeadingOffsetIsCounted: Bool = false
    @State private var minTrailingOffsetIsCounted: Bool = false
    
    private let menuTyped: MenuType
    private let leadingSwipeView: Group<V1>?
    private let trailingSwipeView: Group<V2>?
    
    private let swipeColor: Color?
    private let allowsFullSwipe: Bool
    private let fullSwipeRole: SwipeRole
    private let action: (() -> Void)?
    private let id: UUID = UUID()
    
    private func reset() {
        visibleButton = .none
        offset = 0
        oldOffset = 0
    }
    
    private var leadingView: some View {
        leadingSwipeView
            .measureSize {
                if !maxLeadingOffsetIsCounted {
                    maxLeadingOffset = maxLeadingOffset + $0.width
                }
            }
            .onAppear {
                /**
                 maxLeadingOffsetIsCounted for of lazy views
                 */
                if #available(iOS 15, *) {
                    maxLeadingOffsetIsCounted = true
                }
            }
    }
    
    private var trailingView: some View {
        trailingSwipeView
            .measureSize {
                if !minTrailingOffsetIsCounted {
                    minTrailingOffset = (abs(minTrailingOffset) + $0.width) * -1
                }
            }
            .onAppear {
                /**
                 maxLeadingOffsetIsCounted for of lazy views
                 */
                if #available(iOS 15, *) {
                    minTrailingOffsetIsCounted = true
                }
            }
    }
    
    private var swipedMenu: some View {
        HStack(spacing: 0) {
            leadingView
            Spacer()
            trailingView
                .offset(x: allowsFullSwipe && offset < minTrailingOffset ? (-1 * minTrailingOffset) + offset : 0)
        }
    }
    
    private var slidedMenu: some View {
        HStack(spacing: 0) {
            leadingView
                .offset(x: (-1 * maxLeadingOffset) + offset)
            Spacer()
            trailingView
                .offset(x: (-1 * minTrailingOffset) + offset)
        }
    }
    
    private func gesturedContent(content: Content) -> some View {
        content
            .id(id)
            .contentShape(Rectangle()) ///otherwise swipe won't work in vacant area
            .offset(x: offset)
            .measureSize {
                contentWidth = $0.width
            }
            .gesture (
                DragGesture(minimumDistance: 15, coordinateSpace: .global)
                    .updating($isDragging) { _, isDragging, _ in
                        isDragging = true
                    }
                    .onChanged(onDragChange(_:))
                    .onEnded(onDragEnded(_:))
            )
            .valueChanged(of: gestureState) { state in
                guard state == .started else { return }
                gestureState = .active
            }
            .valueChanged(of: isDragging) { value in
                DispatchQueue.main.async {
                    if value, gestureState != .started {
                        gestureState = .started
                    } else if !value, gestureState != .ended {
                        gestureState = .cancelled
                        reset()
                    }
                }
            }
            .valueChanged(of: state) { value in
                switch value {
                case .swiped(let tag):
                    if
                        id != tag,
                        visibleButton != .none
                    {
                        withAnimation(.default) {
                            reset()
                        }
                        if offset > 0 {
                            visibleButton = .left(id)
                        } else {
                            visibleButton = .right(id)
                        }
                    }
                default:
                    break
                }
            }
            .onAppear {
                switch (state, visibleButton, offset) {
                case (.swiped(let id), .left(let id2), _):
                    if id != id2  {
                        withAnimation(.default) {
                            reset()
                        }
                        state = .swiped(id)
                    }
                case (.swiped(let id), .right(let id3), _):
                    if id != id3  {
                        withAnimation(.default) {
                            reset()
                        }
                        state = .swiped(id)
                    }
                default:
                    // for lazy views
                    // after fast scrolling menu can't close fully
                    if (offset != 0 && visibleButton == .none) {
                        withAnimation(.default) {
                            reset()
                        }
                    }
                    break
                }
            }
    }
    
    private func onDragChange(_ value: DragGesture.Value) {
        guard gestureState == .started || gestureState == .active else { return }
        
        let totalSlide: CGFloat
        
        switch layoutDirection {
        case .rightToLeft:
            totalSlide = -value.translation.width + oldOffset
        default:
            totalSlide = value.translation.width + oldOffset
        }

        if allowsFullSwipe {
            withAnimation {
                offset = max(min(totalSlide, maxLeadingOffset), -contentWidth)
            }
        } else {
            withAnimation {
                offset = max(min(totalSlide, maxLeadingOffset), minTrailingOffset)
            }
        }
        
        // Updating for visible button during gesture
        if offset > 0 {
            visibleButton = .left(id)
        } else if offset < 0 {
            visibleButton = .right(id)
        } else {
            visibleButton = .none
        }
    }
    
    private func onDragEnded(_ value: DragGesture.Value) {
        gestureState = .ended
        
        let translationWidth: CGFloat
        switch layoutDirection {
        case .rightToLeft:
            translationWidth = -value.translation.width
        default:
            translationWidth = value.translation.width
        }
        
        withAnimation {
            if abs(offset) > 25 {
                if offset > 0 {
                    visibleButton = .left(id)
                    offset = maxLeadingOffset
                } else {
                    visibleButton = .right(id)
                    offset = minTrailingOffset
                }
                oldOffset = offset
                state = .swiped(id)
            } else {
                reset()
            }
        }
        
        if
            allowsFullSwipe,
            translationWidth < -(contentWidth * 0.7)
        {
            withAnimation(.default) {
                offset = -contentWidth
            }
            
            switch fullSwipeRole {
            case .destructive:
                withAnimation(.default) {
                    isDeletedRow = true
                }
            case .cancel:
                withAnimation {
                    reset()
                }
            default:
                break
            }
            
            action?()
        }
    }
    
    public func body(content: Content) -> some View {
        switch menuTyped {
        case .slided:
            gesturedContent(content: content).background(
                ZStack {
                    swipeColor
                        .zIndex(1)
                    slidedMenu
                        .zIndex(2)
                },
                alignment: .center
            )
            .frame(height: isDeletedRow ? 0 : nil, alignment: .top)
        case .swiped:
            gesturedContent(content: content).background(
                ZStack {
                    swipeColor
                        .zIndex(1)
                    slidedMenu
                        .zIndex(2)
                },
                alignment: .center
            )
            .frame(height: isDeletedRow ? 0 : nil, alignment: .top)
        }
    }
}

public extension SwipeAction {
    init(
        menu: MenuType,
        allowsFullSwipe: Bool = false,
        fullSwipeRole: SwipeRole = .default,
        swipeColor: Color? = nil,
        state: Binding<SwipeState>,
        @ViewBuilder _ content: @escaping () -> TupleView<(Leading<V1>, Trailing<V2>)>,
        action: (() -> Void)? = nil
    ) {
        menuTyped = menu
        self.allowsFullSwipe = allowsFullSwipe
        self.fullSwipeRole = fullSwipeRole
        self.swipeColor = swipeColor
        _state = state
        leadingSwipeView = content().value.0
        trailingSwipeView = content().value.1
        self.action = action
    }
    
    init(
        menu: MenuType,
        allowsFullSwipe: Bool = false,
        fullSwipeRole: SwipeRole = .default,
        swipeColor: Color? = nil,
        state: Binding<SwipeState>,
        @ViewBuilder leading: @escaping () -> V1,
        action: (() -> Void)? = nil
    ) {
        menuTyped = menu
        self.allowsFullSwipe = allowsFullSwipe
        self.fullSwipeRole = fullSwipeRole
        self.swipeColor = swipeColor
        _state = state
        leadingSwipeView = Group { leading() }
        trailingSwipeView = nil
        self.action = action
    }
    
    init(
        menu: MenuType,
        allowsFullSwipe: Bool = false,
        fullSwipeRole: SwipeRole = .default,
        swipeColor: Color? = nil,
        state: Binding<SwipeState>,
        @ViewBuilder trailing: @escaping () -> V2,
        action: (() -> Void)? = nil
    ) {
        menuTyped = menu
        self.allowsFullSwipe = allowsFullSwipe
        self.fullSwipeRole = fullSwipeRole
        self.swipeColor = swipeColor
        _state = state
        trailingSwipeView = Group { trailing() }
        leadingSwipeView = nil
        self.action = action
    }
}

