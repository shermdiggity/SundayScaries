import Foundation
import FantasyCore
import FantasyProviders

/// Everything a load needs to talk to the platforms, built fresh for one load so the
/// fetch mode is fixed for its whole duration. Shared by the full load and the
/// single-league refresh so the two can never drift apart.
extension WeeklyModel {
    /// Everything a load needs to talk to the platforms, built fresh for one load so the
    /// fetch mode is fixed for its whole duration. Shared by the full load and the
    /// single-league refresh so the two can never drift apart.
    /// A platform the reader has connected: its provider, and the account to read as.
    struct PlatformSource {
        let provider: any PlatformProvider
        let account: LinkedAccount
    }

    struct LoadContext {
        let sources: [PlatformSource]
        let scheduleStore: ByeWeekStore
        let scoreboard: ScoreboardStore
    }

    /// The disk cache, or memory when Application Support cannot be created.
    static func infrastructure() -> (store: any SnapshotStore, http: URLSessionHTTPClient) {
        ((try? FileSnapshotStore.applicationSupport()) ?? InMemorySnapshotStore(), URLSessionHTTPClient())
    }

    func makeContext(
        http: any HTTPClient, store: any SnapshotStore, crosswalk: PlayerCrosswalk,
        season resolvedSeason: String, mode: FetchMode
    ) -> LoadContext {
        let kit = ProviderContext(
            http: http, store: store, crosswalk: crosswalk, season: resolvedSeason, fetchMode: mode
        )
        playerSeasons = kit.playerSeasons
        loadedSeason = resolvedSeason

        var sources: [PlatformSource] = []
        if hasSleeper, disabledPlatforms[.sleeper] == nil {
            sources.append(PlatformSource(
                provider: kit.sleeper(),
                account: LinkedAccount(platform: .sleeper, handle: handle)
            ))
        }
        if hasESPN, disabledPlatforms[.espn] == nil {
            sources.append(PlatformSource(
                provider: kit.espn(credentials: ESPNCredentialStore.current),
                account: LinkedAccount(platform: .espn, handle: espnLeagueIDs)
            ))
        }
        if hasMFL, disabledPlatforms[.myFantasyLeague] == nil {
            sources.append(PlatformSource(
                provider: kit.myFantasyLeague(credentials: MFLCredentialStore.current),
                account: LinkedAccount(platform: .myFantasyLeague, handle: mflLeagueIDs)
            ))
        }
        if hasFleaflicker, disabledPlatforms[.fleaflicker] == nil {
            sources.append(PlatformSource(
                provider: kit.fleaflicker(),
                account: LinkedAccount(platform: .fleaflicker, handle: fleaflickerHandle)
            ))
        }
        if FeatureFlags.yahooEnabled, disabledPlatforms[.yahoo] == nil, let yahoo = YahooCredentialStore.current {
            sources.append(PlatformSource(
                // A refreshed token is a new credential; it goes back to the keychain.
                provider: kit.yahoo(credentials: yahoo, onCredentialsRefreshed: { YahooCredentialStore.save($0) }),
                account: LinkedAccount(platform: .yahoo, handle: "me")
            ))
        }
        return LoadContext(sources: sources, scheduleStore: kit.schedule, scoreboard: kit.scoreboard)
    }
}
