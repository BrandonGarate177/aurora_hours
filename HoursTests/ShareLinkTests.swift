import AppKit
import Foundation
import Testing
@testable import Hours

@Suite struct ShareLinkTests {
    /// A fixed zone so the tests don't depend on the Mac's settings.
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    let areas = [
        FocusArea(id: "coding", name: "Coding", colorHex: "2da44e"),
        FocusArea(id: "writing", name: "Writing", colorHex: "0969DA"),
    ]

    let base = "https://OWNER.github.io/hours/"

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    /// Wednesday Nov 11 2026, 3 pm.
    var now: Date { date(2026, 11, 11, 15) }

    func map(
        _ sessions: [Session],
        selection: MapSelection = .all,
        period: SharePeriod = .year,
        withHours: Bool
    ) -> ShareMap {
        ShareLink.map(
            sessions: sessions, areas: areas, selection: selection, period: period,
            withHours: withHours, now: now, calendar: calendar
        )
    }

    func link(_ map: ShareMap) -> String {
        ShareLink.url(for: map, base: base, calendar: calendar)
    }

    @Test func theBaseURLIsTheOneConstant() {
        #expect(ShareLink.base == "https://OWNER.github.io/hours/")
    }

    @Test func anEmptyYearIs365EmptyDays() {
        let url = link(map([], withHours: false))
        #expect(url == base + "#1.all.20261111.0." + String(repeating: "A", count: 365))
        #expect(url.count == 413)
    }

    @Test func aSingleHourAndAHalfToday() {
        let sessions = [Session(areaId: "coding", start: date(2026, 11, 11, 9), end: date(2026, 11, 11, 10, 30))]
        let empty = String(repeating: "A", count: 364)
        // 6 quarter-hours is G; 1.5 h is step 2, C.
        #expect(link(map(sessions, withHours: true)) == base + "#1.all.20261111.1." + empty + "G")
        #expect(link(map(sessions, withHours: false)) == base + "#1.all.20261111.0." + empty + "C")
    }

    @Test func aDayOver15h45CapsAt63() {
        let sessions = [Session(areaId: "coding", start: date(2026, 11, 11, 0), end: date(2026, 11, 11, 14))]
        let long = [Session(areaId: "coding", start: date(2026, 11, 10, 2), end: date(2026, 11, 10, 22))]
        #expect(link(map(sessions, withHours: true)).last == "4") // 14 h is 56 quarter-hours
        let capped = map(long, period: .ninetyDays, withHours: true)
        #expect(capped.quarters[88] == 63)
        #expect(link(capped).dropLast().last == "_")
        #expect(link(map(long, period: .ninetyDays, withHours: false)).dropLast().last == "E")
    }

    @Test func quarterHoursRoundToTheNearest() {
        #expect(ShareLink.quarters(0) == 0)
        #expect(ShareLink.quarters(449) == 0)
        #expect(ShareLink.quarters(450) == 1)
        #expect(ShareLink.quarters(5400) == 6)
        #expect(ShareLink.quarters(15 * 3600 + 45 * 60) == 63)
        #expect(ShareLink.quarters(24 * 3600) == 63)
    }

    @Test func stepThresholds() {
        let quarters = [0, 1, 3, 4, 7, 8, 15, 16, 63]
        #expect(quarters.map(ShareLink.step) == [0, 1, 1, 2, 2, 3, 3, 4, 4])
        // Without hours a day carries only its step: under 1 h, 1 to 2 h, 2 to 4 h, 4 h and up.
        let hours: [TimeInterval] = [0, 0.5, 0.99, 1, 1.99, 2, 3.99, 4, 9]
        #expect(hours.map { ShareLink.step(ShareLink.quarters($0 * 3600)) } == [0, 1, 2, 2, 3, 3, 4, 4, 4])
    }

    @Test func daysRunOldestFirstAndEndToday() {
        let sessions = [
            Session(areaId: "coding", start: date(2026, 11, 1, 9), end: date(2026, 11, 1, 10)),
            Session(areaId: "coding", start: date(2026, 11, 11, 9), end: date(2026, 11, 11, 11)),
        ]
        let result = map(sessions, period: .ninetyDays, withHours: true)
        #expect(result.quarters.count == 90)
        #expect(result.quarters[89] == 8) // today, last
        #expect(result.quarters[79] == 4) // ten days ago
        #expect(result.quarters.reduce(0, +) == 12)
        #expect(result.lastDay == calendar.startOfDay(for: now))
    }

    @Test func allTimeStartsOnTheFirstLoggedDayOfTheSelectedMap() {
        let sessions = [
            Session(areaId: "writing", start: date(2026, 10, 20, 9), end: date(2026, 10, 20, 10)),
            Session(areaId: "coding", start: date(2026, 11, 1, 9), end: date(2026, 11, 1, 10)),
            Session(areaId: "coding", start: date(2026, 11, 11, 9), end: date(2026, 11, 11, 9, 15)),
        ]
        let all = map(sessions, period: .allTime, withHours: true)
        #expect(all.quarters.count == 23) // Oct 20 through Nov 11
        #expect(all.quarters.first == 4)
        let coding = map(sessions, selection: .area("coding"), period: .allTime, withHours: true)
        #expect(coding.quarters.count == 11) // Nov 1 through Nov 11
        #expect(coding.quarters == [4] + Array(repeating: 0, count: 9) + [1])
        #expect(map([], period: .allTime, withHours: false).quarters == [0])
    }

