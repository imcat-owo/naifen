import SwiftUI
import UIKit

// MARK: - Context-menu preview

/// Opaque rounded-card preview shown under a message's long-press context menu.
///
/// [T-ios-longpress-menu-preview-background] The message cells are hosted with a
/// clear background (host.view / cell backgroundColor = .clear), and the message
/// `.contextMenu`s are attached either to a zero-size `Color.clear` overlay
/// (assistant block/footer) or to a flat milk-pink bubble (user). Without an
/// explicit `preview:`, SwiftUI snapshots
/// that (transparent) attached view, so the long-press preview platter shows
/// through to the messages below — the reported "transparent preview" bug.
///
/// Supplying this as the `.contextMenu(preview:)` gives the platter an opaque
/// porcelain rounded card with the message text, so it reads as a
/// floating card. Theme colors only, so dark mode stays correct.
///
/// [T-ios-longpress-preview-full-content-card] The earlier version hard-capped
/// the text at 1500 chars with a trailing "…", which is what users saw as a
/// "truncated" preview on long assistant messages. It now renders the FULL
/// message content inside a vertical ScrollView: short messages size to their
/// content, long ones are capped to a fraction of the screen height and scroll
/// inside the platter, so the preview is both opaque
/// and complete. An explicit measured height is required because a ScrollView
/// has no intrinsic height — without it the context-menu platter would collapse.
struct MessageContextMenuPreview: View {
    let text: String

    /// [T-ios-usermsg-preview-adaptive-width] Width is now a CAP, not a fixed
    /// size. A short user bubble ("ok") previously lifted into a full 360pt
    /// platter; the platter now hugs the laid-out text width (measured by the
    /// same GeometryReader that already measured height) and only long lines
    /// wrap at this cap, iMessage-style.
    private let maxCardWidth: CGFloat = 360
    /// Long messages cap the platter to this fraction of screen height and
    /// scroll inside; short messages size to content (min of the two).
    private var maxCardHeight: CGFloat { UIScreen.main.bounds.height * 0.55 }

    @State private var contentSize: CGSize = .zero

    /// [T-ios-ctxmenu-preview-watchdog] Hard cap on the characters handed to
    /// the preview's `Text`.
    ///
    /// This platter is a lift-to-peek preview: it is capped to 55% of screen
    /// height and scrolls, so only the first screenful is ever readable. But
    /// the `Text` was given the WHOLE reply, and the `GeometryReader` below
    /// forces SwiftUI to typeset all of it through CoreText — on the main
    /// thread — just to produce `contentSize`. Cost is super-linear in length.
    /// Measured at this exact font (Theme.Font.body()) and wrap width (360 - 2*16 = 328pt):
    ///
    ///      4,000 chars   0.25s
    ///      8,000 chars   0.98s
    ///     12,000 chars   1.63s
    ///     20,000 chars   4.50s
    ///     24,000 chars   6.48s     <- the reported 5591ms hang lands here
    ///     30,000 chars  10.14s
    ///     40,000 chars  17.96s
    ///
    /// which is the issue #284 foreground SIGKILL: a long reply, a main-thread
    /// hang of 5591ms in CTLineCreateWithAttributedString ->
    /// ResolvedStyledText.draw, watchdog kill, memory normal (not an OOM).
    ///
    /// Note the cost is driven by LENGTH, not by LaTeX: raw LaTeX source
    /// measured FASTER than prose at equal length (40,000 chars of formula
    /// source = 0.178s), because its long unspaced backslash runs produce far
    /// fewer line-break opportunities than CJK, where nearly every character is
    /// a break candidate. The reporter's LaTeX-heavy reply was simply a long
    /// one. Capping the string keeps this flat at ~0.06s for any input size.
    private static let maxPreviewChars = 2000

    var body: some View {
        let shown = text.isEmpty ? " " : String(text.prefix(Self.maxPreviewChars))
        ScrollView(.vertical, showsIndicators: true) {
            // No `.frame(maxWidth: .infinity)` here — the Text must report its
            // NATURAL width so short messages yield a narrow platter. The wrap
            // width comes from the ScrollView's width (the outer .frame below),
            // which starts at the cap and shrinks to the measured content.
            Text(shown)
                .font(Theme.Font.body())
                .foregroundStyle(Theme.Color.ink)
                .multilineTextAlignment(.leading)
                .padding(Theme.Spacing.lg)
                .background(
                    // Measure the laid-out text size so the platter can hug
                    // content (short) or cap + wrap/scroll (long).
                    GeometryReader { geo in
                        Color.clear
                            .preference(key: PreviewContentSizeKey.self, value: geo.size)
                    }
                )
        }
        .onPreferenceChange(PreviewContentSizeKey.self) { contentSize = $0 }
        // Size = content size, capped. Falls back to the caps until the first
        // measurement lands so the platter never collapses to zero. The small
        // width floor keeps an (attachment-only) empty-text preview from
        // rendering as a sliver.
        .frame(
            width: contentSize.width > 0 ? min(max(contentSize.width, 60), maxCardWidth) : maxCardWidth,
            height: contentSize.height > 0 ? min(contentSize.height, maxCardHeight) : maxCardHeight
        )
        .modifier(ContextMenuPreviewSurface())
    }
}

