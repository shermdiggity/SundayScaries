import SwiftUI
import WebKit
import FantasyCore
import FantasyProviders

/// Sign in to ESPN, and keep the two cookies that read a private league.
///
/// ESPN has no sanctioned API and no OAuth. The only way to read a private league is the
/// session a browser gets: `SWID` identifies the account, `espn_s2` authorises it. So
/// this hosts ESPN's own login page and takes those two cookies when they appear.
///
/// What this deliberately does NOT do: touch the password. The page is ESPN's, served
/// from ESPN, and nothing here reads the form, injects script into it, or observes what
/// is typed. The only thing taken is the session that login produces — and it goes
/// straight to the keychain.
///
/// The store is the DEFAULT one, not an ephemeral one, and that is load-bearing.
/// ESPN's login is cross-site — you authenticate against `registerdisney.go.com` and the
/// resulting session has to be readable by `espn.com` — and an ephemeral store applies a
/// much stricter cross-site cookie policy. With `nonPersistent()` the sign-in appeared to
/// succeed and then the very next page asked you to log in again, because the session
/// never carried. Hygiene is handled afterwards instead: the moment the credentials are
/// in the keychain, every trace of the session is wiped from the store.
struct ESPNLoginView: View {
    /// Handed the credentials the moment both cookies exist.
    var onCapture: (ESPNCredentials) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var captured = false
    @State private var status: String?
    @State private var showingManual = false
    @State private var goHome = 0
    @State private var backToSignIn = 0

    /// One tap: sign in above, then import.
    ///
    /// The mechanics behind this button are ugly — ESPN only issues the session it needs
    /// when a fantasy page loads while signed in, and their login is a JavaScript overlay
    /// with no redirect to hook, so the hop cannot be folded into a URL. None of that is
    /// the reader's problem, so none of it is on screen. The button says what it does.
    ///
    /// It stays something YOU tap rather than something detected. Three earlier versions
    /// made this jump automatically and every one interrupted a sign-in in progress,
    /// because each cookie that looked like proof of login turned out to exist for
    /// signed-out visitors too.
    private var finishBar: some View {
        VStack(spacing: SWSpacing.sm) {
            if let status {
                Text(status)
                    .font(SWType.caption)
                    .foregroundStyle(SWColor.secondary)
                    .multilineTextAlignment(.center)
            }

            Button {
                goHome += 1
            } label: {
                Text("Once signed in, tap here to import leagues")
                    .font(SWType.bodyMedium)
                    .foregroundStyle(SWColor.canvas)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, SWSpacing.md)
                    .background(Capsule().fill(SWColor.accent))
                    .contentShape(Capsule())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, SWSpacing.lg)
        .padding(.vertical, SWSpacing.md)
        .background(.bar)
        .animation(SWMotion.standard, value: status)
    }

    var body: some View {
        NavigationStack {
            ESPNLoginWebView(
                goHome: goHome,
                backToSignIn: backToSignIn,
                onStatus: { status = $0 },
                onCapture: { credentials in
                    guard !captured else { return }
                    captured = true
                    onCapture(credentials)
                    dismiss()
                }
            )
            .safeAreaInset(edge: .bottom) { finishBar }
            .feedback(.signInSucceeded, trigger: captured) { _, new in new }
            .navigationTitle("Sign in to ESPN")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                // ESPN has no sanctioned API and this flow depends on how their login
                // happens to behave today. A way through by hand means a change on their
                // side costs a bad afternoon, not the whole feature.
                ToolbarItem(placement: .primaryAction) {
                    Menu {
                        // If ESPN lands you somewhere unhelpful, this gets you back to a
                        // page that works — driven by you, never automatically.
                        Button("Back to sign-in page") { backToSignIn += 1 }
                        Button("Paste cookies instead") { showingManual = true }
                    } label: {
                        Image(systemName: "ellipsis.circle")
                            .accessibilityLabel("More options")
                    }
                }
            }
            .sheet(isPresented: $showingManual) {
                ESPNManualCredentialsView { credentials in
                    guard !captured else { return }
                    captured = true
                    onCapture(credentials)
                    showingManual = false
                    dismiss()
                }
            }
        }
        .tint(SWColor.accent)
    }
}

