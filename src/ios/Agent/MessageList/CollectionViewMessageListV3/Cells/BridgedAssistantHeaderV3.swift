//
//  BridgedAssistantHeaderV3.swift
//  Minis - V3 chat message list (Agent/MessageList/CollectionViewMessageListV3)
//
//  Cell content for the assistant header row (avatar + <name> from SOUL.md;
//  tap opens Soul Settings). Hosted by AssistantHeaderCellV3 via the
//  Coordinator's cell provider (+CellConfiguration).
//
//  File map and split rules: CollectionViewMessageListV3.swift (this folder).
//

import SwiftUI
import UIKit
import Combine
import UniformTypeIdentifiers

// MARK: - V3 Bridged Cell Views (no GeometryReader)

/// Header: avatar + name label at the top of each assistant turn.
/// Name comes from SOUL.md (user-editable in Soul Settings).
///
/// [T-ios-assistant-header-open-soul] Tapping the row opens Soul Settings.
/// The row shows the identity the user configured there, so it is the
/// obvious place to reach for when changing it.
struct BridgedAssistantHeaderV3: View {
    @ObservedObject var message: ChatMessage
    var maxWidth: CGFloat = 0
    @State private var soulMeta: SoulMetadata = SoulStore.cachedMetadata
    /// [T-ios-assistant-header-open-soul] Injected, NOT read from the
    /// environment.
    ///
    /// `\.openMinisURL` is set on AIChatView, but each cell here is hosted in
    /// its own `UIHostingConfiguration`, which starts a fresh SwiftUI hierarchy
    /// rather than inheriting that one. Reading the environment inside a cell
    /// therefore silently yields the key's default — an action that returns
    /// `.systemAction` and does nothing. (Verified on device: the tap fired, no
    /// navigation happened, and no deep-link log line appeared.) So the handler
    /// is threaded down the same way every other cell callback already is.
    var onOpenSoulSettings: (() -> Void)?
    var body: some View {
        HStack(spacing: 6) {
            // [T-soul-custom-icon] 36pt chat avatar (plan §B.4): solid
            // circle with milk-pink ring; serif initial when no photo is
            // set. `initial` is the soul name's first letter ("M" for the
            // "Minis" fallback). The icon is square by construction
            // (SoulIconImage.encode crops), so an image cannot make this
            // row taller than the disc does. The avatar's layout footprint
            // is 44pt (36 disc + 2pt gap + 2pt ring each side), so it —
            // not the text — sets the row height.
            SoulIconView(
                icon: soulMeta.icon,
                size: 36,
                initial: soulMeta.name.isEmpty ? "M" : String(soulMeta.name.prefix(1)).uppercased()
            )
            Text(soulMeta.name.isEmpty ? "Minis" : soulMeta.name)
                .font(Theme.Font.bodyEmphasized())
                .foregroundStyle(Theme.Color.ink)
        }
        .frame(minHeight: 44)
        // [T-ios-assistant-header-open-soul] Hit area and tap, applied to the
        // icon+name HStack only — NOT to the full-width row below it.
        //
        // The `.frame(maxWidth: .infinity)` modifiers further down stretch this
        // header across the whole message column; making that tappable would
        // turn the empty space beside the name into a button and swallow taps
        // meant for the transcript.
        //
        // `contentShape` makes the whole icon+name box (including the 6pt gap)
        // hittable rather than only the glyph and text pixels.
        //
        // On the 44pt HIG target: the row IS 44pt. The avatar's layout
        // footprint is 44pt (36pt disc + 2pt gap + 2pt ring each side;
        // SoulIconView in SoulStore.swift), and `.frame(minHeight: 44)`
        // above holds that floor even if the name shrinks. Hit area, from
        // the layout values: 44pt tall x ~81pt wide (44 icon + 6 gap +
        // ~31 name at 13pt semibold, by character-width estimate) —
        // >= 44pt in both dimensions. The old ~28-30pt row and its
        // "deliberately NOT 44pt" exception are gone with the 22pt squircle.
        //
        // NOTE (follow-up, other file): MessageListLayout.swift
        // AssistantHeaderMetrics.formulaHeight() still estimates this row
        // as ceil(max(22, name.lineHeight)) + 4 = 26pt; it must move to
        // ceil(max(44, name.lineHeight)) + 4 = 48pt or headers will grow
        // as they scroll into view. The learned-height cache
        // self-corrects after first measure, so this is estimate
        // fidelity only, not a layout break.
        .contentShape(Rectangle())
        .onTapGesture { onOpenSoulSettings?() }
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(.isButton)
        .accessibilityLabel(AppLocalized("Open Soul settings"))
        .accessibilityHint(AppLocalized("Change the assistant's name, icon and personality"))
        .onReceive(NotificationCenter.default.publisher(for: .soulMdChanged)) { _ in
            soulMeta = SoulStore.cachedMetadata
        }
        .padding(.top, 4)
        .padding(.bottom, 0)
        .frame(maxWidth: .infinity, alignment: .leading)
        .frame(maxWidth: maxWidth > 0 ? maxWidth : .infinity, alignment: .leading)
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .opacity(message.isCompactedHistory ? 0.5 : 1.0)
        .accessibilityIdentifier("assistantHeader")
    }
}
