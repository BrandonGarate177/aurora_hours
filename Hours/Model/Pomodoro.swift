import Foundation
import Observation

/// Work minutes and break minutes, as picked in the right-click menu. Off
/// means the bar counts up as it always has.
enum PomodoroPreset: String, CaseIterable, Sendable {
    case off
    case short = "25/5"
    case medium = "50/10"
    case long = "90/15"

    static let defaultsKey = "pomodoro"

    /// The menu item's title.
    var title: String {
        switch self {
        case .off: "Off"
        case .short: "25 / 5"
        case .medium: "50 / 10"
        case .long: "90 / 15"
        }
    }

    var workMinutes: Int {
        switch self {
        case .off: 0
        case .short: 25
        case .medium: 50
        case .long: 90
        }
    }

    var breakMinutes: Int {
        switch self {
        case .off: 0
        case .short: 5
        case .medium: 10
        case .long: 15
        }
    }

    /// Seconds of work in each interval.
    var work: TimeInterval { TimeInterval(workMinutes * 60) }

    /// Seconds of the break after interval `interval` (1-based). Every 4th
    /// break is three times as long.
    func breakLength(after interval: Int) -> TimeInterval {
        let minutes = breakMinutes * (interval % 4 == 0 ? 3 : 1)
        return TimeInterval(minutes * 60)
    }

    static func load(from defaults: UserDefaults = .standard) -> PomodoroPreset {
        defaults.string(forKey: defaultsKey).flatMap(PomodoroPreset.init(rawValue:)) ?? .off
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}

/// Where a Pomodoro run is. `ends` is when this phase is over. During a break
/// no session runs; `areaId` is the area that starts again after it.
enum PomodoroPhase: Codable, Equatable, Sendable {
    case idle
    case work(interval: Int, ends: Date)
    case rest(areaId: String, interval: Int, ends: Date)

    var ends: Date? {
        switch self {
        case .idle: nil
        case .work(_, let ends), .rest(_, _, let ends): ends
        }
    }
}

/// The interval state machine. With a preset picked, starting an area starts
/// interval 1. When an interval ends the session is closed at that moment and
/// a break starts; when the break ends a new session of the same area starts
/// at that moment and the next interval begins. Breaks are never in a
/// session, so they are never focus hours.
///
/// `tick(now:)` moves it on. The app calls it every second; tests call it
/// with the times they want.
@MainActor
@Observable
final class Pomodoro {
    private(set) var preset: PomodoroPreset
    private(set) var phase: PomodoroPhase = .idle
    /// The time of the last tick. The bar and the break window read it.
    private(set) var now: Date
    /// Whether the break should cover the screens: a break that started off a
    /// call, or one a call ended with over a minute left.
    private(set) var showsBreakWindow = false

    @ObservationIgnored private let store: Store
    @ObservationIgnored private let defaults: UserDefaults
    @ObservationIgnored private let detector: CallDetecting
    /// Multiplies every length, for checking a whole cycle in seconds.
    @ObservationIgnored let scale: Double
    @ObservationIgnored private var nextCallCheck = Date.distantFuture
    @ObservationIgnored private var timer: Timer?
    @ObservationIgnored private var ticking = false

    /// How often a running break asks whether a call started or ended.
    static let callCheckInterval: TimeInterval = 5
    /// A call that ends with this much break left or less doesn't bring the
    /// window in. Scaled like the lengths.
    static let lateWindowCutoff: TimeInterval = 60

    init(
        store: Store,
        defaults: UserDefaults = .standard,
        detector: CallDetecting,
        scale: Double = 1,
        now: Date = Date()
    ) {
        self.store = store
        self.defaults = defaults
        self.detector = detector
        self.scale = scale
        self.now = now
        preset = PomodoroPreset.load(from: defaults)
        restore(now: now)
    }

    // MARK: Lengths

    var workLength: TimeInterval { preset.work * scale }

    func breakLength(after interval: Int) -> TimeInterval {
        preset.breakLength(after: interval) * scale
    }

    /// Seconds left in the current phase, never below zero.
    var remaining: TimeInterval {
        guard let ends = phase.ends else { return 0 }
        return max(0, ends.timeIntervalSince(now))
    }

    // MARK: What the person does

    /// A click on an area word. Off, it is the plain start, stop or switch.
    /// During a break, a click on the break's area stops it for good; a click
    /// on another area starts that one at interval 1. Mid-interval, a switch
    /// keeps the interval clock.
    func areaClicked(_ areaId: String, now: Date = Date()) {
        self.now = now
        guard preset != .off else {
            store.toggle(areaId, now: now)
            return
        }
        switch phase {
        case .rest(let resting, _, _):
            set(.idle)
            if areaId != resting {
                store.toggle(areaId, now: now)
                set(.work(interval: 1, ends: now.addingTimeInterval(workLength)))
            }
        case .work:
            store.toggle(areaId, now: now)
            if store.running == nil { set(.idle) }
        case .idle:
            store.toggle(areaId, now: now)
            if store.running != nil {
                set(.work(interval: 1, ends: now.addingTimeInterval(workLength)))
            }
        }
    }

    /// Skip, or Esc on the break window: the break ends now and the next
    /// interval starts now.
    func skip(now: Date = Date()) {
        self.now = now
        guard case .rest(let areaId, let interval, _) = phase else { return }
        store.toggle(areaId, now: now)
        set(.work(interval: interval + 1, ends: now.addingTimeInterval(workLength)))
    }

