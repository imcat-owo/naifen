import Combine
import Foundation
import SwiftUI

extension Notification.Name {
    static let fontSettingsMessageBaseChanged = Notification.Name("fontSettingsMessageBaseChanged")
}

/// LEGACY level — kept, not deleted, for exactly two reasons:
/// 1. One-time migration: a stored level maps onto the new dial (see
///    `dialBodySize` below). Existing users keep their scale choice.
/// 2. `ConfigRegistry+Builtins.fontScaleField` still reads/writes the three
///    axes by `ReferenceWritableKeyPath<FontSettings, FontScaleLevel>` — the
///    third font path, deliberately NOT rewritten in this block (open item).
///    The axes below are computed projections onto the one dial, so a config
///    write still lands on the dial and still fires the @Published setter.
/// 3. The standalone UserAsk tests read the six multipliers from this file
///    to drive the typography harness.
/// Do NOT add new uses. New code uses `FontSettings.bodySize` / `scaled(_:)`.
enum FontScaleLevel: Int, CaseIterable, Identifiable, Comparable {
    case xSmall = -2
    case small = -1
    case `default` = 0
    case medium = 1
    case large = 2
    case extraLarge = 3

    var id: Int { rawValue }

    /// Explicit declaration so CaseIterable follows display order, not raw-value order.
    static var allCases: [FontScaleLevel] { [.xSmall, .small, .default, .medium, .large, .extraLarge] }

    var multiplier: CGFloat {
        switch self {
        case .xSmall:     return 0.88   // ~15pt body
        case .small:      return 0.94   // ~16pt body
        case .default:    return 1.0    // 17pt body
        case .medium:     return 1.06
        case .large:      return 1.12
        case .extraLarge: return 1.21
        }
    }

    /// Old-level → new-dial mapping (migration only). The dial is the body
    /// size in points, default 13; a level's dial value is 13 × its old
    /// multiplier, clamped to the dial range 10–15pt. Only extraLarge
    /// clamps (13 × 1.21 = 15.73 → 15); every other level maps exactly,
    /// so an existing user's relative scale is preserved, not reset.
    ///   xSmall 11.44 · small 12.22 · default 13 · medium 13.78 ·
    ///   large 14.56 · extraLarge 15 (clamped from 15.73)
    var dialBodySize: CGFloat {
        min(max(FontSettings.defaultBodySize * multiplier,
                FontSettings.minBodySize),
            FontSettings.maxBodySize)
    }

    var label: String {
        switch self {
        case .xSmall:     return "XS"
        case .small:      return "Small"
        case .default:    return "Default"
        case .medium:     return "Medium"
        case .large:      return "Large"
        case .extraLarge: return "Extra Large"
        }
    }

    /// Maps to SwiftUI `DynamicTypeSize` so semantic fonts (`.body`, `.caption`, etc.)
    /// scale automatically when this level is applied via `.dynamicTypeSize()`.
    var dynamicTypeSize: DynamicTypeSize {
        switch self {
        case .xSmall:     return .small
        case .small:      return .medium
        case .default:    return .large        // system default
        case .medium:     return .xLarge
        case .large:      return .xxLarge
        case .extraLarge: return .xxxLarge
        }
    }

    /// UIKit equivalent for applying to all UIWindows (including sheets).
    var contentSizeCategory: UIContentSizeCategory {
        switch self {
        case .xSmall:     return .small
        case .small:      return .medium
        case .default:    return .large
        case .medium:     return .extraLarge
        case .large:      return .extraExtraLarge
        case .extraLarge: return .extraExtraExtraLarge
        }
    }

    static func < (lhs: FontScaleLevel, rhs: FontScaleLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}

/// Centralised font-scale preference for the app.
///
/// ONE global dial, 10–15pt: message text, chat input and general app text
/// scale together. The dial value IS the body size in points (default 13,
/// the same 13pt base `Theme.Font.body()` uses); every other size scales by
/// `bodySize / 13` through `scaled(_:)`. Sans sizes floor at 11pt; layout
/// must survive to AX5 (Body 53pt) via UIFontMetrics / Dynamic Type — never
/// fixed point sizes.
///
/// The old three axes (`chatInputScale` / `messageBaseScale` /
/// `appBaseScale`) are gone as storage. They survive below only as computed
/// projections onto the dial, for `ConfigRegistry+Builtins` (open item).
/// The three per-axis scaling helpers are deleted; call `scaled(_:)` instead.
@MainActor
final class FontSettings: ObservableObject {
    static let shared = FontSettings()