/// The web view, plus a cookie-store observer.
///
/// It hosts ESPN's login and watches for the result. That is the entire job, and the
/// restraint is the design: **it never navigates anywhere by itself.**
///
/// Three versions of this did navigate, each trying to shepherd the user towards the
/// page that mints `espn_s2`, and each one broke the sign-in it was trying to help. The
/// trap both times was a cookie that looked like proof of login and was not — first
/// `SWID`, which ESPN issues to every visitor as a device id, then
/// `ESPN-ONESITE.WEB-PROD.api`, which is OneID's client configuration and is likewise
/// present before anyone has typed a password. Acting on either meant redirecting the
/// user off the login form seconds after it appeared.
///
/// There is no cookie that reliably means "signed in" from the outside, so this stops
/// guessing at one. ESPN's own flow decides where to go; this watches the cookie jar and
/// captures the pair when they land.
///
/// Watching the cookie store rather than navigation matters for a different reason:
/// ESPN's login is a Disney OneID flow that finishes inside an iframe with an XHR, so
/// there is often no page load to hang a check on. `WKHTTPCookieStoreObserver` fires
/// whenever a cookie changes, whatever caused it.
private struct ESPNLoginWebView: UIViewRepresentable {
    /// Incremented by the toolbar to send the web view back to the fantasy home.
    var goHome: Int
    /// Incremented by the menu to return to the sign-in page.
    var backToSignIn: Int
    var onStatus: (String) -> Void
    var onCapture: (ESPNCredentials) -> Void

    /// ESPN's own "Find My Team" page — the one place in fantasy whose entire purpose is
    /// "sign in and we will show you your leagues".
    ///
    /// Two earlier choices were wrong in different ways. `/football/team` is a team
    /// clubhouse and needs a `leagueId`, so signing in arrived at "Invalid league ID" —
    /// that string ships in the page's own HTML — and a fantasy page that errors never
    /// completes the handshake that issues `espn_s2`. `/football/welcome` works, but it
    /// is marketing: it has no visible sign-in button, so a signed-out user lands on it
    /// with nothing to do. This page has one, and is exactly what someone connecting
    /// their ESPN account expects to see.
    static let fantasyHome = URL(string: "https://fantasy.espn.com/find-my-team")
        ?? URL(fileURLWithPath: "/invalid-espn-login-url")

    /// Where the import button goes: ESPN's fantasy hub.
    static let fantasyLanding = URL(string: "https://www.espn.com/fantasy/")
        ?? URL(fileURLWithPath: "/invalid-espn-landing-url")

    /// Safari's own user agent. Without it, WKWebView on iOS 17.5+ fails to bring up its
    /// content process and logs a wall of `com.apple.developer.web-browser-engine.*`
    /// entitlement errors — entitlements only an alternative browser engine can hold, so
    /// there is nothing to grant and nothing to chase.
    private static let userAgent =
        "Mozilla/5.0 (iPhone; CPU iPhone OS 18_0 like Mac OS X) AppleWebKit/605.1.15 "
            + "(KHTML, like Gecko) Version/18.0 Mobile/15E148 Safari/604.1"

    func makeCoordinator() -> Coordinator { Coordinator(onStatus: onStatus, onCapture: onCapture) }

    func makeUIView(context: Context) -> WKWebView {
        let configuration = WKWebViewConfiguration()
        configuration.websiteDataStore = .default()
        // Disney's login opens at least one of its steps in a new window. Without this,
        // WKWebView silently drops `target="_blank"` and the flow dead-ends on a page
        // that looks fine and does nothing.
        configuration.preferences.javaScriptCanOpenWindowsAutomatically = true

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator
        webView.uiDelegate = context.coordinator
        webView.customUserAgent = Self.userAgent
        webView.allowsBackForwardNavigationGestures = true

        let cookies = configuration.websiteDataStore.httpCookieStore
        cookies.add(context.coordinator)
        context.coordinator.cookieStore = cookies

        webView.load(URLRequest(url: Self.fantasyHome))
        return webView
    }

