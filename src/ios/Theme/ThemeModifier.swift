// EnvironmentKey-driven theme injection, so screens read the theme from the
// environment instead of reaching for tokens through string literals.
// Applied once at the app root via .withTheme() (MinisApp.swift,
// WindowGroup). Do not call it anywhere else.

import SwiftUI

// MARK: - Environment value

private struct ThemeEnvironmentKey: EnvironmentKey {
    static let defaultValue: ThemeContext = .default
}

extension EnvironmentValues {
    var theme: ThemeContext {
        get { self[ThemeEnvironmentKey.self] }
        set { self[ThemeEnvironmentKey.self] = newValue }
    }
}

// MARK: - ThemeContext
//
// Holds anything that may vary at runtime (for example a user-selected
// accent or density mode). Static values stay in the `Theme` enum
// (Tokens.swift). Anything dynamic lives here.

struct ThemeContext: Equatable {
    enum Density: String, CaseIterable, Equatable { case airy, balanced, dense }

    var density: Density
    var accent: Color
    var pressFeedback: PressFeedback

    enum PressFeedback: String, Equatable { case scale, opacity }

    static let `default` = ThemeContext(
        density: .balanced,
        accent: Theme.Color.accent,
        pressFeedback: .scale
    )
}

// MARK: - View modifier

struct ThemeModifier: ViewModifier {
    let context: ThemeContext

    func body(content: Content) -> some View {
        content
            .environment(\.theme, context)
            // NOTE (2026-11-05, wiring review fix): NO root .tint(accent) here.
            // Accent on background is 2.91:1 light and locked "never text"
            // (Tokens.swift header); a root tint turns ~178 text buttons
            // accent-colored and illegible. Tint must be applied explicitly
            // per control in Phase 2 migration, only where the control is
            // non-text (or its text is ink on an accent fill).
            .foregroundStyle(Theme.Color.ink)
            // Honor Dynamic Type — never lock the user out of larger sizes.
            .dynamicTypeSize(.xSmall ... .accessibility5)
    }
}

extension View {
    /// Apply the design system theme. Call once at the app root.
    func withTheme(_ context: ThemeContext = .default) -> some View {
        modifier(ThemeModifier(context: context))
    }
}

// MARK: - Convenience accessors
//
// Inside a View body, read the theme via @Environment(\.theme).
//
//     struct MyScreen: View {
//         @Environment(\.theme) private var theme
//         var body: some View {
//             Text("Hello")
//                 .padding(theme.density == .dense ? Theme.Spacing.sm : Theme.Spacing.md)
//         }
//     }
