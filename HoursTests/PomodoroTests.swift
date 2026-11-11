import Foundation
import Testing
@testable import Hours

@MainActor
final class FakeCallDetector: CallDetecting {
    var onCall = false
    func isOnCall() -> Bool { onCall }
}

@Suite struct PomodoroPresetTests {
    @Test func presetsHaveTheirLengths() {
        let minute: TimeInterval = 60
        #expect(PomodoroPreset.short.work == 25 * minute)
        #expect(PomodoroPreset.short.breakLength(after: 1) == 5 * minute)
        #expect(PomodoroPreset.medium.work == 50 * minute)
        #expect(PomodoroPreset.medium.breakLength(after: 1) == 10 * minute)
        #expect(PomodoroPreset.long.work == 90 * minute)
        #expect(PomodoroPreset.long.breakLength(after: 1) == 15 * minute)
    }

    @Test func everyFourthBreakIsThreeTimesAsLong() {
        let short: TimeInterval = 300
        let long: TimeInterval = 900
        let lengths = (1...8).map { PomodoroPreset.short.breakLength(after: $0) }
        #expect(lengths == [short, short, short, long, short, short, short, long])
        let fifteen: TimeInterval = 45 * 60
        #expect(PomodoroPreset.long.breakLength(after: 4) == fifteen)
    }

    @Test func titlesMatchTheMenu() {
        #expect(PomodoroPreset.allCases.map(\.title) == ["Off", "25 / 5", "50 / 10", "90 / 15"])
    }

    @Test func pickSticksInDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "HoursTests-\(UUID().uuidString)"))
        #expect(PomodoroPreset.load(from: defaults) == .off)
        PomodoroPreset.medium.save(to: defaults)
        #expect(PomodoroPreset.load(from: defaults) == .medium)
    }

    @Test func countdownFormat() {
        #expect(minutesSeconds(1500) == "25:00")
        #expect(minutesSeconds(1499.4) == "24:59")
        #expect(minutesSeconds(5400) == "90:00")
        #expect(minutesSeconds(59) == "0:59")
        #expect(minutesSeconds(-3) == "0:00")
    }

    @Test func scaleComesFromTheEnvironment() {
        let tiny: Double = 0.01
        let one: Double = 1
        #expect(pomodoroScale(environment: ["HOURS_POMODORO_SCALE": "0.01"]) == tiny)
        #expect(pomodoroScale(environment: [:]) == one)
        #expect(pomodoroScale(environment: ["HOURS_POMODORO_SCALE": "zero"]) == one)
        #expect(pomodoroScale(environment: ["HOURS_POMODORO_SCALE": "-2"]) == one)
    }
}

