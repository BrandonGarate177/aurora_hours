import AppKit
import Observation

/// The minute tick. `now` moves forward once a minute, lined up with the
/// running session's start so the bar flips from 0:00 to 0:01 exactly one
/// minute in. Views and the status item read `now` instead of calling Date().
@MainActor
@Observable
final class Clock {
    private(set) var now = Date()
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var anchor = Date()
    @ObservationIgnored private var wakeObserver: NSObjectProtocol?

    init() {
        wakeObserver = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didWakeNotification, object: nil, queue: .main
        ) { [weak self] _ in
            MainActor.assumeIsolated { self?.align(to: self?.anchor ?? Date()) }
        }
    }

    /// Ticks every minute from now on, at whole minutes counted from `anchor`.
    /// Pass the running session's start, or the current time when idle.
    func align(to anchor: Date) {
        self.anchor = anchor
        timer?.invalidate()
        refresh()
        let elapsed = now.timeIntervalSince(anchor)
        let untilNext = 60 - elapsed.truncatingRemainder(dividingBy: 60)
        let timer = Timer(fire: now.addingTimeInterval(untilNext), interval: 60, repeats: true) { [weak self] _ in
            MainActor.assumeIsolated { self?.refresh() }
        }
        timer.tolerance = 1
        // .common keeps it ticking while the popover tracks the mouse.
        RunLoop.main.add(timer, forMode: .common)
        self.timer = timer
    }

    func refresh() {
        now = Date()
    }
}
