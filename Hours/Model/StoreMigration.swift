import Foundation

/// Moves the store from Application Support into the app group container,
/// where the widget can read it. Runs once per launch, before the store loads.
///
/// It copies, checks the copy, and only then uses the new path. The old file
/// stays where it was. Anything that goes wrong leaves the app on the old
/// path for this launch, so no session is lost.
enum StoreMigration {
    /// The store file this launch uses. HOURS_STORE wins, untouched.
    static func storeURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        if let path = environment["HOURS_STORE"], !path.isEmpty {
            return Store.defaultURL(environment: environment)
        }
        return resolve(legacy: Store.legacyURL(), group: Store.groupURL())
    }

    /// `group` nil means macOS gave no container for the group.
    static func resolve(legacy: URL, group: URL?, fileManager: FileManager = .default) -> URL {
        guard let group else {
            NSLog("Hours: no app group container; using \(legacy.path)")
            return legacy
        }
        // Already moved, or a fresh install that saved there.
        if fileManager.fileExists(atPath: group.path) { return group }

        guard fileManager.fileExists(atPath: legacy.path) else {
            // Nothing to move. Use the container if a file can be made in it.
            return canWrite(in: group.deletingLastPathComponent(), fileManager: fileManager) ? group : legacy
        }

        do {
            try copy(legacy, to: group, fileManager: fileManager)
            NSLog("Hours: copied the store from \(legacy.path) to \(group.path)")
            return group
        } catch {
            NSLog("Hours: could not move the store to \(group.path) (\(error)); using \(legacy.path)")
            return legacy
        }
    }

    enum Failure: Error {
        /// The old file doesn't decode. Store.load moves it aside on the old path.
        case unreadable
        /// The copy read back different from the original.
        case mismatch
    }

    /// Copies to a temporary name next to `destination`, reads it back, and
    /// renames it into place only when it matches byte for byte and decodes.
    private static func copy(_ source: URL, to destination: URL, fileManager: FileManager) throws {
        let data = try Data(contentsOf: source)
        guard let original = try? JSONDecoder().decode(StoreFile.self, from: data) else { throw Failure.unreadable }

        let folder = destination.deletingLastPathComponent()
        try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
        let temporary = folder.appendingPathComponent("store.migrating-\(UUID().uuidString).json")
        defer { try? fileManager.removeItem(at: temporary) }

        try data.write(to: temporary)
        let copied = try Data(contentsOf: temporary)
        guard copied == data, try JSONDecoder().decode(StoreFile.self, from: copied) == original else {
            throw Failure.mismatch
        }
        try fileManager.moveItem(at: temporary, to: destination)
    }

    private static func canWrite(in folder: URL, fileManager: FileManager) -> Bool {
        do {
            try fileManager.createDirectory(at: folder, withIntermediateDirectories: true)
            let probe = folder.appendingPathComponent(".write-check-\(UUID().uuidString)")
            try Data().write(to: probe)
            try fileManager.removeItem(at: probe)
            return true
        } catch {
            NSLog("Hours: cannot write in \(folder.path) (\(error))")
            return false
        }
    }
}
