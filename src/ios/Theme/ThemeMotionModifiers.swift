// ThemeMotionModifiers — the SwiftUI pieces for DressUpMotion.
//
// What the shop builder consumes:
//   .dressUpSignature(_:)        declare the screen's one signature motion
//   .dressUpPress(feedback:)     press feedback, scale OR opacity, never both
//   .dressUpSheet(isPresented:)  native sheet, system drag contract
//   AnyTransition.dressUpModal / .dressUpModalReducedMotion
//   DressUpModalSheet            custom bottom sheet, hand-rolled drag
//   .dressUpModalSheet(...)      overlay form of the custom sheet
//   DressUpTryOnPreview          tap a sample card, preview swaps on a spring
//   .dressUpTryOnSwap(value:)    modifier form of the try-on swap
//   ThinkingDotsView             three dots, 0.4s rhythm, opacity only
//
// These APIs read accessibilityReduceMotion and fall back to a fade (or
// to no motion for the dots): DressUpPressButtonStyle, DressUpModalSheet,
// DressUpTryOnPreview, DressUpTryOnSwapModifier, and ThinkingDotsView.
// The native sheet (.dressUpSheet) never reads it — it relies on the
// system sheet, which follows Reduce Motion itself. No API animates on
// its own: the caller opts in, and the screen declares at most one
// signature motion.
//
// Honest status: no local Xcode compile is possible on this VM and no
// simulator run has happened. CI is the only compile gate. Sheet-spring
// feel, try-on swap feel, dots looping, and grab-mid-animation behaviour
// are SPECULATION until a simulator run.
//
// OPEN ITEM: this file is not yet in Minis.xcodeproj/project.pbxproj.
// It must gain a file ref and a Minis-target Sources entry before it
// compiles into the app. That wiring is a separate step, not this block.

import SwiftUI

// MARK: - Signature budget

private struct DressUpSignatureKey: EnvironmentKey {
    static let defaultValue: DressUpMotion.Signature? = nil
}

extension EnvironmentValues {
    var dressUpSignature: DressUpMotion.Signature? {
        get { self[DressUpSignatureKey.self] }
        set { self[DressUpSignatureKey.self] = newValue }
    }
}

extension View {
    /// Declare this screen's one signature motion. Call at most once per
    /// screen, at the screen root. The default (no call) is quiet.
    /// Reviewers check the budget by reading dressUpSignature calls.
    func dressUpSignature(_ signature: DressUpMotion.Signature) -> some View {
        environment(\.dressUpSignature, signature)
    }
}

// MARK: - Press

/// Press feedback for a Button. Scale 0.97 OR opacity 0.85, never both.
/// Which one applies comes from ThemeContext.pressFeedback (default
/// .scale); Reduce Motion always uses the opacity fade and never scales.
/// Signature: .press.
struct DressUpPressButtonStyle: ButtonStyle {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.theme) private var theme

    var feedback: SensoryFeedback

    init(feedback: SensoryFeedback = .selection) {
        self.feedback = feedback
    }

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(pressedScale(configuration: configuration))
            .opacity(pressedOpacity(configuration: configuration))
            .animation(
                DressUpMotion.animation(for: .press, reduceMotion: reduceMotion),
                value: configuration.isPressed
            )
            .sensoryFeedback(feedback, trigger: configuration.isPressed)
    }

    private func pressedScale(configuration: Configuration) -> CGFloat {
        guard configuration.isPressed else { return 1 }
        if reduceMotion { return 1 }
        if theme.pressFeedback == .scale { return DressUpMotion.pressedScale }
        return 1
    }

    private func pressedOpacity(configuration: Configuration) -> CGFloat {
        guard configuration.isPressed else { return 1 }
        if reduceMotion { return DressUpMotion.pressedOpacity }
        if theme.pressFeedback == .opacity { return DressUpMotion.pressedOpacity }
        return 1
    }
}

extension View {
    /// Apply press feedback to a Button.
    /// - Parameter feedback: sensory feedback matching the action:
    ///   .selection for select / try-on, .success for confirm / apply,
    ///   .impact for a destructive action. It fires on press-down and on
    ///   release (a down/up pair, like a physical key).
    func dressUpPress(feedback: SensoryFeedback = .selection) -> some View {
        buttonStyle(DressUpPressButtonStyle(feedback: feedback))
    }
}

// MARK: - Sheet, native

