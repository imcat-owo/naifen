//
//  ContentView+FAB.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  ContentView, floating buttons: the draggable new-chat and search FABs and
//  the search bar they expand into (Liquid Glass on iOS 26+). Their drag /
//  focus state and glass namespace are stored in ContentView.swift.
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI

extension ContentView {
    // MARK: - FAB Row (New Chat + Search)



    /// Brand fill for the new-chat FAB: the milk-pink user-bubble token.
    /// Replaces the hardcoded warm beige (light 183/175/150, dark 80/76/66).
    /// On iOS 26 this is the fallback only — the disc renders as tinted
    /// glass (see `newChatGlassTint`); below 26 it is the flat fill.
    /// Ink glyph on this fill: 6.14:1 light / 8.83:1 dark — PASS.
    private static let newChatBrandColor = Theme.Color.bubbleUser

    /// Glass TINT for the new-chat FAB — deliberately NOT `newChatBrandColor`.
    ///
    /// The old beige tint's device measurements (warmth / ring-pixel std)
    /// were for the beige values and are retired with them; they are NOT
    /// re-measured for pink here — no device run exists on this VM. What is
    /// preserved is the STRUCTURE that made the old tint work: a lifted,
    /// warmed hue at 0.30 alpha, because `Glass.tint` honours the colour's
    /// alpha and full-strength tinting reads as an opaque disc. The milk-pink
    /// accent is the lifted rose for this role: at 0.30 it keeps a visible
    /// pink cast while the glass still refracts. The pale bubble fill at
    /// 0.30 would be nearly invisible, so the accent — not the fill — tints.
    private static let newChatGlassTint = Theme.Color.accent.opacity(0.30)