    /// Dial range and default, in points. Default 13 matches
    /// `Theme.Font.body()`'s 13pt base — keep the two in sync.
    static let minBodySize: CGFloat = 10
    static let maxBodySize: CGFloat = 15
    static let defaultBodySize: CGFloat = 13
    /// Sans floor (plan §B.2): no scaled sans size renders below 11pt.
    static let minScaledSize: CGFloat = 11

    // MARK: - Published properties

    /// The one global dial: body size in points, 10–15, default 13.
    /// Message text, chat input and app text all scale by `bodySize / 13`.
    @Published var bodySize: CGFloat {
        didSet {
            let clamped = min(max(bodySize, Self.minBodySize), Self.maxBodySize)
            if clamped != bodySize { bodySize = clamped; return }
            guard bodySize != oldValue else { return }
            UserDefaults.standard.set(bodySize, forKey: Keys.bodySize)
            DispatchQueue.main.async {
                NotificationCenter.default.post(name: .fontSettingsMessageBaseChanged, object: nil)
            }
            // Defer to next runloop to avoid layout feedback loop with Slider
            DispatchQueue.main.async { [weak self] in self?.applyAppScaleToAllWindows() }
        }
    }

    /// `true` when the dial differs from default.
    var isModified: Bool {
        bodySize != Self.defaultBodySize
    }

    // MARK: - Scaling

    /// Scale factor for the current dial value (1.0 at the 13pt default).
    var scaleFactor: CGFloat {
        bodySize / Self.defaultBodySize
    }

    /// Scale a font size by the one global dial. Floored at 11pt.
    func scaled(_ size: CGFloat) -> CGFloat {
        max(Self.minScaledSize, size * scaleFactor)
    }

    /// The dial as a SwiftUI Dynamic Type size, for the app root
    /// (`.dynamicTypeSize`) and `appFontScale()`. Thresholds are the
    /// midpoints between the migrated level values (11.44 / 12.22 / 13 /
    /// 13.78 / 14.56 / 15), so a migrated user lands on exactly the
    /// DynamicTypeSize their old level mapped to.
    var dynamicTypeSize: DynamicTypeSize {
        switch bodySize {
        case ..<11.83: .small
        case ..<12.61: .medium
        case ..<13.39: .large        // system default
        case ..<14.17: .xLarge
        case ..<14.78: .xxLarge
        default: .xxxLarge
        }
    }

    /// UIKit equivalent of `dynamicTypeSize`, for `applyAppScaleToAllWindows()`.
    var contentSizeCategory: UIContentSizeCategory {
        switch bodySize {
        case ..<11.83: .small
        case ..<12.61: .medium
        case ..<13.39: .large
        case ..<14.17: .extraLarge
        case ..<14.78: .extraExtraLarge
        default: .extraExtraExtraLarge
        }
    }

    /// The legacy level nearest the current dial value (same midpoints as
    /// `dynamicTypeSize`). Backs the legacy axis projections below.
    var nearestLevel: FontScaleLevel {
        switch bodySize {
        case ..<11.83: .xSmall
        case ..<12.61: .small
        case ..<13.39: .default
        case ..<14.17: .medium
        case ..<14.78: .large
        default: .extraLarge
        }
    }

    // MARK: - Legacy axis projections (ConfigRegistry compatibility only)
    //
    // The three axes no longer store anything: reading one returns the
    // level nearest the dial, writing one moves the dial to that level's
    // mapped value. `ConfigRegistry+Builtins.fontScaleField` keeps working
    // unchanged, and its writes still fire the `bodySize` publisher above
    // (UserDefaults write + cache-invalidation notification + window
    // retint), exactly as the old @Published setters did.

    /// LEGACY — projection onto the dial. Do not use in new code.
    var chatInputScale: FontScaleLevel {
        get { nearestLevel }
        set { bodySize = newValue.dialBodySize }
    }

