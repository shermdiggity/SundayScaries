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
                            action("Disconnect", label: "Disconnect Sleeper", role: .destructive) {
                                handle = ""
                                persist()
                            }
                        }
                    }

                    platformRow(.espn, title: "ESPN") {
                        statusText(espnStatus)
                    } trailing: {
                        if signedInToESPN {
                            action("Sign out", label: "Sign out of ESPN", role: .destructive) {
                                ESPNCredentialStore.clear()
                                signedInToESPN = false
                                didSignInThisSession = true
                            }
                        } else {
                            action("Sign in", label: "Sign in to ESPN") { showingESPNLogin = true }
                        }
                    }

                    // Yahoo: the one official OAuth sign-in. Hidden until the API key exists.
                    if FeatureFlags.yahooEnabled {
                        platformRow(.yahoo, title: "Yahoo") {
                            statusText(signedInToYahoo ? "Signed in" : "Not connected")
                        } trailing: {
                            if signedInToYahoo {
                                action("Sign out", label: "Sign out of Yahoo", role: .destructive) {
                                    YahooCredentialStore.clear()
                                    signedInToYahoo = false
                                    didSignInThisSession = true
                                }
                            } else {
                                action("Sign in", label: "Sign in to Yahoo") { showingYahooLogin = true }
                            }
                        }
                    }

                    // MyFantasyLeague: sign in, or name public leagues by id.
                    platformRow(.myFantasyLeague, title: "MyFantasyLeague") {
                        statusText(mflStatus)
                    } trailing: {
                        if signedInToMFL {
                            action("Sign out", label: "Sign out of MyFantasyLeague", role: .destructive) {
                                MFLCredentialStore.clear()
                                signedInToMFL = false
                                didSignInThisSession = true
                            }
                        } else {
                            action(mflLeagues.isEmpty ? "Connect" : "Sign in", label: "Sign in to MyFantasyLeague") {
                                showingMFLConnect = true
                            }
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
                            action("Disconnect", label: "Disconnect Fleaflicker", role: .destructive) {
                                fleaflicker = ""
                                persist()
                            }
                        }
                    }

                    // Only once signed in or once an id exists, and only as a disclosure:
                    // nearly nobody needs it, and a bare "League ID" field beneath a
                    // sign-in button was most of what made this screen read as a
                    // developer's checklist. An id typed earlier must stay editable after
                    // a sign-out, because it keeps loading that league.
                    if signedInToESPN || !espnLeagues.isEmpty {
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

                AccountLeaguesSection(model: model) { showingLeagueEditor = true }
                AccountAboutSection(model: model)
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
            PlatformMark(platform: platform, size: SWSize.markLarge)
            VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                Text(title)
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.primary)
                detail()
            }
            Spacer()
            trailing()
        }
    }

    /// A row's one action. Destructive ones are quieter than the way in.
    private func action(
        _ title: LocalizedStringKey, label: LocalizedStringKey, role: ButtonRole? = nil,
        perform: @escaping () -> Void
    ) -> some View {
        Button(title, role: role, action: perform)
            .font(role == .destructive ? SWType.caption : SWType.bodyMedium)
            .buttonStyle(.borderless)
            .frame(minHeight: SWSize.hitTarget)
            .accessibilityLabel(label)
    }

    private func statusText(_ text: LocalizedStringKey) -> some View {
        Text(text)
            .font(SWType.caption)
            .foregroundStyle(SWColor.secondary)
    }

    private var espnStatus: LocalizedStringKey {
        if signedInToESPN { return "Signed in" }
        let count = LeagueIDs.parse(espnLeagues).count
        return count == 0 ? "Not connected" : "\(count) leagues by ID"
    }

    private var mflStatus: LocalizedStringKey {
        if signedInToMFL { return "Signed in" }
        let count = LeagueIDs.parse(mflLeagues).count
        return count == 0 ? "Not connected" : "\(count) leagues by ID"
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
