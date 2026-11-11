import Foundation
import Testing
@testable import Hours

@Suite struct WidgetTimelineTests {
    let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "America/Los_Angeles")!
        return calendar
    }()

    func date(_ y: Int, _ m: Int, _ d: Int, _ h: Int, _ min: Int = 0, _ s: Int = 0) -> Date {
        calendar.date(from: DateComponents(year: y, month: m, day: d, hour: h, minute: min, second: s))!
    }

    @Test func nextEntryIsTheTopOfTheNextHour() {
        #expect(WidgetSnapshot.nextRefresh(after: date(2026, 11, 11, 14, 7, 28), calendar: calendar) == date(2026, 11, 11, 15))
        #expect(WidgetSnapshot.nextRefresh(after: date(2026, 11, 11, 14, 59, 59), calendar: calendar) == date(2026, 11, 11, 15))
    }

    @Test func onTheHourMovesToTheNextOne() {
        #expect(WidgetSnapshot.nextRefresh(after: date(2026, 11, 11, 15), calendar: calendar) == date(2026, 11, 11, 16))
    }

    @Test func lateEveningRollsOverToMidnight() {
        #expect(WidgetSnapshot.nextRefresh(after: date(2026, 11, 11, 23, 30), calendar: calendar) == date(2026, 11, 12, 0))
    }

    @Test func anHourLaterAcrossDaylightSaving() {
        // Nov 1 2026, 1:00 to 1:59 happens twice in Los Angeles. Either way the
        // next entry is at most an hour away.
        let firstOneThirty = date(2026, 11, 1, 0, 30).addingTimeInterval(3600)
        let next = WidgetSnapshot.nextRefresh(after: firstOneThirty, calendar: calendar)
        let half: TimeInterval = 1800
        #expect(next.timeIntervalSince(firstOneThirty) == half)
    }
}

@Suite struct StoreMigrationTests {
    let dir: URL
    let legacy: URL
    let group: URL

    init() {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("HoursMigration-\(UUID().uuidString)")
        legacy = dir.appendingPathComponent("Application Support/Hours/store.json")
        group = dir.appendingPathComponent("Group Containers/group.com.hoursapp.Hours/store.json")
    }

    func writeLegacy(_ data: Data) throws {
        try FileManager.default.createDirectory(at: legacy.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: legacy)
    }

    var sample: StoreFile {
        StoreFile(
            areas: [FocusArea(id: "coding", name: "Coding", colorHex: "2da44e")],
            sessions: [
                Session(areaId: "coding", start: Date(timeIntervalSinceReferenceDate: 800_000_000.25),
                        end: Date(timeIntervalSinceReferenceDate: 800_003_600.5)),
                Session(areaId: "coding", start: Date(timeIntervalSinceReferenceDate: 800_100_000), end: nil),
            ]
        )
    }

    @Test func oldFileIsCopiedVerifiedAndTheNewPathUsed() throws {
        let original = try JSONEncoder().encode(sample)
        try writeLegacy(original)

        let chosen = StoreMigration.resolve(legacy: legacy, group: group)

        #expect(chosen == group)
        #expect(try Data(contentsOf: group) == original)
        #expect(try JSONDecoder().decode(StoreFile.self, from: Data(contentsOf: group)) == sample)
        // The old file stays where it was, unchanged.
        #expect(try Data(contentsOf: legacy) == original)
        // No temporary copy left behind.
        let names = try FileManager.default.contentsOfDirectory(atPath: group.deletingLastPathComponent().path)
        #expect(names == ["store.json"])
    }

    @Test func theAppLoadsTheSameSessionsAfterMoving() throws {
        try writeLegacy(try JSONEncoder().encode(sample))
        let chosen = StoreMigration.resolve(legacy: legacy, group: group)
        #expect(Store.load(from: chosen) == Store.load(from: legacy))
    }

    @Test func anExistingGroupStoreIsNeverOverwritten() throws {
        try writeLegacy(try JSONEncoder().encode(sample))
        try FileManager.default.createDirectory(at: group.deletingLastPathComponent(), withIntermediateDirectories: true)
        let newer = try JSONEncoder().encode(StoreFile(areas: sample.areas, sessions: []))
        try newer.write(to: group)

        #expect(StoreMigration.resolve(legacy: legacy, group: group) == group)
        #expect(try Data(contentsOf: group) == newer)
    }

