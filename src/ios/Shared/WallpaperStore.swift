// WallpaperStore — custom wallpaper storage + WallpaperBackdrop (Phase 1).
//
// Upstream has NO wallpaper feature at all (0 hits for `wallpaper` in
// src/ios). This file builds it new, WITH the blur-stretch fallback the
// plan requires (plan §A.3 #29, §B.4).
//
// STORAGE: one JPEG in the app-support folder
// (`Application Support/Wallpaper/wallpaper.jpg`), square center-cropped
// on upload and downsampled to at most 2048px on its long side, JPEG
// quality 0.85. One file, one custom wallpaper: a new upload replaces
// the old one. The bundled milk-pink wallpaper is an asset-catalog
// image (`WallpaperMilkPink`), not a stored file — it needs no storage.
//
// RENDERING (`WallpaperBackdrop`, the shared component later chat use
// reads in Phase 2 — do NOT wire it into AIChatView here):
// - Full-bleed: place as the bottom layer of a ZStack with
//   `.ignoresSafeArea()` (the view ignores the safe area itself), so it
//   runs under the translucent tab bar and into the bottom safe area.
//   Never white margins: the base layer is the scheme background.
// - Blur-stretch fallback for undersized images (min pixel dimension
//   under 1080): a blurred, stretched copy of the SAME image at 120%
//   scale underneath, the sharp original centered on top at native
//   aspect (contain — never cropped, never distorted).
// - Legibility scrim: scheme background gradient, 85% at the top to
//   60% at the bottom, between the wallpaper and the content.
//
// PLACEMENT CONTRACT: put `WallpaperBackdrop` as the bottom ZStack layer
// of the screen, not as `.background()` of a small view — a background
// sizes to its host and cannot go full-bleed on its own.

import SwiftUI
import UIKit

// MARK: - Store

/// Stores the user's one custom wallpaper. The bundled wallpaper needs
/// no store: it is the `WallpaperMilkPink` asset, selected by ID in
/// `DressUpStore` (`appliedWallpaperId == "bundled:WallpaperMilkPink"`).
@MainActor
final class WallpaperStore: ObservableObject {
    static let shared = WallpaperStore()

    /// ID used in `DressUpStore.appliedWallpaperId` for a custom upload.
    static let customWallpaperId = "custom"
    /// ID used in `DressUpStore.appliedWallpaperId` for the bundled image.
    static let bundledWallpaperId = "bundled:WallpaperMilkPink"

    /// Longest stored side, in pixels. Uploads larger than this are
    /// downsampled; smaller uploads are kept as-is (and rendered with
    /// the blur-stretch fallback when undersized).
    static let maxStoredDimension: CGFloat = 2048
    /// An image whose shorter pixel side is under this is undersized and
    /// gets the blur-stretch fallback instead of stretching the sharp
    /// original (plan §B.4).
    static let minFullDimension: CGFloat = 1080
    /// JPEG quality for the stored file.
    private static let jpegQuality: CGFloat = 0.85

    @Published private(set) var hasCustomWallpaper: Bool

    private let fileManager: FileManager

    init(fileManager: FileManager = .default) {
        self.fileManager = fileManager
        hasCustomWallpaper = Self.storedFileURL(fileManager: fileManager)
            .map { fileManager.fileExists(atPath: $0.path) } ?? false
    }

    /// The stored file, if one exists.
    func loadCustomWallpaper() -> UIImage? {
        guard let url = Self.storedFileURL(fileManager: fileManager),
              let data = try? Data(contentsOf: url) else { return nil }
        return UIImage(data: data)
    }

    /// Square center-crop, downsample, store as JPEG. Replaces any
    /// previous custom wallpaper. Returns false when the image could
    /// not be read or written.
    @discardableResult
    func saveCustomWallpaper(_ image: UIImage) -> Bool {
        guard let url = Self.storedFileURL(fileManager: fileManager) else { return false }
        let cropped = Self.centerCroppedSquare(image)
        let sized = Self.downsampled(cropped)
        guard let data = sized.jpegData(compressionQuality: Self.jpegQuality) else { return false }
        do {
            try fileManager.createDirectory(
                at: url.deletingLastPathComponent(),
                withIntermediateDirectories: true
            )
            try data.write(to: url, options: .atomic)
            hasCustomWallpaper = true
            return true
        } catch {
            return false
        }
    }

