import AppKit
import Observation
import SwiftUI

/// The full-screen break. One borderless window per screen, above everything
/// and on every Space, while `Pomodoro.showsBreakWindow` is true. It goes when
/// the break ends, on Skip, or on Esc.
@MainActor
final class BreakWindow {
    private let pomodoro: Pomodoro
    private var windows: [NSWindow] = []
    /// The app in front before the break took over; it gets focus back after.
    private var previousApp: NSRunningApplication?
    private var screenObserver: NSObjectProtocol?
    private var escMonitor: Any?

    init(pomodoro: Pomodoro) {
        self.pomodoro = pomodoro
        screenObserver = NotificationCenter.default.addObserver(
            forName: NSApplication.didChangeScreenParametersNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.screensChanged() }
        }
        follow()
    }

    var isShown: Bool { !windows.isEmpty }

    private func follow() {
        let wanted = withObservationTracking {
            pomodoro.showsBreakWindow
        } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        if wanted, !isShown {
            show()
        } else if !wanted, isShown {
            hide()
        }
    }

    private func show() {
        let front = NSWorkspace.shared.frontmostApplication
        if front != NSRunningApplication.current { previousApp = front }
        windows = NSScreen.screens.map(makeWindow)
        // No Dock icon, so the app has to take focus itself for Esc to reach it.
        NSApp.activate(ignoringOtherApps: true)
        let main = windows.first { $0.screen == NSScreen.main } ?? windows.first
        main?.makeKeyAndOrderFront(nil)
        // Esc skips the break whichever of its windows is key.
        escMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard event.keyCode == 53 else { return event }
            MainActor.assumeIsolated { self?.pomodoro.skip() }
            return nil
        }
    }

    private func hide() {
        for window in windows { window.orderOut(nil) }
        windows = []
        if let escMonitor { NSEvent.removeMonitor(escMonitor) }
        escMonitor = nil
        previousApp?.activate()
        previousApp = nil
    }

    /// A screen plugged in or out mid-break gets its own window or loses it.
    private func screensChanged() {
        guard isShown else { return }
        for window in windows { window.orderOut(nil) }
        windows = NSScreen.screens.map(makeWindow)
        windows.first { $0.screen == NSScreen.main }?.makeKeyAndOrderFront(nil)
    }

    private func makeWindow(for screen: NSScreen) -> NSWindow {
        let window = KeyableWindow(contentRect: screen.frame, styleMask: [.borderless], backing: .buffered, defer: false)
        window.level = .screenSaver
        window.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary, .ignoresCycle]
        window.backgroundColor = .breakBackground
        window.isOpaque = true
        window.hasShadow = false
        window.isReleasedWhenClosed = false
        window.contentView = NSHostingView(rootView: BreakView(pomodoro: pomodoro))
        window.setFrame(screen.frame, display: false)
        window.orderFrontRegardless()
        return window
    }
}

extension NSColor {
    /// White in light mode, black in dark. The text background color would be
    /// a dark gray in dark mode.
    static let breakBackground = NSColor(name: "breakBackground") { appearance in
        appearance.bestMatch(from: [.aqua, .darkAqua]) == .darkAqua ? .black : .white
    }
}

/// Borderless windows refuse key status by default; this one takes it, so
/// the app's keys, Esc among them, reach it.
private final class KeyableWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}

/// "Break", the time left as one large light numeral, and "Skip". Nothing else.
struct BreakView: View {
    let pomodoro: Pomodoro

    var body: some View {
        VStack(spacing: 12) {
            Text("Break")
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(minutesSeconds(pomodoro.remaining))
                .font(.system(size: 200, weight: .ultraLight).monospacedDigit())
                .foregroundStyle(.primary)
            Button("Skip") { pomodoro.skip() }
                .buttonStyle(.plain)
                .font(.title3)
                .foregroundStyle(.primary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color(nsColor: .breakBackground))
    }
}
