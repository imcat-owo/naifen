// ShopItem — dress-up shop data model + store (greenfield, Phase 1).
//
// Upstream has NO shop, NO theme engine, NO wallpaper. This file is the
// shop's data layer: stable item IDs, the six categories, the one saved
// set, and the applied-selection store.
//
// THE ONE SET IS MILK PINK. The shop lists the milk-pink theme, its bubble
// system, avatar frame, font dial entry, namecards, and inspiration items.
// Black-pink and milk blue were rejected and are NOT built here — no item
// for either exists in this catalog.
//
// Stable IDs: every item has a prefixed stable ID (THM / BUB / PEN / WAL /
// FON / NMC / INSP / COM). IDs never change once shipped: saved sets keep
// items by ID, and the store keys are versioned (`dressUp.v1.*`), so a
// future catalog change cannot silently re-point a saved set.
//
// Saved sets are kept by ID in UserDefaults and NOTHING clears them:
// applying a theme, a bubble, a pendant, or a wallpaper writes only its
// own applied key. Changing theme NEVER clears saved sets.
//
// Honest scope: this store is the record of what the user applied. The
// milk-pink theme itself is already wired at the app root (`.withTheme()`),
// so applying THM-MILK-PINK-01 records the choice. Bubble / pendant /
// font / namecard choices are read by the shop preview today and by the
// live chat in Phase 2 (chat wiring is explicitly out of scope here).
// The wallpaper choice IS live: the shop preview and the shared
// `WallpaperBackdrop` read `appliedWallpaperId` / `WallpaperStore`.

import SwiftUI

// MARK: - Categories

/// The six shop categories (plan §A.3 #30, §B.4). Wallpaper is not a
/// seventh category: the bundled milk-pink wallpaper is an item of the
/// theme category, and a custom upload lives in `WallpaperStore`.
enum ShopCategory: String, CaseIterable, Identifiable {
    case theme
    case bubbles
    case avatarPendants
    case fonts
    case namecards
    case inspiration

    var id: String { rawValue }

    var title: String {
        switch self {
        case .theme: return "Theme"
        case .bubbles: return "Bubbles"
        case .avatarPendants: return "Avatar Pendants"
        case .fonts: return "Fonts"
        case .namecards: return "Namecards"
        case .inspiration: return "Inspiration"
        }
    }
}

// MARK: - Items

/// One shop item. `id` is stable and prefixed by kind; never rename an
/// ID once shipped — saved sets reference items by ID.
struct ShopItem: Identifiable, Equatable, Hashable {
    /// Stable prefixed ID, e.g. "THM-MILK-PINK-01".
    let id: String
    let category: ShopCategory
    let title: String
    /// One line, plain words: what this item is and where it shows.
    let detail: String
}

/// The sample sentence every bubble sample renders. The sentence never
/// changes — only the bubble does — so two bubble samples differ in
/// exactly one thing (plan §B.4).
enum ShopSampleText {
    static let bubbleSentence = "Milk pink, poured softly."
    /// The same avatar (the default sparkle) under every pendant — only
    /// the pendant changes.
    static let avatarIcon = ""
    /// The name shown on every namecard sample.
    static let namecardName = "Xiao Meng"
    /// The line shown on every namecard sample.
    static let namecardLine = "Milk pink, retro and soft."
}