    @Test func noContainerKeepsTheOldPath() throws {
        try writeLegacy(try JSONEncoder().encode(sample))
        #expect(StoreMigration.resolve(legacy: legacy, group: nil) == legacy)
    }

    @Test func anUnwritableContainerKeepsTheOldPath() throws {
        try writeLegacy(try JSONEncoder().encode(sample))
        // A plain file where the container folder should be: nothing can be made in it.
        let blocked = dir.appendingPathComponent("blocked")
        try Data().write(to: blocked)
        let unwritable = blocked.appendingPathComponent("store.json")

        #expect(StoreMigration.resolve(legacy: legacy, group: unwritable) == legacy)
        #expect(try JSONDecoder().decode(StoreFile.self, from: Data(contentsOf: legacy)) == sample)
    }

    @Test func anUnreadableOldFileStaysForTheStoreToMoveAside() throws {
        try writeLegacy(Data("not json".utf8))
        #expect(StoreMigration.resolve(legacy: legacy, group: group) == legacy)
        #expect(!FileManager.default.fileExists(atPath: group.path))
        #expect(try Data(contentsOf: legacy) == Data("not json".utf8))
    }

    @Test func aFreshInstallStartsInTheContainer() {
        #expect(StoreMigration.resolve(legacy: legacy, group: group) == group)
        #expect(!FileManager.default.fileExists(atPath: legacy.path))
    }

    @Test func hoursStoreSkipsTheMigration() {
        let url = StoreMigration.storeURL(environment: ["HOURS_STORE": "/tmp/x/hours.json"])
        #expect(url.path == "/tmp/x/hours.json")
    }
}

@MainActor
@Suite struct WidgetDataTests {
    let url: URL
    let now = Date()
    let areas = [
        FocusArea(id: "coding", name: "Coding", colorHex: "2da44e"),
        FocusArea(id: "writing", name: "Writing", colorHex: "0969da"),
    ]

    init() {
        url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HoursWidget-\(UUID().uuidString)").appendingPathComponent("store.json")
    }

    /// A store with a few days of sessions, one still running, saved to disk
    /// through the app's own Store.
    func makeStore() -> Store {
        let store = Store(url: url)
        store.setAreas(areas)
        let day: TimeInterval = 86400
        let hour: TimeInterval = 3600
        for offset in [1, 3, 8, 40, 200] {
            let start = now.addingTimeInterval(-Double(offset) * day)
            store.toggle(offset % 2 == 0 ? "coding" : "writing", now: start)
            store.stop(now: start.addingTimeInterval(Double(offset % 5 + 1) * hour))
        }
        store.toggle("coding", now: now.addingTimeInterval(-1200))
        return store
    }

    /// What the dropdown draws for `selection` (MapSection and AreasRow).
    func appMap(_ store: Store, _ selection: MapSelection) -> (levels: [Int], colorHex: String?, today: TimeInterval) {
        let area = selection.areaId.flatMap { id in store.areas.first { $0.id == id } }
        let levels = MapLevels.levels(store.sessions, areaId: area?.id, grid: MapGrid(now: now), now: now)
        return (levels, area?.colorHex, Totals.today(store.sessions, now: now))
    }

    @Test(arguments: [MapSelection.all, .area("coding"), .area("writing"), .area("deleted")])
    func widgetMapEqualsTheDropdownMap(selection: MapSelection) {
        let store = makeStore()
        let app = appMap(store, selection)
        let widget = WidgetSnapshot(file: WidgetSnapshot.read(from: url), areaId: selection.areaId, now: now)
        #expect(widget.levels == app.levels)
        #expect(widget.colorHex == app.colorHex)
        #expect(widget.today == app.today)
        #expect(widget.levels.contains { $0 > 0 })
    }

    @Test func aMissingOrBrokenFileShowsAnEmptyMapAndMovesNothing() throws {
        #expect(WidgetSnapshot.read(from: url) == StoreFile())
        #expect(WidgetSnapshot.read(from: nil) == StoreFile())
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        #expect(WidgetSnapshot.read(from: url) == StoreFile())
        #expect(FileManager.default.fileExists(atPath: url.path))
    }
}
