import SwiftUI

/// The league cards. A `Button` each, and nothing else around them.
///
/// The exact structure the zoom transition was clean with, restored after two things
/// broke it. First the custom drag put transforms and a shadow around every card, and a
/// card in its own layer is what the transition snapshotted — a hard dark rectangle over
/// the rounded card. Then removing the drag swapped the `Button` for `onTapGesture` plus
/// `onLongPressGesture`, and that was worse: a `LongPressGesture` inside a scroll view
/// delays the pan and is left in a bad state when a transition hands the touch back, so
/// scrolling stopped registering after closing a league and the card twitched. UIKit's
/// button gets touch-versus-scroll right; a raw gesture does not.
///
/// So: a `Button`. Reordering and hiding live in `LeagueEditor`, reached from an explicit
/// control rather than a hidden long press.
struct LeagueStack<Item: Identifiable, Content: View>: View where Item.ID == String {
    let items: [Item]
    var spacing: CGFloat = SWSpacing.lg
    var onSelect: (Item) -> Void
    @ViewBuilder var content: (Item) -> Content

    var body: some View {
        VStack(spacing: spacing) {
            ForEach(items) { item in
                // A Button and NOTHING else. There used to be a `.transition(.opacity)`
                // here, on the container of the zoom transition's source view. It never
                // animated the skeleton-to-card swap it was meant for — that swap happens
                // inside the element, under the same id — but a transition modifier on a
                // zoom source's container can leave the re-inserted source rendering in
                // a detached, viewport-anchored layer after the pop, which is a card that
                // stays put while everything else scrolls and slides behind the next one.
                Button {
                    onSelect(item)
                } label: {
                    content(item)
                }
                .buttonStyle(.plain)
            }
        }
    }
}