/// Background for the long-press preview platter.
///
/// Flat milk-pink porcelain card — no Liquid Glass. The bubble this platter
/// lifts from is flat now (see `UserBubbleSurface`), so the platter stays
/// flat too. The shape (`RoundedRectangle(cornerRadius: Theme.Radius.user)`,
/// non-`.continuous`) is deliberately the same one the bubble and the row's
/// `.contentShape(.contextMenuPreview, …)` already use.
///
/// **The opaque base stays.** [T-ios-longpress-menu-preview-background] exists
/// because the platter was showing through to the messages underneath: cells are
/// hosted on a clear background and the menus hang off either a zero-size
/// `Color.clear` overlay or a flat bubble, so SwiftUI's snapshot of the
/// attached view was effectively transparent. The opaque `Theme.Color.surface`
/// fill keeps the platter solid no matter what the system composites behind it.
private struct ContextMenuPreviewSurface: ViewModifier {
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: Theme.Radius.user)
    }

    func body(content: Content) -> some View {
        content.background(shape.fill(Theme.Color.surface))
    }
}

/// Preference key carrying the laid-out preview text size up to the platter.
/// Background for the user message bubble.
///
/// Two states that must stay tellable apart at a glance:
///
///  - **Sent** (`isQueued == false`) — flat milk-pink fill
///    (`Theme.Color.bubbleUser`). Liquid Glass was the old sent state; glass
///    is current-state material and is re-derived here as a flat surface.
///    Text uses its own slot (`Theme.Color.bubbleUserText`, 6.14:1 light /
///    8.83:1 dark).
///  - **Queued** (`isQueued == true`) — deliberately NOT a solid fill, on
///    either OS. It keeps the existing empty fill + dashed border, so
///    "queued" still looks provisional next to the solid fill of everything
///    already sent.
///
/// Shape: short messages are a full pill (radius = half the bubble height,
/// measured at layout time by the row); long messages fall back to the
/// Porcelain Card radius (`Theme.Radius.card`), never an ellipse, never
/// clipped text. The radius arrives as `cornerRadius`, computed by the row.
/// [T-multi-select-share] The `chatSnapshotRendering` environment value is
/// still SET by the share/export renderer, but the bubble no longer reads it:
/// the fill is flat on every path now, so there is no live-compositor surface
/// left for an offscreen `layer.render` to miss. The key stays defined here
/// because the exporter sets it; remove both together in a later cleanup.
private struct ChatSnapshotRenderingKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var chatSnapshotRendering: Bool {
        get { self[ChatSnapshotRenderingKey.self] }
        set { self[ChatSnapshotRenderingKey.self] = newValue }
    }
}

private struct UserBubbleSurface: ViewModifier {
    let isQueued: Bool
    /// Corner radius for this bubble, computed by the row from the measured
    /// bubble size: half the bubble height (full pill) for short messages,
    /// `Theme.Radius.card` for long ones.
    let cornerRadius: CGFloat

    /// Matches `.contentShape(.contextMenuPreview, …)` on the row exactly —
    /// the row passes this same radius there, including the default
    /// (non-`.continuous`) corner style. A `.continuous` bubble against a
    /// circular-arc preview clip would show the corners subtly change shape
    /// as the long-press lift begins.
    private var shape: RoundedRectangle {
        RoundedRectangle(cornerRadius: cornerRadius)
    }

    func body(content: Content) -> some View {
        if isQueued {
            // Provisional look, identical on every OS version.
            content
                .background(shape.fill(Color.clear))
                .overlay(
                    shape
                        .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6, 4]))
                        .foregroundStyle(Theme.Color.ink2.opacity(0.5))
                )
        } else {
            // Flat milk-pink surface — no Liquid Glass anywhere on the bubble.
            content.background(shape.fill(Theme.Color.bubbleUser))
        }
    }
}

private struct PreviewContentSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        let next = nextValue()
        value = CGSize(width: max(value.width, next.width), height: max(value.height, next.height))
    }
}

// MARK: - Chat row layout constants (this file only)

/// Named layout values for the chat rows — no bare literals in the bodies
/// below. 44pt is the HIG minimum tap target; 72% is the plan's user-bubble
/// width cap; 120 chars / 3.5 lines is the plan's long-bubble threshold
/// (>3 lines / ~120 chars falls back to the Porcelain Card radius).
private enum ChatMessageLayout {
    static let minTapTarget: CGFloat = 44
    static let userBubbleMaxWidthFraction: CGFloat = 0.72
    static let longBubbleCharThreshold: Int = 120
    static let longBubbleLineThreshold: CGFloat = 3.5
}

/// Carries the laid-out user-bubble size (text + padding, width-capped) up
/// to the row, so the pill radius and the long-message fallback are derived
/// from the real layout instead of guessed from the string.
private struct UserBubbleSizeKey: PreferenceKey {
    static var defaultValue: CGSize = .zero
    static func reduce(value: inout CGSize, nextValue: () -> CGSize) {
        value = nextValue()
    }
}

/// The ONE date-group capsule.
///
/// Per-message row timestamps do not exist upstream (only the hidden
/// usage-reveal clock), and none are added here: messages are grouped by
/// calendar day under a single centered capsule. Locked pairing — ink text
/// on surface-2 (8.00:1 light / 11.16:1 dark). ink-2 and ink-3 are forbidden
/// at this size. `Theme.Font.meta()` floors to 11pt (see Tokens.swift); the
/// locked part is the color pairing, which holds at any size. There is no
/// second capsule style for dates.
private struct DateGroupCapsule: View {
    let date: Date

