import Foundation
import Observation

/// What goes on disk. Plain Codable with default coders (dates as seconds
/// since 2001), so another target, like the widget, can decode it with a bare
/// JSONDecoder. Lives in Shared/, built into both the app and the widget.
struct StoreFile: Codable, Equatable, Sendable {
    var version = 1
    var areas: [FocusArea] = []
    var sessions: [Session] = []
}

/// The focus areas and every session, saved as one JSON file after each change.
@MainActor
@Observable
final class Store {
    private(set) var areas: [FocusArea]
    private(set) var sessions: [Session]
    let url: URL

    init(url: URL = Store.defaultURL()) {
        self.url = url
        let file = Store.load(from: url)
        areas = file.areas
        sessions = file.sessions
    }

    // MARK: Location

    /// The app group both the app and the widget are entitled to. The widget
    /// is sandboxed, so the group container is the only place both can read.
    nonisolated static let appGroup = "group.com.hoursapp.Hours"

    /// Where the store should live. The env var HOURS_STORE (a file path) wins,
    /// for tests and seeding; otherwise the group container. The app may still
    /// run from `legacyURL()` for a launch (see StoreMigration).
    nonisolated static func defaultURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let path = environment["HOURS_STORE"], !path.isEmpty {
            return URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
        }
        return groupURL() ?? legacyURL()
    }

    /// `store.json` in the group container, or nil when macOS gives this
    /// process no container for the group (not entitled to it).
    nonisolated static func groupURL() -> URL? {
        FileManager.default.containerURL(forSecurityApplicationGroupIdentifier: appGroup)?
            .appendingPathComponent("store.json")
    }

    /// Where builds before the widget kept the store.
    nonisolated static func legacyURL() -> URL {
        let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return support.appendingPathComponent("Hours", isDirectory: true).appendingPathComponent("store.json")
    }

    // MARK: Reading and writing

    /// Reads the file. A missing file is an empty store. A file that won't
    /// decode is moved aside, not overwritten, so nothing is lost.
    nonisolated static func load(from url: URL) -> StoreFile {
        guard let data = try? Data(contentsOf: url) else { return StoreFile() }
        do {
            return try JSONDecoder().decode(StoreFile.self, from: data)
        } catch {
            let stamp = Int(Date().timeIntervalSince1970)
            let aside = url.deletingPathExtension().appendingPathExtension("unreadable-\(stamp).json")
            try? FileManager.default.moveItem(at: url, to: aside)
            NSLog("Hours: store at \(url.path) did not decode (\(error)); moved it to \(aside.lastPathComponent)")
            return StoreFile()
        }
    }

    /// Writes to a temporary file and renames it over the old one, so a crash
    /// mid-write leaves the previous file whole.
    nonisolated static func write(_ file: StoreFile, to url: URL) throws {
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        try encoder.encode(file).write(to: url, options: .atomic)
    }

    var file: StoreFile { StoreFile(areas: areas, sessions: sessions) }

    func save() {
        do {
            try Store.write(file, to: url)
        } catch {
            NSLog("Hours: could not save the store to \(url.path): \(error)")
        }
    }

    // MARK: Timer

    /// The session that is running now, if any.
    var running: Session? { sessions.last(where: \.isRunning) }

    /// Click on an area: start it, stop it if it is the one running, or switch
    /// to it from another.
    func toggle(_ areaId: String, now: Date = Date()) {
        let wasRunning = running?.areaId
        stopAll(at: now)
        if wasRunning != areaId {
            sessions.append(Session(areaId: areaId, start: now, end: nil))
        }
        save()
    }

    func stop(now: Date = Date()) {
        stopAll(at: now)
        save()
    }

    private func stopAll(at now: Date) {
        for index in sessions.indices where sessions[index].end == nil {
            sessions[index].end = max(now, sessions[index].start)
        }
    }

    // MARK: Areas

    func setAreas(_ newAreas: [FocusArea]) {
        areas = newAreas
        save()
    }

    func area(id: String) -> FocusArea? {
        areas.first { $0.id == id }
    }
}
