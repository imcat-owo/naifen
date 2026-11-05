// DressUpShopView — the dress-up shop screen (greenfield, Phase 1).
//
// Upstream has NO shop. This is the shop: one milk-pink set, six
// categories, real sample cards, try-then-apply, saved sets, and the
// wallpaper picker + full-screen preview.
//
// TRY / APPLY FLOW: tap a sample card to try it on — the preview at the
// top swaps to that item on the try-on spring (interruptible; a new tap
// retargets mid-flight). Nothing is applied by tapping. Confirm with
// the Apply button under the preview (success feedback); Cancel clears
// the try-on. Every row is live: no dead buttons, no placeholders.
// All tap targets are at least the 44pt HIG minimum.
//
// SHEETS: the wallpaper full-screen preview uses the native sheet
// (`.dressUpSheet`, system drag contract). The custom modal sheet
// (`.dressUpModalSheet`) is not needed here — the native sheet is
// enough — so it is not attached anywhere on this screen.
//
// SIGNATURE MOTION: this screen's one signature is the try-on swap
// (`.tryOnSwap`). Everything else stays quiet.
//
// WALLPAPER PREVIEW: the inline wallpaper tile is only a picker tile.
// The full-bleed proof is the full-screen preview sheet, where
// `WallpaperBackdrop` is the bottom ZStack layer with its own
// `.ignoresSafeArea()` — full-bleed incl. the bottom safe area and
// under the translucent tab bar, with the blur-stretch fallback and
// the legibility scrim. The backdrop is NOT wired into the live chat
// here (Phase 2).
//
// ORNAMENT: RibbonBow appears in ONE place only — the hero. Ornament
// line art is hero/profile only, never under body text, never on chat
// rows or bubbles, never animated.

import SwiftUI
import PhotosUI

struct DressUpShopView: View {
    /// HIG minimum tap target (Apple HIG, plan §C). Not a Theme token:
    /// it is the platform minimum, applied to every tappable row here.
    private static let minTapTarget: CGFloat = 44

    @ObservedObject private var store = DressUpStore.shared
    @ObservedObject private var wallpaperStore = WallpaperStore.shared

    /// The item currently tried on (not yet applied). Nil = preview
    /// shows the applied theme item.
    @State private var triedItem: ShopItem?
    /// Which wallpaper the preview sheet shows.
    @State private var previewWallpaper: PreviewWallpaper = .bundled
    /// Full-screen wallpaper preview sheet.
    @State private var showWallpaperPreview = false
    /// Photo picker for a custom wallpaper upload.
    @State private var showPhotoPicker = false
    @State private var photoItem: PhotosPickerItem?
    /// The stored custom wallpaper, loaded on appear and after upload.
    @State private var customWallpaperImage: UIImage?
    /// Upload failure, in plain ink text (no pure `.red` anywhere).
    @State private var wallpaperError: String?

    private enum PreviewWallpaper {
        case bundled
        case custom(UIImage)
    }

