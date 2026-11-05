//
//  ContentView+SelectionToolbar.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  ContentView, multi-select toolbar: bulk actions on the selected sessions
//  (move to group, export, delete, force sync / pull).
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI

extension ContentView {
    // MARK: - Selection Toolbar

    var selectionToolbar: some View {
        HStack(spacing: 0) {
            Menu {
                Button {
                    exportSessions(ids: selectedIds, format: .json)
                } label: {
                    Label("JSON", systemImage: "doc.text")
                }
                Button {
                    exportSessions(ids: selectedIds, format: .plainText)
                } label: {
                    Label("Plain Text", systemImage: "text.alignleft")
                }
            } label: {
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "square.and.arrow.up")
                        // 20pt glyph: Theme.Font.displaySmall is the nearest
                        // role (same precedent as the composer controls).
                        .font(Theme.Font.displaySmall())
                    Text("Export")
                        .font(Theme.Font.caption())
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(selectedIds.isEmpty)
            .dressUpPress()

            Button {
                let anyFiled = sessions.contains { selectedIds.contains($0.id) && $0.isFiled }
                folderPickerRequest = FolderPickerRequest(
                    sessionIds: selectedIds, fromMultiSelect: true, anyFiled: anyFiled)
            } label: {
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "folder")
                        .font(Theme.Font.displaySmall())
                    Text("Move")
                        .font(Theme.Font.caption())
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
            }
            .disabled(selectedIds.isEmpty)
            .dressUpPress()

            // Force Sync is gated to iOS 17+ — CloudKit features (queryable
            // record fields, fetchRecordZoneChanges async APIs) used by the
            // v2 sync engine require iOS 17. iOS 16 users see the action bar
            // without this button rather than seeing it hit a no-op.
            // Same gate as the single-session menu — drop the action bar
            // entry entirely when iCloud sync is off.
            if #available(iOS 17.0, *), iCloudSyncEnabled {
                Button {
                    runForceSyncOnSelection()
                } label: {
                    VStack(spacing: Theme.Spacing.xs) {
                        Image(systemName: forceSyncInFlight ? "arrow.triangle.2.circlepath" : "icloud.and.arrow.up")
                            .font(Theme.Font.displaySmall())
                        Text("Force Sync")
                            .font(Theme.Font.caption())
                    }
                    .frame(maxWidth: .infinity, minHeight: 44)
                    .contentShape(Rectangle())
                }
                .disabled(selectedIds.isEmpty || forceSyncInFlight)
                .dressUpPress()
            }

            Button(role: .destructive) {
                deleteInfo = nil
                isComputingDelete = true
                showDeleteConfirm = true
                let ids = selectedIds
                Task { @MainActor in
                    let info = await Self.computeDeleteInfoExpanded(for: ids)
                    deleteInfo = info
                    isComputingDelete = false
                }
            } label: {
                VStack(spacing: Theme.Spacing.xs) {
                    Image(systemName: "trash")
                        .font(Theme.Font.displaySmall())
                    Text("Delete")
                        .font(Theme.Font.caption())
                }
                .frame(maxWidth: .infinity, minHeight: 44)
                .contentShape(Rectangle())
                // Destructive stays milk-pink dark ink (no pure .red):
                // the .disabled below dims it when nothing is selected.
                .foregroundStyle(Theme.Color.ink)
            }
            .disabled(selectedIds.isEmpty)
            .dressUpPress()
        }
        .foregroundStyle(Theme.Color.ink)
        .padding(.vertical, Theme.Spacing.md)
        .background(Theme.Color.tabBar)
        .overlay(alignment: .top) {
            Theme.Color.line.frame(height: 1)
        }
    }

    /// Force-sync the given sessions: bumps each session, its messages,
    /// compact markers, and SessionFiles into the v2 dirty queue, and
    /// tells SyncCore to push immediately. Shows a transient
    /// confirmation toast with the total record count and auto-
    /// dismisses selection mode if engaged.
    ///
    /// Pass `singleSession` for the row-level swipe-action / context-
    /// menu path; falls back to `selectedIds` for the multi-select
    /// toolbar.
    func runForceSyncOnSelection(singleSession: String? = nil) {
        let ids: Set<String> = singleSession.map { Set([$0]) } ?? selectedIds
        guard !ids.isEmpty, !forceSyncInFlight else { return }
        forceSyncInFlight = true
        Task {
            var totalMarked = 0
            for sid in ids {
                let n = await ChatStore.shared.forceSyncSession(sid)
                totalMarked += n
            }
            // Kick the v2 transport so the freshly-marked rows leave
            // local SQLite in this minute rather than waiting for the
            // ambient debounce.
            if #available(iOS 17.0, *) {
                await MainActor.run { SyncCore.shared.scheduleSend(delay: 0.5) }
            }
            await MainActor.run {
                let sessionCount = ids.count
                forceSyncToast = AppLocalized("Marked \(sessionCount) sessions (\(totalMarked) records) for sync. iCloud is syncing now.")
                forceSyncInFlight = false
                if singleSession == nil {
                    // Multi-select path also exits selection mode for the user.
                    isSelecting = false
                    selectedIds.removeAll()
                }
            }
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            await MainActor.run {
                if forceSyncToast != nil { forceSyncToast = nil }
            }
        }
    }

    /// Force Pull a single session from iCloud: queries cloud for the
    /// session's MessageV2 / CompactMarkerV2 / SessionV2 records, and
    /// only commits the local swap if cloud returned a non-empty set.
    /// Reuses the toast banner from runForceSyncOnSelection.
    func runForcePullOnSession(_ sessionId: String) {
        guard !forceSyncInFlight else { return }
        forceSyncInFlight = true
        forceSyncToast = AppLocalized("Pulling from iCloud…")
        // [T-ios-sessionrow-destroy-crash] Isolate the whole Task to @MainActor.
        // This is the site 6687cf1a (T-ios-state-publish-offmain-crash) MISSED:
        // a bare `Task {}` started from this non-isolated func inherits a
        // background cooperative thread, so the `sessions =` @State write after
        // the `forcePullSession` actor-hop await lands off-main → it concurrently
        // mutates the [ChatSession] AttributeGraph state while the main thread is
        // mid-transaction destroying the old SessionRow value graph (the crash:
        // BodyAccessor.setBody → assignWithCopy for Button → release →
        // `outlined destroy of SessionRow` → freed ChatSession backing). Forcing
        // the Task onto MainActor makes the @State write main-thread, matching
        // every other session-write site fixed in 6687cf1a.
        Task { @MainActor in
            let outcome = await ChatStore.shared.forcePullSession(sessionId: sessionId)
            switch outcome {
            case .applied(let pulled, let deleted):
                forceSyncToast = AppLocalized("Pulled \(pulled) records · removed \(deleted) local")
            case .cloudEmpty:
                forceSyncToast = AppLocalized("iCloud has no records for this chat — local messages preserved")
            case .failed(let msg):
                forceSyncToast = AppLocalized("Force Pull failed: \(msg) — local messages preserved")
            }
            forceSyncInFlight = false
            // Refresh sessions so any title/updatedAt that came down from
            // the SessionV2 record reflects in the list.
            refreshSessionList()
            try? await Task.sleep(nanoseconds: 4_000_000_000)
            if forceSyncToast != nil { forceSyncToast = nil }
        }
    }
}
