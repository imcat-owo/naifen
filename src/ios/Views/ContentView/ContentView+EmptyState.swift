//
//  ContentView+EmptyState.swift
//  Minis - home screen (session list, navigation, settings entry)
//
//  ContentView, empty state: the first-run checklist (add a provider, select
//  models, or restore a backup). Its sheet flags and the provider store are
//  stored in ContentView.swift.
//
//  Map of the ContentView files: ContentView/ContentView.swift.
//

import SwiftUI

extension ContentView {
    // MARK: - Empty State

    /// [T-onboarding-hide-fab] Whether the floating New Chat / Search buttons
    /// stay hidden because the first-run checklist owns the screen. The two are
    /// mounted independently (checklist = list overlay, buttons = bottom safe
    /// area inset), so without this the New Chat button floated over steps 1-2
    /// before any provider or model existed - offering a chat that cannot run.
    /// Hidden only until models are selected: from then on step 3's subtitle
    /// ("Tap the button below to begin") points at that very button, and a
    /// returning user with no chats lands on this same screen.
    /// `showSearchBar` keeps an open search field from vanishing under it.
    /// Not gated on `didInitialLoad`: the provider config is read synchronously
    /// in ProviderConfigStore.init, so a set-up user never matches, and a first
    /// launch no longer flashes the buttons while the (empty) list loads.
    func hidesFABForOnboarding(listIsEmpty: Bool) -> Bool {
        listIsEmpty && !showSearchBar && providerStore.modelGroups.isEmpty
    }