/// The catalog: the ONE milk-pink set, and nothing else.
enum ShopCatalog {
    static let milkPinkTheme = ShopItem(
        id: "THM-MILK-PINK-01",
        category: .theme,
        title: "Milk Pink",
        detail: "The one theme set. Retro, Rococo and kawaii, pale and soft."
    )
    static let milkPinkWallpaper = ShopItem(
        id: "WAL-MILK-PINK-01",
        category: .theme,
        title: "Milk Pink Wallpaper",
        detail: "The bundled milk-pink wallpaper, full-bleed behind chat."
    )
    static let userBubble = ShopItem(
        id: "BUB-USER-MILK-01",
        category: .bubbles,
        title: "User Bubble",
        detail: "Milk-pink pill for your messages, same bubble as chat."
    )
    static let assistantSurface = ShopItem(
        id: "BUB-AI-MILK-01",
        category: .bubbles,
        title: "Assistant Surface",
        detail: "Porcelain surface for replies, no bubble, hairline border."
    )
    static let avatarRing = ShopItem(
        id: "PEN-AVATAR-RING-01",
        category: .avatarPendants,
        title: "Milk Ring",
        detail: "A milk-pink ring around the avatar, with a clear gap."
    )
    static let avatarFrame = ShopItem(
        id: "PEN-AVATAR-FRAME-01",
        category: .avatarPendants,
        title: "Ornament Frame",
        detail: "Thin ornamental frame around the avatar, hero only."
    )
    static let frauncesDisplay = ShopItem(
        id: "FON-DISPLAY-FRAUNCES-01",
        category: .fonts,
        title: "Fraunces Display",
        detail: "Serif display for titles, one line per screen at most."
    )
    static let fontDial = ShopItem(
        id: "FON-DIAL-01",
        category: .fonts,
        title: "One Font Dial",
        detail: "One size, 10 to 15pt, for message, input and app text."
    )
    static let porcelainNamecard = ShopItem(
        id: "NMC-PORCELAIN-01",
        category: .namecards,
        title: "Porcelain Card",
        detail: "A plain white card, hairline border, soft shadow."
    )
    static let tagPill = ShopItem(
        id: "NMC-TAG-01",
        category: .namecards,
        title: "Tag Pill",
        detail: "A small capsule pill, pale pink fill, ink text."
    )
    static let roseCluster = ShopItem(
        id: "INSP-ROSE-01",
        category: .inspiration,
        title: "Rose Cluster",
        detail: "Thin-line roses, ornament only, never under text."
    )
    static let butterfly = ShopItem(
        id: "INSP-BUTTERFLY-01",
        category: .inspiration,
        title: "Butterfly",
        detail: "A faint butterfly, ornament only, never animated."
    )
    static let archFrame = ShopItem(
        id: "INSP-ARCH-01",
        category: .inspiration,
        title: "Arch Frame",
        detail: "A thin arch frame, hero and profile surfaces only."
    )

    /// Every item in the shop, in display order.
    static let allItems: [ShopItem] = [
        milkPinkTheme, milkPinkWallpaper,
        userBubble, assistantSurface,
        avatarRing, avatarFrame,
        frauncesDisplay, fontDial,
        porcelainNamecard, tagPill,
        roseCluster, butterfly, archFrame,
    ]

    static func items(in category: ShopCategory) -> [ShopItem] {
        allItems.filter { $0.category == category }
    }

    static func item(id: String) -> ShopItem? {
        allItems.first { $0.id == id }
    }
}

// MARK: - Saved sets

/// A saved set: a bundle of item IDs kept by ID. The set stores IDs, not
/// copies, so renaming an item's title never breaks a saved set — and
/// changing the theme never clears the set, because the set lives under
/// its own key.
struct ShopSet: Identifiable, Equatable, Hashable {
    /// Stable prefixed ID, e.g. "COM-SET-MILK-PINK-01".
    let id: String
    let title: String
    /// Item IDs in the set, in apply order.
    let itemIds: [String]

    var items: [ShopItem] { itemIds.compactMap { ShopCatalog.item(id: $0) } }
}

enum ShopSets {
    /// The one set: the whole milk-pink set, as IDs.
    static let milkPinkSet = ShopSet(
        id: "COM-SET-MILK-PINK-01",
        title: "Milk Pink Set",
        itemIds: [
            ShopCatalog.milkPinkTheme.id,
            ShopCatalog.milkPinkWallpaper.id,
            ShopCatalog.userBubble.id,
            ShopCatalog.assistantSurface.id,
            ShopCatalog.avatarRing.id,
            ShopCatalog.frauncesDisplay.id,
            ShopCatalog.porcelainNamecard.id,
        ]
    )

