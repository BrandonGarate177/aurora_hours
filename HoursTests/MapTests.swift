import Foundation
import Testing
@testable import Hours

@Suite struct MapTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int = 0, _ min: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min))!
    }

    let minute: TimeInterval = 60
    let hour: TimeInterval = 3600

    // MARK: Steps

    @Test func stepsChangeAtOneTwoAndFourHours() {
        #expect(MapLevels.step(0) == 0)
        #expect(MapLevels.step(1) == 1)
        #expect(MapLevels.step(59 * minute) == 1)
        #expect(MapLevels.step(60 * minute) == 2)
        #expect(MapLevels.step(2 * hour - 1) == 2)
        #expect(MapLevels.step(2 * hour) == 3)
        #expect(MapLevels.step(4 * hour - 1) == 3)
        #expect(MapLevels.step(4 * hour) == 4)
        #expect(MapLevels.step(15 * hour) == 4)
    }

    // MARK: Grid

    @Test func yearOf365DaysEndsOnTodaysWeekday() {
        // Wed Nov 11 2026. A year back is Nov 12 2025, also a Wednesday.
        let grid = MapGrid(now: date(2026, 11, 11, 15), calendar: calendar)
        #expect(grid.dayCount == 365)
        #expect(grid.leading == 3)
        #expect(grid.firstDay == date(2025, 11, 12))
        #expect(grid.cell(of: date(2026, 11, 11, 23, 59)) == MapGrid.Cell(column: 52, row: 3))
        #expect(grid.cell(of: date(2025, 11, 12)) == MapGrid.Cell(column: 0, row: 3))
        // Sun Nov 8 2026 starts today's week; Sat Nov 7 ends the week before.
        #expect(grid.cell(of: date(2026, 11, 8)) == MapGrid.Cell(column: 52, row: 0))
        #expect(grid.cell(of: date(2026, 11, 7)) == MapGrid.Cell(column: 51, row: 6))
    }

    @Test func daysOffTheMapHaveNoCell() {
        let grid = MapGrid(now: date(2026, 11, 11, 15), calendar: calendar)
        #expect(grid.index(of: date(2025, 11, 11)) == nil)
        #expect(grid.index(of: date(2026, 11, 12)) == nil)
        #expect(grid.date(at: 0) == nil)
        #expect(grid.date(at: 2) == nil)
        #expect(grid.date(at: 3) == date(2025, 11, 12))
        #expect(grid.date(at: 52 * 7 + 3) == date(2026, 11, 11))
        #expect(grid.date(at: 52 * 7 + 4) == nil)
    }

    @Test func leapYearShows366Days() {
        // Wed Mar 1 2028. The year back holds Feb 29 2028.
        let grid = MapGrid(now: date(2028, 3, 1, 9), calendar: calendar)
        #expect(grid.dayCount == 366)
        #expect(grid.leading == 2)
        #expect(grid.firstDay == date(2027, 3, 2))
        #expect(grid.cell(of: date(2027, 3, 2)) == MapGrid.Cell(column: 0, row: 2))
        #expect(grid.cell(of: date(2028, 2, 29)) == MapGrid.Cell(column: 52, row: 2))
        #expect(grid.cell(of: date(2028, 3, 1)) == MapGrid.Cell(column: 52, row: 3))
    }

    @Test func leapYearEndingOnSundayDropsItsOldestDay() {
        // Sun Mar 5 2028: 366 days would need a 54th column.
        let grid = MapGrid(now: date(2028, 3, 5, 9), calendar: calendar)
        #expect(grid.dayCount == 365)
        #expect(grid.leading == 0)
        #expect(grid.firstDay == date(2027, 3, 7))
        #expect(grid.cell(of: date(2028, 3, 5)) == MapGrid.Cell(column: 52, row: 0))
        #expect(grid.index(of: date(2027, 3, 6)) == nil)
    }

    @Test func gridCrossesDaylightSavingWithoutSlipping() {
        // Nov 1 2026 is 25 hours long in Los Angeles; Mar 8 2026 is 23.
        let grid = MapGrid(now: date(2026, 11, 11, 15), calendar: calendar)
        #expect(grid.cell(of: date(2026, 11, 1)) == MapGrid.Cell(column: 51, row: 0))
        #expect(grid.cell(of: date(2026, 11, 2)) == MapGrid.Cell(column: 51, row: 1))
        #expect(grid.cell(of: date(2026, 3, 8)) == MapGrid.Cell(column: 17, row: 0))
        #expect(grid.cell(of: date(2026, 3, 9)) == MapGrid.Cell(column: 17, row: 1))
    }

    // MARK: Levels

    @Test func combinedMapSumsTheAreas() {
        let now = date(2026, 11, 11, 15)
        let grid = MapGrid(now: now, calendar: calendar)
        let sessions = [
            Session(areaId: "coding", start: date(2026, 11, 10, 9), end: date(2026, 11, 10, 9, 40)),
            Session(areaId: "writing", start: date(2026, 11, 10, 14), end: date(2026, 11, 10, 14, 30)),
            Session(areaId: "study", start: date(2026, 11, 9, 8), end: date(2026, 11, 9, 12)),
        ]
        let tuesday = grid.index(of: date(2026, 11, 10))!
        let monday = grid.index(of: date(2026, 11, 9))!
        let coding = MapLevels.levels(sessions, areaId: "coding", grid: grid, now: now, calendar: calendar)
        let writing = MapLevels.levels(sessions, areaId: "writing", grid: grid, now: now, calendar: calendar)
        let all = MapLevels.levels(sessions, areaId: nil, grid: grid, now: now, calendar: calendar)
        #expect(coding[tuesday] == 1)
        #expect(writing[tuesday] == 1)
        #expect(all[tuesday] == 2)
        #expect(coding[monday] == 0)
        #expect(all[monday] == 4)
        #expect(all.count == MapGrid.cellCount)
        #expect(all.filter { $0 > 0 }.count == 2)
    }

    @Test func runningSessionFillsTodaysSquare() {
        let now = date(2026, 11, 11, 15)
        let grid = MapGrid(now: now, calendar: calendar)
        let sessions = [Session(areaId: "coding", start: date(2026, 11, 11, 13, 30), end: nil)]
        let levels = MapLevels.levels(sessions, areaId: "coding", grid: grid, now: now, calendar: calendar)
        #expect(levels[grid.index(of: now)!] == 2)
    }
}
