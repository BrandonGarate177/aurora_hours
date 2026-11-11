import Foundation
import Testing
@testable import Hours

@Suite struct TotalsTests {
    /// A fixed zone with DST so the tests don't depend on the Mac's settings.
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    func day(_ y: Int, _ m: Int, _ d: Int) -> Date { date(y, m, d, 0) }

    /// Typed constants: #expect splits `a == 2 * 3600` apart and can infer the
    /// right side as a different type than the dictionary's TimeInterval.
    let hour: TimeInterval = 3600
    let minute: TimeInterval = 60

    @Test func sessionAcrossMidnightSplitsIntoTwoDays() {
        let sessions = [Session(areaId: "coding", start: date(2026, 11, 10, 23), end: date(2026, 11, 11, 1, 30))]
        let totals = Totals.daily(sessions, now: date(2026, 11, 11, 12), calendar: calendar)
        #expect(totals[day(2026, 11, 10)] == 3600)
        #expect(totals[day(2026, 11, 11)] == 5400)
        #expect(totals.count == 2)
    }

    @Test func sessionSpanningSeveralDaysFillsTheDaysBetween() {
        let sessions = [Session(areaId: "coding", start: date(2026, 11, 9, 22), end: date(2026, 11, 11, 2))]
        let totals = Totals.daily(sessions, now: date(2026, 11, 11, 12), calendar: calendar)
        #expect(totals[day(2026, 11, 9)] == 2 * hour)
        #expect(totals[day(2026, 11, 10)] == 24 * hour)
        #expect(totals[day(2026, 11, 11)] == 2 * hour)
    }

    @Test func splitFollowsLocalMidnightOnADaylightSavingDay() {
        // 2026-11-01 is 25 hours long in Los Angeles.
        let sessions = [Session(areaId: "coding", start: day(2026, 11, 1), end: day(2026, 11, 2))]
        let totals = Totals.daily(sessions, now: day(2026, 11, 3), calendar: calendar)
        #expect(totals[day(2026, 11, 1)] == 25 * hour)
        #expect(totals.count == 1)
    }

    @Test func todayAddsFinishedAndRunningSessions() {
        let now = date(2026, 11, 11, 15)
        let sessions = [
            Session(areaId: "coding", start: date(2026, 11, 10, 9), end: date(2026, 11, 10, 10)),
            Session(areaId: "coding", start: date(2026, 11, 11, 9), end: date(2026, 11, 11, 10, 15)),
            Session(areaId: "writing", start: date(2026, 11, 11, 14), end: nil),
        ]
        #expect(Totals.today(sessions, now: now, calendar: calendar) == 75 * minute + hour)
    }

    @Test func todayCountsOnlyTheAfterMidnightPartOfLastNightsSession() {
        let now = date(2026, 11, 11, 8)
        let sessions = [Session(areaId: "study", start: date(2026, 11, 10, 23, 30), end: date(2026, 11, 11, 0, 45))]
        #expect(Totals.today(sessions, now: now, calendar: calendar) == 45 * minute)
    }

    @Test func todayIsZeroWithNoSessions() {
        #expect(Totals.today([], now: date(2026, 11, 11, 8), calendar: calendar) == 0)
    }

    @Test func perAreaKeepsOneAreaAndFillsEveryDay() {
        let now = date(2026, 11, 11, 12)
        let sessions = [
            Session(areaId: "coding", start: date(2026, 11, 11, 9), end: date(2026, 11, 11, 10)),
            Session(areaId: "writing", start: date(2026, 11, 11, 10), end: date(2026, 11, 11, 11)),
            Session(areaId: "coding", start: date(2026, 11, 9, 9), end: date(2026, 11, 9, 9, 30)),
            Session(areaId: "coding", start: date(2026, 11, 1, 9), end: date(2026, 11, 1, 10)), // outside 7 days
        ]
        let coding = Totals.perArea(sessions, areaId: "coding", days: 7, now: now, calendar: calendar)
        #expect(coding.count == 7)
        #expect(coding[day(2026, 11, 11)] == 3600)
        #expect(coding[day(2026, 11, 10)] == 0)
        #expect(coding[day(2026, 11, 9)] == 1800)
        #expect(coding[day(2026, 11, 5)] == 0)
        #expect(coding[day(2026, 11, 4)] == nil)

        let all = Totals.perArea(sessions, areaId: nil, days: 7, now: now, calendar: calendar)
        #expect(all[day(2026, 11, 11)] == 7200)
    }

    @Test func runningSessionCountsUpToNowOnly() {
        let now = date(2026, 11, 11, 10, 42)
        let sessions = [Session(areaId: "coding", start: date(2026, 11, 11, 10), end: nil)]
        let totals = Totals.perArea(sessions, areaId: "coding", days: 1, now: now, calendar: calendar)
        #expect(totals[day(2026, 11, 11)] == 42 * minute)
    }

    @Test func hoursMinutesRoundsDown() {
        #expect(hoursMinutes(0) == "0:00")
        #expect(hoursMinutes(59) == "0:00")
        #expect(hoursMinutes(42 * 60 + 59) == "0:42")
        #expect(hoursMinutes(2 * hour + 15 * 60) == "2:15")
        #expect(hoursMinutes(12 * hour + 5 * 60) == "12:05")
    }
}
