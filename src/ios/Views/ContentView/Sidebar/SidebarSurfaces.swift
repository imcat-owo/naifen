//
//  SidebarSurfaces.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  View modifiers and backgrounds of the sidebar: selection opt-out, folder
//  header visibility probe, folder card / member-row surfaces (one source of
//  truth for the folder look), and the search bar / FAB glass styling.
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI

/// List-selection opt-out with an availability floor. The folder card row
/// must never become the List(selection:)'s selected value — its "tap" is
/// collapse/expand, not navigation — but .selectionDisabled is iOS 17+ and
/// the app floors at 16 (where the plain Button row doesn't self-select).
struct SelectionDisabledIfAvailable: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 17.0, *) {
            content.selectionDisabled()
        } else {
            content
        }
    }
}

/// Tracks whether an expanded folder's header card has scrolled out above
/// the list's visible top, reporting only on TRANSITIONS (Bool onChange) so
/// scroll frames don't churn ContentView state. Lives in the header row's
/// background — geometry is read in .global and compared against the
/// threshold the mini-bar overlay measured, which sidesteps the known-flaky
/// preference propagation across List cell hosting boundaries entirely.
///
/// `lastMaxY` exists for the CULLING edge: when the List recycles the header
/// cell far offscreen, onDisappear is the only signal left, and it alone
/// can't tell "culled above" from "culled below". The last observed frame
/// disambiguates. onDisappear also fires on collapse and on entering select
/// mode (the header row unmounts) — those reports are harmless because the
/// mini-bar's display guard independently requires an expanded folder
/// outside select mode.
struct FolderHeaderVisibilityProbe: View {
    let folderId: String
    let thresholdY: CGFloat
    let onVisibilityChange: (String, Bool) -> Void

    @State private var lastMaxY: CGFloat = .infinity

    var body: some View {
        GeometryReader { geo in
            let maxY = geo.frame(in: .global).maxY
            let hidden = maxY < thresholdY
            Color.clear
                .onAppear {
                    lastMaxY = maxY
                    onVisibilityChange(folderId, hidden)
                }
                .onChange(of: maxY) { newValue in
                    lastMaxY = newValue
                }
                .onChange(of: hidden) { newValue in
                    onVisibilityChange(folderId, newValue)
                }
                .onDisappear {
                    onVisibilityChange(folderId, lastMaxY < thresholdY)
                }
        }
    }
}

/// Folder card container: what visually separates a folder from the flat
/// session rows around it. On iOS 26+ this is the system Liquid Glass
/// material (`glassEffect`) in a continuous rounded rect; on earlier systems
/// it degrades to a deliberately plain filled card with a hairline stroke —
/// no custom blur, since `.blur` is an offscreen pass and this list is the
/// site of two archived scroll-perf incidents. The drop-target state draws an
/// accent tint + stroke ON TOP of either material, so drag feedback reads the
/// same on both OS generations.
/// One row's share of the expanded container's OUTER border. The top kind
/// draws the top arc + upper side walls, middle draws side walls only, and
/// bottom draws the lower walls + bottom arc — tiled across the group's rows
/// they form one continuous rounded-rect highlight, with no horizontal lines
/// at the row boundaries (which a per-segment full stroke would create).
private struct FolderSegmentBorder: Shape {
    enum Kind { case top, middle, bottom }
    let kind: Kind
    var radius: CGFloat = Theme.Radius.card

    func path(in rect: CGRect) -> Path {
        var p = Path()
        switch kind {
        case .top:
            p.move(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.minY + radius))
            p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.minY + radius),
                     radius: radius, startAngle: .degrees(180), endAngle: .degrees(270), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.minY))
            p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.minY + radius),
                     radius: radius, startAngle: .degrees(270), endAngle: .degrees(0), clockwise: false)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .middle:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY))
            p.move(to: CGPoint(x: rect.maxX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY))
        case .bottom:
            p.move(to: CGPoint(x: rect.minX, y: rect.minY))
            p.addLine(to: CGPoint(x: rect.minX, y: rect.maxY - radius))
            p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                     radius: radius, startAngle: .degrees(180), endAngle: .degrees(90), clockwise: true)
            p.addLine(to: CGPoint(x: rect.maxX - radius, y: rect.maxY))
            p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                     radius: radius, startAngle: .degrees(90), endAngle: .degrees(0), clockwise: true)
            p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        }
        return p
    }
}