    private static let dayFormatter: DateFormatter = {
        let f = DateFormatter()
        f.dateStyle = .medium
        f.timeStyle = .none
        return f
    }()

    private var label: String {
        let calendar = Calendar.current
        if calendar.isDateInToday(date) { return AppLocalized("Today") }
        if calendar.isDateInYesterday(date) { return AppLocalized("Yesterday") }
        return Self.dayFormatter.string(from: date)
    }

    var body: some View {
        Text(label)
            .font(Theme.Font.meta())
            .foregroundStyle(Theme.Color.ink)
            // Pill-tag padding from the plan (§B.5): H12 / V6.
            .padding(.horizontal, Theme.Spacing.md)
            .padding(.vertical, 6)
            .background(Theme.Color.surface2)
            .clipShape(Capsule())
    }
}

// MARK: - Chat Message Row

struct ChatMessageRow: View {
    @ObservedObject var message: ChatMessage
    /// Only the actively streaming message needs vm access (for typing indicator & stop button).
    let isActiveMessage: Bool
    /// Set by the list host on the first message of each calendar day: the
    /// row draws the single centered date-group capsule above itself.
    /// Defaults to false so existing call sites compile unchanged; the
    /// first-of-day computation lives in the list host, not in this file.
    var showDateHeader: Bool = false
    var commandStartTime: Date?
    var onStop: (() -> Void)?
    var onRetry: (() -> Void)?
    var onEdit: (() -> Void)?
    /// [T-ios-delete-from-message] Delete this user message and everything
    /// after it. Only set for non-queued user bubbles when idle.
    var onDeleteFrom: (() -> Void)?
    var onWithdraw: (() -> Void)?
    var autoRetryAttempt: Int = 0
    var autoRetryCountdown: Int = 0
    var canResume: Bool = false
    var onResume: (() -> Void)?
    var onCompact: (() -> Void)?
    var onShareMessages: (() -> Void)?
    /// Read this whole reply aloud from the start (clears any in-progress TTS).
    /// Wired from AIChatView (which owns the view model). Disabled while the
    /// message is still streaming to avoid fighting the live streaming TTS.
    var onReadAloud: (() -> Void)?
    /// When set, presents the compact summary sheet outside the cell tree (V3).
    /// Falls back to a local .sheet when nil (non-V3 / standalone usage).
    var onShowCompactSummary: ((String) -> Void)?
    /// Triggers AIChatViewModel.revertCompact(). Wired from AIChatView so the
    /// row + sheet stay free of view-model imports.
    var onRevertCompact: (() -> Void)?
    var browserPool: BrowserTabPool?
    var toolSnapshots: [ToolSnapshotItem] = []
    @State private var showUsage = false
    @State private var showCompactSummary = false
    /// [T-ios-delete-from-message] Confirmation gate for the suffix delete.
    @State private var showDeleteFromConfirm = false
    /// Two-phase token usage reveal: space expands first, then content fades in.
    @State private var usageContentVisible = false
    /// Row frame in window coordinates — used to gate token-usage tap to bottom zone.
    @State private var rowFrameInWindow: CGRect = .zero
    /// Measured user-bubble size (text + padding, width-capped) — drives the
    /// pill radius and the long-message fallback for this row's bubble.
    @State private var userBubbleSize: CGSize = .zero
    private let usageTapLogger = AppLogger(category: "UsageTap")
    /// ID of the block currently highlighted after a copy action.
    @State private var highlightedBlockId: UUID?
    /// The tool block whose detail sheet is currently presented.
    /// Lifted out of ToolCapsuleView so ForEach item changes don't reset it.
    @State private var detailBlock: AssistantBlock?
    /// [T-in-chat-search] Highlights and the "Search in Chat" opener; nil
    /// outside the message list.
    @Environment(\.chatSearchHighlights) private var searchHighlights

    /// [T-in-chat-search] Key of this message's text for the search.
    private func searchKey(_ field: ChatSearchField = .body) -> ChatSearchUnitKey {
        ChatSearchUnitKey(messageId: message.id, blockId: nil, field: field)
    }

    /// All text block contents joined, for "Copy All".
    private var fullReplyText: String {
        message.blocks
            .filter { if case .text = $0.kind { return true }; return false }
            .map(\.content)
            .joined(separator: "\n\n")
    }

    /// Full message including tool calls and their results, for clipboard export.
    private var fullMessageText: String {
        var parts: [String] = []
        for block in message.blocks {
            switch block.kind {
            case .text:
                if !block.content.isEmpty { parts.append(block.content) }
            case .shellTool(let command):
                let cmd = command.isEmpty ? block.toolDescription : command
                var s = "$ \(cmd)"
                if !block.content.isEmpty {
                    // content is "$ cmd\noutput…", strip the command line
                    let output = block.content.hasPrefix("$ ") ?
                        String(block.content.drop(while: { $0 != "\n" }).dropFirst()) : block.content
                    if !output.isEmpty { s += "\n\(output)" }
                }
                parts.append(s)
            case .fileReadTool(let path):
                parts.append("Read: \(path)\n\(block.content)")
            case .fileWriteTool(let path):
                parts.append("Write: \(path)\n\(block.content)")
            case .fileEditTool(let path):
                parts.append("Edit: \(path)\n\(block.content)")
            case .browserTool(let action):
                parts.append("Browser: \(action)\n\(block.content)")
            case .readImageTool(let path):
                parts.append("Image: \(path)")
            case .memoryTool(let action):
                parts.append("Memory: \(action)\n\(block.content)")
            case .delegateTool(let title):
                parts.append("Agent: \(title)\n\(block.content)")
            case .userAskTool:
                // [T-user-ask] Copy the questions and the result, not the UI.
                parts.append("Asked: \(UserAskCardModel.questionsSummary(block))\n\(block.content)")
            case .thinking:
                if !block.content.isEmpty { parts.append("[Thinking]\n\(block.content)") }
            case .info:
                if !block.content.isEmpty { parts.append(block.content) }
            }
        }
        return parts.joined(separator: "\n\n")
    }

