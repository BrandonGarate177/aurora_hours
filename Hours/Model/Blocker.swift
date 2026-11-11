import Foundation
import Observation

/// Blocks the sites in blocked.txt while a session runs and the Block sites
/// setting is on, by writing them into the hosts file between Hours' markers
/// (see HostsFile). Off by default.
///
/// The real target is /etc/hosts, which needs admin rights: each write asks
/// for the password through the standard macOS prompt (AppleScript's `with
/// administrator privileges`), so a session start and a stop each ask once.
/// HOURS_HOSTS=/path points it at a plain file instead and skips the prompt,
/// for tests and manual checks.
@MainActor
final class Blocker {
    static let defaultsKey = "blockSites"
    static let defaultList = [
        "x.com", "twitter.com", "youtube.com", "reddit.com",
        "instagram.com", "facebook.com", "tiktok.com", "news.ycombinator.com",
    ]

    enum Target: Equatable, Sendable {
        /// A plain file, written directly. No prompt, no DNS flush.
        case file(URL)
        /// /etc/hosts, written as root after the admin prompt, then a DNS flush.
        case system
    }

    let store: Store
    let listURL: URL
    let target: Target
    private let defaults: UserDefaults

    init(
        store: Store,
        listURL: URL = Blocker.defaultListURL(),
        target: Target = Blocker.defaultTarget(),
        defaults: UserDefaults = .standard
    ) {
        self.store = store
        self.listURL = listURL
        self.target = target
        self.defaults = defaults
    }

    // MARK: Locations

    /// blocked.txt sits next to the store, so HOURS_STORE moves it too and test
    /// runs never touch ~/Library/Application Support/Hours/.
    nonisolated static func defaultListURL(environment: [String: String] = ProcessInfo.processInfo.environment) -> URL {
        Store.defaultURL(environment: environment).deletingLastPathComponent().appendingPathComponent("blocked.txt")
    }

    nonisolated static func defaultTarget(environment: [String: String] = ProcessInfo.processInfo.environment) -> Target {
        if let path = environment["HOURS_HOSTS"], !path.isEmpty {
            return .file(URL(fileURLWithPath: (path as NSString).expandingTildeInPath))
        }
        return .system
    }

    var hostsURL: URL {
        switch target {
        case .file(let url): url
        case .system: URL(fileURLWithPath: "/etc/hosts")
        }
    }

    // MARK: Setting

    /// The Block sites checkmark. Flipping it blocks or unblocks at once if a
    /// session is running.
    var isOn: Bool {
        get { defaults.bool(forKey: Self.defaultsKey) }
        set {
            defaults.set(newValue, forKey: Self.defaultsKey)
            sync()
        }
    }

    // MARK: Blocking

    /// Brings the hosts file in line now, then again each time a session starts
    /// or stops. Called once at launch: a block left by a crash goes away
    /// unless its session is still running with the setting on.
    func follow() {
        withObservationTracking {
            _ = store.running
        } onChange: { [weak self] in
            Task { @MainActor in self?.follow() }
        }
        sync()
    }

    /// Blocks if the setting is on and a session runs, unblocks otherwise.
    /// Switching areas keeps the block: the store ends one session and starts
    /// the next in one step.
    func sync() {
        apply(blocking: isOn && store.running != nil)
    }

    /// Removes the block whatever the setting. Quit calls this.
    func unblock() {
        apply(blocking: false)
    }

    /// The hosts to block, read fresh each time so edits count at the next
    /// start or switch. Creates the list with the defaults on first use.
    func hosts() -> [String] {
        guard let text = try? String(contentsOf: ensureList(), encoding: .utf8) else { return [] }
        return HostsFile.hosts(inList: text)
    }

    /// blocked.txt, created with the default sites if it isn't there yet.
    @discardableResult
    func ensureList() -> URL {
        if !FileManager.default.fileExists(atPath: listURL.path) {
            do {
                try FileManager.default.createDirectory(at: listURL.deletingLastPathComponent(), withIntermediateDirectories: true)
                try (Self.defaultList.joined(separator: "\n") + "\n").write(to: listURL, atomically: true, encoding: .utf8)
            } catch {
                NSLog("Hours: could not create the blocked list at \(listURL.path): \(error)")
            }
        }
        return listURL
    }

    private func apply(blocking: Bool) {
        let current: String
        do {
            current = try readHosts()
        } catch {
            // Never write over a hosts file we couldn't read.
            NSLog("Hours: could not read \(hostsURL.path): \(error)")
            return
        }
        let next = HostsFile.rewrite(current, blocking: blocking ? hosts() : [])
        guard next != current else { return }
        do {
            switch target {
            case .file(let url): try next.write(to: url, atomically: true, encoding: .utf8)
            case .system: try Self.writeSystemHosts(next)
            }
        } catch {
            NSLog("Hours: could not \(blocking ? "block" : "unblock") sites: \(error)")
        }
    }

    /// A missing file reads as empty only for a test file; /etc/hosts always exists.
    private func readHosts() throws -> String {
        if case .file(let url) = target, !FileManager.default.fileExists(atPath: url.path) { return "" }
        return try String(contentsOf: hostsURL, encoding: .utf8)
    }

    // MARK: Admin write

    struct AdminError: Error, CustomStringConvertible {
        let description: String
    }

    /// Writes the new text to a temp file, then has root copy it over
    /// /etc/hosts (cat keeps the file's owner and mode) and flush the DNS
    /// cache. macOS shows its password prompt for this.
    private static func writeSystemHosts(_ text: String) throws {
        let temp = FileManager.default.temporaryDirectory.appendingPathComponent("hours-hosts-\(UUID().uuidString)")
        try text.write(to: temp, atomically: true, encoding: .utf8)
        defer { try? FileManager.default.removeItem(at: temp) }

        var error: NSDictionary?
        guard let script = NSAppleScript(source: adminScript(copying: temp.path, to: "/etc/hosts")) else {
            throw AdminError(description: "could not build the admin script")
        }
        script.executeAndReturnError(&error)
        if let error {
            let message = error[NSAppleScript.errorMessage] as? String ?? "\(error)"
            throw AdminError(description: message)
        }
    }

    /// The AppleScript that copies `source` over `destination` as root and
    /// flushes DNS.
    nonisolated static func adminScript(copying source: String, to destination: String) -> String {
        let shell = "/bin/cat \(shellQuoted(source)) > \(shellQuoted(destination)) || exit 1; "
            + "/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder; exit 0"
        let escaped = shell.replacingOccurrences(of: "\\", with: "\\\\").replacingOccurrences(of: "\"", with: "\\\"")
        return "do shell script \"\(escaped)\" with administrator privileges"
    }

    nonisolated static func shellQuoted(_ path: String) -> String {
        "'" + path.replacingOccurrences(of: "'", with: "'\\''") + "'"
    }
}
