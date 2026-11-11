import Foundation

/// What the widget draws, worked out from the store file the same way the
/// dropdown works out its map and total. Shared so the tests can hold the two
/// side by side.
struct WidgetSnapshot: Equatable, Sendable {
    /// One step per cell of the year map (see MapLevels). The small widget
    /// draws the last 13 columns of it, the medium one all 53.
    var levels: [Int]
    /// The area's color, or nil for the combined map.
    var colorHex: String?
    /// Seconds focused today, every area together, as the dropdown shows it.
    var today: TimeInterval

    /// `areaId` nil, or an area that no longer exists, is the combined map.
    init(file: StoreFile, areaId: String?, now: Date, calendar: Calendar = .current) {
        let area = areaId.flatMap { id in file.areas.first { $0.id == id } }
        let grid = MapGrid(now: now, calendar: calendar)
        levels = MapLevels.levels(file.sessions, areaId: area?.id, grid: grid, now: now, calendar: calendar)
        colorHex = area?.colorHex
        today = Totals.today(file.sessions, now: now, calendar: calendar)
    }

    static let empty = WidgetSnapshot(file: StoreFile(), areaId: nil, now: Date())

    /// Reads the store for the widget. Unlike Store.load it never moves a file
    /// aside: the widget only reads, and the app owns the file.
    static func read(from url: URL?) -> StoreFile {
        guard let url, let data = try? Data(contentsOf: url) else { return StoreFile() }
        return (try? JSONDecoder().decode(StoreFile.self, from: data)) ?? StoreFile()
    }

    /// When the widget's next timeline entry starts: the top of the next hour.
    /// The app reloads the widget sooner when a session starts or stops.
    static func nextRefresh(after now: Date, calendar: Calendar = .current) -> Date {
        calendar.dateInterval(of: .hour, for: now)?.end ?? now.addingTimeInterval(3600)
    }
}
