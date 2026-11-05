// HomeWallpaperBackground — home-list wallpaper wiring (Phase 3).
//
// Upstream has NO home wallpaper (0 hits): this is new construction, not
// a restyle. It reuses the shared `WallpaperBackdrop` (Phase 1 Block 8,
// `WallpaperStore.swift`) and the same DressUpStore wallpaper slot the
// live chat reads (`AIChatView.chatWallpaperBackdrop`), so shop choice
// and home agree by construction: bundled `WallpaperMilkPink` by
// default (nil id = never chose), `custom` for the user's upload.
//
// PLACEMENT CONTRACT (same as the chat screen): `WallpaperBackdrop` is
// the bottom layer of a ZStack, never `.background()` of a small view —
// a background sizes to its host and cannot go full-bleed on its own.
// The backdrop ignores the safe area itself, so it runs full-bleed
// incl. the bottom safe area and under the bottom safeAreaInset
// (fabRow / selectionToolbar), which sit in the top ZStack layer above
// it. Never white margins: the backdrop's own base is the scheme
// background, and its blur-stretch fallback + scrim (scheme background
// gradient 85% top -> 60% bottom) come from the component itself —
// nothing is rebuilt here.
//
// LIST TRANSPARENCY: `.homeWallpaperBackground()` also hides the
// scroll content background, so the wallpaper shows through the
// list's empty areas, section gaps and the empty state. That modifier
// propagates through the environment to the descendant List; if a
// runtime check ever shows it not taking, add
// `.scrollContentBackground(.hidden)` directly on the List chain
// instead (same call, one line, in SessionList.swift).
//
// ADOPTION — done in Phase 3 W-A merge f28d866 (one line per list):
//   - stack (iPhone): `ContentView+SessionList.swift:326`, added
//     `.homeWallpaperBackground()` right after
//     `.toolbar { sidebarToolbarContent }`, before the closing `)`.
//   - split (iPad): `ContentView+SessionList.swift:430`, same modifier
//     right after `.toolbar { sidebarToolbarContent }`.
// Both lists already host the empty state as an `.overlay`, so the
// restyled empty state sits over the wallpaper + scrim with no change.
//
// OPEN (not in this file — row backgrounds live elsewhere): the
// iPhone stack rows paint an opaque `Color(.systemBackground)`
// (`SessionListRows.swift:84-89`), so until that file goes clear the
// wallpaper shows through the list background and gaps but NOT behind
// non-folder iPhone rows. Split rows are already clear
// (`SessionListRows.swift:154-171`) and folder rows keep their opaque
// sampled-glass card (`FolderMemberRowBackground`, user-chosen) by
// design. Legibility holds either way: ink text on the scrim-backed
// wallpaper is 8.74:1 light / 15.11:1 dark, and opaque rows are
// unchanged.

import SwiftUI
import UIKit

/// The home screen's wallpaper: the applied DressUpStore slot rendered
/// through the shared `WallpaperBackdrop`. Mirrors
/// `AIChatView.chatWallpaperBackdrop` exactly (same slot, same
/// fallback): bundled by default, custom upload when the slot says
/// `custom`, bundled again when a custom file is missing — never a
/// blank screen.
struct HomeWallpaperBackground: View {
    @ObservedObject private var dressUpStore = DressUpStore.shared
    @State private var customWallpaper: UIImage?

    var body: some View {
        Group {
            if dressUpStore.appliedWallpaperId == WallpaperStore.customWallpaperId,
               let image = customWallpaper {
                WallpaperBackdrop(image: image, undersized: WallpaperStore.isUndersized(image))
            } else {
                // Default (never chose) and bundled id both show the
                // bundled milk-pink wallpaper. A custom id with a
                // missing/unreadable file also falls back here.
                WallpaperBackdrop(assetName: "WallpaperMilkPink")
            }
        }
        .onAppear { refreshHomeWallpaper() }
        .onChange(of: dressUpStore.appliedWallpaperId) { _ in refreshHomeWallpaper() }
    }

    /// (Re)load the custom wallpaper image from disk into
    /// `customWallpaper`, once per apply — not per body pass.
    /// Called on appear and whenever the dress-up slot changes.
    private func refreshHomeWallpaper() {
        if dressUpStore.appliedWallpaperId == WallpaperStore.customWallpaperId {
            customWallpaper = WallpaperStore.shared.loadCustomWallpaper()
        } else {
            customWallpaper = nil
        }
    }
}

extension View {
    /// Wrap a home list with its wallpaper: the backdrop as the bottom
    /// ZStack layer (full-bleed, see the placement contract above) and
    /// the list's scroll content background hidden so the wallpaper
    /// shows through. One-line adoption — see the file header for the
    /// exact call sites in `ContentView+SessionList.swift`.
    func homeWallpaperBackground() -> some View {
        ZStack {
            HomeWallpaperBackground()
            self.scrollContentBackground(.hidden)
        }
    }
}
