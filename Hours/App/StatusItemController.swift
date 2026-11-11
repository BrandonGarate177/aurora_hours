import AppKit
import Observation
import SwiftUI
import WidgetKit

/// The menu bar item, its popover and its right-click menu. Idle reads
/// "Hours"; running reads the area and time, "Coding 0:42".
@MainActor
final class StatusItemController: NSObject {
    private let store: Store
    private let clock: Clock
    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
    private let popover = NSPopover()
    private let menu: MenuController
    private var hosting: NSHostingView<DropdownView>?
    /// nil follows the menu bar, like every other status item's popover.
    var popoverAppearance: NSAppearance?
    /// A left click with no areas yet reopens onboarding instead of an empty dropdown.
    var onClickWithoutAreas: (() -> Void)?

    init(store: Store, clock: Clock, blocker: Blocker) {
        self.store = store
        self.clock = clock
        menu = MenuController(blocker: blocker, onQuit: { NSApp.terminate(nil) })
        super.init()

        if let button = statusItem.button {
            button.target = self
            button.action = #selector(clicked)
            button.sendAction(on: [.leftMouseUp, .rightMouseUp])
        }

        popover.behavior = .transient
        popover.contentViewController = makeContent()

        updateTitle()
    }

    private func makeContent() -> NSViewController {
        let view = DropdownView(
            store: store,
            clock: clock,
            onArea: { [weak self] id in self?.areaClicked(id) }
        )
        let hosting = NSHostingView(rootView: view)
        self.hosting = hosting
        let controller = NSViewController()
        controller.view = Glass.wrap(hosting)
        return controller
    }

    // MARK: Popover

    /// Left click toggles the dropdown. Right click or control-click shows the menu.
    @objc private func clicked() {
        let event = NSApp.currentEvent
        if event?.type == .rightMouseUp || event?.modifierFlags.contains(.control) == true {
            showMenu()
        } else if popover.isShown {
            closePopover()
        } else if store.areas.isEmpty, let onClickWithoutAreas {
            onClickWithoutAreas()
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

    /// Pops the standard menu under the item, the way system items do.
    func showMenu() {
        closePopover()
        statusItem.menu = menu.menu
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    func cancelMenu() {
        menu.menu.cancelTracking()
    }

    #if DEBUG
    /// What choosing a menu item does, for scripts that can't click the menu.
    func performMenuItem(titled title: String) {
        let index = menu.menu.indexOfItem(withTitle: title)
        guard index >= 0 else { return NSLog("Hours debug: no menu item \(title)") }
        menu.menu.performActionForItem(at: index)
    }
    #endif

    /// What a click on an area word does: start, stop or switch, then close.
    /// Starting one also switches the map to that area, and the widget redraws
    /// so its total is right within the minute.
    func areaClicked(_ id: String) {
        store.toggle(id, now: Date())
        WidgetCenter.shared.reloadAllTimelines()
        if let running = store.running {
            MapSelection.area(running.areaId).save()
        }
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
