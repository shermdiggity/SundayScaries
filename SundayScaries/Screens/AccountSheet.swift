import SwiftUI
import FantasyCore
import FantasyProviders

/// The only thing outside the weekly view and the league view: connecting accounts.
struct AccountSheet: View {
    let model: WeeklyModel
    @Environment(\.dismiss) private var dismiss
    @State private var handle: String = ""
    @State private var espnLeagues: String = ""
    @State private var signedInToESPN = false
    @State private var showingESPNLogin = false
    /// Tracked separately because by the time `save()` runs the keychain already holds
    /// the new cookies, so comparing against the model reports "no change" and the
    /// reload never fires. That was the bug where signing in appeared to do nothing.
    @State private var didSignInThisSession = false
    @State private var showingLeagueEditor = false
    @State private var showingLeagueIDs = false
    @State private var fleaflicker: String = ""
    @State private var mflLeagues: String = ""
    @State private var signedInToMFL = false
    @State private var signedInToYahoo = false
    @State private var showingMFLConnect = false
    @State private var showingYahooLogin = false

    private var leagueSummary: LocalizedStringKey {
        let total = model.allLeagues.count
        let hidden = model.allLeagues.count { model.isHidden($0) }
        if total == 0 { return "None yet" }
        return hidden == 0 ? "\(total)" : "\(total - hidden) of \(total)"
    }