    @Test func colorIsTheAreasHexOrAll() {
        #expect(map([], selection: .area("coding"), withHours: false).color == "2da44e")
        #expect(map([], selection: .area("writing"), withHours: false).color == "0969da")
        #expect(map([], selection: .all, withHours: false).color == "all")
        #expect(map([], selection: .area("deleted"), withHours: false).color == "all")
    }

    @Test func anAreaMapCountsOnlyThatArea() {
        let sessions = [
            Session(areaId: "coding", start: date(2026, 11, 11, 9), end: date(2026, 11, 11, 10)),
            Session(areaId: "writing", start: date(2026, 11, 11, 10), end: date(2026, 11, 11, 12)),
        ]
        #expect(map(sessions, selection: .area("coding"), withHours: true).quarters.last == 4)
        #expect(map(sessions, withHours: true).quarters.last == 12)
    }

    /// The same 70 days as `python3 -I site/sample-link.py 70 --ramp [--hours]
    /// --end 20261111 --base https://OWNER.github.io/hours/`, which prints these.
    @Test func agreesWithTheSiteSampleScript() {
        let ramp = ShareMap(
            color: "2da44e", lastDay: date(2026, 11, 11, 0),
            quarters: (0..<70).map { $0 % 64 }, withHours: true
        )
        #expect(link(ramp) == "https://OWNER.github.io/hours/#1.2da44e.20261111.1.ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_ABCDEF")
        var shaded = ramp
        shaded.withHours = false
        #expect(link(shaded) == "https://OWNER.github.io/hours/#1.2da44e.20261111.0.ABBBCCCCDDDDDDDDEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEEABBBCC")
    }

    @Test func totalRoundsLikeTheSharePage() {
        let map = ShareMap(color: "all", lastDay: now, quarters: [6, 0, 2, 63], withHours: true)
        #expect(map.totalHours == 18) // 71 / 4 = 17.75
    }

    @Test func periodCyclesYearNinetyDaysAllTime() {
        #expect(SharePeriod.year.next == .ninetyDays)
        #expect(SharePeriod.ninetyDays.next == .allTime)
        #expect(SharePeriod.allTime.next == .year)
        #expect(SharePeriod.allCases.map(\.label) == ["1 year", "90 days", "All time"])
    }

    @Test func settingsPersistInUserDefaults() throws {
        let defaults = try #require(UserDefaults(suiteName: "HoursTests-\(UUID().uuidString)"))
        defaults.set(SharePeriod.allTime.rawValue, forKey: SharePeriod.defaultsKey)
        defaults.set(true, forKey: ShareLink.withHoursKey)
        #expect(SharePeriod(rawValue: defaults.string(forKey: SharePeriod.defaultsKey) ?? "") == .allTime)
        #expect(defaults.bool(forKey: ShareLink.withHoursKey))
    }
}

@Suite struct ShareGridTests {
    @Test func aYearIs53ColumnsInOneStrip() {
        // Nov 12 2025 is a Wednesday, so the first column starts three rows down.
        let grid = ShareGrid(days: 365, firstWeekday: 3)
        #expect(grid.columns == 53)
        #expect(grid.strips == 1)
        #expect(grid.position(of: 0) == (0, 3))
        #expect(grid.position(of: 4) == (1, 0))
        #expect(grid.position(of: 364) == (52, 3))
        #expect(grid.size == CGSize(width: 739, height: 95))
    }

    @Test func pastFiftyThreeWeeksTheMapWrapsLikeThePage() {
        let grid = ShareGrid(days: 800, firstWeekday: 0)
        #expect(grid.columns == 115)
        #expect(grid.strips == 3)
        // 159 - 115 = 44 empty columns push the oldest strip right.
        #expect(grid.position(of: 0) == (44, 0))
        // Day 799 is 799 % 7 = 1 row down in the third strip, which starts on row 16.
        #expect(grid.position(of: 799) == (52, 16 + 1))
        #expect(grid.size == CGSize(width: 739, height: 23 * 14 - 3))
    }
}

@MainActor
@Suite struct ShareCopyTests {
    @Test func oneItemCarriesTheCardAndTheLink() throws {
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("HoursTests-\(UUID().uuidString)"))
        defer { pasteboard.releaseGlobally() }
        let map = ShareMap(
            color: "2da44e", lastDay: Date(),
            quarters: (0..<365).map { $0 % 20 }, withHours: true
        )
        ShareRow.copy(map, to: pasteboard)

        let items = try #require(pasteboard.pasteboardItems)
        #expect(items.count == 1)
        let item = try #require(items.first)
        #expect(item.string(forType: .string) == ShareLink.url(for: map))
        let png = try #require(item.data(forType: .png))
        let image = try #require(NSBitmapImageRep(data: png))
        // 739 pt map + 2 x 16 pt padding, at 2x.
        #expect(image.pixelsWide == 1542)
        #expect(image.pixelsHigh > 300)
    }
}
