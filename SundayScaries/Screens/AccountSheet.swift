import SwiftUI
import FantasyCore
import FantasyProviders

/// The only thing outside the weekly view and the league view: connecting accounts.
struct AccountSheet: View {
    @Bindable var model: WeeklyModel
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

    private var leagueSummary: String {
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
                    HStack(spacing: SWSpacing.md) {
                        PlatformMark(platform: .sleeper, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Sleeper")
                                .font(SWType.bodyMedium)
                                .foregroundStyle(SWColor.primary)
                            TextField("Your username", text: $handle)
                                .font(SWType.caption)
                                .foregroundStyle(handle.isEmpty ? SWColor.tertiary : SWColor.secondary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .submitLabel(.done)
                                .onSubmit(persist)
                        }
                        Spacer()
                        if !handle.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Disconnect", role: .destructive) {
                                handle = ""
                                persist()
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                        }
                    }

                    HStack(spacing: SWSpacing.md) {
                        PlatformMark(platform: .espn, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("ESPN")
                                .font(SWType.bodyMedium)
                                .foregroundStyle(SWColor.primary)
                            Text(signedInToESPN ? "Signed in" : "Not connected")
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.secondary)
                        }
                        Spacer()
                        if signedInToESPN {
                            Button("Sign out", role: .destructive) {
                                ESPNCredentialStore.clear()
                                signedInToESPN = false
                                didSignInThisSession = true
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                        } else {
                            Button("Sign in") { showingESPNLogin = true }
                                .font(SWType.bodyMedium)
                                .buttonStyle(.borderless)
                        }
                    }

                    // Yahoo: the one official OAuth sign-in. Hidden until the API key exists.
                    if FeatureFlags.yahooEnabled {
                    HStack(spacing: SWSpacing.md) {
                        PlatformMark(platform: .yahoo, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Yahoo")
                                .font(SWType.bodyMedium)
                                .foregroundStyle(SWColor.primary)
                            Text(signedInToYahoo ? "Signed in" : "Not connected")
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.secondary)
                        }
                        Spacer()
                        if signedInToYahoo {
                            Button("Sign out", role: .destructive) {
                                YahooCredentialStore.clear()
                                signedInToYahoo = false
                                didSignInThisSession = true
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                        } else {
                            Button("Sign in") { showingYahooLogin = true }
                                .font(SWType.bodyMedium)
                                .buttonStyle(.borderless)
                        }
                    }
                    }

                    // MyFantasyLeague: sign in, or name public leagues by id.
                    HStack(spacing: SWSpacing.md) {
                        PlatformMark(platform: .myFantasyLeague, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("MyFantasyLeague")
                                .font(SWType.bodyMedium)
                                .foregroundStyle(SWColor.primary)
                            Text(mflStatus)
                                .font(SWType.caption)
                                .foregroundStyle(SWColor.secondary)
                        }
                        Spacer()
                        if signedInToMFL {
                            Button("Sign out", role: .destructive) {
                                MFLCredentialStore.clear()
                                signedInToMFL = false
                                didSignInThisSession = true
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
                        } else {
                            Button(mflLeagues.isEmpty ? "Connect" : "Sign in") { showingMFLConnect = true }
                                .font(SWType.bodyMedium)
                                .buttonStyle(.borderless)
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
                    HStack(spacing: SWSpacing.md) {
                        PlatformMark(platform: .fleaflicker, size: 26)
                        VStack(alignment: .leading, spacing: 1) {
                            Text("Fleaflicker")
                                .font(SWType.bodyMedium)
                                .foregroundStyle(SWColor.primary)
                            TextField("Email on your account", text: $fleaflicker)
                                .font(SWType.caption)
                                .foregroundStyle(fleaflicker.isEmpty ? SWColor.tertiary : SWColor.secondary)
                                .textInputAutocapitalization(.never)
                                .autocorrectionDisabled()
                                .keyboardType(.emailAddress)
                                .submitLabel(.done)
                                .onSubmit(persist)
                        }
                        Spacer()
                        if !fleaflicker.trimmingCharacters(in: .whitespaces).isEmpty {
                            Button("Disconnect", role: .destructive) {
                                fleaflicker = ""
                                persist()
                            }
                            .font(SWType.caption)
                            .buttonStyle(.borderless)
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
                    if let note = model.seasonNote {
                        Text(note)
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

    private var mflStatus: String {
        if signedInToMFL { return "Signed in" }
        let count = ESPNProvider.leagueIDs(from: mflLeagues).count
        return count == 0 ? "Not connected" : (count == 1 ? "1 league by ID" : "\(count) leagues by ID")
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
