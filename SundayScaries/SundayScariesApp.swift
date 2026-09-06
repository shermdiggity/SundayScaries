import SwiftUI

@main
struct SundayScariesApp: App {
    init() {
        FontRegistrar.registerAll()
        // Headshots are static files with long cache headers, so a generous disk cache
        // makes the second launch nearly free.
        ImageCache.configureDiskCache()
        // Must happen before launch finishes: the widgets' off-screen refresh.
        BackgroundRefresh.register()
    }

    var body: some Scene {
        WindowGroup {
            ContentView()
                .preferredColorScheme(.dark)
        }
    }
}
