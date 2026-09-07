import Foundation
import BackgroundTasks

/// A refresh while the app is closed, so a widget on a Sunday afternoon is not what was
/// true at breakfast. iOS decides when it runs; the request is renewed after each load,
/// sooner on a game day.
enum BackgroundRefresh {
    static func register() {
        BGTaskScheduler.shared.register(forTaskWithIdentifier: WidgetStore.refreshTaskID, using: nil) { task in
            guard let refresh = task as? BGAppRefreshTask else {
                task.setTaskCompleted(success: false)
                return
            }
            handle(refresh)
        }
    }

    static func schedule(liveSoon: Bool) {
        let request = BGAppRefreshTaskRequest(identifier: WidgetStore.refreshTaskID)
        request.earliestBeginDate = Date(timeIntervalSinceNow: liveSoon ? 15 * 60 : 3 * 3600)
        try? BGTaskScheduler.shared.submit(request)
    }

    private static func handle(_ task: BGAppRefreshTask) {
        let work = Task { @MainActor in
            let model = WeeklyModel()
            await model.load(force: true)
            schedule(liveSoon: model.hasLiveGame)
            // Once expired, the expiration handler has already answered for us. Marking a
            // task complete twice is harmless, but claiming success for work that was
            // cut short is not.
            guard !Task.isCancelled else { return }
            task.setTaskCompleted(success: true)
        }
        // iOS treats a task that expires without completing as a misbehaving app and
        // throttles the next requests, which are the widgets' only lifeline while the
        // app is closed. So: cancel the work AND complete the task, honestly.
        task.expirationHandler = {
            work.cancel()
            task.setTaskCompleted(success: false)
        }
    }
}
