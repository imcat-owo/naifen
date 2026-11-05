# DESIGN RULES — Milk Pink (the one set)

Style name: **retro + Rococo + kawaii (NOT Nordic)**.
Nordic — white walls, wood, straight lines, minimal — is the opposite of this
set. Never use it as an anchor, a reference, or a fallback. The only place the
word Nordic appears is in NOT-Nordic prohibitions like this one.

One set only: milk pink. Black-pink was rejected (easily neon/cyber, hurts
eyes). Milk blue was rejected too. Nothing else is built until this set passes
on the user's real device.

## Anchors (ui-ios)

- Primary: **6 Apple Music / Podcasts** — supplies type, color, spacing,
  radius, shadow.
- Type: **4 Editorial / NYT** — overrides display type only.
- Motion: **5 Arc / Raycast / Things 3** — overrides motion only.
- Blending rule: primary provides everything unless a named anchor overrides
  exactly its own lane. Color always comes from the primary anchor.

Every choice traces to a named anchor recipe + a `Theme` token. A buzzword
(clean, modern, professional, sleek, premium, beautiful, elegant) is never a
substitute for a token.

## Tokens

- All color, spacing, radius, font, shadow and motion values live in
  `src/ios/Theme/Tokens.swift` and resolve through
  `src/ios/Assets.xcassets/` color sets (Any + Dark per token).
- No values in views. Add tokens here instead. No magic numbers, no
  `Color(hex:)`, no `.font(.system(size:))` outside `Theme.Font`.
- Spacing is a 4pt grid only: 4/8/12/16/20/24/32/48/64.
- Radius: 12 thinking, 14 seal / pill tag, 16 card, 18 user bubble.
- Font: Fraunces 600 display 20/24/28/32 (capped ~36pt) via `Theme.Font`
  with a declared `.system(..., design: .serif)` fallback only. Fraunces is
  NOT bundled yet; the fallback renders until Phase 1 bundles it. There is
  no other serif path in code — never introduce one. Body is SF Pro /
  PingFang SC, 13pt default, one global 10–15pt dial, floor 11pt, layout
  survives to AX5. Mono is SF Mono / Menlo 12pt, code / time / numbers only.
- Display type is display-only: Latin display words and section titles, one
  line per screen max. Never body, bubbles, or buttons.
- Shadow: one layered card shadow + none. Never a large shadow on everything.
- Motion: durations 0.0 / 0.06 / 0.20 / 0.32 / 0.40 (all ≤ 0.5s). One
  signature motion per screen max. Reduce Motion fallback: fade, no
  depth/blur animation.

## Contrast restrictions (locked, recomputed 2026-11-05, Python/WCAG)

- Ink on background 8.74:1 light / 15.11:1 dark — body text, PASS.
- **ink-2 light only: ≥18pt, or ≥14pt bold. Never body, never 11pt
  meta/caption.** Light ink-2 on background is 4.09:1 (fails 4.5:1). Dark
  ink-2 is 10.50:1, no restriction.
- **ink-3 decorative only, never text** in either mode (2.03:1 light /
  5.15:1 dark).
- **Accent small only, never text, no on-accent text** (accent on background
  2.91:1 light; white on accent 3.14:1 light / 1.47:1 dark).
- **Time capsule locked pairing:** 10pt text is ink on surface-2
  (8.00:1 light / 11.16:1 dark). **ink-2 / ink-3 FORBIDDEN at 10pt**
  (ink-2 on surface-2 3.74:1 light, ink-3 1.86:1 light).
- **thinkingDots decorative only**, never text (1.42:1 light / 9.47:1 dark).
- Bubble user text on bubble user fill 6.14:1 light / 8.83:1 dark — PASS.
  (Switched from the old in-code anchor #F6DDE3 / #573C43 at 7.68:1 to
  #ECC7D6 / #5B3F41; 6.14:1 is the new light ratio.)
- Bubble AI text on bubble AI fill 9.41:1 light / 13.10:1 dark — PASS.

## Bans

- No gradients (generic gradient slop), no neon, no purple-pink gradients.
  Forbidden purple: electric violet #734DED / #A385FF and `.purple` /
  `.pink` tool accents — replaced by the milk-pink accent family.
- No lorem ipsum / filler copy. No card-in-card nesting. No glass over
  content (ultraThinMaterial on chrome only, never cards). No decorative
  motion. No generic SwiftUI-tutorial layouts.
- No dead buttons, no placeholders, no "coming soon" cards.
- No flag emoji in settings. No squircle avatars (solid circle only).
- 44×44pt minimum tap target everywhere.
- Ornament line art (`Theme.Color.ornamentLine`, #ECC7D6 at ≤0.35 opacity):
  hero/profile surfaces only, stroke 0.5–1pt, always behind content, never
  under body text, never on chat rows, never on bubbles, never animated.
  One ornamental frame per surface max. If it reduces legibility it is
  deleted, not darkened.

## DO-NOT-USE

- The pre-existing blue `AccentColor` asset
  (`src/ios/Assets.xcassets/AccentColor.colorset/`) stays untouched and is
  **NOT used by `Theme.*`**. It is the Xcode global accent color name in the
  build settings, not a theme token. Do not delete it, do not recolor it,
  do not reference it from theme code.
- The seven parallel token sources upstream (`ChatColors`,
  `SelectableMarkdownTheme`, `HelperAccent`, hardcoded tool-category colors,
  triple-read `appearanceMode`, direct `UserDefaults` reads,
  `ConfigRegistry+Builtins` font fields) all collapse into ONE `Theme`
  store. Nothing from them is ported; they are replaced, one file at a time.
- No Together / PlayHub surface exists upstream. None is faked here.

## Gates

- Tokens are built, NOT yet approved by the user. No Phase 2 UI work until
  she approves the tokens.
- `.withTheme()` is defined but NOT wired into the app yet (Phase 1).
- A green CI build proves only that the code compiles — never that she has
  seen the change on her phone. A pass means she has seen it and nodded.
