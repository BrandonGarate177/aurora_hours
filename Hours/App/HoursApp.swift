import AppKit

/// Entry point. Builds the store, clock and status item, and keeps them alive.
@main
@MainActor
final class HoursApp: NSObject, NSApplicationDelegate {
    private var store: Store?
    private var clock: Clock?
    private var blocker: Blocker?
    private var pomodoro: Pomodoro?
    private var breakWindow: BreakWindow?
    private var statusItem: StatusItemController?
    private var onboarding: OnboardingWindow?

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

        let store = Store(url: StoreMigration.storeURL())
        let clock = Clock()
        clock.align(to: store.running?.start ?? Date())

        // Site blocking: clears a block a crash left behind, then follows
        // session starts and stops.
        let blocker = Blocker(store: store)
        blocker.follow()

        let detector = SystemCallDetector()
        let pomodoro = Pomodoro(store: store, detector: detector, scale: pomodoroScale())

        self.store = store
        self.clock = clock
        self.blocker = blocker
        self.pomodoro = pomodoro
        let statusItem = StatusItemController(store: store, clock: clock, blocker: blocker, pomodoro: pomodoro)
        self.statusItem = statusItem
        statusItem.onClickWithoutAreas = { [weak self] in self?.showOnboarding() }
        breakWindow = BreakWindow(pomodoro: pomodoro)
        pomodoro.startTicking()
        #if DEBUG
        DebugControl.shared.listen(statusItem: statusItem)
        DebugControl.shared.pomodoro = pomodoro
        DebugControl.shared.callDetector = detector
        #endif

        if store.areas.isEmpty {
            showOnboarding()
        }
    }

    /// First launch, or a click on the menu bar word after the window was
    /// closed without Start. Start opens the dropdown once, so the person sees
    /// where the app lives.
    private func showOnboarding() {
        guard let store else { return }
        let onboarding = self.onboarding ?? OnboardingWindow(store: store) { [weak self] in
            self?.onboarding = nil
            self?.statusItem?.openPopover()
        }
        self.onboarding = onboarding
        #if DEBUG
        DebugControl.shared.onboarding = onboarding
        #endif
        onboarding.show()
    }

    /// Quit unblocks. The session itself keeps running across a relaunch, and
    /// the block comes back at launch if it still should.
    func applicationWillTerminate(_ notification: Notification) {
        blocker?.unblock()
    }

    private static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }
}