@MainActor
@Suite struct PomodoroTests {
    let store: Store
    let defaults: UserDefaults
    let detector = FakeCallDetector()
    let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000)
    let work: TimeInterval = 1500
    let rest: TimeInterval = 300

    init() throws {
        let dir = FileManager.default.temporaryDirectory.appendingPathComponent("HoursTests-\(UUID().uuidString)")
        store = Store(url: dir.appendingPathComponent("store.json"))
        store.setAreas([
            FocusArea(id: "coding", name: "Coding", colorHex: "2da44e"),
            FocusArea(id: "writing", name: "Writing", colorHex: "0969da"),
        ])
        defaults = try #require(UserDefaults(suiteName: "HoursTests-\(UUID().uuidString)"))
        PomodoroPreset.short.save(to: defaults)
    }

    func makePomodoro(now: Date? = nil) -> Pomodoro {
        Pomodoro(store: store, defaults: defaults, detector: detector, now: now ?? t0)
    }

    func at(_ seconds: TimeInterval) -> Date { t0.addingTimeInterval(seconds) }

    @Test func offIsThePlainToggle() {
        PomodoroPreset.off.save(to: defaults)
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work + 1))
        #expect(pomodoro.phase == .idle)
        #expect(store.running?.areaId == "coding")
        #expect(store.sessions.count == 1)
    }

    @Test func startingAnAreaStartsIntervalOne() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        #expect(pomodoro.phase == .work(interval: 1, ends: at(work)))
        pomodoro.tick(now: at(1))
        let left: TimeInterval = 1499
        #expect(pomodoro.remaining == left)
    }

    @Test func intervalEndSplitsTheSessionAroundTheBreak() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        #expect(store.running == nil)
        #expect(pomodoro.phase == .rest(areaId: "coding", interval: 1, ends: at(work + rest)))

        pomodoro.tick(now: at(work + rest))
        #expect(pomodoro.phase == .work(interval: 2, ends: at(work + rest + work)))
        #expect(store.sessions.count == 2)
        let first = store.sessions[0]
        let second = store.sessions[1]
        #expect(first.areaId == "coding")
        #expect(second.areaId == "coding")
        #expect(first.end == at(work))
        #expect(second.start == at(work + rest))
        #expect(second.end == nil)
        let gap = second.start.timeIntervalSince(first.end ?? .distantPast)
        #expect(gap == rest)

        // A minute into interval 2: 25 minutes of work plus one, no break.
        let now = at(work + rest + 60)
        let expected: TimeInterval = 1560
        let daily = Totals.daily(store.sessions, now: now)
        #expect(daily.values.reduce(0, +) == expected)
    }

    @Test func aLateTickSplitsAtTheExactBoundaries() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        // Asleep through one whole interval and break, woken mid interval 2.
        pomodoro.tick(now: at(work + rest + 100))
        #expect(pomodoro.phase == .work(interval: 2, ends: at(work + rest + work)))
        #expect(store.sessions.map(\.start) == [t0, at(work + rest)])
        #expect(store.sessions[0].end == at(work))
    }

    @Test func fourthBreakIsLong() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        var time: TimeInterval = 0
        var breaks: [TimeInterval] = []
        for _ in 1...4 {
            time += work
            pomodoro.tick(now: at(time))
            guard case .rest(_, _, let ends) = pomodoro.phase else {
                Issue.record("expected a break, got \(pomodoro.phase)")
                return
            }
            let length = ends.timeIntervalSince(at(time))
            breaks.append(length)
            time += length
            pomodoro.tick(now: at(time))
        }
        let long: TimeInterval = 900
        #expect(breaks == [rest, rest, rest, long])
        #expect(store.sessions.count == 5)
    }

    @Test func skipStartsTheNextIntervalNow() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        pomodoro.skip(now: at(work + 30))
        #expect(pomodoro.phase == .work(interval: 2, ends: at(work + 30 + work)))
        #expect(store.running?.areaId == "coding")
        #expect(store.running?.start == at(work + 30))
        #expect(pomodoro.showsBreakWindow == false)
    }

    @Test func skipOutsideABreakDoesNothing() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.skip(now: at(10))
        #expect(pomodoro.phase == .work(interval: 1, ends: at(work)))
        #expect(store.sessions.count == 1)
    }

    @Test func stoppingDuringABreakCancelsTheRest() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        pomodoro.areaClicked("coding", now: at(work + 60))
        #expect(pomodoro.phase == .idle)
        #expect(pomodoro.showsBreakWindow == false)
        pomodoro.tick(now: at(work + rest + 10))
        #expect(store.running == nil)
        #expect(store.sessions.count == 1)
    }

    @Test func anotherAreaDuringABreakStartsItFresh() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        pomodoro.areaClicked("writing", now: at(work + 60))
        #expect(store.running?.areaId == "writing")
        #expect(pomodoro.phase == .work(interval: 1, ends: at(work + 60 + work)))
    }

    @Test func switchingMidIntervalKeepsTheClock() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.areaClicked("writing", now: at(600))
        #expect(pomodoro.phase == .work(interval: 1, ends: at(work)))
        pomodoro.tick(now: at(work))
        #expect(pomodoro.phase == .rest(areaId: "writing", interval: 1, ends: at(work + rest)))
        #expect(store.sessions.map(\.areaId) == ["coding", "writing"])
        #expect(store.sessions[1].end == at(work))
    }

    @Test func stoppingMidIntervalGoesIdle() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.areaClicked("coding", now: at(600))
        #expect(pomodoro.phase == .idle)
        pomodoro.areaClicked("coding", now: at(700))
        #expect(pomodoro.phase == .work(interval: 1, ends: at(700 + work)))
    }

    @Test func turningItOffDuringAnIntervalKeepsTheSession() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.setPreset(.off, now: at(60))
        #expect(pomodoro.phase == .idle)
        pomodoro.tick(now: at(work + 10))
        #expect(store.running?.areaId == "coding")
        #expect(PomodoroPreset.load(from: defaults) == .off)
    }

    @Test func turningItOnWhileRunningStartsIntervalOneNow() {
        PomodoroPreset.off.save(to: defaults)
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.setPreset(.medium, now: at(100))
        let fifty: TimeInterval = 3000
        #expect(pomodoro.phase == .work(interval: 1, ends: at(100 + fifty)))
    }

    @Test func aRelaunchPicksUpTheBreak() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        let again = makePomodoro(now: at(work + 10))
        #expect(again.phase == .rest(areaId: "coding", interval: 1, ends: at(work + rest)))
        again.tick(now: at(work + rest))
        #expect(store.running?.areaId == "coding")
    }

    // MARK: Calls

    @Test func offACallTheBreakTakesOver() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        #expect(pomodoro.showsBreakWindow == false)
        pomodoro.tick(now: at(work))
        #expect(pomodoro.showsBreakWindow == true)
        pomodoro.tick(now: at(work + rest))
        #expect(pomodoro.showsBreakWindow == false)
    }

    @Test func onACallTheWindowStaysAway() {
        detector.onCall = true
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        #expect(pomodoro.phase == .rest(areaId: "coding", interval: 1, ends: at(work + rest)))
        #expect(pomodoro.showsBreakWindow == false)
        for second in stride(from: 1.0, to: rest, by: 1) {
            pomodoro.tick(now: at(work + second))
            #expect(pomodoro.showsBreakWindow == false)
        }
    }

    @Test func aCallEndingWithOverAMinuteLeftBringsTheWindowIn() {
        detector.onCall = true
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        detector.onCall = false
        // Checked every 5 s: not yet at 3 s, seen at 5 s.
        pomodoro.tick(now: at(work + 3))
        #expect(pomodoro.showsBreakWindow == false)
        pomodoro.tick(now: at(work + 5))
        #expect(pomodoro.showsBreakWindow == true)
    }

    @Test func aCallEndingWithAMinuteOrLessLeftStaysInTheBar() {
        detector.onCall = true
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        for second in stride(from: 5.0, through: rest - 60, by: 5) {
            pomodoro.tick(now: at(work + second))
        }
        detector.onCall = false
        for second in stride(from: rest - 55, to: rest, by: 5) {
            pomodoro.tick(now: at(work + second))
            #expect(pomodoro.showsBreakWindow == false)
        }
    }

    @Test func aCallStartingMidBreakTakesTheWindowAway() {
        let pomodoro = makePomodoro()
        pomodoro.areaClicked("coding", now: t0)
        pomodoro.tick(now: at(work))
        #expect(pomodoro.showsBreakWindow == true)
        detector.onCall = true
        pomodoro.tick(now: at(work + 5))
        #expect(pomodoro.showsBreakWindow == false)
    }
}