extension View {
    /// Native sheet with the shop's chrome. The system sheet already meets
    /// the modal contract (interruptible, drag 1:1, fling dismiss, grab
    /// stops in place), so prefer it when system chrome is enough. Use
    /// DressUpModalSheet only when the shop needs its own sheet.
    /// Signature: .sheet.
    func dressUpSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        sheet(isPresented: isPresented) {
            content()
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationBackground(Theme.Color.background)
        }
    }

    /// Overlay form of the custom bottom sheet. See DressUpModalSheet.
    /// Attach ONLY at the screen root: SwiftUI sizes overlay content to
    /// the host view, so attached to a smaller host the scrim dims only
    /// that subview and the sheet is clamped to the host width.
    /// Signature: .sheet.
    func dressUpModalSheet<SheetContent: View>(
        isPresented: Binding<Bool>,
        @ViewBuilder content: @escaping () -> SheetContent
    ) -> some View {
        overlay {
            DressUpModalSheet(isPresented: isPresented, content: content)
        }
    }
}

// MARK: - Modal transition

extension AnyTransition {
    /// Milk-pink modal transition: the sheet slides from the bottom.
    /// Drive it with the modal spring on the container
    /// (DressUpMotion.animation(for: .modal, ...)). Signature: .sheet.
    static var dressUpModal: AnyTransition {
        .move(edge: .bottom)
    }

    /// Reduce Motion modal transition: fade only. No slide, no depth,
    /// no blur. Drive it with DressUpMotion.fadeAnimation(reduceMotion: true).
    static var dressUpModalReducedMotion: AnyTransition {
        .opacity
    }
}

// MARK: - Custom bottom sheet

/// Custom bottom sheet for the dress-up shop, for when the shop needs its
/// own sheet instead of the system one.
///
/// Attach at the screen root only (via .dressUpModalSheet): SwiftUI sizes
/// overlay content to the host view, so on a smaller host the scrim dims
/// only that subview and the sheet is clamped to the host width.
///
/// Contract, all by hand so the shop builder can read it here:
/// - Drag is 1:1 downward; an upward drag is pinned at the rest position.
/// - Fling velocity decides dismiss: the drag's predicted end (which the
///   system derives from the drag velocity) or the drag distance passing
///   half the sheet height dismisses; anything less springs back on the
///   motion spring.
/// - Grab mid-animation stops in place: the drag writes the offset with
///   no animation, so the finger takes over from wherever the sheet is;
///   on release the spring retargets from that spot.
/// - Tapping the scrim dismisses. The scrim fades on its own curve, the
///   sheet slides on the modal spring.
/// - Reduce Motion: the sheet crossfades (fast linear), the scrim fades,
///   no slide, no spring travel.
///
/// The sheet background runs to the screen edge; the bottom inset
/// (Theme.Spacing.xxl) clears the home indicator zone. Content that sits
/// near the home indicator adds its own bottom clearance.
/// Signature: .sheet.
struct DressUpModalSheet<Content: View>: View {
    @Binding var isPresented: Bool
    @ViewBuilder var content: () -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var dragTranslation: CGFloat = 0
    @State private var sheetHeight: CGFloat = 0

