import AppKit
import Observation
import SwiftUI

/// The menu bar item and its popover. Idle reads "Hours"; running reads the
/// area and time, "Coding 0:42".
@MainActor
final class StatusItemController: NSObject {
    private let store: Store
    private let clock: Clock
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private var hosting: NSHostingView<DropdownView>?
    /// nil follows the menu bar, like every other status item's popover.
    var popoverAppearance: NSAppearance?

    init(store: Store, clock: Clock) {
        self.store = store
        self.clock = clock
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(togglePopover)
        }

        popover.behavior = .transient
        popover.contentViewController = makeContent()

        updateTitle()
    }

    private func makeContent() -> NSViewController {
        let view = DropdownView(
            store: store,
            clock: clock,
            onArea: { [weak self] id in self?.areaClicked(id) },
            onQuit: { NSApp.terminate(nil) }
        )
        let hosting = NSHostingView(rootView: view)
        self.hosting = hosting
        let controller = NSViewController()
        controller.view = Glass.wrap(hosting)
        return controller
    }

    // MARK: Popover

    @objc private func togglePopover() {
        if popover.isShown {
            closePopover()
        } else {
            openPopover()
        }
    }

    func openPopover() {
        guard !popover.isShown, let button = statusItem.button else { return }
        clock.refresh()
        popover.appearance = popoverAppearance
        if let hosting {
            popover.contentSize = hosting.fittingSize
        }
        popover.show(relativeTo: button.bounds, of: button, preferredEdge: .minY)
        NSApp.activate()
    }

    func closePopover() {
        popover.performClose(nil)
    }

    /// What a click on an area row does: start, stop or switch, then close.
    func areaClicked(_ id: String) {
        store.toggle(id, now: Date())
        clock.align(to: store.running?.start ?? Date())
        closePopover()
    }

    // MARK: Title

    /// Redraws the title whenever the running session or the minute changes.
    private func updateTitle() {
        withObservationTracking {
            render()
        } onChange: { [weak self] in
            Task { @MainActor in self?.updateTitle() }
        }
    }

    private func render() {
        guard let button = statusItem.button else { return }
        let text: String
        if let session = store.running, let area = store.area(id: session.areaId) {
            text = "\(area.name) \(hoursMinutes(session.duration(now: clock.now)))"
        } else {
            text = "Hours"
        }
        let size = NSFont.menuBarFont(ofSize: 0).pointSize
        button.attributedTitle = NSAttributedString(string: text, attributes: [
            .font: NSFont.monospacedDigitSystemFont(ofSize: size, weight: .regular),
        ])
    }
}