    /// A pick in the Pomodoro submenu. Off ends any run (a running session
    /// keeps counting up; a break just ends). Turning it on with a session
    /// running starts interval 1 now. Switching between presets keeps the
    /// current phase; the new lengths start with the next one.
    func setPreset(_ newPreset: PomodoroPreset, now: Date = Date()) {
        self.now = now
        preset = newPreset
        newPreset.save(to: defaults)
        if newPreset == .off {
            set(.idle)
        } else if phase == .idle, store.running != nil {
            set(.work(interval: 1, ends: now.addingTimeInterval(workLength)))
        }
    }

    // MARK: Time

    /// Moves the run on to `now`. Phase changes happen at their exact end
    /// times, so a late tick (after sleep) still splits sessions where the
    /// interval ended, however many phases it has to catch up on.
    func tick(now: Date = Date()) {
        self.now = now
        if preset == .off {
            if phase != .idle { set(.idle) }
            return
        }
        var breakStarted = false
        while let ends = phase.ends, now >= ends {
            switch phase {
            case .work(let interval, let ends):
                guard let running = store.running else {
                    set(.idle)
                    return
                }
                store.stop(now: ends)
                set(.rest(areaId: running.areaId, interval: interval, ends: ends.addingTimeInterval(breakLength(after: interval))))
                breakStarted = true
            case .rest(let areaId, let interval, let ends):
                store.toggle(areaId, now: ends)
                set(.work(interval: interval + 1, ends: ends.addingTimeInterval(workLength)))
                breakStarted = false
            case .idle:
                return
            }
        }
        if case .rest = phase, breakStarted || now >= nextCallCheck {
            checkCall(breakStarting: breakStarted)
        }
    }

    /// On a call the break stays in the bar. Off one, it covers the screens
    /// when it starts, or later only if more than a minute is left.
    private func checkCall(breakStarting: Bool) {
        nextCallCheck = now.addingTimeInterval(Self.callCheckInterval)
        if detector.isOnCall() {
            showsBreakWindow = false
        } else if breakStarting || remaining > Self.lateWindowCutoff * scale {
            showsBreakWindow = true
        }
    }

    /// Ticks every second while a run is on, and not at all when idle. Tests
    /// leave it off and call tick themselves.
    func startTicking() {
        ticking = true
        updateTimer()
        tick()
    }

    private func updateTimer() {
        let wanted = ticking && phase != .idle
        if wanted, timer == nil {
            let timer = Timer(timeInterval: 1, repeats: true) { [weak self] _ in
                MainActor.assumeIsolated { self?.tick() }
            }
            timer.tolerance = 0.1
            // .common keeps it ticking while a menu or the popover tracks the mouse.
            RunLoop.main.add(timer, forMode: .common)
            self.timer = timer
        } else if !wanted {
            timer?.invalidate()
            timer = nil
        }
    }

    // MARK: State

    private func set(_ newPhase: PomodoroPhase) {
        let wasResting = if case .rest = phase { true } else { false }
        phase = newPhase
        if case .rest = newPhase {
            if !wasResting { nextCallCheck = now }
        } else {
            showsBreakWindow = false
            nextCallCheck = .distantFuture
        }
        updateTimer()
        save()
    }

    /// The phase is kept next to the store, so a quit mid-interval or
    /// mid-break picks up where it was, and copies with other stores keep
    /// their own.
    var phaseURL: URL {
        store.url.deletingPathExtension().appendingPathExtension("pomodoro.json")
    }

    private func save() {
        do {
            try FileManager.default.createDirectory(at: phaseURL.deletingLastPathComponent(), withIntermediateDirectories: true)
            try JSONEncoder().encode(phase).write(to: phaseURL, options: .atomic)
        } catch {
            NSLog("Hours: could not save the Pomodoro phase to \(phaseURL.path): \(error)")
        }
    }

    /// Picks the saved phase back up if it still fits the store: an interval
    /// needs a running session, a break needs none. A session running without
    /// a saved interval starts interval 1 now.
    private func restore(now: Date) {
        guard preset != .off else { return }
        let saved = (try? Data(contentsOf: phaseURL)).flatMap { try? JSONDecoder().decode(PomodoroPhase.self, from: $0) }
        switch saved {
        case .work? where store.running != nil:
            phase = saved ?? .idle
        case .rest? where store.running == nil:
            phase = saved ?? .idle
            nextCallCheck = now
        default:
            if store.running != nil {
                phase = .work(interval: 1, ends: now.addingTimeInterval(workLength))
            }
        }
    }
}

/// "m:ss" for a countdown, minutes not wrapped into hours: 1499 -> "24:59",
/// 5400 -> "90:00". Rounded down, so a fresh 25 minutes reads 24:59 a moment in.
func minutesSeconds(_ seconds: TimeInterval) -> String {
    let total = max(0, Int(seconds.rounded(.down)))
    return String(format: "%d:%02d", total / 60, total % 60)
}

/// HOURS_POMODORO_SCALE in Debug builds, so a whole cycle runs in seconds
/// (0.01 makes 25 / 5 into 15 s / 3 s). Release builds always use 1.
func pomodoroScale(environment: [String: String] = ProcessInfo.processInfo.environment) -> Double {
    #if DEBUG
    if let text = environment["HOURS_POMODORO_SCALE"], let value = Double(text), value > 0 {
        return value
    }
    #endif
    return 1
}
