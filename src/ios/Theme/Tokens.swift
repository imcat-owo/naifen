// Milk Pink — the ONE theme set. Locked 2026-11-05.
// Black-pink and milk blue were rejected and are not built here.
// No neon, no purple-pink gradients, no cyber glow. All pinks are
// low-saturation milk tones; the deep ink carries titles and body text.
//
// Anchors (ui-ios): primary 6 Apple Music / Podcasts; type 4 Editorial /
// NYT; motion 5 Arc / Raycast / Things 3. Primary supplies type, color,
// spacing, radius and shadow; the type anchor overrides display type only;
// the motion anchor overrides motion only. Color always comes from primary.
//
// Provenance: hexes marked [verified] come from the milk-tea note
// (research_notes/colour-palettes-milk-tea-20261102.md, 2026-11-02).
// Hexes marked [proposal] were derived to complete the table. Dark variants
// are separately designed, never a plain inversion.
//
// Contrast, recomputed by hand with Python/WCAG on 2026-11-05 from the hexes
// in this file (not copied from any earlier file):
//   ink on background            8.74:1 light / 15.11:1 dark — body text, PASS.
//   ink-2 on background          4.09:1 light / 10.50:1 dark — FAILS 4.5:1 for
//     body in light mode. LOCKED RESTRICTION: light mode, ink-2 is >=18pt, or
//     >=14pt bold, only. Never body, never 11pt meta/caption. (Theme.Font
//     meta() floors to 11pt regular, which fails at 4.09:1.) Dark mode: no
//     restriction.
//   ink-3 on background          2.03:1 light / 5.15:1 dark — decorative only
//     (dots, rings, dividers, borders). NEVER as text in either mode.
//   accent on background         2.91:1 light — small accent only, never text,
//     never a text background. White on accent is 3.14:1 light / 1.47:1 dark,
//     so there is deliberately no on-accent text: no on-accent text ever.
//   time capsule, LOCKED pairing: 10pt text is ink #5B3F41 on surface-2
//     #FFE7E8 = 8.00:1 light; dark ink #FBF8EA on #4A3036 = 11.16:1. ink-2
//     and ink-3 are FORBIDDEN at 10pt in either mode (ink-2 on surface-2 is
//     3.74:1 light, ink-3 is 1.86:1 light — both fail 4.5:1).
//   bubble user text on bubble user fill  6.14:1 light / 8.83:1 dark — PASS.
//     (Switched from the old in-code anchor #F6DDE3 / #573C43 at 7.68:1 to
//     #ECC7D6 / #5B3F41; 6.14:1 is the new light ratio.)
//   bubble AI text on bubble AI fill      9.41:1 light / 13.10:1 dark — PASS.
//   thinking dots on thinking background  1.42:1 light / 9.47:1 dark —
//     decorative only, never text, in either mode.
//
// Do not add values in views. Add tokens here instead. Every padding, frame,
// cornerRadius, font and color in the app must reference Theme.*.
// Fraunces is used ONLY through Theme.Font, with a declared
// .system(..., design: .serif) fallback. There is NO other serif path in
// this file: upstream has no bundled serif face, and no new one is
// introduced here. The font is not bundled yet; until Phase 1 bundles it,
// the system serif fallback is what renders.

import SwiftUI
import UIKit

enum Theme {

    // MARK: - Color
    //
    // Every color is an asset-catalog color set with Any + Dark variants, so
    // light and dark resolve from the same token. Same color = same meaning
    // everywhere; one accent, tinted = tappable.

    enum Color {
        // Ground
        static let background = SwiftUI.Color("Background") // #FFF4F5 [verified] / #2A1E20 [proposal]
        static let surface = SwiftUI.Color("Surface") // #FBF8EA [verified] / #3A272B [proposal]
        static let surface2 = SwiftUI.Color("Surface2") // #FFE7E8 [verified] / #4A3036 [proposal]

        // Ink — see the contrast restrictions in the file header
        static let ink = SwiftUI.Color("TextPrimary") // #5B3F41 [verified] / #FBF8EA [verified]
        static let ink2 = SwiftUI.Color("TextSecondary") // #8B736C [verified] / #ECC7D6 [verified]
        static let ink3 = SwiftUI.Color("TextTertiary") // #C3AB99 [verified] / #9F8F82 [verified]
        static let line = SwiftUI.Color("Line") // #ECC7D6 [verified] / #5B3F41 [verified]

