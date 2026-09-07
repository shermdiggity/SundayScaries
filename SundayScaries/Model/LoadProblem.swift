import Foundation
import FantasyCore
import FantasyProviders

/// Why a load could not show everything. The screen turns it into words; the model
/// only says what happened.
enum LoadProblem: Equatable {
    /// The player index could not be fetched and nothing was cached.
    case playerIndexUnavailable
    /// One platform failed while listing its leagues. The others may have worked.
    case platformFailed(Platform, PlatformFailure, season: String, handle: String)
    /// Nothing failed, and nothing came back.
    case noLeagues(season: String)
    /// Signed in to ESPN only, and it returned no leagues.
    case espnReturnedNothing(season: String)
    /// The kill switch has paused this platform; the reason is what the switch said.
    case platformDisabled(Platform, reason: String)
}

/// The part of a provider error the screen distinguishes.
enum PlatformFailure: Equatable {
    /// The platform wants a sign-in; the message is the platform's own, if it gave one.
    case unauthorized(message: String?)
    case notFound(resource: String)
    case other

    init(_ error: any Error) {
        switch error {
        case let ProviderError.unauthorized(_, message): self = .unauthorized(message: message)
        case let ProviderError.notFound(resource):       self = .notFound(resource: resource)
        default:                                         self = .other
        }
    }
}

/// The requested season had no leagues, so the one before it is on screen.
struct SeasonFallback: Equatable {
    let shown: String
    let requested: String
}