    func updateUIView(_ webView: WKWebView, context: Context) {
        // Only ever in response to a tap. This view does not navigate on its own.
        if goHome != context.coordinator.lastGoHome {
            context.coordinator.lastGoHome = goHome
            // The fantasy page, not the sign-in page: this load mints `espn_s2`.
            webView.load(URLRequest(url: Self.fantasyLanding))
        } else if backToSignIn != context.coordinator.lastBackToSignIn {
            context.coordinator.lastBackToSignIn = backToSignIn
            webView.load(URLRequest(url: Self.fantasyHome))
        }
    }

    static func dismantleUIView(_ webView: WKWebView, coordinator: Coordinator) {
        coordinator.cookieStore?.remove(coordinator)
        // Cancel, or a sign-in that never minted `espn_s2`, used to leave the Disney
        // session sitting in the app's shared web store. The wipe runs on every exit.
        coordinator.wipeSession()
    }

    final class Coordinator: NSObject, WKNavigationDelegate, WKUIDelegate, WKHTTPCookieStoreObserver {
        private let onStatus: (String) -> Void
        private let onCapture: (ESPNCredentials) -> Void
        private var finished = false
        private var toldUserItFailed = false
        /// The names last reported, so the log records what CHANGED. ESPN rewrites
        /// analytics cookies constantly and the unchanged forty-name list drowned the
        /// one line that mattered.
        private var lastLoggedNames: Set<String> = []
        private var firstSeen: Date?
        var lastGoHome = 0
        var lastBackToSignIn = 0
        weak var cookieStore: WKHTTPCookieStore?

        init(
            onStatus: @escaping (String) -> Void,
            onCapture: @escaping (ESPNCredentials) -> Void
        ) {
            self.onStatus = onStatus
            self.onCapture = onCapture
        }

        func cookiesDidChange(in cookieStore: WKHTTPCookieStore) {
            harvest(from: cookieStore)
        }

        func webView(_ webView: WKWebView, didFinish navigation: WKNavigation!) {
            log("loaded \(webView.url?.host ?? "?")\(webView.url?.path ?? "")")
            if let store = cookieStore { harvest(from: store) }
        }

        /// A window ESPN asks to open in a new tab is loaded in THIS one instead.
        /// Returning nil — which is what happens with no `WKUIDelegate` — drops the
        /// request on the floor and the login stalls with no error anywhere.
        func webView(
            _ webView: WKWebView,
            createWebViewWith configuration: WKWebViewConfiguration,
            for navigationAction: WKNavigationAction,
            windowFeatures: WKWindowFeatures
        ) -> WKWebView? {
            if navigationAction.targetFrame == nil, let url = navigationAction.request.url {
                log("popup redirected inline: \(url.host ?? "?")")
                webView.load(navigationAction.request)
            }
            return nil
        }

        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: any Error) {
            log("navigation failed: \(error.localizedDescription)")
        }

        func webView(
            _ webView: WKWebView,
            didFailProvisionalNavigation navigation: WKNavigation!,
            withError error: any Error
        ) {
            log("could not load page: \(error.localizedDescription)")
        }

        private func harvest(from store: WKHTTPCookieStore) {
            guard !finished else { return }
            store.getAllCookies { [weak self] cookies in
                guard let self, !self.finished else { return }
                let espn = cookies.filter { $0.domain.hasSuffix("espn.com") || $0.domain.hasSuffix("go.com") }
                let swid = espn.first { $0.name == "SWID" }?.value
                let s2 = espn.first { $0.name == "espn_s2" }?.value

                guard let swid, let s2, !swid.isEmpty, !s2.isEmpty else {
                    reportChanges(Set(espn.map(\.name)))
                    return
                }

                finished = true
                log("captured both cookies")
                // The observer fires off the main actor; the UI update must not.
                Task { @MainActor in
                    self.onCapture(ESPNCredentials(swid: swid, espnS2: s2))
                    self.wipeSession()
                }
            }
        }

