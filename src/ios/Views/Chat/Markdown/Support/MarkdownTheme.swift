//
//  MarkdownTheme.swift
//  Minis - markdown renderer module (Views/Chat/Markdown)
//
//  Visual vocabulary of rendered markdown.
//
//  - NSAttributedString.Key extensions: attributes the renderer writes and
//    MinisLayoutManager / the text view read back (inline code background and
//    text, blockquote depth).
//  - minisInlineCodeBackgroundColor: the single source of the inline-code pill
//    colour, shared by the theme, MinisLayoutManager (the paint site) and table
//    cells, so they cannot drift apart.
//  - SelectableMarkdownTheme: UIKit mirror of the `.minisChat` MarkdownUI theme
//    (fonts, colours, spacing). Attachments keep a copy of the theme they were
//    rendered with.
//  - renderMarkdownBlocks: one-shot render for callers outside the view, e.g.
//    AIChatViewModel caching the attributed string of a finished message.
//
//  Module map and conventions: Bridge/SelectableMarkdownView.swift.
//

import AVFoundation
import Combine
import CoreText
import Photos
import SwiftUI
import UIKit

// MARK: - Custom Attributed String Keys

extension NSAttributedString.Key {
    static let inlineCodeBackground = NSAttributedString.Key("minisInlineCodeBackground")
    static let inlineCodeText = NSAttributedString.Key("minisInlineCodeText")
    static let blockquoteDepth = NSAttributedString.Key("minisBlockquoteDepth")
}

// MARK: - SelectableMarkdownTheme

/// [T-inline-code-dark-bg-ios] Inline-code span background, shared by the
/// theme and the layout manager's fillBackgroundRectArray (the actual paint
/// site) so the two can never drift. Milk-pink Surface2 token in both modes
/// (light #FFE7E8 / dark #4A3036); ink text on it is 8.00:1 light /
/// 11.16:1 dark. Replaces the old .systemGray6 / #3A3A3C pair — the old
/// dark value existed only because systemGray6 resolved to near-black
/// #1C1C1E in dark; the token resolves per mode now, so no per-mode
/// literal is needed.
let minisInlineCodeBackgroundColor = UIColor(Theme.Color.surface2)

/// Mirrors the `.minisChat` MarkdownUI theme using UIKit types.
/// Every color and radius comes from Theme.* — no system color literals,
/// no hex, no magic numbers — except inlineCodeCornerRadius, which is
/// layout-owned (see its comment) and must stay 5 until the paint sites
/// are wired to the theme. Text colors are ink only: ink-2 is 4.09:1
/// for body in light mode (fails 4.5:1) and accent is 2.91:1 as text, so
/// blockquote secondary text, links and inline code all collapse to ink;
/// links keep their existing single underline and inline code keeps its
/// Surface2 pill, which carry the distinction instead of a hue.
struct SelectableMarkdownTheme {
    let baseFontSize: CGFloat
    // Code block is a card surface; inline code is a pill. The code-block
    // radius is the Theme.Radius.card token.
    let codeBlockCornerRadius: CGFloat = Theme.Radius.card
    // Layout owns this value: the paint sites hardcode 5
    // (MinisLayoutManager.swift:39, used at :346; TableCellViews.swift:398)
    // and nothing reads this slot, so it must stay 5 here. Do not change
    // it without wiring those sites to read the theme (open follow-up).
    let inlineCodeCornerRadius: CGFloat = 5

    init(baseFontSize: CGFloat? = nil) {
        self.baseFontSize = baseFontSize ?? 16.5
    }

