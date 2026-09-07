import SwiftUI
import FantasyCore
import FantasyProviders

/// The three platform sign-ins the welcome cards open. Each saves what it was handed
/// and reloads.
struct SignInSheets: ViewModifier {
    let model: WeeklyModel
    @Binding var espn: Bool
    @Binding var mfl: Bool
    @Binding var yahoo: Bool

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: $espn) {
                ESPNLoginView { credentials in
                    ESPNCredentialStore.save(credentials)
                    Task { await model.load() }
                }
            }
            .sheet(isPresented: $mfl) {
                MFLConnectView { credentials in
                    MFLCredentialStore.save(credentials)
                    Task { await model.load() }
                } onLeagueIDs: { ids in
                    model.mflLeagueIDs = ids
                    Task { await model.load() }
                }
            }
            .sheet(isPresented: $yahoo) {
                YahooSignInView { credentials in
                    YahooCredentialStore.save(credentials)
                    Task { await model.load() }
                }
            }
    }
}

/// The live poll. Once a minute it asks one cheap question — is any starter in a game
/// right now? — and only if so does it refresh. On a Tuesday this loop does nothing but
/// sleep. On a Sunday it keeps every number within a minute of true, quietly, without a
/// skeleton ever appearing.
struct LivePoll: ViewModifier {
    let model: WeeklyModel

    func body(content: Content) -> some View {
        content.task {
            while !Task.isCancelled {
                try? await Task.sleep(for: .seconds(60))
                guard !Task.isCancelled, model.hasLiveGame else { continue }
                await model.load(force: true)
            }
        }
    }
}

/// The `[zoom-diag]` frame log CLAUDE.md points at if the stuck-card symptom ever returns:
/// a closed card moving with its neighbour on scroll is a system snapshot, one frozen in
/// place is our layout. Logs only the cards under suspicion, and only in DEBUG.
struct ZoomDiagnostics: ViewModifier {
    let name: String
    let isSubject: Bool

    @State private var lastY: CGFloat = .nan

    func body(content: Content) -> some View {
        #if DEBUG
        content.onGeometryChange(for: CGFloat.self) { $0.frame(in: .global).minY } action: { y in
            guard isSubject, lastY.isNaN || abs(y - lastY) > 4 else { return }
            lastY = y
            print("[zoom-diag] \(name) screenY=\(Int(y))")
        }
        #else
        content
        #endif
    }
}
