import Foundation

/// The shade of each square in the map. Fixed steps by hours that day, not
/// relative to the person's busiest day, so two people's maps compare:
///   0  nothing logged
///   1  under 1 h
///   2  1 h to under 2 h
///   3  2 h to under 4 h
///   4  4 h and up
enum MapLevels {
    /// Opacity of the map's color for each step. Step 0 is the empty gray.
    static let opacities: [Double] = [0, 0.3, 0.55, 0.8, 1.0]

    static func step(_ seconds: TimeInterval) -> Int {
        switch seconds {
        case ...0: 0
        case ..<3600: 1
        case ..<7200: 2
        case ..<14400: 3
        default: 4
        }
    }

    /// One step per cell of `grid`, blank cells 0. nil `areaId` is the combined
    /// map, shaded by the day's total across every area.
    static func levels(
        _ sessions: [Session],
        areaId: String?,
        grid: MapGrid,
        now: Date,
        calendar: Calendar = .current
    ) -> [Int] {
        let totals = Totals.perArea(sessions, areaId: areaId, days: grid.dayCount, now: now, calendar: calendar)
        var levels = Array(repeating: 0, count: MapGrid.cellCount)
        for (day, seconds) in totals {
            if let index = grid.index(of: day) {
                levels[index] = step(seconds)
            }
        }
        return levels
    }
}