    static let allSets: [ShopSet] = [milkPinkSet]
}

// MARK: - Store

/// The shop's applied-selection store. Own UserDefaults keys, versioned
/// (`dressUp.v1.*`), one key per slot. Each `apply` writes only its own
/// key; `savedSetIds` is written only by `saveSet` / `removeSet`, so no
/// apply path can clear a saved set.
@MainActor
final class DressUpStore: ObservableObject {
    static let shared = DressUpStore()

    private enum Keys {
        static let version = "dressUp.v1.version"
        static let appliedThemeId = "dressUp.v1.appliedThemeId"
        static let appliedUserBubbleId = "dressUp.v1.appliedUserBubbleId"
        static let appliedAssistantId = "dressUp.v1.appliedAssistantId"
        static let appliedPendantId = "dressUp.v1.appliedPendantId"
        static let appliedFontId = "dressUp.v1.appliedFontId"
        static let appliedNamecardId = "dressUp.v1.appliedNamecardId"
        /// "bundled:WallpaperMilkPink" or "custom". Read by the shop
        /// preview and by `WallpaperBackdrop` (Phase 2 chat reads it too).
        static let appliedWallpaperId = "dressUp.v1.appliedWallpaperId"
        static let savedSetIds = "dressUp.v1.savedSetIds"
    }

    /// Store schema version. Bumped only when a key meaning changes.
    static let storeVersion = 1

    @Published private(set) var appliedThemeId: String?
    @Published private(set) var appliedUserBubbleId: String?
    @Published private(set) var appliedAssistantId: String?
    @Published private(set) var appliedPendantId: String?
    @Published private(set) var appliedFontId: String?
    @Published private(set) var appliedNamecardId: String?
    @Published private(set) var appliedWallpaperId: String?
    @Published private(set) var savedSetIds: [String]

    private let defaults: UserDefaults

    init(defaults: UserDefaults = .standard) {
        self.defaults = defaults
        defaults.set(Self.storeVersion, forKey: Keys.version)
        appliedThemeId = defaults.string(forKey: Keys.appliedThemeId)
        appliedUserBubbleId = defaults.string(forKey: Keys.appliedUserBubbleId)
        appliedAssistantId = defaults.string(forKey: Keys.appliedAssistantId)
        appliedPendantId = defaults.string(forKey: Keys.appliedPendantId)
        appliedFontId = defaults.string(forKey: Keys.appliedFontId)
        appliedNamecardId = defaults.string(forKey: Keys.appliedNamecardId)
        appliedWallpaperId = defaults.string(forKey: Keys.appliedWallpaperId)
        savedSetIds = defaults.stringArray(forKey: Keys.savedSetIds) ?? []
    }

    /// The item currently applied in a category's slot, if any. One item
    /// only: categories with two slots (theme holds the theme AND the
    /// wallpaper; bubbles hold the user bubble AND the assistant
    /// surface) have no single answer here — this returns the
    /// category's primary slot (theme, user bubble) for the preview,
    /// which wants the theme. Rows must use `isApplied(_:)`, which
    /// reads each item's own slot.
    func appliedItem(in category: ShopCategory) -> ShopItem? {
        let id: String?
        switch category {
        case .theme: id = appliedThemeId
        case .bubbles: id = appliedUserBubbleId
        case .avatarPendants: id = appliedPendantId
        case .fonts: id = appliedFontId
        case .namecards: id = appliedNamecardId
        case .inspiration: id = nil
        }
        return id.flatMap { ShopCatalog.item(id: $0) }
    }