    /// LEGACY — projection onto the dial. Do not use in new code.
    var messageBaseScale: FontScaleLevel {
        get { nearestLevel }
        set { bodySize = newValue.dialBodySize }
    }

    /// LEGACY — projection onto the dial. Do not use in new code.
    var appBaseScale: FontScaleLevel {
        get { nearestLevel }
        set { bodySize = newValue.dialBodySize }
    }

    // MARK: - Init

    private init() {
        let ud = UserDefaults.standard
        if let stored = ud.object(forKey: Keys.bodySize) as? Double {
            bodySize = min(max(CGFloat(stored), Self.minBodySize), Self.maxBodySize)
        } else {
            // First launch on the dial: migrate the stored legacy choice
            // instead of silently resetting the user to default.
            bodySize = Self.migratedBodySize(from: ud)
            ud.set(bodySize, forKey: Keys.bodySize)
        }
        // Defer to after first window is available
        DispatchQueue.main.async { [weak self] in self?.applyAppScaleToAllWindows() }
    }

    /// Map a stored three-axis choice onto the one dial. Strict priority:
    /// the message axis first (it drove bubbles, markdown and height
    /// estimation — the most visible surface), then app, then chat input.
    /// An axis counts only if its key was ever stored; an untouched axis
    /// does not override a touched one. All untouched → default 13.
    private static func migratedBodySize(from ud: UserDefaults) -> CGFloat {
        for key in [Keys.legacyMessageBase, Keys.legacyAppBase, Keys.legacyChatInput] {
            guard let raw = ud.object(forKey: key) as? Int,
                  let level = FontScaleLevel(rawValue: raw) else { continue }
            return level.dialBodySize
        }
        return defaultBodySize
    }

    // MARK: - UIKit global application

    /// Override the preferred content size category on all connected UIWindows.
    /// This affects UIKit views, SwiftUI sheets, and any presented view controllers.
    /// Driven by the one dial now (was: the app-base axis only).
    func applyAppScaleToAllWindows() {
        guard #available(iOS 17.0, *) else { return }
        // Skip if default — no need to override system traits
        guard bodySize != Self.defaultBodySize else {
            // Remove any previous override
            for scene in UIApplication.shared.connectedScenes {
                guard let windowScene = scene as? UIWindowScene else { continue }
                for window in windowScene.windows {
                    if window.traitOverrides.contains(UITraitPreferredContentSizeCategory.self) {
                        window.traitOverrides.remove(UITraitPreferredContentSizeCategory.self)
                    }
                }
            }
            return
        }
        let category = contentSizeCategory
        for scene in UIApplication.shared.connectedScenes {
            guard let windowScene = scene as? UIWindowScene else { continue }
            for window in windowScene.windows {
                window.traitOverrides.preferredContentSizeCategory = category
            }
        }
    }

    // MARK: - Reset

    func resetToDefaults() {
        bodySize = Self.defaultBodySize
    }

    // MARK: - Notification

    /// Posted when `bodySize` changes so view models can invalidate rendered caches.
    /// Name kept (`fontSettingsMessageBaseChanged`) — AIChatViewModel and the
    /// message-list coordinator observe it; renaming would touch logic files.
    static let messageBaseChangedNotification = Notification.Name.fontSettingsMessageBaseChanged

    // MARK: - Keys

    private enum Keys {
        static let bodySize = "fontSettings.bodySize"
        // Legacy three-axis keys — read once by the migration above, never written.
        static let legacyChatInput = "fontSettings.chatInputScale"
        static let legacyMessageBase = "fontSettings.messageBaseScale"
        static let legacyAppBase = "fontSettings.appBaseScale"
    }
}

// MARK: - View extension for app-wide font scaling

/// Applies the one global dial via `dynamicTypeSize`.
/// Use on sheet content and any view that doesn't inherit the root environment.
private struct AppFontScaleModifier: ViewModifier {
    @ObservedObject private var fontSettings = FontSettings.shared

    func body(content: Content) -> some View {
        content.dynamicTypeSize(fontSettings.dynamicTypeSize)
    }
}

extension View {
    /// Applies the user's global font dial to this view hierarchy.
    func appFontScale() -> some View {
        modifier(AppFontScaleModifier())
    }
}