    var body: some View {
        VStack(alignment: .center, spacing: Theme.Spacing.sm) {
            if showDateHeader {
                DateGroupCapsule(date: message.timestamp)
            }
            messageContent
        }
    }

    /// The row itself, without the date-group capsule above it.
    @ViewBuilder
    private var messageContent: some View {
        switch message.role {
        case .user:
            if let callback = message.agentCallback {
                AgentCallbackCellView(callback: callback, sessionId: nil)
                    .environment(\.chatSearchMessageId, message.id)
                    .opacity(message.isCompactedHistory ? 0.5 : 1.0)
            } else {
                userRow
                    .opacity(message.isCompactedHistory ? 0.5 : 1.0)
            }
        case .assistant:
            assistantRow
                .opacity(message.isCompactedHistory ? 0.5 : 1.0)
        case .compactDivider:
            compactDividerRow
        case .systemInfo:
            systemDividerRow(icon: message.isCompactLoading ? nil : (message.systemIcon ?? "info.circle"),
                             loading: message.isCompactLoading, compact: false)
        }
    }

    /// Corner radius for this row's user bubble, derived from the measured
    /// layout: full pill (half the bubble height) for short messages,
    /// Porcelain Card radius for long ones (>3 lines / ~120 chars). Before
    /// the first measurement lands, the character count decides and the
    /// radius falls back to `Theme.Radius.user`, so the bubble never renders
    /// with a zero radius or clipped text.
    private var userBubbleCornerRadius: CGFloat {
        if userBubbleIsLong { return Theme.Radius.card }
        if userBubbleSize.height > 0 { return userBubbleSize.height / 2 }
        return Theme.Radius.user
    }

    /// Long-message test: measured line count once layout has run, character
    /// count before that. The 3.5 threshold sits between 3 and 4 whole lines,
    /// so rounding in the measured height cannot flip a 3-line bubble.
    /// Line height comes from the same 13pt base `Theme.Font.body()` renders
    /// (scaled by UIFontMetrics for Dynamic Type, floored at 11pt, exactly as
    /// `Theme.Font.scaledSize` does) — NOT the 17pt system `.body` style,
    /// whose ~22pt line height would undercount lines and give long messages
    /// the pill radius instead of the Porcelain Card radius.
    private var userBubbleIsLong: Bool {
        if userBubbleSize.height > 0 {
            let textHeight = userBubbleSize.height - Theme.Spacing.sm * 2
            // Keep this 13 in sync with Theme.Font.body()'s base (and
            // FontSettings.defaultBodySize); the 11pt floor matches
            // Theme.Font's sans floor.
            let scaledSize = max(UIFontMetrics(forTextStyle: .body).scaledValue(for: 13), 11)
            let lineHeight = UIFont.systemFont(ofSize: scaledSize).lineHeight
            if lineHeight > 0 { return textHeight / lineHeight > ChatMessageLayout.longBubbleLineThreshold }
        }
        return userDisplayText.count > ChatMessageLayout.longBubbleCharThreshold
    }

    /// 72% screen-width cap for the user bubble.
    private var maxUserBubbleWidth: CGFloat {
        UIScreen.main.bounds.width * ChatMessageLayout.userBubbleMaxWidthFraction
    }

    // MARK: Compact Divider Row

