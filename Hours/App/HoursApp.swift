import AppKit

/// Entry point. Builds the store, clock and status item, and keeps them alive.
@main
@MainActor
final class HoursApp: NSObject, NSApplicationDelegate {
    private var store: Store?
    private var clock: Clock?
    private var statusItem: StatusItemController?

    static func main() {
        let app = NSApplication.shared
        let delegate = HoursApp()
        app.delegate = delegate
        app.setActivationPolicy(.accessory)
        withExtendedLifetime(delegate) { app.run() }
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        // Unit tests load inside this app; they bring their own store.
        if HoursApp.isRunningTests { return }

        let store = Store()
        let clock = Clock()
        clock.align(to: store.running?.start ?? Date())

        self.store = store
        self.clock = clock
        let statusItem = StatusItemController(store: store, clock: clock)
        self.statusItem = statusItem
        #if DEBUG
        DebugControl.shared.listen(statusItem: statusItem)
        #endif
    }

    private static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }
}
