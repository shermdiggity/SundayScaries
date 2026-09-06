import SwiftUI

/// The moments that earn a haptic, named once. Every screen goes through `.feedback`;
/// nothing else plays `.sensoryFeedback` directly, and nothing fires on scroll, on
/// appearance, or on data arriving without a touch. The system's Haptics setting is
/// honoured by `.sensoryFeedback` itself.
enum SWFeedback {
    /// The detail screen's refresh button finished: a tap on glass over the sky needs an
    /// end as clear as its spinner.
    case refreshCompleted
    /// A sign-in the reader typed was refused. The message lands below the field, out of
    /// the eyeline while they look at the keyboard.
    case signInFailed
    /// A sign-in worked. The sheet closes and the screen turns to skeletons; this marks
    /// it before anything visible does.
    case signInSucceeded
    /// A league was hidden or shown in the editor. The row stays put and only an icon
    /// tints, so the switch needs to be felt.
    case leagueVisibilityChanged

    var sensory: SensoryFeedback {
        switch self {
        case .refreshCompleted, .signInSucceeded: .success
        case .signInFailed:                       .error
        case .leagueVisibilityChanged:            .selection
        }
    }
}

extension View {
    /// Plays `moment` whenever `trigger` changes.
    func feedback(_ moment: SWFeedback, trigger: some Equatable) -> some View {
        sensoryFeedback(moment.sensory, trigger: trigger)
    }

    /// Plays `moment` when `trigger` changes and `condition` holds for that change.
    func feedback<T: Equatable>(
        _ moment: SWFeedback, trigger: T, when condition: @escaping (_ old: T, _ new: T) -> Bool
    ) -> some View {
        sensoryFeedback(trigger: trigger) { old, new in condition(old, new) ? moment.sensory : nil }
    }
}
