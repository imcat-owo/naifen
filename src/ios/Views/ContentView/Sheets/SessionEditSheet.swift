//
//  SessionEditSheet.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  Edit a session's title and category; SpinningRing is shared with the rows
//  and section headers.
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI

// MARK: - Session Edit Sheet

struct SessionEditSheet: View {
    let session: ChatSession
    let onSave: (String, String?) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var editTitle: String = ""
    @State private var editCategory: String = ""
    @State private var isRegenerating = false

    /// key → label only. Icon + color come from the single shared map
    /// `sessionCategoryIcon(for:)` (SessionRow.swift) — the old 16-entry
    /// copy with its own orange/blue/teal/pink/green/purple/cyan/red/gray
    /// literals is gone. One accent family: every category renders its glyph
    /// in ink on an accent tint; the glyph shape distinguishes categories.
    private static let categories: [(key: String, label: String)] = [
        ("code",         "Code"),
        ("writing",      "Writing"),
        ("research",     "Research"),
        ("analysis",     "Analysis"),
        ("creative",     "Creative"),
        ("chat",         "Chat"),
        ("math",         "Math"),
        ("translation",  "Translation"),
        ("health",       "Health"),
        ("finance",      "Finance"),
        ("travel",       "Travel"),
        ("education",    "Education"),
        ("design",       "Design"),
        ("productivity", "Productivity"),
        ("support",      "Support"),
        ("other",        "Other"),
    ]

    var body: some View {
        NavigationStack {
            List {
                Section("Title") {
                    TextField("Session title", text: $editTitle)
                }

                Section("Category") {
                    LazyVGrid(columns: [GridItem(.adaptive(minimum: 72), spacing: Theme.Spacing.md)], spacing: Theme.Spacing.md) {
                        ForEach(Self.categories, id: \.key) { cat in
                            let icon = sessionCategoryIcon(for: cat.key)
                            let isSelected = editCategory == cat.key
                            Button {
                                editCategory = cat.key
                            } label: {
                                VStack(spacing: Theme.Spacing.xs) {
                                    // displaySmall() is the 20pt size carrier
                                    // for this SF Symbol only (see SessionRow).
                                    // Glyph ink on the accent tint (7.36:1
                                    // light); selected adds a surface-2 fill
                                    // + accent ring + semibold label — never
                                    // white-on-accent (1.47:1 dark).
                                    Image(systemName: icon.systemName)
                                        .font(Theme.Font.displaySmall())
                                        .foregroundStyle(Theme.Color.ink)
                                        .frame(width: 44, height: 44)
                                        .background(
                                            Circle()
                                                .fill(isSelected ? Theme.Color.surface2 : Theme.Color.accent.opacity(0.12))
                                        )
                                        .overlay(
                                            Circle()
                                                .stroke(Theme.Color.accent, lineWidth: 2)
                                                .opacity(isSelected ? 1 : 0)
                                        )
                                    Text(LocalizedStringKey(cat.label))
                                        .font(Theme.Font.caption())
                                        .fontWeight(isSelected ? .semibold : .regular)
                                        .foregroundStyle(Theme.Color.ink)
                                }
                            }
                            .buttonStyle(.plain)
                        }
                    }
                    .padding(.vertical, Theme.Spacing.sm)
                }

                Section {
                    Button {
                        regenerate()
                    } label: {
                        HStack {
                            if isRegenerating {
                                SpinningRing(color: Theme.Color.accent)
                                    .frame(width: 18, height: 18)
                            } else {
                                Image(systemName: "arrow.triangle.2.circlepath")
                            }
                            Text("Regenerate Title")
                        }
                        .frame(maxWidth: .infinity, alignment: .center)
                    }
                    .disabled(isRegenerating)
                }
            }
            .navigationTitle("Edit Session")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        let title = editTitle.trimmingCharacters(in: .whitespacesAndNewlines)
                        guard !title.isEmpty else { return }
                        onSave(title, editCategory.isEmpty ? nil : editCategory)
                    }
                    .bold()
                    .disabled(editTitle.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                }
            }
            .onAppear {
                editTitle = session.title ?? ""
                editCategory = session.category ?? ""
            }
        }
    }

    private func regenerate() {
        guard !isRegenerating else { return }
        isRegenerating = true
        Task { @MainActor in
            defer { isRegenerating = false }
            do {
                try await AIChatViewModel.regenerateSessionTitle(sessionId: session.id)
                if let updated = await ChatStore.shared.getSession(session.id) {
                    if let title = updated.title { editTitle = title }
                    editCategory = updated.category ?? editCategory
                }
            } catch {
                AppLogger(category: "RegenerateTitle").error(
                    "session=\(session.id) failed: \(error.localizedDescription) — \(String(describing: error))"
                )
            }
        }
    }
}

/// A self-contained spinning arc that uses TimelineView to avoid
/// stacking animations on repeated onAppear calls.
struct SpinningRing: View {
    let color: Color

    var body: some View {
        TimelineView(.animation) { timeline in
            let angle = timeline.date.timeIntervalSinceReferenceDate.remainder(dividingBy: 1.0) * 360
            Circle()
                .trim(from: 0, to: 0.3)
                .stroke(color, style: StrokeStyle(lineWidth: 1.5, lineCap: .round))
                .rotationEffect(.degrees(angle))
        }
    }
}