        /// Logs only what changed, and after long enough with no `espn_s2`, points at
        /// the way through by hand. It does NOT navigate: every automatic navigation
        /// this view ever attempted interrupted a sign-in in progress.
        private func reportChanges(_ names: Set<String>) {
            if names != lastLoggedNames {
                let added = names.subtracting(lastLoggedNames).sorted()
                lastLoggedNames = names
                if !added.isEmpty { log("new cookies: [\(added.joined(separator: ", "))]") }
            }

            let now = Date()
            guard let firstSeen else {
                firstSeen = now
                return
            }
            guard now.timeIntervalSince(firstSeen) > 60, !toldUserItFailed else { return }
            toldUserItFailed = true
            log("no espn_s2 after 60s — \(names.count) other cookies present")
            Task { @MainActor in
                self.onStatus(String(localized: "Still not connected — try Paste instead from the menu"))
            }
        }

        /// Clears the web view's stored session once the credentials are in the keychain.
        /// The default store is shared and persistent, so without this a live ESPN login
        /// would be left sitting inside the app.
        @MainActor
        func wipeSession() {
            let store = WKWebsiteDataStore.default()
            let types = WKWebsiteDataStore.allWebsiteDataTypes()
            store.fetchDataRecords(ofTypes: types) { records in
                let espn = records.filter {
                    $0.displayName.contains("espn") || $0.displayName.contains("go.com")
                        || $0.displayName.contains("disney")
                }
                store.removeData(ofTypes: types, for: espn) {}
            }
        }

        /// Names only. A session cookie's VALUE is a live credential and never belongs in
        /// a log line, a crash report, or a screenshot of the console.
        private func log(_ message: String) {
            #if DEBUG
            print("[espn-login] \(message)")
            #endif
        }
    }
}

/// The way in by hand, for when ESPN's login does not cooperate.
///
/// Deliberately kept: this app reads ESPN through endpoints ESPN does not document or
/// support, and the login flow it depends on can change without warning. When it does,
/// this is the difference between a broken feature and an inconvenience — and it is the
/// same pair of values the web view captures, so nothing downstream knows the difference.
struct ESPNManualCredentialsView: View {
    var onCapture: (ESPNCredentials) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var swid = ""
    @State private var s2 = ""

    /// Pasted from a browser, so a trailing newline is the common case, and a newline
    /// inside a cookie header is a sign-in that fails for no visible reason.
    private var trimmedSWID: String { swid.trimmingCharacters(in: .whitespacesAndNewlines) }
    private var trimmedS2: String { s2.trimmingCharacters(in: .whitespacesAndNewlines) }

    private var isComplete: Bool { !trimmedSWID.isEmpty && !trimmedS2.isEmpty }

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    TextField("SWID", text: $swid, axis: .vertical)
                    TextField("espn_s2", text: $s2, axis: .vertical)
                } header: {
                    Text("Cookies")
                } footer: {
                    Text("Braces on the SWID are optional — they're added if missing.")
                }

                Section("Where to find them") {
                    VStack(alignment: .leading, spacing: SWSpacing.sm) {
                        step(1, "On a computer, sign in at fantasy.espn.com.")
                        step(2, "Open the browser's developer tools.")
                        step(3, "Find Application (or Storage) → Cookies → espn.com.")
                        step(4, "Copy the values of SWID and espn_s2.")
                    }
                    .padding(.vertical, SWSpacing.xs)
                }
            }
            .textInputAutocapitalization(.never)
            .autocorrectionDisabled()
            .navigationTitle("Paste cookies")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") {
                        onCapture(ESPNCredentials(swid: trimmedSWID, espnS2: trimmedS2))
                    }
                    .disabled(!isComplete)
                }
            }
        }
        .tint(SWColor.accent)
    }

    private func step(_ number: Int, _ text: String) -> some View {
        HStack(alignment: .firstTextBaseline, spacing: SWSpacing.sm) {
            Text("\(number).")
                .font(SWType.micro)
                .foregroundStyle(SWColor.tertiary)
                .monospacedDigit()
            Text(text)
                .font(SWType.caption)
                .foregroundStyle(SWColor.secondary)
        }
    }
}
