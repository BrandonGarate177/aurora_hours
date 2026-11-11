#if DEBUG
import AppKit

/// Debug builds only: lets scripts/hours-debug.swift open the dropdown and
/// click areas, so agents can take screenshots without Accessibility access.
/// Commands: open, close, area:<id>, menu (shows the right-click menu for
/// three seconds). HOURS_APPEARANCE=light or dark forces
/// the app's appearance, for screenshots of the mode the Mac isn't in.
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

    func listen(statusItem: StatusItemController) {
        self.statusItem = statusItem
        switch ProcessInfo.processInfo.environment["HOURS_APPEARANCE"] {
        case "light": statusItem.popoverAppearance = NSAppearance(named: .aqua)
        case "dark": statusItem.popoverAppearance = NSAppearance(named: .darkAqua)
        default: break
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
        case _ where command.hasPrefix("area:"): statusItem.areaClicked(String(command.dropFirst(5)))
        default: NSLog("Hours debug: unknown command \(command)")
        }
    }
}
#endif