    /// Clear/dismiss control inside the expanded search capsule.
    ///
    /// A bare glyph with NO background of its own, which is what system search
    /// fields do. The alternatives were compared on device: `.buttonStyle(.glass)`
    /// and a small `glassEffect` circle both put a second glass surface INSIDE
    /// the already-glass capsule, and glass-on-glass read as a raised, competing
    /// control — noticeably so in dark mode — for what is only a small clear
    /// action. Letting the capsule stay the single glass surface keeps the row
    /// coherent with the FABs beside it.
    ///
    /// `xmark` rather than the old `xmark.circle.fill`: the filled circle was
    /// itself a solid background, the very thing that clashed with the glass.
    /// Sub-26 keeps the original filled-circle look, where there is no glass for
    /// it to fight with.
    ///
    /// Press: `.dressUpPress()` (press spring 0.3 / 0.6 + `.selection`
    /// feedback, Reduce Motion fade) — a plain scale/opacity style, NOT a
    /// glass style, so it does not reintroduce the glass-on-glass problem.
    /// Hit area is the full 44pt: the glyph is 13pt, the frame is 44x44.
    @ViewBuilder
    private var searchClearButton: some View {
        if #available(iOS 26.0, *) {
            Button { dismissSearch() } label: {
                Image(systemName: "xmark")
                    .font(Theme.Font.bodyEmphasized())
                    .foregroundStyle(Theme.Color.ink2)
                    // [T-ios-search-bar-glass-hit-hole] The frame alone was not
                    // a tap target: with `.buttonStyle(.plain)` and no fill,
                    // hit-testing follows the DRAWN GLYPH, so only the ~13pt
                    // strokes of the "xmark" were live and the rest of this box
                    // was a hole. Height goes to 44 (Apple's minimum) and
                    // `contentShape` makes the whole box tappable; the glyph is
                    // unchanged, so this is hit area only, no visual change.
                    // The bar is 56pt tall, so 44 fits without growing it.
                    // [Phase 3 milk-pink] Width widened 32 → 44: the clear
                    // action is a full 44x44 target now, not a 32pt-wide one.
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .dressUpPress()
        } else {
            Button { dismissSearch() } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(Theme.Color.ink2)
                    .frame(width: 44, height: 44)
                    .contentShape(Rectangle())
            }
            .dressUpPress()
        }
    }

    /// Circular FAB surface wrapping its `icon`.
    ///
    /// The icon has to be passed IN rather than `.overlay`-ed on afterwards:
    /// `.glassEffect` draws the material over the view it modifies, so an
    /// overlay applied to the surface ends up UNDER the glass and disappears
    /// (verified on device — the tinted disc rendered with no glyph, pixel
    /// variance ~1.2 across its centre). Putting the icon inside means the glass
    /// is the background and the glyph rides on top of it.
    ///
    /// iOS 26+: `.glassEffect(.regular[.tint], in: .circle)`. The old manual
    /// `.shadow` is dropped on that path on purpose — Liquid Glass renders its
    /// own shadow/edge, and stacking the hand-rolled one on top reads as a dark
    /// halo rather than depth. Sub-26 keeps the original opaque circle, with
    /// its shadow now the one Theme card shadow (`Theme.Shadow.card`) instead
    /// of the two hand-rolled opacities (0.2 new-chat / 0.15 search).
    ///
    /// Unlike `FolderSurface`, live glass is safe here: the FAB floats in a
    /// `safeAreaInset` over a stable backdrop and never scrolls past
    /// heterogeneous content, so the flicker that forced that type onto a
    /// sampled constant does not apply.
    @ViewBuilder
    /// [T-ios-crash-objectdestroy-fab-uaf] `static`, deliberately.
    ///
    /// This is a pure function of its parameters — it reads no instance state.
    /// But as an INSTANCE method, calling it from inside `DraggableFAB`'s
    /// stored `label` closure captured `self`, which drags an entire
    /// ContentView struct copy into that closure's heap context. When SwiftUI
    /// tears the graph down it releases the closure, destroying the stale copy
    /// field by field — and its `@State` boxes are already gone. That is the
    /// `objectdestroy.90Tm` crash (owner: ContentView), still arriving on
    /// 1.14(21) after `e3579b381` fixed only the `onTap` half.
    ///
    /// Making it static removes the last `self` capture from `label`: every
    /// other reference in there is `Self.`-qualified, a singleton, or the
    /// `fabActions` channel, and `Namespace.ID` is a value type that copies.
    ///
    /// Keep it static. Adding an instance reference here silently reintroduces
    /// the capture and the crash.
    private static func fabCircleSurface<Icon: View>(
        tint: Color?,
        fallbackFill: Color,
        @ViewBuilder icon: () -> Icon
    ) -> some View {
        if #available(iOS 26.0, *) {
            icon()
                .frame(width: 56, height: 56)
                .glassEffect(
                    tint.map { Glass.regular.tint($0) } ?? Glass.regular,
                    in: .circle
                )
                // [T-fab-glass-contextmenu-regression] Without this the long-press
                // menu on the new-chat FAB stops opening.
                //
                // The pre-glass label was `Circle().fill(...)`, a filled shape,
                // so its hit-test region was the whole 56x56 disc and
                // `.contextMenu` (attached to that same view) picked up a
                // long-press anywhere on the button. The glass version's content
                // is a bare `Image` — `.frame` only reserves space, and
                // `.glassEffect` draws a material without contributing a
                // hit-testable shape — so the only interactive pixels left were
                // the glyph's own strokes. A long press on the surrounding
                // (visually filled) area hit nothing and no menu appeared.
                //
                // Tapping still worked, which is what made this look like a
                // gesture-priority fight with glassEffect rather than a hit-test
                // hole: DraggableFAB re-applies `.frame` and `.onTapGesture` at
                // ITS level, one layer out, so taps were being caught there.
                // `.contextMenu` is the only one of the three attached inside.
                //
                // Restoring an explicit circular content shape gives the glass
                // surface the same hit region the filled Circle had. Applied
                // AFTER glassEffect so it covers the rendered disc.
                .contentShape(.circle)
                // …and the same shape again for the context-menu PREVIEW.
                // `.contentShape(_:)` only sets the INTERACTION region; the
                // lifted platter resolves its shape separately and otherwise
                // falls back to the view's rectangular bounds, which is what
                // showed a grey rounded-rect slab peeking out from under the
                // circular button on long press. `ChatMessageRow` already
                // declares the two shapes separately for the same reason.
                .contentShape(.contextMenuPreview, Circle())
        } else {
            Circle()
                .fill(fallbackFill)
                .overlay { icon() }
                .themeShadow(Theme.Shadow.card)
        }
    }

    @ViewBuilder
    var fabRow: some View {
        // [T-fab-glass-contextmenu-regression] NO GlassEffectContainer here.
        //
        // The row was briefly wrapped in `GlassEffectContainer(spacing: 10)` so the
        // search FAB and the expanded search bar (which share a `glassEffectID`)
        // would morph into one another like the system Dock. That container is what
        // broke the new-chat FAB's long-press "New Chat with Group" menu.
        //
        // Verified on device by A/B-ing the view tree with the debug inspector, same
        // screen both times, looking for views owning a `UIContextMenuInteraction`:
        //   with the container:  [WKContentView, UpdateCoalescingCollectionView]
        //   without it:          [WKContentView, HostingView, UpdateCoalescingCollectionView]
        // The `HostingView` that hosts this row only gets its context-menu
        // interaction when the container is absent — inside it, SwiftUI never
        // materialises one, so no long press can ever raise the menu no matter how
        // the hit region is shaped. (That is why the earlier `.contentShape(.circle)`
        // fix did not help: it widened a hit region for an interaction that was
        // never created.)
        //
        // Dropping the container costs only the FAB→search-bar morph animation,
        // which falls back to the scale+opacity transition the row already declares.
        // The glass MATERIAL is unaffected — `.glassEffect` does not require a
        // container, and the FABs still render as glass (verified by screenshot).
        fabRowContent
    }

    @ViewBuilder
    private var fabRowContent: some View {
        ZStack {
            // New chat FAB (draggable)
            DraggableFAB(
                fabOnLeft: $fabOnLeft,
                dragOffset: $fabDragOffset,
                didDrag: $fabDidDrag
            ) { [fabActions] in
                // [T-ios-crash-objectdestroy-fab-uaf] Capture ONLY the channel,
                // never self. The drag guard moved to the receiver, which reads
                // the live @State rather than a captured copy.
                fabActions.send(.newChat)
            } label: {
                Self.fabCircleSurface(
                    tint: Self.newChatGlassTint,
                    fallbackFill: Self.newChatBrandColor
                ) {
                    Image(systemName: {
                        if #available(iOS 17.0, *) { return "bubble.left.and.text.bubble.right" }
                        return "plus.message.fill"
                    }())
                        // [Phase 3 milk-pink] 22pt semibold → displaySmall
                        // (20pt, nearest Theme role; glyph precedent:
                        // ChatSendButton maps glyphs to display roles).
                        // Ink glyph: 6.14:1 light / 8.83:1 dark on the
                        // milk-pink fill, 8.74:1 / 15.11:1 on tinted glass.
                        .font(Theme.Font.displaySmall())
                        .foregroundStyle(Theme.Color.ink)
                }
                    .contextMenu {
                        let groups = Array(ProviderConfigStore.shared.config.modelGroups.prefix(10))
                        if !groups.isEmpty {
                            Section(AppLocalized("New Chat with Group")) {
                                ForEach(groups) { group in
                                    Button { [fabActions] in
                                        fabActions.send(.newChatInGroup(group.id))
                                    } label: {
                                        Label(group.name, systemImage: "square.stack.3d.up")
                                    }
                                }
                            }
                        }
                    }
            }

            // Search FAB or inline search bar (hidden when no sessions)
            if !sessions.isEmpty {
                if showSearchBar {
                    // Inline search bar — fills space between edges, leaving room for New Chat
                    GeometryReader { geo in
                        let fabSize: CGFloat = 56
                        let edgePad: CGFloat = Theme.Spacing.lg
                        let gap: CGFloat = Theme.Spacing.sm
                        let barX: CGFloat = fabOnLeft
                            ? edgePad + fabSize + gap
                            : edgePad
                        let barWidth: CGFloat = geo.size.width - edgePad * 2 - fabSize - gap

                        HStack(spacing: Theme.Spacing.sm) {
                            Image(systemName: "magnifyingglass")
                                // [Phase 3 milk-pink] 15pt medium → bodyEmphasized
                                // (13pt semibold, nearest Theme role). Ink-2
                                // glyph: 4.09:1 light passes the 3:1 non-text bar.
                                .font(Theme.Font.bodyEmphasized())
                                .foregroundStyle(Theme.Color.ink2)
                            TextField("Search chats...", text: $searchText)
                                .font(Theme.Font.body())
                                .textFieldStyle(.plain)
                                .autocorrectionDisabled()
                                .focused($searchFocused)
                                .onChange(of: searchText) { _ in scheduleSearch() }
                            searchClearButton
                        }
                        // [T-ios-search-bar-glass-hit-hole] Trailing padding is
                        // trimmed to 8 so the X button's 44pt-wide target sits
                        // closer to the capsule edge instead of behind 18pt of
                        // dead space (the button keeps its own internal
                        // padding, so the glyph barely moves). Leading stays 18
                        // — that side holds the magnifier and needs the inset.
                        .padding(.leading, 18)
                        .padding(.trailing, Theme.Spacing.sm)
                        .frame(width: barWidth, height: fabSize)
                        .modifier(SearchBarSurface())
                        // [T-ios-search-bar-glass-hit-hole] `glassEffect(in:)`
                        // RENDERS a capsule but contributes no hit region of
                        // its own, and this row sits in a `safeAreaInset` over
                        // the session List — an inset does not swallow touches
                        // where it has nothing hit-testable. So every point of
                        // the bar not covered by a real control (icon,
                        // TextField, X button) passed the touch straight
                        // through to the cell scrolling underneath and opened
                        // whatever session or folder was there.
                        //
                        // Declaring the capsule's shape restores the hit region
                        // to match what is drawn. NOTE this is necessary but
                        // not sufficient on its own: verified on device that
                        // the capsule still cannot fully consume taps (the
                        // a11y tree exposes no element for it, only its
                        // children), so the durable part of this fix is the
                        // enlarged, explicitly-shaped X target in
                        // `searchClearButton` — that is what the user actually
                        // aims at, and it now hits at all four corners.
                        .contentShape(.capsule)
                        .modifier(FABGlassMorphID(namespace: fabGlassNamespace))
                        .position(x: barX + barWidth / 2, y: fabSize / 2)
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: fabOnLeft ? .leading : .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: fabOnLeft ? .leading : .trailing).combined(with: .opacity)
                    ))
                    .onAppear { searchFocused = true }
                } else {
                    // Search FAB (draggable, inverted side)
                    DraggableFAB(
                        fabOnLeft: $fabOnLeft,
                        dragOffset: $searchDragOffset,
                        didDrag: $searchDidDrag,
                        inverted: true
                    ) { [fabActions] in
                        fabActions.send(.openSearch)
                    } label: {
                        Self.fabCircleSurface(
                            tint: nil,
                            fallbackFill: Theme.Color.surface
                        ) {
                            Image(systemName: "magnifyingglass")
                                // [Phase 3 milk-pink] 22pt semibold → displaySmall
                                // (20pt, nearest Theme role). Ink on surface:
                                // 8.74:1 light / 15.11:1 dark.
                                .font(Theme.Font.displaySmall())
                                .foregroundStyle(Theme.Color.ink)
                        }
                            .modifier(FABGlassMorphID(namespace: fabGlassNamespace))
                    }
                    .transition(.asymmetric(
                        insertion: .scale(scale: 0.85, anchor: fabOnLeft ? .leading : .trailing).combined(with: .opacity),
                        removal: .scale(scale: 0.85, anchor: fabOnLeft ? .leading : .trailing).combined(with: .opacity)
                    ))
                }
            }
        }
        .frame(height: 56)
        .padding(.bottom, Theme.Spacing.xl)
        // [Phase 3 milk-pink] Selection feedback when the search bar OPENS
        // (search FAB tap or Cmd-F). Fires on open only — dismiss sets
        // showSearchBar false and the condition suppresses it, so opening
        // and closing do not double-fire. The new-chat FAB has no equivalent
        // trigger in this file: its tap goes through DraggableFAB's
        // onTapGesture (not a Button) and creates a draft via the channel,
        // so press feedback for it belongs inside DraggableFAB.swift —
        // recorded as an open item, not faked here with a navigation trigger
        // that would also fire on session-row taps.
        .sensoryFeedback(.selection, trigger: showSearchBar) { _, new in new }
    }
}