    var body: some View {
        NavigationStack {
            List {

                // MARK: Connected

                Section {
                    // Sleeper: a username, editable in place. It reads as a row about you
                    // — your handle, connected — not as a form field about a platform.
                    platformRow(.sleeper, title: "Sleeper") {
                        TextField("Your username", text: $handle)
                            .font(SWType.caption)
                            .foregroundStyle(handle.isEmpty ? SWColor.tertiary : SWColor.secondary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.done)
                            .onSubmit(persist)
                    } trailing: {
                        if !handle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Disconnect", role: .destructive) {
                                handle = ""
                                persist()
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Disconnect Sleeper")
                        }
                    }

                    platformRow(.espn, title: "ESPN") {
                        statusText(signedInToESPN ? "Signed in" : "Not connected")
                    } trailing: {
                        if signedInToESPN {
                            Button("Sign out", role: .destructive) {
                                ESPNCredentialStore.clear()
                                signedInToESPN = false
                                didSignInThisSession = true
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Sign out of ESPN")
                        } else {
                            Button("Sign in") { showingESPNLogin = true }
                                .font(SWType.bodyMedium)
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Sign in to ESPN")
                        }
                    }

                    // Yahoo: the one official OAuth sign-in. Hidden until the API key exists.
                    if FeatureFlags.yahooEnabled {
                        platformRow(.yahoo, title: "Yahoo") {
                            statusText(signedInToYahoo ? "Signed in" : "Not connected")
                        } trailing: {
                            if signedInToYahoo {
                                Button("Sign out", role: .destructive) {
                                    YahooCredentialStore.clear()
                                    signedInToYahoo = false
                                    didSignInThisSession = true
                                }
                                .font(SWType.caption)
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Sign out of Yahoo")
                            } else {
                                Button("Sign in") { showingYahooLogin = true }
                                    .font(SWType.bodyMedium)
                                    .buttonStyle(.borderless)
                                    .accessibilityLabel("Sign in to Yahoo")
                            }
                        }
                    }

                    // MyFantasyLeague: sign in, or name public leagues by id.
                    platformRow(.myFantasyLeague, title: "MyFantasyLeague") {
                        statusText(mflStatus)
                    } trailing: {
                        if signedInToMFL {
                            Button("Sign out", role: .destructive) {
                                MFLCredentialStore.clear()
                                signedInToMFL = false
                                didSignInThisSession = true
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Sign out of MyFantasyLeague")
                        } else {
                            Button(mflLeagues.isEmpty ? "Connect" : "Sign in") { showingMFLConnect = true }
                                .font(SWType.bodyMedium)
                                .buttonStyle(.borderless)
                                .accessibilityLabel("Sign in to MyFantasyLeague")
                        }
                    }
                    if !mflLeagues.isEmpty || signedInToMFL {
                        DisclosureGroup {
                            TextField("League IDs, comma-separated", text: $mflLeagues)
                                .font(SWType.caption)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.numbersAndPunctuation)
                                .onSubmit(persist)
                            Text("A public league needs no sign-in. The id is the number after /home/ in the league's address.")
                                .font(SWType.micro)
                                .foregroundStyle(SWColor.tertiary)
                        } label: {
                            Text("Leagues by ID")
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.secondary)
                        }
                    }

                    // Fleaflicker: the account's email. No password exists to ask for.
                    platformRow(.fleaflicker, title: "Fleaflicker") {
                        TextField("Email on your account", text: $fleaflicker)
                            .font(SWType.caption)
                            .foregroundStyle(fleaflicker.isEmpty ? SWColor.tertiary : SWColor.secondary)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .submitLabel(.done)
                            .onSubmit(persist)
                    } trailing: {
                        if !fleaflicker.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Disconnect", role: .destructive) {
                                fleaflicker = ""
                                persist()
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                            .accessibilityLabel("Disconnect Fleaflicker")
                        }
                    }

                    // Only once signed in, and only as a disclosure: nearly nobody needs
                    // it, and a bare "League ID" field beneath a sign-in button was most
                    // of what made this screen read as a developer's checklist.
                    if signedInToESPN {
                        DisclosureGroup(isExpanded: $showingLeagueIDs) {
                            TextField("League IDs, comma-separated", text: $espnLeagues)
                                .font(SWType.caption)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.numbersAndPunctuation)
                                .onSubmit(persist)
                            Text("Your leagues are found automatically. Add an ID only if one is missing — it's the number after leagueId= in the league's address.")
                                .font(SWType.micro)
                                .foregroundStyle(SWColor.tertiary)
                        } label: {
                            Text("Add a league by ID")
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.secondary)
                        }
                    }
                } header: {
                    Text("Platforms")
                }

                // MARK: Your week

                Section {
                    Button {
                        showingLeagueEditor = true
                    } label: {
                        HStack {
                            Text("Show and reorder")
                                .font(SWType.bodyMedium)
                                .foregroundStyle(SWColor.primary)
                            Spacer()
                            Text(leagueSummary)
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.tertiary)
                            Image(systemName: "chevron.right")
                                .font(SWType.glyph)
                                .foregroundStyle(SWColor.tertiary)
                                .accessibilityHidden(true)
                        }
                    }
                    .disabled(model.allLeagues.isEmpty)

                    HStack {
                        Text("Season")
                            .font(SWType.bodyMedium)
                            .foregroundStyle(SWColor.primary)
                        Spacer()
                        Text(model.allLeagues.first?.season ?? WeeklyModel.currentSeason())
                            .font(SWType.caption)
                            .foregroundStyle(SWColor.tertiary)
                            .monospacedDigit()
                    }
                    if let fallback = model.seasonFallback {
                        fallback.note
                            .font(SWType.micro)
                            .foregroundStyle(SWColor.tertiary)
                    }
                } header: {
                    Text("Leagues")
                }

                // MARK: About

                Section {
                    // Where the data comes from belongs here, at the bottom of a screen
                    // about the app — not under every week on the main screen.
                    ForEach(model.attribution, id: \.self) { line in
                        Text(line)
                            .font(SWType.micro)
                            .foregroundStyle(SWColor.tertiary)
                    }
                    HStack {
                        Text("Version")
                            .font(SWType.caption)
                            .foregroundStyle(SWColor.secondary)
                        Spacer()
                        Text(Self.version)
                            .font(SWType.caption)
                            .foregroundStyle(SWColor.tertiary)
                            .monospacedDigit()
                    }
                } header: {
                    Text("About")
                }
            }
            .listStyle(.insetGrouped)
            .navigationTitle("You")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    // Done closes. Saving already happened — on submit, and again on the
                    // way out — so there is no trap where closing loses what you typed.
                    Button("Done") { persist(); dismiss() }
                }
            }
            .onAppear {
                handle = model.handle
                espnLeagues = model.espnLeagueIDs
                signedInToESPN = model.isSignedInToESPN
                showingLeagueIDs = !espnLeagues.isEmpty
                fleaflicker = model.fleaflickerHandle
                mflLeagues = model.mflLeagueIDs
                signedInToMFL = model.isSignedInToMFL
                signedInToYahoo = model.hasYahoo
            }
            .onDisappear(perform: persist)
            .sheet(isPresented: $showingLeagueEditor) {
                LeagueEditor(model: model)
            }
            .sheet(isPresented: $showingESPNLogin) {
                ESPNLoginView { credentials in
                    ESPNCredentialStore.save(credentials)
                    signedInToESPN = true
                    didSignInThisSession = true
                }
            }
            .sheet(isPresented: $showingMFLConnect) {
                MFLConnectView(initialLeagueIDs: mflLeagues) { credentials in
                    MFLCredentialStore.save(credentials)
                    signedInToMFL = true
                    didSignInThisSession = true
                } onLeagueIDs: { ids in
                    mflLeagues = ids
                    persist()
                }
            }
            .sheet(isPresented: $showingYahooLogin) {
                YahooSignInView { credentials in
                    YahooCredentialStore.save(credentials)
                    signedInToYahoo = true
                    didSignInThisSession = true
                }
            }
        }
        .tint(SWColor.accent)
    }

    /// The platform's mark, its name, one line about its state, and one action.
    private func platformRow(
        _ platform: Platform, title: String,
        @ViewBuilder detail: () -> some View, @ViewBuilder trailing: () -> some View
    ) -> some View {
        HStack(spacing: SWSpacing.md) {
            PlatformMark(platform: platform, size: 26)
            VStack(alignment: .leading, spacing: 1) {
                Text(title)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.primary)
                detail()
            }
            Spacer()
            trailing()
        }
    }

    private func statusText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(SWType.caption)
            .foregroundStyle(SWColor.secondary)
    }

    private var mflStatus: LocalizedStringKey {
        if signedInToMFL { return "Signed in" }
        let count = LeagueIDs.parse(mflLeagues).count
        return count == 0 ? "Not connected" : "\(count) leagues by ID"
    }

    private static var version: String {
        let short = Bundle.main.object(forInfoDictionaryKey: "CFBundleShortVersionString") as? String ?? "1.0"
        let build = Bundle.main.object(forInfoDictionaryKey: "CFBundleVersion") as? String ?? "1"
        return "\(short) (\(build))"
    }

    /// Writes what has changed and reloads if it matters. Safe to call repeatedly.
    private func persist() {
        let trimmedHandle = handle.trimmingCharacters(in: .whitespaces)
        let trimmedLeagues = espnLeagues.trimmingCharacters(in: .whitespaces)
        let trimmedFleaflicker = fleaflicker.trimmingCharacters(in: .whitespaces)
        let trimmedMFL = mflLeagues.trimmingCharacters(in: .whitespaces)
        let changed = trimmedHandle != model.handle
            || trimmedLeagues != model.espnLeagueIDs
            || trimmedFleaflicker != model.fleaflickerHandle
            || trimmedMFL != model.mflLeagueIDs
            || didSignInThisSession
        guard changed else { return }
        model.handle = trimmedHandle
        model.espnLeagueIDs = trimmedLeagues
        model.fleaflickerHandle = trimmedFleaflicker
        model.mflLeagueIDs = trimmedMFL
        didSignInThisSession = false
        Task { await model.load() }
    }
}
