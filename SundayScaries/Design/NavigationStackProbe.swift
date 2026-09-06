import SwiftUI
import UIKit

/// One clock for every `[detail-diag]` line, so the order of a swipe, a pop and a tap can
/// be read straight off the console. Seconds within the hour, to the millisecond.
func diagStamp() -> String {
    let t = Date().timeIntervalSince1970
    return String(format: "%.3f", t.truncatingRemainder(dividingBy: 1000))
}

/// DEBUG-only console line for the dismissal diagnosis. Compiles to nothing in release.
func diagLog(_ message: @autoclosure () -> String) {
    #if DEBUG
    print("[detail-diag] \(diagStamp()) \(message())")
    #endif
}

/// Answers, at the moment a tap lands, whether the screen it sits in may present.
///
/// Two things UIKit knows and SwiftUI does not. First, whether the screen is still on
/// the navigation stack: the zoom transition's swipe-to-close pops the controller before
/// the `navigationDestination(item:)` binding clears. Second, whether a navigation
/// transition is in flight. A short swipe-to-close that does not travel far enough is
/// CANCELLED as a dismissal, and the same touch is then delivered as a tap on whatever
/// row it started on — with the controller on the stack, on top, and looking perfectly
/// alive. The console showed exactly that (`transition=true cancelled=true` on the tap
/// that opened a sheet), and the cancelled dismissal then completed anyway and popped
/// the screen out from under its sheet. So a tap presents only when the stack holds the
/// screen AND no transition coordinator exists. Outside a transition UIKit has none, so
/// nothing is refused on a settled screen.
struct NavigationStackProbe: UIViewRepresentable {
    let onAttach: (_ canPresent: @escaping @MainActor () -> Bool, _ describe: @escaping @MainActor () -> String) -> Void

    func makeUIView(context: Context) -> ProbeView {
        let view = ProbeView()
        view.isUserInteractionEnabled = false
        view.isAccessibilityElement = false
        return view
    }

    func updateUIView(_ view: ProbeView, context: Context) {
        onAttach({ [weak view] in view?.canPresent ?? false }, { [weak view] in view?.diagnostics ?? "probe gone" })
    }

    final class ProbeView: UIView {
        override var intrinsicContentSize: CGSize { .zero }

        /// On the stack, and not mid-transition. See the type's note.
        var canPresent: Bool {
            isOnNavigationStack && nearestController?.navigationController?.transitionCoordinator == nil
        }

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

        #if DEBUG
        override func didMoveToWindow() {
            super.didMoveToWindow()
            diagLog("probe window=\(window != nil) \(window == nil ? "(detail LEFT the window)" : "(detail ENTERED the window)")")
        }

        /// Everything that could explain why a tap reached this screen.
        var diagnostics: String {
            var alpha: CGFloat = 1, hidden = false, transformed = false, view: UIView? = self
            while let current = view {
                alpha *= current.alpha
                hidden = hidden || current.isHidden
                if !current.transform.isIdentity { transformed = true }
                view = current.superview
            }
            let controller = nearestController
            var chain: [String] = []
            var cursor = controller
            while let current = cursor { chain.append(String(describing: type(of: current))); cursor = current.parent }
            let nav = controller?.navigationController
            let top = nav?.topViewController
            var topIsMine = false
            cursor = controller
            while let current = cursor { if current === top { topIsMine = true }; cursor = current.parent }
            let frame = window.map { convert(bounds, to: $0) } ?? .zero
            return [
                "t=\(diagStamp()) window=\(window != nil) alpha=\(alpha) hidden=\(hidden) transformed=\(transformed) frameInWindow=\(frame) screen=\(window?.bounds.size ?? .zero)",
                "chain=\(chain.joined(separator: " > "))",
                "nav=\(nav != nil) stack=\(nav?.viewControllers.count ?? -1) onStack=\(isOnNavigationStack) canPresent=\(canPresent) topIsMine=\(topIsMine) transition=\(nav?.transitionCoordinator != nil) interactive=\(nav?.transitionCoordinator?.isInteractive ?? false) cancelled=\(nav?.transitionCoordinator?.isCancelled ?? false) movingFromParent=\(controller?.isMovingFromParent ?? false) beingDismissed=\(controller?.isBeingDismissed ?? false)",
            ].joined(separator: "\n   ")
        }
        #endif

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