        // Ornament — thin ornamental line art only (plan §B.5, from the user's
        // milk-pink reference image). #ECC7D6 [verified] at 0.35 opacity,
        // derived from the Line asset so light and dark resolve from one token.
        // RULES: hero/profile surfaces ONLY. Stroke 0.5–1pt, always behind
        // content, never under body text, never on chat rows, never on bubbles,
        // never animated. One ornamental frame per surface max. If it reduces
        // legibility it is deleted, not darkened.
        static let ornamentLine = SwiftUI.Color("Line").opacity(0.35)

        // Accent — small only, never text (see header)
        static let accent = SwiftUI.Color("Accent") // #C97B8C [proposal] / #FAC7DA [verified]

        // Bubbles — user text on user fill 6.14:1 light, 8.83:1 dark
        static let bubbleUser = SwiftUI.Color("BubbleUser") // #ECC7D6 [verified] / #5B3F41 [verified]
        static let bubbleUserText = SwiftUI.Color("TextPrimary") // #5B3F41 [verified] / #FBF8EA [verified]
        static let bubbleAI = SwiftUI.Color("BubbleAI") // #FFFFFF [verified] / #3A272B [proposal]
        static let bubbleAIText = SwiftUI.Color("TextPrimary") // #5B3F41 [verified] / #FBF8EA [verified]
        static let bubbleAIBorder = SwiftUI.Color("BubbleAIBorder") // #ECC7D6 [verified] / #5B3F41 [verified]

        // Avatar — solid circle, ring only; ring 2pt + 2pt clear gap (Phase 2)
        static let avatarRing = SwiftUI.Color("AvatarRing") // #ECC7D6 [verified] / #FAC7DA [verified]
        static let avatarBackground = SwiftUI.Color("AvatarBackground") // #FFE7E8 [verified] / #5B3F41 [verified]

        // Thinking — its own group, never hidden under generic colors
        static let thinkingBackground = SwiftUI.Color("ThinkingBackground") // #FFF4F5 [verified] / #3A272B [proposal]
        static let thinkingDots = SwiftUI.Color("ThinkingDots") // #ECC7D6 [verified] / #FAC7DA [proposal]

        // Input bar + tab bar
        static let inputBackground = SwiftUI.Color("InputBackground") // #FFFFFF [verified] / #3A272B [proposal]
        static let inputBorder = SwiftUI.Color("InputBorder") // #ECC7D6 [verified] / #5B3F41 [proposal]
        static let tabBar = SwiftUI.Color("TabBar") // #FBF8EA [verified] / #2A1E20 [proposal]
    }

    // MARK: - Spacing
    //
    // 4pt grid only. No odd values. If a value is not here, that is a design
    // decision to make deliberately — do not invent one inline in a view.

    enum Spacing {
        static let xs: CGFloat = 4
        static let sm: CGFloat = 8
        static let md: CGFloat = 12
        static let lg: CGFloat = 16
        static let xl: CGFloat = 20
        static let xxl: CGFloat = 24
        static let xxxl: CGFloat = 32
        static let huge: CGFloat = 48
        static let massive: CGFloat = 64
    }

    // MARK: - Radius
    //
    // Four distinct sizes across five named tokens: pillTag shares the 14pt
    // value with seal — a separate semantic token, not a fifth size.
    // Short user bubbles are a full pill (radius = half the bubble height,
    // computed at layout time), not a token. Long messages fall back to the
    // Porcelain Card radius regardless of sender.

    enum Radius {
        static let thinking: CGFloat = 12
        static let seal: CGFloat = 14
        static let card: CGFloat = 16
        static let user: CGFloat = 18

        // Pill tags: capsule pills, pale pink fill surface-2 #FFE7E8,
        // ink text #5B3F41, 10–11pt, H12/V6 padding. 14pt is the token for
        // the standard ~28pt tag height; use half the height at layout time
        // if a tag's height differs. Tappable pills still need a 44pt hit
        // area (visual stays small).
        static let pillTag: CGFloat = 14
    }

    // MARK: - Font
    //
    // Named roles only, all Dynamic Type aware via UIFontMetrics and system
    // text styles. Display 20/24/28/32, capped at ~36pt. Body 13pt default
    // on the one global 10–15pt dial. Sans floor is 11pt. Layout must
    // survive to AX5 (Body 53pt).
    //
    // Display: Fraunces 600 (Latin); if Fraunces is not bundled, the declared
    // .system(..., design: .serif) fallback renders instead. There is no
    // other serif path in this file. Never .font(.custom) in a view.
    //
    // DISPLAY-ONLY: Latin display words and section titles, one line per
    // screen max. Never body text, never bubbles, never buttons.

