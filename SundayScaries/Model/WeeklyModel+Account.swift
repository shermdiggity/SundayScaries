import Foundation
import FantasyCore
import FantasyProviders

/// What the reader has connected, kept in `UserDefaults` because none of it is secret:
/// handles, league ids, and which leagues are hidden or in what order. The credentials
/// themselves live in the keychain behind the `*CredentialStore` types.
extension WeeklyModel {
    var handle: String {
        get { UserDefaults.standard.string(forKey: Self.handleKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.handleKey) }
    }

    /// ESPN league ids, comma separated. ESPN has no public "list my leagues" endpoint —
    /// the one that exists sits behind the same login as a private league — so the user
    /// names their leagues and the credentials decide whether private ones can be read.
    var espnLeagueIDs: String {
        get { UserDefaults.standard.string(forKey: Self.espnLeaguesKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.espnLeaguesKey) }
    }

    /// Leagues the user has hidden, and the order they want the rest in.
    ///
    /// Held by league id rather than by index, so adding or leaving a league cannot
    /// silently reshuffle everything else. An id that is not in `leagueOrder` yet — a
    /// league joined since the order was set — sorts to the end by name rather than
    /// disappearing.
    var hiddenLeagueIDs: Set<String> {
        get { Set(UserDefaults.standard.stringArray(forKey: Self.hiddenKey) ?? []) }
        set { UserDefaults.standard.set(Array(newValue), forKey: Self.hiddenKey) }
    }

    var leagueOrder: [String] {
        get { UserDefaults.standard.stringArray(forKey: Self.orderKey) ?? [] }
        set { UserDefaults.standard.set(newValue, forKey: Self.orderKey) }
    }

    private static let handleKey = "sleeperHandle"
    private static let espnLeaguesKey = "espnLeagueIDs"
    private static let mflLeaguesKey = "mflLeagueIDs"
    private static let fleaflickerKey = "fleaflickerHandle"
    private static let hiddenKey = "hiddenLeagueIDs"
    private static let orderKey = "leagueOrder"

    var hasSleeper: Bool { !handle.trimmingCharacters(in: .whitespaces).isEmpty }

    /// MyFantasyLeague: public league ids typed in, or a sign-in that lists the user's.
    var mflLeagueIDs: String {
        get { UserDefaults.standard.string(forKey: Self.mflLeaguesKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.mflLeaguesKey) }
    }

    var isSignedInToMFL: Bool { MFLCredentialStore.current != nil }
    var hasMFL: Bool { !LeagueIDs.parse(mflLeagueIDs).isEmpty || isSignedInToMFL }

    /// Fleaflicker: the account's email, or its numeric user id. No password exists.
    var fleaflickerHandle: String {
        get { UserDefaults.standard.string(forKey: Self.fleaflickerKey) ?? "" }
        set { UserDefaults.standard.set(newValue, forKey: Self.fleaflickerKey) }
    }

    var hasFleaflicker: Bool { !fleaflickerHandle.trimmingCharacters(in: .whitespaces).isEmpty }

    var hasYahoo: Bool { FeatureFlags.yahooEnabled && YahooCredentialStore.current != nil }

    /// The handle a platform's error message should quote.
    func handle(for platform: Platform) -> String {
        switch platform {
        case .sleeper:         handle
        case .fleaflicker:     fleaflickerHandle
        case .myFantasyLeague: mflLeagueIDs
        case .espn:            espnLeagueIDs
        default:               ""
        }
    }

    /// Signing in is enough on its own: with no ids typed, the provider asks ESPN which
    /// leagues this account plays in. Requiring an id here meant signing in did nothing
    /// at all, which is how this first went wrong.
    var hasESPN: Bool { !LeagueIDs.parse(espnLeagueIDs).isEmpty || isSignedInToESPN }
    var isSignedInToESPN: Bool { ESPNCredentialStore.current != nil }

    var hasAccount: Bool { hasSleeper || hasESPN || hasMFL || hasFleaflicker || hasYahoo }

    /// The NFL league year rolls over in March.
    static func currentSeason(now: Date = Date(), calendar: Calendar = .current) -> String {
        let year = calendar.component(.year, from: now)
        let month = calendar.component(.month, from: now)
        return String(month >= 3 ? year : year - 1)
    }
}
