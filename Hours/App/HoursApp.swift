import AppKit

/// Entry point. Builds the store, clock and status item, and keeps them alive.
@main
@MainActor
final class HoursApp: NSObject, NSApplicationDelegate {
    private var store: Store?
    private var clock: Clock?
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

        let store = Store()
        let clock = Clock()
        clock.align(to: store.running?.start ?? Date())

        self.store = store
        self.clock = clock
        let statusItem = StatusItemController(store: store, clock: clock)
        self.statusItem = statusItem
        statusItem.onClickWithoutAreas = { [weak self] in self?.showOnboarding() }
        #if DEBUG
        DebugControl.shared.listen(statusItem: statusItem)
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

    private static var isRunningTests: Bool {
        let env = ProcessInfo.processInfo.environment
        return env["XCTestConfigurationFilePath"] != nil || env["XCTestBundlePath"] != nil
            || env["XCTestSessionIdentifier"] != nil
    }
}
