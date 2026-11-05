// ShopSampleCards — the dress-up shop's sample cards (Phase 1).
//
// These cards render REAL components, not mocks. The rule for every card:
// the same sentence for every bubble sample, the same avatar for every
// pendant, only the sampled thing changes (plan §B.4). Preview equals
// real chat by construction wherever the shared component could be
// reused; where it could not, the reason is written on the card.
//
// REUSE RECORD (read before changing any card):
// - User bubble: `UserBubbleSurface` in ChatMessageViews.swift is
//   `private`, so it cannot be reused as-is. `ShopUserBubbleSurface`
//   below duplicates its branches exactly (Liquid Glass on iOS 26+,
//   `Theme.Color.bubbleUser` fill otherwise; queued state is not
//   sampled), with the same H14/V10 padding, the same
//   `FontSettings.shared.scaled(16.5)` text size, the same ink text,
//   and the same 18pt radius. If the chat bubble changes, this card
//   must change with it — that is the cost of the private original.
// - Assistant: the real assistant text is `SelectableMarkdownView`, a
//   UIViewRepresentable bound to a message model — it cannot render a
//   static sample string. The card uses the same tokens instead
//   (`bubbleAI` fill, `bubbleAIBorder` hairline, ink text, 16pt
//   Porcelain radius, card shadow) with plain `Text` at the same size
//   the live row uses (`.system(size: FontSettings.shared.scaled(16.5))`,
//   as in `ChatMessageViews` — NOT `Theme.Font.body()` at 13pt).
// - Avatar: `SoulIconView` IS shared — the card uses the same renderer
//   the chat header uses, with the same default icon. The pendant is an
//   overlay only; the renderer itself is untouched. Note the renderer
//   still clips to a squircle today (plan §A #9); the circle avatar is
//   Phase 2 chat work, not this shop.
// - Fonts: `Theme.Font` directly — the same API the app uses.
// - Namecard: the Porcelain Card is a surface spec (plain white surface,
//   16pt radius, hairline border, soft shadow — plan §B.5), built here
//   from the same tokens, not a picture of a card.

import SwiftUI

// MARK: - User bubble sample (shared rendering, duplicated — see header)

/// The chat's user-bubble surface, duplicated because the original
/// (`UserBubbleSurface`, ChatMessageViews.swift) is private. Same
/// branches, same radius, same fill token. Queued state is not sampled:
/// every shop sample is a sent message.
private struct ShopUserBubbleSurface: ViewModifier {
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.user)
    }

    func body(content: Content) -> some View {
        if #available(iOS 26.0, *) {
            content.glassEffect(.regular, in: shape)
        } else {
            content.background(shape.fill(Theme.Color.bubbleUser))
        }
    }
}

/// A user bubble sample: the same sentence every time, only the bubble
/// changes. Text size, padding, fill and radius match the live chat row
/// (`ChatMessageViews.userRow`: 16.5pt scaled, H14/V10, radius 18).
struct ShopUserBubbleSample: View {
    var body: some View {
        HStack {
            Spacer(minLength: Theme.Spacing.massive)
            Text(ShopSampleText.bubbleSentence)
                .font(.system(size: FontSettings.shared.scaled(16.5)))
                .foregroundStyle(Theme.Color.bubbleUserText)
                .padding(.horizontal, Theme.Spacing.md + 2)
                .padding(.vertical, Theme.Spacing.sm + 2)
                .modifier(ShopUserBubbleSurface())
        }
    }
}

/// An assistant sample: bubble-less text on the porcelain surface, the
/// same tokens the live assistant surface uses. Plain `Text` because
/// `SelectableMarkdownView` cannot render a static sample (see header).
/// Text size matches the live assistant row: 16.5pt scaled, the same
/// expression `ChatMessageViews` uses.
struct ShopAssistantSample: View {
    var body: some View {
        HStack {
            Text(ShopSampleText.bubbleSentence)
                .font(.system(size: FontSettings.shared.scaled(16.5)))
                .foregroundStyle(Theme.Color.bubbleAIText)
                .padding(.horizontal, Theme.Spacing.lg)
                .padding(.vertical, Theme.Spacing.md)
                .background(Theme.Color.bubbleAI, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(Theme.Color.bubbleAIBorder, lineWidth: 1)
                )
                .themeShadow(Theme.Shadow.card)
            Spacer(minLength: Theme.Spacing.massive)
        }
    }
}

// MARK: - Avatar samples (shared SoulIconView + pendant overlay)

/// An avatar sample: the same `SoulIconView` the chat header renders,
/// with the same default icon, at the 40pt profile-header size. Only the
/// pendant overlay changes between items.
struct ShopAvatarSample: View {
    /// The pendant to show: `.ring`, `.frame`, or `.none`.
    var pendant: ShopPendant

    enum ShopPendant {
        case none
        case ring
        case frame
    }

    /// Avatar size: the 40pt profile-header size (plan §B.4).
    private static let avatarSize: CGFloat = 40
    /// Ring: 2pt ring + 2pt clear gap on each side (plan §B.1).
    private static let ringFrameSize: CGFloat = 48

