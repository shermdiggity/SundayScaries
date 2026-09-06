import SwiftUI
import UIKit

/// Answers, at the moment a tap lands, whether the screen it sits in is still on the
/// navigation stack.
///
/// The zoom transition's swipe-to-close pops the screen's controller the instant the
/// gesture begins; SwiftUI's `navigationDestination(item:)` binding is cleared only when
/// the pop ANIMATION completes. In between, the screen is visibly gone, still
/// hit-testable, and still believes it is the selected league — so a tap where a player
/// row was presented a sheet from a dead screen. Gating on the selection cannot close
/// that window; only UIKit's stack can. `isOnStack()` walks from this view to its
/// hosting controller and asks the navigation controller whether it still holds it.
struct NavigationStackProbe: UIViewRepresentable {
    let onAttach: (_ isOnStack: @escaping @MainActor () -> Bool) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        onAttach { [weak view] in view?.isOnNavigationStack ?? false }
    }

    final class ProbeView: UIView {
        override var intrinsicContentSize: CGSize { .zero }

        /// True while some ancestor controller is in its navigation controller's stack.
        /// A view with no navigation controller at all (a sheet) is presented, not
        /// pushed, and counts as on.
        var isOnNavigationStack: Bool {
            var controller = nearestController
            var sawNavigation = false
            while let current = controller {
                if let navigation = current.navigationController {
                    sawNavigation = true
                    if navigation.viewControllers.contains(current) { return true }
                }
                controller = current.parent
            }
            return !sawNavigation
        }

        private var nearestController: UIViewController? {
            var responder: UIResponder? = self
            while let current = responder {
                if let controller = current as? UIViewController { return controller }
                responder = current.next
            }
            return nil
        }
    }
}