    /// The item the preview shows: the tried item, else the applied
    /// theme item, else the milk-pink theme itself.
    private var previewItem: ShopItem {
        triedItem
            ?? store.appliedItem(in: .theme)
            ?? ShopCatalog.milkPinkTheme
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: Theme.Spacing.xxl) {
                hero
                tryOnPreview
                wallpaperSection
                ForEach(ShopCategory.allCases) { category in
                    categorySection(category)
                }
                savedSetsSection
            }
            .padding(.horizontal, Theme.Spacing.lg)
            .padding(.vertical, Theme.Spacing.xl)
        }
        .background(Theme.Color.background)
        .navigationTitle("Dress Up")
        .navigationBarTitleDisplayMode(.inline)
        .dressUpSignature(.tryOnSwap)
        .dressUpSheet(isPresented: $showWallpaperPreview) {
            wallpaperPreviewSheet
        }
        .photosPicker(
            isPresented: $showPhotoPicker,
            selection: $photoItem,
            matching: .images,
            photoLibrary: .shared()
        )
        .onChange(of: photoItem) { newItem in
            guard let newItem else { return }
            Task { await applyPickedWallpaper(newItem) }
        }
        .onAppear {
            customWallpaperImage = wallpaperStore.loadCustomWallpaper()
        }
    }

    // MARK: - Hero (RibbonBow lives here, and nowhere else)

    private var hero: some View {
        VStack(alignment: .center, spacing: Theme.Spacing.md) {
            Image("RibbonBow")
                .resizable()
                .aspectRatio(contentMode: .fit)
                .frame(height: Theme.Spacing.massive + Theme.Spacing.xxl)
                .accessibilityHidden(true)
            Text("Milk Pink")
                .font(Theme.Font.displayLarge())
                .foregroundStyle(Theme.Color.ink)
            Text("The one set. Retro, Rococo and kawaii, pale and soft.")
                .font(Theme.Font.body())
                .foregroundStyle(Theme.Color.ink)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Try-on preview + Apply / Cancel

    private var tryOnPreview: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Preview")
                .font(Theme.Font.bodyEmphasized())
                .foregroundStyle(Theme.Color.ink)
            DressUpTryOnPreview(selection: previewItem.id) { _ in
                ShopSampleCards.sample(for: previewItem)
            }
            // Fixed frame: the swap container must not resize mid-flight
            // as the incoming and outgoing previews differ in size.
            .frame(height: Theme.Spacing.massive + Theme.Spacing.huge * 3)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
            if let tried = triedItem {
                HStack(spacing: Theme.Spacing.md) {
                    Button {
                        applyItem(tried)
                    } label: {
                        Text("Apply \(tried.title)")
                            .font(Theme.Font.bodyEmphasized())
                            .foregroundStyle(Theme.Color.ink)
                            .frame(maxWidth: .infinity, minHeight: Self.minTapTarget)
                            .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                    }
                    .dressUpPress(feedback: .success)
                    Button {
                        triedItem = nil
                    } label: {
                        Text("Cancel")
                            .font(Theme.Font.body())
                            .foregroundStyle(Theme.Color.ink)
                            .frame(minHeight: Self.minTapTarget)
                            .padding(.horizontal, Theme.Spacing.lg)
                    }
                    .dressUpPress(feedback: .selection)
                }
            }
        }
    }

    // MARK: - Wallpaper

    private var wallpaperSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Wallpaper")
                .font(Theme.Font.bodyEmphasized())
                .foregroundStyle(Theme.Color.ink)
            if let custom = customWallpaperImage {
                Image(uiImage: custom)
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
            } else {
                ShopWallpaperSample()
            }
            if let error = wallpaperError {
                Text(error)
                    .font(Theme.Font.body())
                    .foregroundStyle(Theme.Color.ink)
            }
            HStack(spacing: Theme.Spacing.md) {
                Button {
                    previewWallpaper = customWallpaperImage.map { .custom($0) } ?? .bundled
                    showWallpaperPreview = true
                } label: {
                    Text("Preview Full Screen")
                        .font(Theme.Font.bodyEmphasized())
                        .foregroundStyle(Theme.Color.ink)
                        .frame(maxWidth: .infinity, minHeight: Self.minTapTarget)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
                .dressUpPress(feedback: .selection)
                Button {
                    showPhotoPicker = true
                } label: {
                    Text("Choose Photo")
                        .font(Theme.Font.body())
                        .foregroundStyle(Theme.Color.ink)
                        .frame(minHeight: Self.minTapTarget)
                        .padding(.horizontal, Theme.Spacing.lg)
                        .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
                .dressUpPress(feedback: .selection)
            }
            if wallpaperStore.hasCustomWallpaper {
                Button {
                    wallpaperStore.removeCustomWallpaper()
                    customWallpaperImage = nil
                    previewWallpaper = .bundled
                } label: {
                    Text("Remove My Wallpaper")
                        .font(Theme.Font.body())
                        .foregroundStyle(Theme.Color.ink)
                        .frame(maxWidth: .infinity, minHeight: Self.minTapTarget)
                }
                .dressUpPress(feedback: .selection)
            }
        }
    }

    /// Full-screen wallpaper preview: the backdrop as the bottom ZStack
    /// layer, full-bleed, with sample chat rows on top of the scrim.
    /// This is the full-bleed proof — the inline tile above is not.
    private var wallpaperPreviewSheet: some View {
        ZStack {
            switch previewWallpaper {
            case .bundled:
                WallpaperBackdrop(assetName: "WallpaperMilkPink")
            case .custom(let image):
                WallpaperBackdrop(image: image, undersized: WallpaperStore.isUndersized(image))
            }
            VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                HStack(spacing: Theme.Spacing.md) {
                    ShopAvatarSample(pendant: .ring)
                    Text("Xiao Meng")
                        .font(Theme.Font.bodyEmphasized())
                        .foregroundStyle(Theme.Color.ink)
                }
                ShopUserBubbleSample()
                ShopAssistantSample()
                Spacer()
                Button {
                    showWallpaperPreview = false
                } label: {
                    Text("Close Preview")
                        .font(Theme.Font.bodyEmphasized())
                        .foregroundStyle(Theme.Color.ink)
                        .frame(maxWidth: .infinity, minHeight: Self.minTapTarget)
                        .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                }
                .dressUpPress(feedback: .selection)
            }
            .padding(Theme.Spacing.lg)
        }
    }

    // MARK: - Categories

    private func categorySection(_ category: ShopCategory) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text(category.title)
                .font(Theme.Font.bodyEmphasized())
                .foregroundStyle(Theme.Color.ink)
            ForEach(ShopCatalog.items(in: category)) { item in
                shopItemRow(item)
            }
        }
    }

    private func shopItemRow(_ item: ShopItem) -> some View {
        Button {
            triedItem = item
        } label: {
            VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                ShopSampleCards.sample(for: item)
                HStack(spacing: Theme.Spacing.sm) {
                    Text(item.title)
                        .font(Theme.Font.bodyEmphasized())
                        .foregroundStyle(Theme.Color.ink)
                    if store.isApplied(item) {
                        ShopTagPill(label: "Applied")
                    } else if triedItem?.id == item.id {
                        ShopTagPill(label: "Trying")
                    }
                    Spacer()
                }
                Text(item.detail)
                    .font(Theme.Font.body())
                    .foregroundStyle(Theme.Color.ink)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(Theme.Spacing.lg)
            .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
            .overlay(
                RoundedRectangle(cornerRadius: Theme.Radius.card)
                    .stroke(Theme.Color.line, lineWidth: 1)
            )
        }
        .dressUpPress(feedback: .selection)
        .frame(maxWidth: .infinity, minHeight: Self.minTapTarget)
    }

    // MARK: - Saved sets

    private var savedSetsSection: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.md) {
            Text("Saved Sets")
                .font(Theme.Font.bodyEmphasized())
                .foregroundStyle(Theme.Color.ink)
            ForEach(ShopSets.allSets) { set in
                VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
                    Text(set.title)
                        .font(Theme.Font.bodyEmphasized())
                        .foregroundStyle(Theme.Color.ink)
                    Text("\(set.items.count) items, kept by ID. Changing the theme never clears a saved set.")
                        .font(Theme.Font.body())
                        .foregroundStyle(Theme.Color.ink)
                    HStack(spacing: Theme.Spacing.md) {
                        Button {
                            store.applySet(set)
                        } label: {
                            Text("Apply Set")
                                .font(Theme.Font.bodyEmphasized())
                                .foregroundStyle(Theme.Color.ink)
                                .frame(maxWidth: .infinity, minHeight: Self.minTapTarget)
                                .background(Theme.Color.surface2, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        }
                        .dressUpPress(feedback: .success)
                        Button {
                            if store.isSaved(set) {
                                store.removeSet(set)
                            } else {
                                store.saveSet(set)
                            }
                        } label: {
                            Text(store.isSaved(set) ? "Saved" : "Save Set")
                                .font(Theme.Font.body())
                                .foregroundStyle(Theme.Color.ink)
                                .frame(minHeight: Self.minTapTarget)
                                .padding(.horizontal, Theme.Spacing.lg)
                                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                        }
                        .dressUpPress(feedback: .selection)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(Theme.Spacing.lg)
                .background(Theme.Color.surface, in: RoundedRectangle(cornerRadius: Theme.Radius.card))
                .overlay(
                    RoundedRectangle(cornerRadius: Theme.Radius.card)
                        .stroke(Theme.Color.line, lineWidth: 1)
                )
            }
        }
    }

    // MARK: - Actions

    /// Confirm a try-on: record the choice in the store, then clear the
    /// try-on. Applying never touches saved sets.
    private func applyItem(_ item: ShopItem) {
        store.apply(item)
        if item.id == ShopCatalog.fontDial.id {
            // The dial entry's live action: back to the 13pt default.
            FontSettings.shared.bodySize = FontSettings.defaultBodySize
        }
        if item.id == ShopCatalog.milkPinkWallpaper.id {
            previewWallpaper = .bundled
        }
        triedItem = nil
    }

    /// Load a picked photo, store it as the custom wallpaper
    /// (square center-crop + downsample in the store), and try it on.
    private func applyPickedWallpaper(_ item: PhotosPickerItem) async {
        defer { photoItem = nil }
        guard let data = try? await item.loadTransferable(type: Data.self),
              let image = UIImage(data: data) else {
            await MainActor.run {
                wallpaperError = "That image couldn't be read."
            }
            return
        }
        await MainActor.run {
            if wallpaperStore.saveCustomWallpaper(image) {
                customWallpaperImage = wallpaperStore.loadCustomWallpaper()
                previewWallpaper = customWallpaperImage.map { .custom($0) } ?? .bundled
                wallpaperError = nil
            } else {
                wallpaperError = "That image couldn't be saved."
            }
        }
    }
}
