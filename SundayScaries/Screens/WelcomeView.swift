import SwiftUI
import FantasyCore

/// The weekly view with nothing in it yet. Not a separate flow: the same sky, the same
/// voice, and a way in per platform. The moment one connects, the screen turns into the
/// real one in place — skeletons where the cards will be — and that is the onboarding.
///
/// It is also the way BACK in when a connect failed: a mistyped handle is left in its
/// field, ready to be fixed, rather than persisted and hidden behind an error.
struct WelcomeView: View {
    let model: WeeklyModel
    @Binding var showingESPNLogin: Bool
    @Binding var showingMFLConnect: Bool
    @Binding var showingYahooLogin: Bool
    /// One load for a connect the reader just made. The owner counts how it went.
    let connect: () async -> Void

    @State private var sleeperDraft = ""
    @State private var isEnteringSleeper = false
    @State private var fleaflickerDraft = ""
    @State private var isEnteringFleaflicker = false
    @FocusState private var sleeperFieldFocused: Bool
    @FocusState private var fleaflickerFieldFocused: Bool

    /// The weekly view with nothing in it yet. Not a separate flow: the same sky, the same
    /// voice, and two ways in. The moment either connects, this turns into the real
    /// screen in place — skeletons where the cards will be — and that is the onboarding.
    var body: some View {
        VStack(alignment: .leading, spacing: SWSpacing.xl) {
            VStack(alignment: .leading, spacing: SWSpacing.sm) {
                Text("Your whole Sunday, one screen.")
                    .swVoice(SWType.displayFace)
                    .foregroundStyle(SWColor.onSky)
                    .shadow(color: .black.opacity(0.35), radius: 6, y: 1)
                    .lineLimit(2)
                    .minimumScaleFactor(0.6)
                Text("Every league you're in. Live scores, who you're relying on, who's coming for you.")
                    .font(SWType.body)
                    .foregroundStyle(SWColor.onSkySecondary)
                    // Same legibility shadow as the headline: midday white cloud is the
                    // case that breaks bare light type over the sky.
                    .shadow(color: .black.opacity(0.3), radius: 4, y: 1)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(spacing: SWSpacing.md) {
                connectCard(.sleeper, detail: "Just your username. No password.") {
                    withAnimation(SWMotion.standard) { isEnteringSleeper.toggle() }
                }
                if isEnteringSleeper {
                    HStack(spacing: SWSpacing.sm) {
                        TextField("Sleeper username", text: $sleeperDraft)
                            .font(SWType.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .submitLabel(.go)
                            .focused($sleeperFieldFocused)
                            .onSubmit(connectSleeper)
                        Button("Connect", action: connectSleeper)
                            .font(SWType.bodyMedium)
                            .disabled(sleeperDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, SWSpacing.lg)
                    .padding(.vertical, SWSpacing.md)
                    .leagueSurface()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
                connectCard(.espn, detail: "Sign in on ESPN's page. We keep nothing but your session.") {
                    showingESPNLogin = true
                }
                if FeatureFlags.yahooEnabled {
                    connectCard(.yahoo, detail: "Yahoo's official sign-in. Your password never comes here.") {
                        showingYahooLogin = true
                    }
                }
                connectCard(.myFantasyLeague, detail: "Sign in, or paste a public league's ID.") {
                    showingMFLConnect = true
                }
                connectCard(.fleaflicker, detail: "Just the email on your account. No password.") {
                    withAnimation(SWMotion.standard) { isEnteringFleaflicker.toggle() }
                }
                if isEnteringFleaflicker {
                    HStack(spacing: SWSpacing.sm) {
                        TextField("Email on your Fleaflicker account", text: $fleaflickerDraft)
                            .font(SWType.body)
                            .textInputAutocapitalization(.never)
                            .autocorrectionDisabled()
                            .keyboardType(.emailAddress)
                            .submitLabel(.go)
                            .focused($fleaflickerFieldFocused)
                            .onSubmit(connectFleaflicker)
                        Button("Connect", action: connectFleaflicker)
                            .font(SWType.bodyMedium)
                            .disabled(fleaflickerDraft.trimmingCharacters(in: .whitespaces).isEmpty)
                    }
                    .padding(.horizontal, SWSpacing.lg)
                    .padding(.vertical, SWSpacing.md)
                    .leagueSurface()
                    .transition(.opacity.combined(with: .move(edge: .top)))
                }
            }
        }
        .onAppear {
            // A handle that failed comes back into its field, ready to be fixed.
            if sleeperDraft.isEmpty { sleeperDraft = model.handle }
            if fleaflickerDraft.isEmpty { fleaflickerDraft = model.fleaflickerHandle }
        }
        .onChange(of: isEnteringSleeper) { _, entering in
            // Focus after the field exists. Set in the same update that creates it,
            // the focus request had nothing to land on.
            if entering { sleeperFieldFocused = true }
        }
        .onChange(of: isEnteringFleaflicker) { _, entering in
            if entering { fleaflickerFieldFocused = true }
        }
    }

    private func connectFleaflicker() {
        let handle = fleaflickerDraft.trimmingCharacters(in: .whitespaces)
        guard !handle.isEmpty else { return }
        fleaflickerFieldFocused = false
        model.fleaflickerHandle = handle
        Task { await connect() }
    }

    /// One way in. The platform's own mark, its name, one honest line about what
    /// connecting involves, and a chevron. The same surface the league cards wear, so
    /// the moment it becomes one nothing about the screen's material changes.
    private func connectCard(_ platform: Platform, detail: String, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack(spacing: SWSpacing.md) {
                PlatformMark(platform: platform, size: SWSize.markLarge)
                VStack(alignment: .leading, spacing: SWSpacing.xxs) {
                    Text(platform.displayName)
                        .font(SWType.cardTitle)
                        .foregroundStyle(SWColor.primary)
                    Text(detail)
                        .font(SWType.caption)
                        .foregroundStyle(SWColor.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
                Spacer(minLength: SWSpacing.sm)
                Image(systemName: "chevron.right")
                    .font(SWType.glyph)
                    .foregroundStyle(SWColor.tertiary)
                    .accessibilityHidden(true)
            }
            .padding(SWSpacing.lg)
            .leagueSurface()
            .contentShape(.rect(cornerRadius: SWRadius.lg))
        }
        .buttonStyle(.plain)
    }

    private func connectSleeper() {
        let handle = sleeperDraft.trimmingCharacters(in: .whitespaces)
        guard !handle.isEmpty else { return }
        sleeperFieldFocused = false
        model.handle = handle
        Task { await connect() }
    }
}