    /// Delete the stored custom wallpaper, if any.
    func removeCustomWallpaper() {
        guard let url = Self.storedFileURL(fileManager: fileManager) else { return }
        try? fileManager.removeItem(at: url)
        hasCustomWallpaper = false
    }

    /// True when the image's shorter pixel side is under the full-size
    /// threshold — the blur-stretch fallback applies.
    static func isUndersized(_ image: UIImage) -> Bool {
        let size = image.size
        let scale = image.scale
        return min(size.width, size.height) * scale < minFullDimension
    }

    // MARK: - Image prep

    /// Square center-crop: the largest centered square, no distortion.
    static func centerCroppedSquare(_ image: UIImage) -> UIImage {
        let side = min(image.size.width, image.size.height)
        guard side > 0 else { return image }
        let origin = CGPoint(
            x: (image.size.width - side) / 2,
            y: (image.size.height - side) / 2
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = image.scale
        format.opaque = true
        return UIGraphicsImageRenderer(size: CGSize(width: side, height: side), format: format)
            .image { _ in
                image.draw(at: CGPoint(x: -origin.x, y: -origin.y))
            }
    }

    /// Downsample so the longest side is at most `maxStoredDimension`.
    /// Smaller images pass through untouched.
    static func downsampled(_ image: UIImage) -> UIImage {
        let longest = max(image.size.width, image.size.height)
        guard longest > maxStoredDimension else { return image }
        let scale = maxStoredDimension / longest
        let target = CGSize(
            width: image.size.width * scale,
            height: image.size.height * scale
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true
        return UIGraphicsImageRenderer(size: target, format: format)
            .image { _ in
                image.draw(in: CGRect(origin: .zero, size: target))
            }
    }

    // MARK: - Paths

    private static func storedFileURL(fileManager: FileManager) -> URL? {
        fileManager
            .urls(for: .applicationSupportDirectory, in: .userDomainMask).first?
            .appendingPathComponent("Wallpaper", isDirectory: true)
            .appendingPathComponent("wallpaper.jpg", isDirectory: false)
    }
}

// MARK: - Shared backdrop

/// The shared wallpaper backdrop. Built for the shop preview now; the
/// live chat reads it in Phase 2 (do NOT wire it into AIChatView here).
/// Full-bleed incl. the bottom safe area and under the translucent tab
/// bar, never white margins — see the placement contract in the file
/// header.
struct WallpaperBackdrop: View {
    /// Stretched fallback copy scale: ~120% (plan §B.4).
    private static let fallbackScale: CGFloat = 1.2
    /// Fallback blur radius, in points.
    private static let fallbackBlur: CGFloat = Theme.Spacing.xxl

    private enum Source {
        case bundled(String)
        case custom(UIImage)
    }

    private let source: Source
    /// True when the image is undersized: the blurred stretched copy
    /// shows underneath. Bundled wallpaper is full-size, so false.
    private let undersized: Bool

    /// Bundled wallpaper by asset name (e.g. "WallpaperMilkPink").
    /// Full-size by construction: no fallback layer.
    init(assetName: String) {
        source = .bundled(assetName)
        undersized = false
    }

    /// A custom uploaded image. Pass `WallpaperStore.isUndersized(_:)`.
    init(image: UIImage, undersized: Bool) {
        source = .custom(image)
        self.undersized = undersized
    }

    var body: some View {
        ZStack {
            // Base: scheme background, never white — no white margins
            // even before the image loads.
            Theme.Color.background
            if undersized {
                // Blurred stretched copy of the SAME image, ~120% scale,
                // filling the screen. Blurred so the stretch never reads
                // as a pixelated photo.
                imageLayer
                    .aspectRatio(contentMode: .fill)
                    .scaleEffect(Self.fallbackScale)
                    .blur(radius: Self.fallbackBlur)
            }
            // Sharp original, centered at native aspect (contain):
            // never cropped, never distorted.
            imageLayer
                .aspectRatio(contentMode: .fit)
            // Legibility scrim: scheme background 85% top -> 60% bottom,
            // between wallpaper and content.
            LinearGradient(
                colors: [
                    Theme.Color.background.opacity(0.85),
                    Theme.Color.background.opacity(0.6),
                ],
                startPoint: .top,
                endPoint: .bottom
            )
        }
        .ignoresSafeArea()
    }

    private var imageLayer: some View {
        Group {
            switch source {
            case .bundled(let name):
                Image(name)
                    .resizable()
            case .custom(let image):
                Image(uiImage: image)
                    .resizable()
            }
        }
    }
}
