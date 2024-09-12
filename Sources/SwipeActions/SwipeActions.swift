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
    
    @Environment(\.identifier) private var parentId
    @Environment(\.layoutDirection) private var layoutDirection
    @Environment(\.isFullSwipeHapticsEnabled) private var isHapticsEnabled
    @Environment(\.fullSwipeHapticFeedback) private var hapticFeedback
    
    @Binding private var state: SwipeState
    @Binding private var tapAllowed: Bool
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
    
    @State private var lastTrailingWidth: CGFloat = .zero
    @State private var lastLeadingWidth: CGFloat = .zero
    
    @State private var contentWidth: CGFloat = .zero
    @State private var contentHeight: CGFloat = .zero
    @State private var isDeletedRow: Bool = false
    
    /**
     For lazy views
     ________________________
     because of measuring size
     occurred every onAppear
     */
    @State private var maxLeadingOffsetIsCounted: Bool = false
    @State private var minTrailingOffsetIsCounted: Bool = false
    
    private let manualId: UUID = UUID() // custom id
    private let menuTyped: MenuType
    private let leadingSwipeView: Group<V1>?
    private let trailingSwipeView: Group<V2>?
    
    private let swipeColor: Color?
    private let allowsFullSwipe: Bool
    private let fullSwipeRole: SwipeRole
    private let action: (() -> Void)?
    
    /**
     For catching any changing in views
     _________________________
     We can't detect what exactly has change
     that's why we rebuild the view only with
     generating new id:
     */
    @State private var leadingViewId: UUID = UUID()
    @State private var trailingViewId: UUID = UUID()
    
    private func reset() {
        visibleButton = .none
        offset = 0
        oldOffset = 0
    }
    
    private var leadingView: some View {
        leadingSwipeView
            .opacity(isDeletedRow ? 0 : 1)
            .frame(maxHeight: contentHeight)
            .animation(.none, value: isDeletedRow)
            .id(leadingViewId)
            .measureSize {
                if maxLeadingOffsetIsCounted == false || $0.width != lastLeadingWidth {
                    maxLeadingOffset = $0.width
                    lastLeadingWidth = $0.width
                    maxLeadingOffsetIsCounted = true
                }
            }
            .valueChanged(of: leadingSwipeView.debugDescription.hashValue) { _ in
                leadingViewId = UUID()
                maxLeadingOffsetIsCounted = false
                maxLeadingOffset = .zero
                lastLeadingWidth = .zero
                withAnimation(.default) {
                    reset()
                }
            }
    }
    
    private var trailingView: some View {
        trailingSwipeView
            .opacity(isDeletedRow ? 0 : 1)
            .frame(maxHeight: contentHeight)
            .animation(.none, value: isDeletedRow)
            .id(trailingViewId)
            .measureSize {
                if minTrailingOffsetIsCounted == false || $0.width != lastTrailingWidth {
                    minTrailingOffset = -$0.width
                    lastTrailingWidth = $0.width
                    minTrailingOffsetIsCounted = true
                }
            }
            .valueChanged(of: trailingSwipeView.debugDescription.hashValue) { _ in
                trailingViewId = UUID()
                minTrailingOffsetIsCounted = false
                minTrailingOffset = .zero
                lastTrailingWidth = .zero
                withAnimation(.default) {
                    reset()
                }
            }
    }
    
    private var swipedMenu: some View {
        HStack(spacing: 0) {
            leadingView
            Spacer()
            trailingView
                .background(
                    Rectangle()
                        .fill(swipeColor ?? .clear)
                        .frame(width: abs(offset) + lastTrailingWidth)
                    ,alignment: .leading
                )
                .offset(x: allowsFullSwipe && offset < minTrailingOffset ? (-1 * minTrailingOffset) + offset : 0)
        }
    }
    
    private var slidedMenu: some View {
        HStack(spacing: 0) {
            leadingView
                .offset(x: (-1 * maxLeadingOffset) + offset)
            Spacer()
            trailingView
                .background(
                    Rectangle()
                        .fill(swipeColor ?? .clear)
                        .frame(width: abs(offset) + lastTrailingWidth)
                    ,alignment: .leading
                )
                .offset(x: (-1 * minTrailingOffset) + offset)
        }
    }
    
    private var identifier: UUID {
        parentId?.uuid ?? manualId
    }
    
    private func gesturedContent(content: Content) -> some View {
        content
            .contentShape(Rectangle()) ///otherwise swipe won't work in vacant area
            .offset(x: offset)
            .measureSize {
                contentWidth = $0.width
                contentHeight = $0.height
            }
            .simultaneousGesture (
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
                    tapAllowed = !isDragging
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
                        identifier != tag,
                        visibleButton != .none
                    {
                        withAnimation(.default) {
                            reset()
                        }
                        if offset > 0 {
                            visibleButton = .left(identifier)
                        } else {
                            visibleButton = .right(identifier)
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
        
        // Updating visible buttons during gesture:
        if offset > 0 {
            visibleButton = .left(identifier)
        } else if offset < 0 {
            visibleButton = .right(identifier)
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
                    visibleButton = .left(identifier)
                    offset = maxLeadingOffset
                } else {
                    visibleButton = .right(identifier)
                    offset = minTrailingOffset
                }
                oldOffset = offset
                state = .swiped(identifier)
            } else {
                reset()
            }
        }
        
        if
            allowsFullSwipe,
            translationWidth < -(contentWidth * 0.7)
        {
            if isHapticsEnabled {
                HapticsProvider.sendHapticFeedback(hapticFeedback ?? .heavy())
            }
            
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
            ZStack {
                slidedMenu
                    .frame(height: isDeletedRow ? 0 : nil)
                    .zIndex(1)
                
                gesturedContent(content: content)
                    .opacity(isDeletedRow ? 0 : 1)
                    .frame(height: isDeletedRow ? 0 : nil)
                    .zIndex(2)
            }
            .compositingGroup()
        case .swiped:
            ZStack {
                swipedMenu
                    .frame(height: isDeletedRow ? 0 : nil)
                    .zIndex(1)
                
                gesturedContent(content: content)
                    .opacity(isDeletedRow ? 0 : 1)
                    .frame(height: isDeletedRow ? 0 : nil)
                    .zIndex(2)
            }
            .compositingGroup()
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
        tapAllowed: Binding<Bool>,
        @ViewBuilder _ content: @escaping () -> TupleView<(Leading<V1>, Trailing<V2>)>,
        action: (() -> Void)? = nil
    ) {
        menuTyped = menu
        self.allowsFullSwipe = allowsFullSwipe
        self.fullSwipeRole = fullSwipeRole
        self.swipeColor = swipeColor
        _state = state
        _tapAllowed = tapAllowed
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
        tapAllowed: Binding<Bool>,
        @ViewBuilder leading: @escaping () -> V1,
        action: (() -> Void)? = nil
    ) {
        menuTyped = menu
        self.allowsFullSwipe = allowsFullSwipe
        self.fullSwipeRole = fullSwipeRole
        self.swipeColor = swipeColor
        _state = state
        _tapAllowed = tapAllowed
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
        tapAllowed: Binding<Bool>,
        @ViewBuilder trailing: @escaping () -> V2,
        action: (() -> Void)? = nil
    ) {
        menuTyped = menu
        self.allowsFullSwipe = allowsFullSwipe
        self.fullSwipeRole = fullSwipeRole
        self.swipeColor = swipeColor
        _state = state
        _tapAllowed = tapAllowed
        trailingSwipeView = Group { trailing() }
        leadingSwipeView = nil
        self.action = action
    }
}