    /// Whether this exact item is the one applied in its own slot.
    /// Per-slot: each item id maps to its own stored key — theme to
    /// `appliedThemeId`, wallpaper to `appliedWallpaperId`, user bubble
    /// to `appliedUserBubbleId`, assistant surface to
    /// `appliedAssistantId`, pendant / font / namecard to their own
    /// keys. The wallpaper stores "bundled:WallpaperMilkPink", not its
    /// item id (see `apply(_:)`), so it compares against that value.
    /// Applying one slot therefore never marks a different slot's row
    /// Applied, and the assistant surface shows Applied even when the
    /// user bubble is applied too.
    func isApplied(_ item: ShopItem) -> Bool {
        switch item.id {
        case ShopCatalog.milkPinkTheme.id:
            return appliedThemeId == item.id
        case ShopCatalog.milkPinkWallpaper.id:
            return appliedWallpaperId == WallpaperStore.bundledWallpaperId
        case ShopCatalog.userBubble.id:
            return appliedUserBubbleId == item.id
        case ShopCatalog.assistantSurface.id:
            return appliedAssistantId == item.id
        case ShopCatalog.avatarRing.id, ShopCatalog.avatarFrame.id:
            return appliedPendantId == item.id
        case ShopCatalog.frauncesDisplay.id, ShopCatalog.fontDial.id:
            return appliedFontId == item.id
        case ShopCatalog.porcelainNamecard.id, ShopCatalog.tagPill.id:
            return appliedNamecardId == item.id
        default:
            // Inspiration items have no slot: nothing to apply, so
            // never Applied.
            return false
        }
    }

    /// Apply an item: writes only that item's slot key. Saved sets are
    /// untouched — changing the theme never clears them.
    func apply(_ item: ShopItem) {
        switch item.id {
        case ShopCatalog.milkPinkTheme.id:
            set(item.id, key: Keys.appliedThemeId, to: &appliedThemeId)
        case ShopCatalog.milkPinkWallpaper.id:
            set(WallpaperStore.bundledWallpaperId, key: Keys.appliedWallpaperId, to: &appliedWallpaperId)
        case ShopCatalog.userBubble.id:
            set(item.id, key: Keys.appliedUserBubbleId, to: &appliedUserBubbleId)
        case ShopCatalog.assistantSurface.id:
            set(item.id, key: Keys.appliedAssistantId, to: &appliedAssistantId)
        case ShopCatalog.avatarRing.id, ShopCatalog.avatarFrame.id:
            set(item.id, key: Keys.appliedPendantId, to: &appliedPendantId)
        case ShopCatalog.frauncesDisplay.id, ShopCatalog.fontDial.id:
            set(item.id, key: Keys.appliedFontId, to: &appliedFontId)
        case ShopCatalog.porcelainNamecard.id, ShopCatalog.tagPill.id:
            set(item.id, key: Keys.appliedNamecardId, to: &appliedNamecardId)
        default:
            // Inspiration items are ornament only: nothing to apply to
            // the live UI, so there is no slot for them. Trying one still
            // shows it in the preview; applying is a no-op by design.
            break
        }
    }

    /// Apply a whole saved set, item by item. Saved sets are untouched.
    func applySet(_ set: ShopSet) {
        for item in set.items { apply(item) }
    }

    /// Save a set by ID. The theme slot is never touched here.
    func saveSet(_ set: ShopSet) {
        guard !savedSetIds.contains(set.id) else { return }
        savedSetIds.append(set.id)
        defaults.set(savedSetIds, forKey: Keys.savedSetIds)
    }

    func removeSet(_ set: ShopSet) {
        savedSetIds.removeAll { $0 == set.id }
        defaults.set(savedSetIds, forKey: Keys.savedSetIds)
    }

    func isSaved(_ set: ShopSet) -> Bool {
        savedSetIds.contains(set.id)
    }

    /// The saved sets, resolved to `ShopSet` values.
    var savedSets: [ShopSet] {
        savedSetIds.compactMap { id in ShopSets.allSets.first { $0.id == id } }
    }

    private func set(_ value: String, key: String, to published: inout String?) {
        defaults.set(value, forKey: key)
        published = value
    }
}
