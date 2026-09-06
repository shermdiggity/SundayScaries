import SwiftUI
import FantasyCore
import FantasyProviders

/// MyFantasyLeague: sign in for private leagues and "which leagues am I in", or paste a
/// public league's id and skip the sign-in entirely. Either way the password is used
/// once, by MFL's own login request, and never kept.
struct MFLConnectView: View {
    var initialLeagueIDs: String = ""
    let onCredentials: (MFLCredentials) -> Void
    let onLeagueIDs: (String) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var username = ""
    @State private var password = ""
    @State private var leagueIDs = ""
    @State private var isSigningIn = false
    @State private var failure: String?

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Username", text: $username)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .textContentType(.username)
                    SecureField("Password", text: $password)
                        .textContentType(.password)
                    Button {
                        signIn()
                    } label: {
                        HStack {
                            Text(isSigningIn ? "Signing in…" : "Sign in")
                            if isSigningIn { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isSigningIn || username.trimmingCharacters(in: .whitespaces).isEmpty || password.isEmpty)
                    if let failure {
                        Text(failure)
                            .font(SWType.caption)
                            .foregroundStyle(SWColor.negative)
                    }
                } header: {
                    Text("Sign in")
                } footer: {
                    Text("Your password goes to MyFantasyLeague once, over HTTPS, and is never stored. Only the sign-in cookie is kept, in the keychain, and it lists the leagues you're in.")
                }

                Section {
                    TextField("League IDs, comma-separated", text: $leagueIDs)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .keyboardType(.numbersAndPunctuation)
                        .submitLabel(.done)
                        .onSubmit(saveIDs)
                    Button("Add leagues") { saveIDs() }
                        .disabled(ESPNProvider.leagueIDs(from: leagueIDs).isEmpty)
                } header: {
                    Text("Or add a public league by ID")
                } footer: {
                    Text("The number in the league's address, after /home/. A public league needs no sign-in.")
                }
            }
            .navigationTitle("MyFantasyLeague")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear { leagueIDs = initialLeagueIDs }
        }
        .tint(SWColor.accent)
    }

    private func signIn() {
        isSigningIn = true
        failure = nil
        let user = username.trimmingCharacters(in: .whitespaces)
        let pass = password
        Task {
            defer { isSigningIn = false }
            do {
                let credentials = try await MFLProvider.login(
                    username: user, password: pass,
                    season: WeeklyModel.currentSeason(), http: URLSessionHTTPClient()
                )
                onCredentials(credentials)
                dismiss()
            } catch let ProviderError.unexpectedStatus(_, body) {
                failure = body ?? "MyFantasyLeague didn't accept that sign-in."
            } catch {
                failure = "Couldn't reach MyFantasyLeague. Check the connection and try again."
            }
        }
    }

    private func saveIDs() {
        let trimmed = leagueIDs.trimmingCharacters(in: .whitespaces)
        guard !ESPNProvider.leagueIDs(from: trimmed).isEmpty else { return }
        onLeagueIDs(trimmed)
        dismiss()
    }
}

/// Yahoo, through its official OAuth 2.0 flow, out of band: Yahoo's page shows a short
/// code after sign-in, and the code is typed back here. Yahoo requires the app's own
/// client id and secret, from a developer app registered at developer.yahoo.com.
struct YahooSignInView: View {
    let onSuccess: (YahooCredentials) -> Void

    @Environment(\.dismiss) private var dismiss
    @Environment(\.openURL) private var openURL
    @State private var clientID = ""
    @State private var clientSecret = ""
    @State private var code = ""
    @State private var isExchanging = false
    @State private var failure: String?
    @State private var openedYahoo = false

    private var haveApp: Bool {
        !clientID.trimmingCharacters(in: .whitespaces).isEmpty && !clientSecret.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("Client ID", text: $clientID)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                    SecureField("Client Secret", text: $clientSecret)
                } header: {
                    Text("Your Yahoo app")
                } footer: {
                    Text("Yahoo's API needs an app of your own: developer.yahoo.com › Create an App. Choose Installed Application, redirect URI oob, and the Fantasy Sports (read) permission. Paste its Client ID and Client Secret here. They're kept in the keychain.")
                }

                Section {
                    Button {
                        if let url = YahooOAuth.authorizationURL(clientID: clientID.trimmingCharacters(in: .whitespaces)) {
                            openedYahoo = true
                            openURL(url)
                        }
                    } label: {
                        Label("Open Yahoo sign-in", systemImage: "arrow.up.right")
                    }
                    .disabled(!haveApp)
                    TextField("Code from Yahoo", text: $code)
                        .textInputAutocapitalization(.never)
                        .autocorrectionDisabled()
                        .submitLabel(.go)
                        .onSubmit(connect)
                    Button {
                        connect()
                    } label: {
                        HStack {
                            Text(isExchanging ? "Connecting…" : "Connect")
                            if isExchanging { Spacer(); ProgressView() }
                        }
                    }
                    .disabled(isExchanging || !haveApp || code.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                    if let failure {
                        Text(failure)
                            .font(SWType.caption)
                            .foregroundStyle(SWColor.negative)
                    }
                } header: {
                    Text("Sign in")
                } footer: {
                    Text(openedYahoo
                         ? "After you sign in, Yahoo shows a short code. Type it above."
                         : "Sign in on Yahoo's own page. Yahoo shows a short code afterwards; type it above.")
                }
            }
            .navigationTitle("Yahoo")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar { ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } } }
            .onAppear {
                // A previous app registration is worth keeping across sign-outs.
                if let existing = YahooCredentialStore.current {
                    clientID = existing.clientID
                    clientSecret = existing.clientSecret
                }
            }
        }
        .tint(SWColor.accent)
    }

    private func connect() {
        isExchanging = true
        failure = nil
        let id = clientID.trimmingCharacters(in: .whitespaces)
        let secret = clientSecret.trimmingCharacters(in: .whitespaces)
        let typed = code
        Task {
            defer { isExchanging = false }
            do {
                let credentials = try await YahooOAuth.exchange(code: typed, clientID: id, clientSecret: secret, http: URLSessionHTTPClient())
                onSuccess(credentials)
                dismiss()
            } catch let ProviderError.unexpectedStatus(_, body) {
                failure = body ?? "Yahoo didn't accept that code."
            } catch {
                failure = "Couldn't reach Yahoo. Check the connection and try again."
            }
        }
    }
}