    var body: some View {
        ZStack {
            // Same renderer the chat header uses, same default-icon path
            // (sparkle glyph). The gradient is the renderer's own
            // sparkle path, recoloured to theme tokens: the header's
            // beige-grey gradient is the old default, not this set.
            SoulIconView(
                icon: ShopSampleText.avatarIcon,
                size: Self.avatarSize,
                sparkleGradient: LinearGradient(
                    colors: [Theme.Color.avatarBackground, Theme.Color.bubbleUser],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            )
            switch pendant {
            case .none:
                EmptyView()
            case .ring:
                // No extra overlay: SoulIconView already draws its own
                // milk-pink ring (2pt + 2pt gap), so a second ring here
                // drew a double band over it. The renderer ring IS the
                // ring pendant now.
                EmptyView()
            case .frame:
                Image("AvatarFrame")
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(width: Self.ringFrameSize, height: Self.ringFrameSize)
            }
        }
        .frame(width: Self.ringFrameSize, height: Self.ringFrameSize)
    }
}

// MARK: - Font samples (Theme.Font directly)

/// A font sample: display, body and mono, all through `Theme.Font` —
/// the same API the app uses. Display is one line, as the rule requires.
struct ShopFontSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text("Milk Pink")
                .font(Theme.Font.displayMedium())
                .foregroundStyle(Theme.Color.ink)
            Text(ShopSampleText.bubbleSentence)
                .font(Theme.Font.body())
                .foregroundStyle(Theme.Color.ink)
            Text("13 pt body  ·  10–15 pt dial")
                .font(Theme.Font.mono())
                .foregroundStyle(Theme.Color.ink)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

// MARK: - Namecard samples (Porcelain Card surface spec)

/// A tag pill: capsule, pale pink fill, ink text (8.00:1 light /
/// 11.16:1 dark — the locked capsule pairing). Visual stays small;
/// the tappable hit area is the shop card's 44pt row, not the pill.
struct ShopTagPill: View {
    let label: String

    var body: some View {
        Text(label)
            .font(Theme.Font.caption())
            .foregroundStyle(Theme.Color.ink)
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, Theme.Spacing.xs + 2)
            .background(Theme.Color.surface2, in: Capsule())
    }
}

/// A namecard sample: the Porcelain Card — plain white surface, 16pt
/// radius, hairline border, soft shadow — with the same name and line
/// on every namecard. No second competing card style exists.
struct ShopNamecardSample: View {
    var body: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            Text(ShopSampleText.namecardName)
                .font(Theme.Font.displaySmall())
                .foregroundStyle(Theme.Color.ink)
            Text(ShopSampleText.namecardLine)
                .font(Theme.Font.body())
                .foregroundStyle(Theme.Color.ink)
            ShopTagPill(label: "Milk Pink")
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(Theme.Spacing.lg)
        .background(Theme.Color.bubbleAI, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .stroke(Theme.Color.line, lineWidth: 1)
        )
        .themeShadow(Theme.Shadow.card)
    }
}

// MARK: - Inspiration + wallpaper samples (ornament image assets)

/// An inspiration sample: one ornamental line-art asset, on its own.
/// Ornament is decorative only — never under body text, never animated.
/// Which asset a given item shows is fixed in `ShopSampleCards.sample`.
struct ShopInspirationSample: View {
    let assetName: String

    var body: some View {
        Image(assetName)
            .resizable()
            .aspectRatio(contentMode: .fit)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.massive + Theme.Spacing.xxl)
    }
}

/// A wallpaper sample: the bundled milk-pink wallpaper asset, scaled
/// to fill the tile and cropped to its frame (`.fill` + `.clipped()`).
/// The full-bleed proof (blur-stretch fallback, scrim, safe area) lives
/// in `WallpaperBackdrop`, used by the shop's wallpaper preview — this
/// thumb is only the picker tile.
struct ShopWallpaperSample: View {
    var body: some View {
        Image("WallpaperMilkPink")
            .resizable()
            .aspectRatio(contentMode: .fill)
            .frame(maxWidth: .infinity)
            .frame(height: Theme.Spacing.massive + Theme.Spacing.huge)
            .clipped()
            .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
    }
}

// MARK: - Card dispatch

/// Renders the right sample card for an item. One place decides the
/// mapping, so a category can never show the wrong card.
enum ShopSampleCards {
    @ViewBuilder
    static func sample(for item: ShopItem) -> some View {
        switch item.id {
        case ShopCatalog.userBubble.id:
            ShopUserBubbleSample()
        case ShopCatalog.assistantSurface.id:
            ShopAssistantSample()
        case ShopCatalog.avatarRing.id:
            HStack {
                ShopAvatarSample(pendant: .ring)
                Spacer()
            }
        case ShopCatalog.avatarFrame.id:
            HStack {
                ShopAvatarSample(pendant: .frame)
                Spacer()
            }
        case ShopCatalog.frauncesDisplay.id, ShopCatalog.fontDial.id:
            ShopFontSample()
        case ShopCatalog.porcelainNamecard.id:
            ShopNamecardSample()
        case ShopCatalog.tagPill.id:
            HStack {
                ShopTagPill(label: "Milk Pink")
                Spacer()
            }
        case ShopCatalog.roseCluster.id:
            ShopInspirationSample(assetName: "RoseClusterSmall")
        case ShopCatalog.butterfly.id:
            ShopInspirationSample(assetName: "ButterflyFaint")
        case ShopCatalog.archFrame.id:
            ShopInspirationSample(assetName: "ArchFrame")
        case ShopCatalog.milkPinkWallpaper.id:
            ShopWallpaperSample()
        default:
            // Theme item: the set's own mark — a porcelain card with the
            // display title. No invented swatch grid: the old lying
            // preview (5 swatches, no bubbles/text/wallpaper/avatar) is
            // not rebuilt here.
            ShopNamecardSample()
        }
    }
}