    var baseFont: UIFont { .systemFont(ofSize: baseFontSize) }
    var labelColor: UIColor { UIColor(Theme.Color.ink) }
    // Same as labelColor on purpose: this colors blockquote body text at
    // base size, where ink-2 fails 4.5:1 in light mode. The accent bar +
    // indent carry the quote distinction, not a lighter ink.
    var secondaryLabelColor: UIColor { UIColor(Theme.Color.ink) }
    // Ink, not blue: accent fails 4.5:1 as text. The existing single
    // underline marks links.
    var linkColor: UIColor { UIColor(Theme.Color.ink) }
    // Pale-pink Surface2 block (light #FFE7E8 / dark #4A3036) with dark ink
    // text: 8.00:1 light / 11.16:1 dark. Replaces black bg / green text.
    var codeBlockBackground: UIColor { UIColor(Theme.Color.surface2) }
    var codeBlockTextColor: UIColor { UIColor(Theme.Color.ink) }
    var inlineCodeBackground: UIColor { minisInlineCodeBackgroundColor }
    // Ink on the Surface2 pill (8.00:1 light / 11.16:1 dark); the pill,
    // not a hue, marks code spans. Replaces .systemOrange.
    var inlineCodeColor: UIColor { UIColor(Theme.Color.ink) }
    // Decorative bar, not text — the one place accent is used at full
    // strength. Replaces .systemOrange at 0.5 alpha.
    var blockquoteBarColor: UIColor { UIColor(Theme.Color.accent) }
    // Hairline token. Replaces .label at 0.25 alpha.
    var tableBorderColor: UIColor { UIColor(Theme.Color.line) }

    func headingFont(level: Int) -> UIFont {
        let size: CGFloat
        let weight: UIFont.Weight
        switch level {
        case 1: size = baseFontSize * 1.5; weight = .bold
        case 2: size = baseFontSize * 1.3; weight = .bold
        case 3: size = baseFontSize * 1.15; weight = .semibold
        case 5: size = baseFontSize * 0.875; weight = .semibold
        case 6: size = baseFontSize * 0.85; weight = .semibold
        default: size = baseFontSize; weight = .semibold // H4 and fallback
        }
        // Serif resolution lives in Theme.Font (uiSerif) — the single
        // serif path. This UIKit theme cannot consume SwiftUI.Font, so
        // headings call the UIKit mirror there, not a local copy.
        return Theme.Font.uiSerif(size: size, weight: weight)
    }

    var inlineCodeFont: UIFont { inlineCodeFont(matching: nil) }

    /// [T-md-inline-code-context-font] Inline code sized RELATIVE to the text
    /// it sits in — 0.845× the CONTEXT font, the exact ratio body text has
    /// always used (0.845 × baseFontSize), so paragraph rendering is
    /// unchanged while a code span inside an H1/H2 scales with the heading
    /// instead of rendering at body size and reading sunken/undersized.
    func inlineCodeFont(matching contextFont: UIFont?) -> UIFont {
        let size = (contextFont?.pointSize ?? baseFontSize) * 0.845
        if let menlo = UIFont(name: "Menlo", size: size) {
            let descriptor = menlo.fontDescriptor.addingAttributes([
                .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "PingFang SC"])]
            ])
            return UIFont(descriptor: descriptor, size: size)
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }

    var codeBlockFont: UIFont {
        let size = baseFontSize * 0.85
        // Use Menlo as the base monospaced font, with PingFang SC as CJK fallback.
        // PingFang SC's CJK glyphs are exactly 2x the width of Menlo's ASCII glyphs
        // at the same point size, enabling proper table alignment in code blocks.
        if let menlo = UIFont(name: "Menlo", size: size) {
            let descriptor = menlo.fontDescriptor.addingAttributes([
                .cascadeList: [UIFontDescriptor(fontAttributes: [.name: "PingFang SC"])]
            ])
            return UIFont(descriptor: descriptor, size: size)
        }
        return .monospacedSystemFont(ofSize: size, weight: .regular)
    }
}

/// Renders markdown blocks into an NSAttributedString using a fresh MarkdownNSRenderer.
/// Intended for one-shot rendering of completed messages (e.g. caching in AIChatViewModel).
@MainActor
func renderMarkdownBlocks(_ blocks: [BlockNode]) -> NSAttributedString {
    let renderer = MarkdownNSRenderer(baseFontSize: FontSettings.shared.scaled(16.5))
    return renderer.render(blocks: blocks)
}
