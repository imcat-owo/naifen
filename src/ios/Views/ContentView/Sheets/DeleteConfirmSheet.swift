//
//  DeleteConfirmSheet.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  Confirmation sheet for deleting sessions, listing what will be removed
//  (DeleteInfo from ContentView+SessionActions).
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI

// MARK: - Delete Confirm Sheet

struct DeleteConfirmSheet: View {
    @Binding var info: ContentView.DeleteInfo?
    let isLoading: Bool
    let onDelete: () -> Void
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if isLoading || info == nil {
                    Spacer()
                    ProgressView("Calculating…")
                        .controlSize(.large)
                        .tint(Theme.Color.ink)
                    Spacer()
                    let _ = print("[DELETE] DeleteConfirmSheet showing ProgressView. isLoading=\(isLoading), info is \(info == nil ? "nil" : "non-nil")")
                } else if let info {
                    let _ = print("[DELETE] DeleteConfirmSheet showing info. sessionCount=\(info.sessionCount)")
                    ScrollView {
                        VStack(alignment: .leading, spacing: Theme.Spacing.lg) {
                            // Sessions
                            infoRow(
                                title: "Sessions",
                                value: info.childCount > 0
                                    ? "\(info.sessionCount - info.childCount) session\(info.sessionCount - info.childCount == 1 ? "" : "s") + \(info.childCount) agent session\(info.childCount == 1 ? "" : "s") and all messages"
                                    : "\(info.sessionCount) session\(info.sessionCount == 1 ? "" : "s") and all messages"
                            )

                            // Files
                            if info.totalFileCount > 0 {
                                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                                    Text("Associated Files")
                                        .font(.subheadline.bold())
                                        .foregroundStyle(Theme.Color.ink)
                                    ForEach(info.fileNames, id: \.self) { name in
                                        HStack(spacing: Theme.Spacing.sm) {
                                            Image(systemName: "doc")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                            Text(name)
                                                .font(.subheadline)
                                                .foregroundStyle(.secondary)
                                        }
                                    }
                                    if info.totalFileCount > info.fileNames.count {
                                        Text("and \(info.totalFileCount - info.fileNames.count) more file\(info.totalFileCount - info.fileNames.count == 1 ? "" : "s")")
                                            .font(.caption)
                                            .foregroundStyle(.tertiary)
                                    }
                                }
                            }

                            // Storage
                            infoRow(title: "Releases Storage", value: info.formattedSize)
                        }
                        .padding(Theme.Spacing.xl)
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }

                    Divider()

                    // Buttons
                    VStack(spacing: Theme.Spacing.md) {
                        // Delete: ink fill + surface2 text (locked pairing,
                        // WCAG-recomputed 8.00:1 light / 11.16:1 dark).
                        // surface2 fill on bubbleAI was 1.18:1 / 1.17:1.
                        Button(role: .destructive) {
                            onDelete()
                            dismiss()
                        } label: {
                            Text("Delete (\(info.formattedSize))")
                                .font(.body.bold())
                                .foregroundStyle(Theme.Color.surface2)
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                                .background(Theme.Color.ink, in: RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous))
                        }
                        .dressUpPress(feedback: .impact)

                        Button {
                            dismiss()
                        } label: {
                            Text("Cancel")
                                .frame(maxWidth: .infinity)
                                .frame(minHeight: 44)
                        }
                        .buttonStyle(.bordered)
                        .tint(Theme.Color.ink)
                    }
                    .padding(.horizontal, Theme.Spacing.xl)
                    .padding(.vertical, Theme.Spacing.md)
                }
            }
            .background(Theme.Color.bubbleAI)
            .navigationTitle("Confirm Deletion")
            .navigationBarTitleDisplayMode(.inline)
        }
        .dressUpPresentationBackground(Theme.Color.bubbleAI)
    }

    private func infoRow(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
            Text(title)
                .font(.subheadline.bold())
                .foregroundStyle(Theme.Color.ink)
            Text(value)
                .font(.subheadline)
                .foregroundStyle(.secondary)
        }
    }
}
