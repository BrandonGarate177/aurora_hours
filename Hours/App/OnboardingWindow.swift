import AppKit
import SwiftUI

/// The one window the app opens, on first launch. Start saves the areas, sets
/// open at login, closes the window and hands over to `onDone`.
@MainActor
final class OnboardingWindow {
    let form = OnboardingForm()
    private let store: Store
    private let onDone: () -> Void
    private var window: NSWindow?

    init(store: Store, onDone: @escaping () -> Void) {
        self.store = store
        self.onDone = onDone
    }

    func show() {
        let window = self.window ?? makeWindow()
        self.window = window
        window.center()
        // No Dock icon, so the app has to come forward on its own.
        NSApp.activate()
        window.makeKeyAndOrderFront(nil)
    }

    func start() {
        guard form.canStart else { return }
        store.setAreas(form.areas())
        LoginItem.set(form.openAtLogin)
        window?.close()
        onDone()
    }

    private func makeWindow() -> NSWindow {
        let view = OnboardingView(form: form, onStart: { [weak self] in self?.start() })
        let window = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 320, height: 230),
            styleMask: [.titled, .closable],
            backing: .buffered,
            defer: false
        )
        window.title = "Hours"
        window.isReleasedWhenClosed = false
        window.contentViewController = NSHostingController(rootView: view)
        return window
    }
}
