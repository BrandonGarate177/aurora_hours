import Foundation

/// Where each day sits in the dropdown map: 53 week columns by 7 weekday rows,
/// Sunday at the top like the share page, today in the last column.
///
/// The map shows one year ending today: 365 days, or 366 when the year back
/// crosses a Feb 29. The cells above the first day in the first column
/// (`leading`) and below today in the last column are blank. When today is a
/// Sunday a 366-day year doesn't fit in 53 columns, and its oldest day is left out.
///
/// Cells are numbered column by column: index = column * 7 + row.
struct MapGrid: Equatable, Sendable {
    static let columns = 53
    static let rows = 7
    static let cellCount = columns * rows

    /// Start of today.
    let today: Date
    /// Start of the oldest day shown.
    let firstDay: Date
    /// Days shown, today included.
    let dayCount: Int
    /// Blank cells before `firstDay` in the first column.
    let leading: Int

    private let calendar: Calendar

    init(now: Date, calendar: Calendar = .current) {
        self.calendar = calendar
        today = calendar.startOfDay(for: now)
        let yearAgo = calendar.date(byAdding: .year, value: -1, to: today) ?? today
        let yearDays = calendar.dateComponents([.day], from: yearAgo, to: today).day ?? 365
        let todayRow = MapGrid.row(of: today, calendar: calendar)
        // Every cell up to and including today's.
        let fits = (MapGrid.columns - 1) * MapGrid.rows + todayRow + 1
        dayCount = min(yearDays, fits)
        leading = fits - dayCount
        firstDay = calendar.date(byAdding: .day, value: -(dayCount - 1), to: today) ?? today
    }

    /// The weekday row, 0 for Sunday through 6 for Saturday.
    static func row(of date: Date, calendar: Calendar) -> Int {
        (calendar.component(.weekday, from: date) - 1) % 7
    }

    /// The cell index for a day, or nil when the day isn't on the map.
    func index(of date: Date) -> Int? {
        let day = calendar.startOfDay(for: date)
        guard day >= firstDay, day <= today,
              let offset = calendar.dateComponents([.day], from: firstDay, to: day).day
        else { return nil }
        return leading + offset
    }

    struct Cell: Equatable, Sendable {
        var column: Int
        var row: Int
    }

    func cell(of date: Date) -> Cell? {
        index(of: date).map { Cell(column: $0 / MapGrid.rows, row: $0 % MapGrid.rows) }
    }

    /// The day in a cell, or nil for a blank cell.
    func date(at index: Int) -> Date? {
        let offset = index - leading
        guard offset >= 0, offset < dayCount else { return nil }
        return calendar.date(byAdding: .day, value: offset, to: firstDay)
    }
}