    private var compactDividerRow: some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack { Divider() }
            HStack(spacing: Theme.Spacing.xs) {
                if message.isCompactLoading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: Theme.Spacing.md, height: Theme.Spacing.md)
                } else {
                    Image(systemName: "arrow.down.right.and.arrow.up.left")
                        .font(Theme.Font.meta())
                }
                SearchHighlightText(message.content, key: searchKey())
                    .font(Theme.Font.bodyEmphasized())
                if !message.isCompactLoading && message.compactSummary != nil {
                    Button {
                        let summary = message.compactSummary ?? ""
                        if let onShowCompactSummary {
                            onShowCompactSummary(summary)
                        } else {
                            showCompactSummary = true
                        }
                    } label: {
                        Image(systemName: "info.circle")
                            .font(Theme.Font.body())
                    }
                    .buttonStyle(.plain)
                    .frame(minWidth: ChatMessageLayout.minTapTarget,
                           minHeight: ChatMessageLayout.minTapTarget)
                }
            }
            .foregroundStyle(Theme.Color.ink)
            .lineLimit(1)
            .fixedSize()
            VStack { Divider() }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, Theme.Spacing.lg)
        .sheet(isPresented: $showCompactSummary) {
            CompactSummarySheet(summary: message.compactSummary ?? "", onRevert: onRevertCompact)
        }
    }

    // MARK: System Divider Row

    /// Shared divider-style row for system info messages.
    private func systemDividerRow(icon: String?, loading: Bool, compact: Bool) -> some View {
        HStack(spacing: Theme.Spacing.sm) {
            VStack { Divider() }
            HStack(spacing: Theme.Spacing.xs) {
                if loading {
                    ProgressView()
                        .scaleEffect(0.6)
                        .frame(width: Theme.Spacing.md, height: Theme.Spacing.md)
                } else if let icon {
                    Image(systemName: icon)
                        .font(Theme.Font.meta())
                }
                SearchHighlightText(message.content, key: searchKey())
                    .font(Theme.Font.bodyEmphasized())
                    .multilineTextAlignment(.center)
            }
            .foregroundStyle(Theme.Color.ink)
            // [T-browser-download-ux-v4] No .lineLimit(1).fixedSize() here:
            // fixedSize forced the text to its full ideal width, so a long
            // systemInfo line (e.g. pre-v3 "Downloaded … to /var/minis/… —
            // minis://…" rows persisted in history) overflowed BOTH screen
            // edges from this centered row. layoutPriority keeps the flexible
            // dividers from squeezing the text; past the available width the
            // text wraps (UIKit breaks unspaced tokens like paths/URLs
            // mid-word) instead of clipping.
            .layoutPriority(1)
            VStack { Divider() }
        }
        .padding(.horizontal, Theme.Spacing.xxl)
        .padding(.vertical, compact ? Theme.Spacing.lg : Theme.Spacing.sm)
    }

    // MARK: User Row

    /// User message text without the `<user-attached-files>` metadata and
    /// without any `<system-reminder>` note meant for the model (e.g. the
    /// answer to a deferred user_ask) - [T-user-bubble-reminder-strip].
    private var userDisplayText: String {
        // [T-in-chat-search] The search reads the bubble through this same
        // function (ChatSearchDisplayText.userBubble).
        SystemReminderStripper.userBubbleText(message.content)
    }

    private var userRow: some View {
        HStack {
            Spacer(minLength: 60)

            VStack(alignment: .trailing, spacing: Theme.Spacing.sm) {
                // User-attached files above the text bubble
                if !message.attachments.isEmpty {
                    UserAttachmentList(attachments: message.attachments, searchMessageId: message.id)
                } else if !message.inputAttachments.isEmpty {
                    // Queued message: show previews from cache before queue drain
                    QueuedAttachmentPreview(attachments: message.inputAttachments)
                }

                if !userDisplayText.isEmpty {
                    HStack(spacing: Theme.Spacing.sm) {
                        SearchHighlightText(userDisplayText, key: searchKey())
                            .font(Theme.Font.body())
                            .foregroundStyle(Theme.Color.bubbleUserText)
                            .padding(.horizontal, Theme.Spacing.md)
                            .padding(.vertical, Theme.Spacing.sm)
                            .modifier(UserBubbleSurface(isQueued: message.isQueued,
                                                       cornerRadius: userBubbleCornerRadius))
                            // Measure the laid-out bubble (text + padding,
                            // width-capped) so the pill radius and the
                            // long-message fallback derive from real layout.
                            .background(
                                GeometryReader { geo in
                                    Color.clear
                                        .preference(key: UserBubbleSizeKey.self, value: geo.size)
                                }
                            )
                            .onPreferenceChange(UserBubbleSizeKey.self) { userBubbleSize = $0 }
                            // Width hugs the text, capped at 72% of the screen.
                            .frame(maxWidth: maxUserBubbleWidth, alignment: .trailing)

                        if message.isQueued {
                            if let onWithdraw {
                                Button {
                                    onWithdraw()
                                } label: {
                                    Image(systemName: "xmark.circle.fill")
                                        .font(Theme.Font.bodyEmphasized())
                                        .foregroundStyle(Theme.Color.accent)
                                }
                                .frame(minWidth: ChatMessageLayout.minTapTarget,
                                       minHeight: ChatMessageLayout.minTapTarget)
                            }
                        }
                    }
                }
            }
            .modifier(MinisOpenURLHandler())
            .contentShape(Rectangle())
            // [T-ios-usermsg-contextmenu-preview-shape] The hit-test shape above
            // stays a full Rectangle (so the whole row is long-pressable), but
            // the context-menu PREVIEW must clip to the bubble's rounded shape —
            // otherwise the lifted preview shows square corners while the bubble
            // is rounded. iOS 16+ lets us specify the preview clip shape
            // independently from the interaction shape. The radius is the same
            // measured one the bubble itself uses (pill for short messages,
            // Porcelain Card for long ones).
            .contentShape(.contextMenuPreview, RoundedRectangle(cornerRadius: userBubbleCornerRadius))
            .contextMenu {
                Button {
                    UIPasteboard.general.string = message.content
                } label: {
                    Label("Copy", systemImage: "doc.on.doc")
                }
                if let onEdit {
                    Button {
                        onEdit()
                    } label: {
                        Label("Edit", systemImage: "square.and.pencil")
                    }
                }
                if let onRetry {
                    Button {
                        onRetry()
                    } label: {
                        Label("Retry", systemImage: "arrow.counterclockwise")
                    }
                }
                // [T-multi-select-share] Copy / Edit / Retry, a divider, then Share
                // Chat… on its own; the destructive items stay last.
                if let onShareMessages {
                    Divider()
                    Button {
                        onShareMessages()
                    } label: {
                        Label(AppLocalized("Share Chat…"), systemImage: "square.and.arrow.up")
                    }
                }
                // [T-in-chat-search]
                if let open = searchHighlights?.openSearch {
                    if onShareMessages == nil { Divider() }
                    Button {
                        open(nil)
                    } label: {
                        Label(AppLocalized("Search in Chat"), systemImage: "magnifyingglass")
                    }
                }
                if onDeleteFrom != nil || onCompact != nil {
                    Divider()
                }
                if onDeleteFrom != nil {
                    Button(role: .destructive) {
                        showDeleteFromConfirm = true
                    } label: {
                        Label("Delete From Here", systemImage: "trash")
                    }
                }
                if let onCompact {
                    Button(role: .destructive) {
                        onCompact()
                    } label: {
                        Label("Compact Above", systemImage: "arrow.down.right.and.arrow.up.left")
                    }
                }
            } preview: {
                // [T-ios-longpress-menu-preview-background] Opaque card so the
                // long-press preview isn't transparent (see MessageContextMenuPreview).
                MessageContextMenuPreview(text: message.content)
            }
        }
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.xs)
        // [T-ios-delete-from-message] Suffix deletion is irreversible and takes
        // the following replies with it, so it gets an explicit confirmation
        // rather than firing straight off the menu.
        .alert(AppLocalized("Delete Message?"), isPresented: $showDeleteFromConfirm) {
            Button(AppLocalized("Cancel"), role: .cancel) {}
            Button(AppLocalized("Delete"), role: .destructive) {
                onDeleteFrom?()
            }
        } message: {
            Text("This message and all messages after it will be deleted. This cannot be undone.")
        }
    }

    // MARK: Assistant Row

    private var assistantRow: some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.sm) {
            // Assistant label
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "sparkles")
                    .font(Theme.Font.bodyEmphasized())
                    .foregroundStyle(Theme.Color.accent)
                AssistantSoulName()
                    .font(Theme.Font.bodyEmphasized())
                    .foregroundStyle(Theme.Color.ink)
            }
            .padding(.top, Theme.Spacing.xs)

            ForEach(message.blocks) { block in
                AssistantBlockView(
                    block: block,
                    message: message,
                    isActiveMessage: isActiveMessage,
                    commandStartTime: commandStartTime,
                    onStop: onStop,
                    onTapBlank: message.usage != nil ? { windowPoint in
                        // Only respond to taps in the bottom 100pt of the message row
                        let bottomZoneTop = rowFrameInWindow.maxY - 100
                        let inZone = windowPoint.y >= bottomZoneTop
                        usageTapLogger.debug("[usageTap] windowPt=\(String(format: "%.0f,%.0f", windowPoint.x, windowPoint.y)) rowBottom=\(String(format: "%.0f", rowFrameInWindow.maxY)) zoneTop=\(String(format: "%.0f", bottomZoneTop)) inZone=\(inZone) showUsage=\(showUsage)")
                        guard inZone else { return }

                        if showUsage {
                            // [Phase 2 milk-pink] Reduce Motion: hide
                            // instantly, no 0.20s fade and no staged delay.
                            if UIAccessibility.isReduceMotionEnabled {
                                usageContentVisible = false
                                showUsage = false
                            } else {
                                withAnimation(.easeInOut(duration: Theme.Motion.base)) { usageContentVisible = false }
                                DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.base) {
                                    showUsage = false
                                }
                            }
                        } else {
                            // [Phase 2 milk-pink] Reduce Motion: show
                            // instantly, no 0.20s fade and no staged delay.
                            if UIAccessibility.isReduceMotionEnabled {
                                showUsage = true
                                usageContentVisible = true
                            } else {
                                showUsage = true
                                DispatchQueue.main.asyncAfter(deadline: .now() + Theme.Motion.fast) {
                                    withAnimation(.easeInOut(duration: Theme.Motion.base)) { usageContentVisible = true }
                                }
                            }
                        }
                    } : nil,
                    onShareMessages: onShareMessages,
                    browserPool: browserPool,
                    toolSnapshots: toolSnapshots,
                    highlightedBlockId: $highlightedBlockId,
                    detailBlock: $detailBlock
                )
            }

            // Typing indicator — "request out, nothing back yet", evaluated per
            // ROUND. See `ChatMessage.shouldShowTypingIndicator`.
            if isActiveMessage && message.shouldShowTypingIndicator {
                TypingIndicator()
            }

            // Inline error + retry
            if let error = message.error {
                inlineError(error)
            }

            // Resume banner for interrupted sessions
            if canResume && message.error == nil {
                resumeBanner
            }

            // Token usage — two-phase reveal: space expands first, then content fades in
            // [T-retry-log-sheet] The "↻ N" interrupt badge is gone (in step
            // with BridgedAssistantFooterV3): retries show as a marker in the
            // typing row, only while one is under way.
            if showUsage {
                HStack(spacing: 6) {
                    if let usage = message.usage {
                        usageCapsule(usage)
                            .opacity(usageContentVisible ? 1 : 0)
                    }
                    Spacer()
                    // [T-usage-capsule-time] Right-aligned, outside the
                    // capsule. Kept byte-for-byte in step with the SAME row in
                    // BridgedAssistantFooterV3 (CollectionViewMessageListV3),
                    // which is the copy an ASSISTANT reply actually renders —
                    // this one only ever draws user / compactDivider /
                    // systemInfo rows. Editing one without the other is how
                    // the clock shipped twice without ever being on screen.
                    if showUsage, let completedAt = message.completedAt {
                        Text(Self.completedAtFormatter.string(from: completedAt))
                            .font(Theme.Font.mono())
                            .foregroundStyle(Theme.Color.ink)
                            .opacity(usageContentVisible ? 1 : 0)
                    }
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        // Porcelain surface: bubble-less text on the white card — 16pt radius,
        // 1pt hairline border, soft shadow. Distinct from the user pill at a
        // glance. Inner padding keeps the text off the card edge.
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.md)
        .background(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .fill(Theme.Color.bubbleAI)
        )
        .overlay(
            RoundedRectangle(cornerRadius: Theme.Radius.card)
                .strokeBorder(Theme.Color.bubbleAIBorder, lineWidth: 1)
        )
        .themeShadow(Theme.Shadow.card)
        .padding(.horizontal, Theme.Spacing.lg)
        .padding(.vertical, Theme.Spacing.sm)
        // [T-ios-geometry-observer-crash] THE crasher from the v1.8b13 IPS:
        // onChange(of: geo.frame(in: .global)) wrote state inside the
        // geometry-observer path and tripped the async renderer
        // (ViewGraphGeometryObservers.needsUpdate SIGTRAP). onGeometryChange
        // measures the same row bounds the background GeometryReader did,
        // and its initial fire covers the old onAppear seed.
        .onGeometryChange(for: CGRect.self) { proxy in
            proxy.frame(in: .global)
        } action: { rowFrameInWindow = $0 }
        .background {
            // Context menu on the background layer so it only fires on
            // blank areas — UITextView link taps in the foreground take priority.
            Color.clear
                .contentShape(Rectangle())
                .contextMenu {
                    // [T-ios-msg-contextmenu-recursion-crash] Gate the eager menu
                    // tree behind an Equatable key so the cell body churn during
                    // `gh`/shell streaming output doesn't rebuild + re-diff the
                    // whole menu subtree every frame — the deep ContextMenuModifier
                    // / UnwrapConditional recursion that blew the update stack into
                    // unmapped heap (incident 98E8805F). Copy actions read
                    // `fullReplyText` lazily at TAP time, so the menu structure
                    // only needs rebuilding when the key changes: which optional
                    // actions exist + the streaming-disabled state.
                    EquatableMenuGate(key: AssistantMenuKey(
                        messageId: message.id,
                        hasReadAloud: onReadAloud != nil,
                        hasShareMessages: onShareMessages != nil,
                        hasCompact: onCompact != nil,
                        isActive: isActiveMessage,
                        hasSearchInChat: searchHighlights?.openSearch != nil
                    )) {
                        Button {
                            UIPasteboard.general.string = fullReplyText
                        } label: {
                            Label("Copy All", systemImage: "doc.on.doc")
                        }
                        Button {
                            UIPasteboard.general.string = fullReplyText
                        } label: {
                            Label(AppLocalized("Copy as Markdown"), systemImage: "text.quote")
                        }
                        if let onReadAloud {
                            Button {
                                onReadAloud()
                            } label: {
                                Label(AppLocalized("Read from Start"), systemImage: "play.circle")
                            }
                            // Greyed out while streaming so it can't clash with the
                            // live streaming TTS of the same reply.
                            .disabled(isActiveMessage)
                        }
                        if let onShareMessages {
                            Button {
                                onShareMessages()
                            } label: {
                                Label(AppLocalized("Share Chat…"), systemImage: "square.and.arrow.up")
                            }
                        }
                        // [T-in-chat-search]
                        if let open = searchHighlights?.openSearch {
                            Button {
                                open(nil)
                            } label: {
                                Label(AppLocalized("Search in Chat"), systemImage: "magnifyingglass")
                            }
                        }
                        if let onCompact {
                            Divider()
                            Button(role: .destructive) {
                                onCompact()
                            } label: {
                                Label("Compact Above", systemImage: "arrow.down.right.and.arrow.up.left")
                            }
                        }
                    }
                    .equatable()
                } preview: {
                    // [T-ios-longpress-menu-preview-background] Opaque card for
                    // this Color.clear-attached contextMenu (see
                    // MessageContextMenuPreview).
                    MessageContextMenuPreview(text: fullReplyText)
                }
        }
        .sheet(item: $detailBlock) { block in
            // [T-agent-tool-sheet-unified] The agent block takes the same
            // live sheet as every other tool.
            ToolLiveSheet(toolBlocks: message.blocks.filter { $0.toolStatus != nil },
                          initialIdx: message.blocks.filter({ $0.toolStatus != nil }).firstIndex(where: { $0.id == block.id }) ?? 0,
                          toolSnapshots: toolSnapshots, browserPool: browserPool)
        }
    }

    /// [T-usage-capsule-time] 24-hour HH:mm for the capsule's completion clock.
    ///
    /// `en_US_POSIX` is not cosmetic: a bare `dateFormat = "HH:mm"` is still
    /// resolved against the device locale, and a region on a 12-hour clock
    /// renders it as 12-hour — so on those devices "22:30" would come out
    /// "10:30" with no AM/PM to tell them apart. Pinning the locale is what
    /// makes 24-hour actually mean 24-hour.
    ///
    /// Static because a DateFormatter is expensive to build and this runs per
    /// message per render pass.
    private static let completedAtFormatter: DateFormatter = {
        let f = DateFormatter()
        f.locale = Locale(identifier: "en_US_POSIX")
        f.dateFormat = "HH:mm"
        return f
    }()

    @ViewBuilder
    private func usageCapsule(_ usage: TokenUsage) -> some View {
        HStack(spacing: Theme.Spacing.xs) {
            Image(systemName: "speedometer")
                .font(Theme.Font.meta())
            Text(usageSummary(usage))
                .font(Theme.Font.mono())
        }
        .foregroundStyle(Theme.Color.ink)
        .padding(.horizontal, Theme.Spacing.sm)
        .padding(.vertical, Theme.Spacing.xs)
        .background(Theme.Color.bubbleUser.opacity(0.6))
        .clipShape(Capsule())
        // Fade only: streaming is this screen's one signature motion, and
        // fade is the Reduce Motion fallback — no scale entrance here.
        .transition(.opacity)
    }

    private func usageSummary(_ u: TokenUsage) -> String {
        var parts: [String] = []
        if u.latestContextTokens > 0 {
            parts.append("ctx:\(formatTokenCount(u.latestContextTokens))")
        }
        parts.append("in:\(formatTokenCount(u.inputTokens))")
        parts.append("out:\(formatTokenCount(u.outputTokens))")
        if u.cacheReadTokens > 0 {
            parts.append("cache:\(formatTokenCount(u.cacheReadTokens))")
        }
        if u.cacheCreationTokens > 0 {
            parts.append("+cache:\(formatTokenCount(u.cacheCreationTokens))")
        }
        return parts.joined(separator: " ")
    }

    /// [T-ios-context-usage-hint] Shared with the composer usage line; see
    /// TokenCountFormatter.
    private func formatTokenCount(_ count: Int) -> String {
        TokenCountFormatter.short(count)
    }

    @ViewBuilder
    private func inlineError(_ error: String) -> some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Color.accent)
                // [T-error-detail-visible issue #368] Was lineLimit(2), which
                // could not show the reason at all: a group failure composes one
                // "⚠️ <model> (<instance>): <reason>" line per attempted entry and
                // appends the real upstream description LAST
                // (groupExhaustedError, AIChatViewModel+Fallback.swift). Two lines
                // were spent on trail lines, so an upstream 400 such as
                // "reasoning_text … must be passed back" was always clipped —
                // measured on-simulator at 280pt and 340pt, where even a
                // single-entry trail cut the sentence mid-phrase.
                //
                // 8 lines fits a 3-4 entry trail plus the description at .caption.
                // Not tap-to-expand: these rows live in a self-sizing collection
                // view whose layout caches heights, so growing a cell in place
                // needs an explicit invalidateHeight round trip (see the
                // stale-height family in CollectionViewMessageListV3). A static
                // limit is measured correctly at first layout and cannot desync.
                Text(error)
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Color.ink)
                    .lineLimit(8)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            .contentShape(Rectangle())
            .contextMenu {
                Button {
                    UIPasteboard.general.string = error
                } label: {
                    Label(AppLocalized("Copy Error"), systemImage: "doc.on.doc")
                }
            }

            Spacer()

            if autoRetryAttempt > 0 {
                Text("Retry in \(autoRetryCountdown)s (\(autoRetryAttempt)/\(AIChatViewModel.retryDelays.count))")
                    .font(Theme.Font.caption().weight(.semibold))
                    .foregroundStyle(Theme.Color.ink)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Color.surface2)
                    .clipShape(Capsule())
            } else if let onRetry {
                Button(action: onRetry) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "arrow.clockwise")
                            .font(Theme.Font.caption().weight(.semibold))
                        Text("Retry")
                            .font(Theme.Font.caption().weight(.semibold))
                    }
                    .foregroundStyle(Theme.Color.ink)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Color.ink.opacity(0.15))
                    .clipShape(Capsule())
                }
                .frame(minWidth: ChatMessageLayout.minTapTarget,
                       minHeight: ChatMessageLayout.minTapTarget)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.thinking))
    }

    private var resumeBanner: some View {
        HStack(alignment: .center, spacing: Theme.Spacing.sm) {
            HStack(spacing: Theme.Spacing.sm) {
                Image(systemName: "pause.circle.fill")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Color.accent)
                Text("Interrupted — tap Resume to continue")
                    .font(Theme.Font.caption())
                    .foregroundStyle(Theme.Color.ink)
            }

            Spacer()

            if let onResume {
                Button(action: onResume) {
                    HStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: "play.fill")
                            .font(Theme.Font.caption().weight(.semibold))
                        Text("Resume")
                            .font(Theme.Font.caption().weight(.semibold))
                    }
                    .foregroundStyle(Theme.Color.bubbleUserText)
                    .padding(.horizontal, Theme.Spacing.md)
                    .padding(.vertical, Theme.Spacing.xs)
                    .background(Theme.Color.bubbleUser)
                    .clipShape(Capsule())
                }
                .frame(minWidth: ChatMessageLayout.minTapTarget,
                       minHeight: ChatMessageLayout.minTapTarget)
            }
        }
        .padding(Theme.Spacing.sm)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Theme.Color.surface2)
        .clipShape(RoundedRectangle(cornerRadius: Theme.Radius.thinking))
    }

    // [T-ios-typing-indicator-scope] The local `hasVisibleContent` that used to
    // live here is gone: the typing indicator's predicate now has exactly one
    // definition, `ChatMessage.shouldShowTypingIndicator`. Keeping a private
    // copy per view is what let the four call sites drift apart in the first
    // place.
}


