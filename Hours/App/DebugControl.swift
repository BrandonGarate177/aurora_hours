#if DEBUG
import AppKit

/// Debug builds only: lets scripts/hours-debug.swift open the dropdown and
/// click areas, so agents can take screenshots without Accessibility access.
/// Commands: open, close, area:<id>, menu (shows the right-click menu for
/// three seconds), item:<title> (what choosing that menu item does), quit,
/// and for the onboarding window onboard:names:<a,b,c>,
/// onboard:color:<field 0-2> (a click on that square), onboard:start, and
/// login:toggle (what a click on Open at login in the menu does).
/// HOURS_APPEARANCE=light or dark forces the app's appearance, for
/// screenshots of the mode the Mac isn't in.
@MainActor
final class DebugControl {
    static let shared = DebugControl()

    /// The notification name a copy listens on. It carries the store's path,
    /// so copies running with different HOURS_STORE files don't hear each
    /// other. scripts/hours-debug.swift builds the same name from its own
    /// HOURS_STORE; change both together.
    nonisolated static func channel(for store: URL) -> Notification.Name {
        Notification.Name("com.hoursapp.Hours.debug:" + store.standardizedFileURL.path)
    }

    private weak var statusItem: StatusItemController?
    weak var onboarding: OnboardingWindow?

    func listen(statusItem: StatusItemController) {
        self.statusItem = statusItem
        let forced: NSAppearance? = switch ProcessInfo.processInfo.environment["HOURS_APPEARANCE"] {
        case "light": NSAppearance(named: .aqua)
        case "dark": NSAppearance(named: .darkAqua)
        default: nil
        }
        if let forced {
            statusItem.popoverAppearance = forced
            NSApp.appearance = forced // the onboarding window
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(received(_:)), name: Self.channel(for: Store.defaultURL()), object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func received(_ note: Notification) {
        guard let command = note.object as? String, let statusItem else { return }
        switch command {
        case "open": statusItem.openPopover()
        case "close": statusItem.closePopover()
        case "menu":
            // The menu tracks in its own run loop mode; a .common timer still fires.
            let timer = Timer(timeInterval: 3, repeats: false) { [weak statusItem] _ in
                MainActor.assumeIsolated { statusItem?.cancelMenu() }
            }
            RunLoop.main.add(timer, forMode: .common)
            statusItem.showMenu()
        case _ where command.hasPrefix("onboard:names:"):
            let names = command.dropFirst("onboard:names:".count).split(separator: ",", omittingEmptySubsequences: false)
            for (field, name) in names.prefix(3).enumerated() {
                onboarding?.form.names[field] = String(name)
            }
        case _ where command.hasPrefix("onboard:color:"):
            if let field = Int(command.dropFirst("onboard:color:".count)), (0..<3).contains(field) {
                onboarding?.form.cycleColor(field)
            }
        case "onboard:start": onboarding?.start()
        case "login:toggle": LoginItem.set(!LoginItem.isOn)
        case "quit": NSApp.terminate(nil)
        case _ where command.hasPrefix("area:"): statusItem.areaClicked(String(command.dropFirst(5)))
        case _ where command.hasPrefix("item:"): statusItem.performMenuItem(titled: String(command.dropFirst(5)))
        default: NSLog("Hours debug: unknown command \(command)")
        }
    }
}
#endif