/// Edge highlight for the folder card: bright hairline in dark mode (the
/// reference system-folder look), a subtle dark line in light mode (white
/// would vanish on the light page). Derived from Theme.Color.ink, which is
/// near-white in dark mode and deep rose-brown in light mode, so one token
/// gives both sides. Lives on FolderSurface as a computed property (which
/// reads colorScheme), not as a file-scope let, so it resolves from Theme
/// only.

/// Background for the expanded FAB search bar. Liquid Glass capsule on iOS 26+,
/// the milk-pink surface capsule + Theme card shadow below it.
///
/// A modifier rather than a background view because the bar's content has to sit
/// INSIDE the glass: `.glassEffect` styles the view it is applied to, so the
/// text field and its icons ride within the material instead of being composited
/// over a separately-drawn shape.
struct SearchBarSurface: ViewModifier {
    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            // No .clipShape needed — glassEffect(in:) already clips to the
            // capsule, and no .shadow: the material carries its own.
            content.glassEffect(.regular, in: .capsule)
        } else {
            content
                .background(Theme.Color.surface)
                .clipShape(Capsule())
                .themeShadow(Theme.Shadow.card)
        }
    }
}

/// Tags the search FAB and the expanded search bar with ONE shared
/// `glassEffectID`.
///
/// Currently INERT: `glassEffectID` only does anything inside a
/// `GlassEffectContainer`, and the FAB row no longer has one — that container
/// suppressed the new-chat FAB's context menu, see the note on `fabRow`. The
/// modifier is kept (harmless, and it costs nothing) so that if the container
/// is ever reinstated with the menu problem solved, the morph works again
/// without re-deriving the id plumbing. The row's scale+opacity transition is
/// what actually animates the swap today.
struct FABGlassMorphID: ViewModifier {
    let namespace: Namespace.ID

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffectID("fabSearch", in: namespace)
        } else {
            content
        }
    }
}

/// THE single source of truth for a folder surface's background — used
/// identically by the collapsed lone card and by every row of an expanded
/// group. Per the user's directive after several rounds of expanded-only
/// material tuning: there is NO expanded-specific material/tint/opacity
/// definition anymore. The only thing that varies by position is the SHAPE
/// (lone / top / middle / bottom corner segmentation) and how the border is
/// tiled; the fill comes from one place.
private struct FolderSurface: ViewModifier {
    enum Kind { case lone, top, middle, bottom }
    let kind: Kind

    @Environment(\.colorScheme) private var colorScheme

    /// Edge highlight for the folder card: bright hairline in dark mode,
    /// subtle dark line in light mode. Theme.Color.ink is near-white in
    /// dark mode and deep rose-brown in light mode, so one token gives
    /// both sides.
    private var edgeHighlight: Color {
        colorScheme == .dark ? Theme.Color.ink.opacity(0.30) : Theme.Color.ink.opacity(0.08)
    }

    /// The collapsed card's fill. The old eyedropper-sampled constants
    /// (dark RGB 18/18/18, light 252/252/252 — sampled from device
    /// screenshots of real glass over a flat list) are retired: the
    /// milk-pink set gives the folder card the card-surface token, so the
    /// fill stays one source of truth with every other card. The
    /// lightweight look the sampling chased (fill nearly on the
    /// background, edge hairline doing the lifting) is kept by the
    /// hairline in the overlay below.
    static let folderFill = Theme.Color.surface