    var body: some View {
        ZStack(alignment: .bottom) {
            if isPresented {
                scrim
                sheet
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(sheetAnimation, value: isPresented)
    }

    // MARK: Scrim

    private var scrim: some View {
        Theme.Color.ink
            .opacity(DressUpMotion.scrimOpacity)
            .ignoresSafeArea()
            .transition(.opacity)
            .animation(
                DressUpMotion.scrimAnimation(reduceMotion: reduceMotion),
                value: isPresented
            )
            .onTapGesture { isPresented = false }
    }

    // MARK: Sheet

    private var sheet: some View {
        VStack(spacing: Theme.Spacing.sm) {
            Capsule()
                .fill(Theme.Color.line)
                .frame(width: Theme.Spacing.massive, height: Theme.Spacing.xs)
            content()
        }
        .padding(.top, Theme.Spacing.sm)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.bottom, Theme.Spacing.xxl)
        .frame(maxWidth: .infinity)
        .background(Theme.Color.background, in: sheetShape)
        .offset(y: dragTranslation)
        .transition(reduceMotion ? .dressUpModalReducedMotion : .dressUpModal)
        .gesture(dragGesture)
        .onGeometryChange(for: CGFloat.self, of: \.size.height) { newHeight in
            sheetHeight = newHeight
        }
        .onDisappear { dragTranslation = 0 }
        .ignoresSafeArea(edges: .bottom)
    }

    private var sheetShape: UnevenRoundedRectangle {
        UnevenRoundedRectangle(
            cornerRadii: RectangleCornerRadii(
                topLeading: Theme.Radius.card,
                bottomLeading: 0,
                bottomTrailing: 0,
                topTrailing: Theme.Radius.card
            )
        )
    }

    private var sheetAnimation: Animation {
        if reduceMotion {
            return DressUpMotion.fadeAnimation(reduceMotion: true)
        }
        return Theme.Motion.modal
    }

    private var dragGesture: some Gesture {
        DragGesture()
            .onChanged { value in
                // 1:1 downward drag, no animation: the sheet follows the
                // finger at once.
                dragTranslation = max(0, value.translation.height)
            }
            .onEnded { value in
                // Geometry not yet measured: sheetHeight starts at 0, so
                // the threshold is unreachable until onGeometryChange
                // fires. Never dismiss in that window — spring back.
                guard sheetHeight > 0 else {
                    withAnimation(
                        DressUpMotion.animation(for: .motion, reduceMotion: reduceMotion)
                    ) {
                        dragTranslation = 0
                    }
                    return
                }
                let threshold = sheetHeight * DressUpMotion.dismissFraction
                let draggedPast = value.translation.height > threshold
                let flungPast = value.predictedEndTranslation.height > threshold
                if draggedPast || flungPast {
                    isPresented = false
                } else {
                    withAnimation(
                        DressUpMotion.animation(for: .motion, reduceMotion: reduceMotion)
                    ) {
                        dragTranslation = 0
                    }
                }
            }
    }
}

// MARK: - Try-on swap

/// Try-on preview swap for the dress-up shop. Tap a sample card, the
/// preview swaps with the primary spring; the swap is interruptible
/// (interactiveSpring retargets from the current spot on a new tap).
/// Shop builder duty: give the preview content a fixed frame. A caller
/// that forgets gets a container that resizes mid-flight as the
/// incoming and outgoing previews differ in size.
/// Signature: .tryOnSwap.
/// Reduce Motion: crossfade only, no scale, no spring travel.
struct DressUpTryOnPreview<Selection: Equatable, Content: View>: View {
    let selection: Selection
    @ViewBuilder var content: (Selection) -> Content

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        ZStack {
            content(selection)
                .id(selection)
                .transition(DressUpMotion.tryOnTransition(reduceMotion: reduceMotion))
        }
        .animation(DressUpMotion.tryOnAnimation(reduceMotion: reduceMotion), value: selection)
    }
}

/// Modifier form of the try-on swap, for layouts that manage their own
/// container. Apply to the preview content together with .id(selection).
struct DressUpTryOnSwapModifier<Value: Equatable>: ViewModifier {
    let value: Value

    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    func body(content: Content) -> some View {
        content
            .transition(DressUpMotion.tryOnTransition(reduceMotion: reduceMotion))
            .animation(DressUpMotion.tryOnAnimation(reduceMotion: reduceMotion), value: value)
    }
}

extension View {
    /// Apply the try-on swap to a preview content view. Pair with
    /// .id(selection) on the same view. See DressUpTryOnPreview for the
    /// self-contained form. Signature: .tryOnSwap.
    func dressUpTryOnSwap<Value: Equatable>(value: Value) -> some View {
        modifier(DressUpTryOnSwapModifier(value: value))
    }
}

// MARK: - Thinking dots

/// Thinking indicator: three dots stepping through a 0.4s rhythm
/// (plan §A #6). Opacity only — no scale, no depth, no blur. One dot is
/// bright at a time; the rest wait dim.
/// Signature: .thinkingDots.
/// Reduce Motion: static dots at full opacity, no animation at all.
/// The dots are decorative; the thinking card itself carries the label.
struct ThinkingDotsView: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                staticDots
            } else {
                PhaseAnimator(
                    DotPhase.allCases,
                    animation: DressUpMotion.thinkingDotsAnimation()
                ) { phase in
                    phasedDots(phase: phase)
                }
            }
        }
        .accessibilityHidden(true)
    }

    private enum DotPhase: CaseIterable {
        case first, second, third
    }

    private var dot: some View {
        Circle()
            .fill(Theme.Color.thinkingDots)
            .frame(width: Theme.Spacing.sm, height: Theme.Spacing.sm)
    }

    private var staticDots: some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<DressUpMotion.thinkingDotCount, id: \.self) { _ in
                dot.opacity(DressUpMotion.dotActiveOpacity)
            }
        }
    }

    private func phasedDots(phase: DotPhase) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            ForEach(0..<DressUpMotion.thinkingDotCount, id: \.self) { index in
                dot.opacity(opacity(for: index, phase: phase))
            }
        }
    }

    private func opacity(for index: Int, phase: DotPhase) -> CGFloat {
        let activeIndex: Int
        switch phase {
        case .first: activeIndex = 0
        case .second: activeIndex = 1
        case .third: activeIndex = 2
        }
        return index == activeIndex ? DressUpMotion.dotActiveOpacity : DressUpMotion.dotIdleOpacity
    }
}
