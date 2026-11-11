import Foundation
import Testing
@testable import Hours

@MainActor
@Suite struct StoreTests {
    let dir: URL
    let url: URL

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("HoursTests-\(UUID().uuidString)")
        url = dir.appendingPathComponent("nested").appendingPathComponent("store.json")
    }

    @Test func missingFileLoadsEmptyAndCreatesNothing() {
        let store = Store(url: url)
        #expect(store.areas.isEmpty)
        #expect(store.sessions.isEmpty)
        #expect(!FileManager.default.fileExists(atPath: url.path))
    }

    @Test func roundTripKeepsAreasAndSessions() {
        let store = Store(url: url)
        store.seedIfEmpty()
        let t0 = Date(timeIntervalSinceReferenceDate: 800_000_000.25)
        store.toggle("coding", now: t0)
        store.toggle("writing", now: t0.addingTimeInterval(600))
        store.toggle("writing", now: t0.addingTimeInterval(900))
        store.toggle("study", now: t0.addingTimeInterval(1000))

        let reloaded = Store(url: url)
        #expect(reloaded.areas == store.areas)
        #expect(reloaded.areas.map(\.name) == ["Coding", "Writing", "Study"])
        #expect(reloaded.sessions == store.sessions)
        #expect(reloaded.sessions.count == 3)
        #expect(reloaded.running?.areaId == "study")
        #expect(reloaded.sessions[0].end == t0.addingTimeInterval(600))
    }

    @Test func togglingTheRunningAreaStopsIt() {
        let store = Store(url: url)
        let t0 = Date()
        store.toggle("coding", now: t0)
        #expect(store.running?.areaId == "coding")
        store.toggle("coding", now: t0.addingTimeInterval(60))
        #expect(store.running == nil)
        #expect(store.sessions.count == 1)
    }

    @Test func fileDecodesWithABareJSONDecoder() throws {
        let store = Store(url: url)
        store.seedIfEmpty()
        store.toggle("coding", now: Date())
        let file = try JSONDecoder().decode(StoreFile.self, from: Data(contentsOf: url))
        #expect(file == store.file)
    }

    @Test func saveReplacesTheFileByRenameAndLeavesNoTempFiles() throws {
        let store = Store(url: url)
        store.seedIfEmpty()
        let before = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int
        store.toggle("coding", now: Date())
        let after = try FileManager.default.attributesOfItem(atPath: url.path)[.systemFileNumber] as? Int
        // An atomic write lands as a new file renamed over the old one.
        #expect(before != nil && before != after)
        let names = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(names == ["store.json"])
    }

    @Test func unreadableFileIsMovedAsideNotOverwritten() throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try Data("not json".utf8).write(to: url)
        let store = Store(url: url)
        #expect(store.areas.isEmpty)
        let names = try FileManager.default.contentsOfDirectory(atPath: url.deletingLastPathComponent().path)
        #expect(names.count == 1)
        #expect(names.first?.hasPrefix("store.unreadable-") == true)
    }

    @Test func envVarOverridesTheLocation() {
        let custom = Store.defaultURL(environment: ["HOURS_STORE": "/tmp/x/hours.json"])
        #expect(custom.path == "/tmp/x/hours.json")
        let standard = Store.defaultURL(environment: [:])
        #expect(standard.path.hasSuffix("Library/Application Support/Hours/store.json"))
    }

    @Test func mapSelectionPersists() throws {
        let defaults = try #require(UserDefaults(suiteName: "HoursTests-\(UUID().uuidString)"))
        #expect(MapSelection.load(from: defaults) == .all)
        MapSelection.area("coding").save(to: defaults)
        #expect(MapSelection.load(from: defaults) == .area("coding"))
        MapSelection.all.save(to: defaults)
        #expect(MapSelection.load(from: defaults) == .all)
    }
}

@Suite struct MapSelectionTests {
    let areas = [
        FocusArea(id: "coding", name: "Coding", colorHex: "2da44e"),
        FocusArea(id: "writing", name: "Writing", colorHex: "0969da"),
    ]

    @Test func clickingTheMapCyclesAllThenEachArea() {
        #expect(MapSelection.all.next(in: areas) == .area("coding"))
        #expect(MapSelection.area("coding").next(in: areas) == .area("writing"))
        #expect(MapSelection.area("writing").next(in: areas) == .all)
    }

    @Test func aDeletedAreaMovesOnToTheFirstArea() {
        #expect(MapSelection.area("gone").next(in: areas) == .area("coding"))
        #expect(MapSelection.area("gone").next(in: []) == .all)
    }
}