    var emptyState: some View {
        let hasProviders = !providerStore.instances.isEmpty
        let hasGroups = !providerStore.modelGroups.isEmpty

        return VStack(spacing: Theme.Spacing.xxxl) {
            Spacer()
            // App icon / hero — ink, never the system tint: the tint is
            // the blue accent, which has no place in the milk-pink set.
            // 56pt had no Theme role; nearest is displayExtraLarge (32pt).
            Image(systemName: "sparkles")
                .font(Theme.Font.displayExtraLarge())
                .foregroundStyle(Theme.Color.ink)
                .padding(.bottom, Theme.Spacing.xs)

            VStack(spacing: Theme.Spacing.sm) {
                Text("Welcome to Minis")
                    .font(Theme.Font.displaySmall())
                    .foregroundStyle(Theme.Color.ink)
                Text("Your first On-Device Agent is almost ready.")
                    .font(Theme.Font.body())
                    .foregroundStyle(Theme.Color.ink)
                    .multilineTextAlignment(.center)
            }

            // Setup steps
            VStack(spacing: Theme.Spacing.lg) {
                // Step 1 – Add Provider
                setupStep(
                    number: 1,
                    title: "Add a Provider",
                    subtitle: hasProviders ? "Done" : "Configure an API key or sign in with OAuth",
                    isDone: hasProviders
                ) {
                    if !hasProviders {
                        showAddProvider = true
                    }
                }

                // Step 2 – Select Models
                setupStep(
                    number: 2,
                    title: "Select Models",
                    subtitle: hasGroups ? "Done" : (hasProviders ? "Choose the models you want to use" : "Complete step 1 first"),
                    isDone: hasGroups
                ) {
                    if hasProviders && !hasGroups {
                        showSelectModels = true
                    }
                }

                // Step 3 – Start chatting
                setupStep(
                    number: 3,
                    title: "Start a Conversation",
                    subtitle: hasGroups ? "Tap the button below to begin" : "Complete step 2 first",
                    isDone: false
                ) {
                    if hasGroups {
                        // [T-nav-ghost-row-link] From the home list: replace, never append.
                        switchToSession(Self.makeNewSessionId())
                    }
                }
            }
            .padding(.horizontal, Theme.Spacing.sm)
            // Reading-width cap for wide windows; no Theme token exists
            // for it, so the value stays a named layout constant.
            .frame(maxWidth: 400)

            Spacer()

            // [T-onboarding-restore-link] A side route for someone moving from
            // another device: kept to a footnote link (not a fourth card) so it
            // does not compete with the three steps. Shown only until models
            // are selected — after that this empty state also greets returning
            // users with no chats, for whom Settings → Backup & Restore is the
            // path. Restore merges, so it is safe after step 1 as well.
            //
            // [T-onboarding-restore-link-bottom] Pinned to the bottom, below
            // the second Spacer, rather than tucked under step 3: a footnote
            // reads as a footer, and the steps keep the centre to themselves.
            // The overlay inherits the list's safe area, so this sits above the
            // Home Indicator; the extra bottom padding keeps it clear of the
            // indicator's swipe zone as well.
            if !hasGroups {
                Button {
                    showRestoreBackup = true
                } label: {
                    Label("Have a backup? Restore from it", systemImage: "clock.arrow.circlepath")
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Color.ink)
                        // The label alone is ~20pt tall: widen the hit
                        // area to the 44pt minimum (visual stays small).
                        .frame(minHeight: 44)
                        .contentShape(Rectangle())
                }
                .buttonStyle(.plain)
                .padding(.bottom, Theme.Spacing.md)
                .accessibilityIdentifier("onboarding.restoreBackup")
            }
        }
        .frame(maxHeight: .infinity)
        .padding(.horizontal, Theme.Spacing.xxxl)
        .sheet(isPresented: $showAddProvider) {
            NavigationStack {
                AddProviderView()
            }
        }
        .sheet(isPresented: $showSelectModels) {
            NavigationStack {
                OnboardingModelSelectionView()
            }
        }
        .sheet(isPresented: $showRestoreBackup) {
            // Same presentation as opening a .minisbak from Files: straight to
            // the Restore tab. Not auto-dismissed on success — the result
            // report is worth reading; the steps above refresh on their own
            // (restore reloads ProviderConfigStore and the session list).
            NavigationStack {
                BackupAndRestoreView(initialTab: .restore)
                    .toolbar {
                        ToolbarItem(placement: .cancellationAction) {
                            Button("Close") { showRestoreBackup = false }
                        }
                    }
            }
        }
    }

    // title/subtitle must stay LocalizedStringKey, not String. A string literal at
    // the call site localizes fine on its own, but routing it through a String
    // parameter erases that: `Text(String)` stores the value verbatim and never
    // consults the string table, so these steps rendered English even though
    // Localizable.xcstrings has all 8 locales for these keys. Typing the parameter
    // as LocalizedStringKey keeps the literals (both branches of the `isDone`
    // ternaries included) resolving as keys.
    private func setupStep(
        number: Int,
        title: LocalizedStringKey,
        subtitle: LocalizedStringKey,
        isDone: Bool,
        action: @escaping () -> Void
    ) -> some View {
        Button(action: action) {
            HStack(spacing: Theme.Spacing.md) {
                // Step indicator — done is a solid ink disc, undone a
                // pale surface-2 disc. The glyph is the locked ink /
                // surface-2 pairing either way (8.00:1 light, 11.16:1
                // dark), so white-on-accent never appears here: white on
                // the milk-pink accent is 3.14:1 light / 1.47:1 dark.
                // Disc diameter reuses the 32pt grid step
                // (Theme.Spacing.xxxl); no Theme size token exists for it.
                ZStack {
                    Circle()
                        .fill(isDone ? Theme.Color.ink : Theme.Color.surface2)
                        .frame(width: Theme.Spacing.xxxl, height: Theme.Spacing.xxxl)
                    if isDone {
                        Image(systemName: "checkmark")
                            .font(Theme.Font.bodyEmphasized())
                            .foregroundColor(Theme.Color.surface2)
                    } else {
                        Text("\(number)")
                            .font(Theme.Font.bodyEmphasized())
                            .foregroundColor(Theme.Color.ink)
                    }
                }

                VStack(alignment: .leading, spacing: Theme.Spacing.xs) {
                    Text(title)
                        .font(Theme.Font.bodyEmphasized())
                        .foregroundStyle(Theme.Color.ink)
                    Text(subtitle)
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Color.ink)
                }

                Spacer()

                if !isDone {
                    Image(systemName: "chevron.right")
                        .font(Theme.Font.caption())
                        .foregroundStyle(Theme.Color.ink)
                }
            }
            .padding(Theme.Spacing.md)
            .background(
                RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                    .fill(Theme.Color.surface)
                    .overlay(
                        RoundedRectangle(cornerRadius: Theme.Radius.card, style: .continuous)
                            .stroke(Theme.Color.line, lineWidth: 1)
                    )
                    .themeShadow(Theme.Shadow.card)
            )
        }
        .buttonStyle(.plain)
        .disabled(isDone)
    }
}
