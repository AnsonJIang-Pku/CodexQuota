import AppKit
import CodexQuotaCore

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var menuBarController: MenuBarController?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)
        let service = QuotaRefreshService()
        let controller = MenuBarController(refreshService: service)
        menuBarController = controller
        controller.start()
    }

    func applicationWillTerminate(_ notification: Notification) {
        // The service owns no persistent credentials or files.
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool {
        false
    }
}
