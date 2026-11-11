#if DEBUG
import AppKit

/// Debug builds only: lets scripts/hours-debug.swift open the dropdown and
/// click areas, so agents can take screenshots without Accessibility access.
/// Commands: open, close, area:<id>. HOURS_APPEARANCE=light or dark forces
/// the app's appearance, for screenshots of the mode the Mac isn't in.
@MainActor
final class DebugControl {
    static let shared = DebugControl()
    static let notification = Notification.Name("com.hoursapp.Hours.debug")

    private weak var statusItem: StatusItemController?

    func listen(statusItem: StatusItemController) {
        self.statusItem = statusItem
        switch ProcessInfo.processInfo.environment["HOURS_APPEARANCE"] {
        case "light": statusItem.popoverAppearance = NSAppearance(named: .aqua)
        case "dark": statusItem.popoverAppearance = NSAppearance(named: .darkAqua)
        default: break
        }
        DistributedNotificationCenter.default().addObserver(
            self, selector: #selector(received(_:)), name: Self.notification, object: nil,
            suspensionBehavior: .deliverImmediately
        )
    }

    @objc private func received(_ note: Notification) {
        guard let command = note.object as? String, let statusItem else { return }
        switch command {
        case "open": statusItem.openPopover()
        case "close": statusItem.closePopover()
        case _ where command.hasPrefix("area:"): statusItem.areaClicked(String(command.dropFirst(5)))
        default: NSLog("Hours debug: unknown command \(command)")
        }
    }
}
#endif