    enum Font {
        // Display — serif, Fraunces 600 / system serif fallback, 20 / 24 / 28 / 32
        static func displaySmall() -> SwiftUI.Font { serif(size: 20, relativeTo: .title3) }
        static func displayMedium() -> SwiftUI.Font { serif(size: 24, relativeTo: .title2) }
        static func displayLarge() -> SwiftUI.Font { serif(size: 28, relativeTo: .title1) }
        static func displayExtraLarge() -> SwiftUI.Font { serif(size: 32, relativeTo: .largeTitle) }

        // Body — SF Pro / PingFang SC, 13pt default, whole 10–15 dial scales together
        // The 13pt base IS the one global dial's default (FontSettings.bodySize):
        // the app root applies the dial as .dynamicTypeSize and UIFontMetrics
        // scales each role from there, so body() needs no dial read of its own.
        // Keep this 13 in sync with FontSettings.defaultBodySize.
        static func body() -> SwiftUI.Font { sans(size: 13, relativeTo: .body) }
        static func bodyEmphasized() -> SwiftUI.Font { sans(size: 13, relativeTo: .body, weight: .semibold) }

        // Caption / meta — 11pt / 10pt base, floored to 11pt
        static func caption() -> SwiftUI.Font { sans(size: 11, relativeTo: .caption1) }
        static func meta() -> SwiftUI.Font { sans(size: 10, relativeTo: .caption2) }

        // Mono — SF Mono / Menlo, 12pt, code / time / numbers only
        static func mono() -> SwiftUI.Font {
            let scaled = scaledSize(12, for: .body)
            return SwiftUI.Font.system(size: scaled, weight: .regular, design: .monospaced)
        }

        // MARK: - Private helpers

        private static func scaledSize(_ base: CGFloat, for style: UIFont.TextStyle, cap: CGFloat? = nil) -> CGFloat {
            let scaled = UIFontMetrics(forTextStyle: style).scaledValue(for: base)
            let capped = cap.map { min(scaled, $0) } ?? scaled
            return max(capped, 11)
        }

        private static func serif(size: CGFloat, relativeTo style: UIFont.TextStyle) -> SwiftUI.Font {
            let scaled = scaledSize(size, for: style, cap: 36)
            if UIFont(name: "Fraunces-SemiBold", size: scaled) != nil {
                return SwiftUI.Font.custom("Fraunces-SemiBold", size: scaled)
            }
            return SwiftUI.Font.system(size: scaled, weight: .semibold, design: .serif)
        }

        private static func sans(size: CGFloat, relativeTo style: UIFont.TextStyle, weight: SwiftUI.Font.Weight = .regular) -> SwiftUI.Font {
            SwiftUI.Font.system(size: scaledSize(size, for: style), weight: weight, design: .default)
        }
    }

    // MARK: - Shadow
    //
    // One layered shadow + none. Color comes from the Shadow asset set so
    // light and dark differ (light rgba(91,63,65,0.08) [proposal], dark
    // rgba(0,0,0,0.35) [proposal]). Never a large shadow on everything.

    struct ShadowSpec {
        let color: SwiftUI.Color
        let radius: CGFloat
        let x: CGFloat
        let y: CGFloat
    }

    enum Shadow {
        static let none = ShadowSpec(color: .clear, radius: 0, x: 0, y: 0)
        static let card = ShadowSpec(color: SwiftUI.Color("Shadow"), radius: 16, x: 0, y: 4)
    }

    // MARK: - Motion
    //
    // Durations in seconds, all <= 0.5s. Press spring response 0.3 /
    // damping 0.6. Primary spring 0.36 / 0.78; motion spring 0.32 / 0.72;
    // modal spring 0.5 / 0.8. Reference these from .animation(_, value:) and
    // withAnimation — never write a literal duration in a view body.
    // One signature motion per screen max; everything else stays quiet.
    // Reduce Motion fallback: fade, no depth/blur animation.

    enum Motion {
        static let instant: Double = 0.0
        static let fast: Double = 0.06
        static let base: Double = 0.20
        static let slow: Double = 0.32
        static let sheet: Double = 0.40

        static let press = Animation.interactiveSpring(response: 0.3, dampingFraction: 0.6, blendDuration: 0)
        static let spring = Animation.interactiveSpring(response: 0.36, dampingFraction: 0.78, blendDuration: 0)
        static let springMotion = Animation.interactiveSpring(response: 0.32, dampingFraction: 0.72, blendDuration: 0)
        static let modal = Animation.interactiveSpring(response: 0.5, dampingFraction: 0.8, blendDuration: 0)
    }
}

// MARK: - View extensions for ergonomics

extension View {
    /// Apply a Theme.ShadowSpec uniformly.
    func themeShadow(_ spec: Theme.ShadowSpec) -> some View {
        self.shadow(color: spec.color, radius: spec.radius, x: spec.x, y: spec.y)
    }
}
