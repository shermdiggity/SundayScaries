import SwiftUI
import FantasyCore

/// The words for what the model reports. Copy lives here, beside the screens, so the
/// model never produces a sentence.
extension LoadProblem {
    var message: Text {
        switch self {
        case .playerIndexUnavailable:
            Text("Couldn't load the player index. It downloads once and is cached after that, so this needs a connection the first time.")
        case let .platformFailed(platform, failure, season, handle):
            Self.message(platform: platform, failure: failure, season: season, handle: handle)
        case let .noLeagues(season):
            Text("No leagues found for \(season).")
        case let .espnReturnedNothing(season):
            Text("Signed in to ESPN, but no \(season) leagues came back. If your league is there, add its ID.")
        }
    }

    /// A sign-in problem is the one with an action attached, so it must not read as a
    /// generic network error.
    private static func message(platform: Platform, failure: PlatformFailure, season: String, handle: String) -> Text {
        switch failure {
        case let .unauthorized(message?):
            return Text(verbatim: message)
        case .unauthorized(nil):
            return Text("\(platform.displayName) needs you to sign in again.")
        case let .notFound(resource):
            return Text("\(platform.displayName): couldn't find \(resource).")
        case .other:
            break
        }
        switch platform {
        case .sleeper:
            return Text("Couldn't find leagues for \"\(handle)\" in \(season).")
        case .fleaflicker:
            return Text("Couldn't find Fleaflicker leagues for \"\(handle)\" in \(season). Use the email on the account, or the user id.")
        case .myFantasyLeague:
            return Text("Couldn't load your MyFantasyLeague leagues for \(season). Check the league id, or sign in for a private league.")
        case .yahoo:
            return Text("Couldn't load your Yahoo leagues for \(season).")
        default:
            return Text("Couldn't load your \(platform.displayName) leagues for \(season).")
        }
    }
}

extension SeasonFallback {
    var note: Text {
        Text("Showing \(shown) — \(requested) leagues haven't been created yet.")
    }
}
