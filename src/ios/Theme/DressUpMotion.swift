// DressUpMotion — the milk-pink motion spec (plan §B.3, §C, §D.3).
//
// One vocabulary for every screen in this set. Every duration and every
// spring comes from Theme.Motion; no view writes a literal duration or
// spring. Durations in use: 0.0 / 0.06 / 0.20 / 0.32 / 0.40, all <= 0.5s.
// Springs in use: press 0.3 / 0.6, primary 0.36 / 0.78,
// motion 0.32 / 0.72, modal 0.5 / 0.8.
//
// The default is quiet: nothing animates unless a caller opts in through
// one of the named APIs in ThemeMotionModifiers.swift. Each screen gets at
// most ONE signature motion (see Signature); everything else stays still
// or uses the quiet fade. There is no entrance animation on every element,
// no decorative motion, and no bounce or elastic easing anywhere.
//
// Reduce Motion: every API has a fade-only fallback (or no motion at all
// for the thinking dots). No depth, no blur, no slide under Reduce Motion.
//
// Honest status: no local Xcode compile is possible on this VM and no
// simulator run has happened. CI is the only compile gate. The feel of
// the sheet spring, the try-on swap, and the dots rhythm is SPECULATION
// until a simulator run.
//
// This file is not yet referenced in Minis.xcodeproj/project.pbxproj.
// Adding the file ref and the Sources entry is Phase 1 wiring work, not
// part of this block (new files only).

import SwiftUI

/// The motion vocabulary for the dress-up shop and the screens that share
/// its language. Values only — the SwiftUI pieces live in
/// ThemeMotionModifiers.swift.
enum DressUpMotion {

    /// The four spring kinds. Each maps to exactly one Theme.Motion spring.
    enum Kind {
        /// Press feedback. Theme.Motion.press (0.3 / 0.6).
        case press
        /// Signature content motion, e.g. the try-on preview swap.
        /// Theme.Motion.spring (0.36 / 0.78).
        case primary
        /// General content motion, e.g. the sheet snap-back after a drag
        /// that does not dismiss. Theme.Motion.springMotion (0.32 / 0.72).
        case motion
        /// Sheet present / dismiss. Theme.Motion.modal (0.5 / 0.8).
        case modal
    }

    /// The one signature motion a screen may claim. At most one per screen;
    /// declare it with .dressUpSignature(_:) so reviewers can check the
    /// budget by reading the screen top to bottom. A screen with no
    /// signature declares nothing.
    enum Signature {
        /// Press feedback is the screen's signature.
        case press
        /// The try-on preview swap is the screen's signature.
        case tryOnSwap
        /// The sheet present / dismiss is the screen's signature.
        case sheet
        /// The thinking dots are the screen's signature.
        case thinkingDots
    }

    // MARK: - Press values (task values, not durations)

    /// Pressed scale for the scale press style. Never combined with
    /// pressedOpacity on the same press.
    static let pressedScale: CGFloat = 0.97
    /// Pressed opacity for the opacity press style. Never combined with
    /// pressedScale on the same press.
    static let pressedOpacity: CGFloat = 0.85

    // MARK: - Try-on values

    /// Scale the outgoing / incoming preview rests at during a try-on swap.
    static let swapScale: CGFloat = 0.97

    // MARK: - Thinking dots values

    /// Number of dots in the thinking indicator (plan §A #6).
    static let thinkingDotCount: Int = 3
    /// Opacity of the dot whose turn it is.
    static let dotActiveOpacity: CGFloat = 1.0
    /// Opacity of the dots waiting their turn.
    static let dotIdleOpacity: CGFloat = 0.35

    // MARK: - Sheet values

    /// Fraction of the sheet height a drag (or its fling) must pass to
    /// dismiss. Not a duration.
    static let dismissFraction: CGFloat = 0.5
    /// Scrim opacity: Theme.Color.ink at this opacity dims the content
    /// behind the sheet.
    static let scrimOpacity: CGFloat = 0.35

    // MARK: - Resolved animations

    /// The spring for a kind, or an at-once change under Reduce Motion.
    /// Use only for position / scale changes; under Reduce Motion those
    /// changes must not travel, so they happen at once. Opacity-only
    /// changes under Reduce Motion use fadeAnimation instead.
    static func animation(for kind: Kind, reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .linear(duration: Theme.Motion.instant)
        }
        switch kind {
        case .press: return Theme.Motion.press
        case .primary: return Theme.Motion.spring
        case .motion: return Theme.Motion.springMotion
        case .modal: return Theme.Motion.modal
        }
    }

    /// Opacity-only fade. Normal: a quiet ease over Theme.Motion.base.
    /// Reduce Motion: a near-at-once linear fade over Theme.Motion.fast —
    /// a fade, never a slide, never depth or blur.
    static func fadeAnimation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return .linear(duration: Theme.Motion.fast)
        }
        return quietFade()
    }

    /// The one quiet opacity fade for incidental, non-signature changes
    /// (a selection tick appearing, a label swapping). Never for movement.
    static func quietFade() -> Animation {
        .easeInOut(duration: Theme.Motion.base)
    }

    /// Scrim fade behind a sheet. Normal: ease over Theme.Motion.slow.
    /// Reduce Motion: the fast linear fade.
    static func scrimAnimation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return fadeAnimation(reduceMotion: true)
        }
        return .easeInOut(duration: Theme.Motion.slow)
    }

    /// Thinking-dots rhythm (plan §A #6): one phase step every 0.4s.
    static func thinkingDotsAnimation() -> Animation {
        .easeInOut(duration: Theme.Motion.sheet)
    }

    /// Try-on swap transition. Normal: crossfade plus a rest at swapScale.
    /// Reduce Motion: crossfade only, no scale.
    static func tryOnTransition(reduceMotion: Bool) -> AnyTransition {
        if reduceMotion {
            return .opacity
        }
        return .opacity.combined(with: .scale(scale: swapScale))
    }

    /// Try-on swap animation. Normal: the primary spring.
    /// Reduce Motion: the fast linear fade.
    static func tryOnAnimation(reduceMotion: Bool) -> Animation {
        if reduceMotion {
            return fadeAnimation(reduceMotion: true)
        }
        return Theme.Motion.spring
    }
}