    private var shape: AnyShape {
        switch kind {
        case .lone:
            return AnyShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
        case .top:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: Theme.Radius.card, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: Theme.Radius.card, style: .continuous))
        case .middle:
            return AnyShape(Rectangle())
        case .bottom:
            return AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: 0, bottomLeadingRadius: Theme.Radius.card,
                bottomTrailingRadius: Theme.Radius.card, topTrailingRadius: 0, style: .continuous))
        }
    }

    func body(content: Content) -> some View {
        Group {
            // Two states, two deliberate treatments (user decision):
            // - COLLAPSED lone card: the Surface token. glassEffect is a
            //   live material and a collapsed card scrolls past heterogeneous
            //   content (blurred colorful pinned rows), so live glass
            //   flickered frame to frame; the token fill is what that glass
            //   rendered over the flat background anyway.
            // - EXPANDED segments: a real material for translucency. Member
            //   rows sit over the STABLE list background only — nothing
            //   colorful ever passes behind them — so the flicker mechanism
            //   doesn't apply, and the material keeps the container from
            //   reading as a dull solid slab. regularMaterial (the brighter
            //   tier; ultraThin ran too dark here before).
            if kind == .lone {
                if #available(iOS 26.0, *) {
                    content.background(shape.fill(Self.folderFill))
                } else {
                    content.background(shape.fill(Theme.Color.surface))
                }
            } else {
                if #available(iOS 26.0, *) {
                    content.background(shape.fill(.regularMaterial))
                } else {
                    content.background(shape.fill(Theme.Color.surface))
                }
            }
        }
        .overlay {
            // Border: full hairline on the lone card (its existing look, sub-26
            // only — glass carries its own edge); tiled outer-perimeter
            // segments on expanded rows so the pieces read as one outline
            // without horizontal lines at the row boundaries.
            switch kind {
            case .lone:
                // With glass gone the card needs an explicit edge for
                // definition — the same highlight the expanded segments tile,
                // as a full perimeter here.
                if #available(iOS 26.0, *) {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(edgeHighlight, lineWidth: 0.75)
                } else {
                    RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                        .stroke(Theme.Color.line, lineWidth: 0.5)
                }
            case .top:
                FolderSegmentBorder(kind: .top)
                    .stroke(edgeHighlight, lineWidth: 0.75)
            case .middle:
                FolderSegmentBorder(kind: .middle)
                    .stroke(edgeHighlight, lineWidth: 0.75)
            case .bottom:
                FolderSegmentBorder(kind: .bottom)
                    .stroke(edgeHighlight, lineWidth: 0.75)
            }
        }
    }
}

struct FolderCardBackground: ViewModifier {
    let isDropTarget: Bool
    let isExpanded: Bool

    private var dropShape: AnyShape {
        isExpanded
            ? AnyShape(UnevenRoundedRectangle(
                topLeadingRadius: Theme.Radius.card, bottomLeadingRadius: 0,
                bottomTrailingRadius: 0, topTrailingRadius: Theme.Radius.card, style: .continuous))
            : AnyShape(RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
    }

    func body(content: Content) -> some View {
        content
            .modifier(FolderSurface(kind: isExpanded ? .top : .lone))
            .overlay {
                if isDropTarget {
                    ZStack {
                        dropShape.fill(Theme.Color.accent.opacity(0.15))
                        dropShape.stroke(Theme.Color.accent, lineWidth: 1.5)
                    }
                }
            }
    }
}

/// Middle/bottom rows of an expanded group: the SAME FolderSurface as the
/// collapsed card, with the corner segmentation and border tiling that
/// multi-row composition needs.
struct FolderMemberRowBackground: View {
    let isLast: Bool

    var body: some View {
        Color.clear
            .modifier(FolderSurface(kind: isLast ? .bottom : .middle))
            .padding(.horizontal, Theme.Spacing.sm)
            .padding(.bottom, isLast ? Theme.Spacing.xs : 0)
    }
}

/// Rename + dissolve alerts for the folder-header menu, extracted into a
/// modifier so their inline Binding(get:set:) expressions don't count against
