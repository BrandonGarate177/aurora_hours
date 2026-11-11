import Foundation
import Testing
@testable import Hours

/// Everything here writes to a temp hosts file through `.file`. The `.system`
/// target, the real /etc/hosts, is never exercised in tests.
@MainActor
@Suite(.serialized) struct BlockerTests {
    let dir: URL
    let hostsURL: URL
    let defaults: UserDefaults
    let store: Store
    let blocker: Blocker
    let original = "127.0.0.1 localhost\n::1 localhost\n"

    init() throws {
        dir = FileManager.default.temporaryDirectory.appendingPathComponent("HoursBlockerTests-\(UUID().uuidString)")
        try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        hostsURL = dir.appendingPathComponent("hosts")
        try original.write(to: hostsURL, atomically: true, encoding: .utf8)
        // One suite, emptied before each test (they run one at a time), so
        // runs don't leave a plist per test in ~/Library/Preferences.
        defaults = try #require(UserDefaults(suiteName: "HoursBlockerTests"))
        defaults.removePersistentDomain(forName: "HoursBlockerTests")
        store = Store(url: dir.appendingPathComponent("store.json"))
        store.seedIfEmpty()
        blocker = Blocker(
            store: store,
            listURL: dir.appendingPathComponent("blocked.txt"),
            target: .file(hostsURL),
            defaults: defaults
        )
    }

    func hostsText() throws -> String {
        try String(contentsOf: hostsURL, encoding: .utf8)
    }

    @Test func offByDefaultAndASessionLeavesTheFileAlone() throws {
        #expect(!blocker.isOn)
        store.toggle("coding")
        blocker.sync()
        #expect(try hostsText() == original)
    }

    @Test func onWithASessionBlocksAndStopUnblocks() throws {
        blocker.isOn = true
        #expect(try hostsText() == original) // No session yet.

        store.toggle("coding")
        blocker.sync()
        let blocked = try hostsText()
        #expect(blocked.hasPrefix(original + "# hours start\n"))
        #expect(blocked.contains("127.0.0.1 youtube.com\n"))
        #expect(blocked.contains("::1 www.news.ycombinator.com\n"))

        store.toggle("writing") // Switch: still blocked.
        blocker.sync()
        #expect(try hostsText() == blocked)

        store.stop()
        blocker.sync()
        #expect(try hostsText() == original)
    }

    @Test func turningItOnOrOffMidSessionTakesEffectAtOnce() throws {
        store.toggle("coding")
        blocker.isOn = true
        #expect(HostsFile.isBlocking(try hostsText()))
        blocker.isOn = false
        #expect(try hostsText() == original)
    }

    @Test func settingSticksInDefaults() {
        blocker.isOn = true
        let again = Blocker(store: store, listURL: blocker.listURL, target: blocker.target, defaults: defaults)
        #expect(again.isOn)
        #expect(defaults.bool(forKey: "blockSites"))
    }

    @Test func unblockRemovesTheBlockEvenWithTheSessionRunning() throws {
        blocker.isOn = true
        store.toggle("coding")
        blocker.sync()
        blocker.unblock()
        #expect(try hostsText() == original)
    }

    @Test func launchRemovesAStaleBlock() throws {
        let stale = HostsFile.rewrite(original, blocking: ["old.example.com"])
        try stale.write(to: hostsURL, atomically: true, encoding: .utf8)
        blocker.isOn = true // On, but no session is running.
        #expect(try hostsText() == original)
    }

    @Test func listIsCreatedWithTheDefaultsAndEditsCount() throws {
        #expect(!FileManager.default.fileExists(atPath: blocker.listURL.path))
        #expect(blocker.hosts() == Blocker.defaultList)
        let text = try String(contentsOf: blocker.listURL, encoding: .utf8)
        #expect(text == Blocker.defaultList.joined(separator: "\n") + "\n")

        try "reddit.com\n".write(to: blocker.listURL, atomically: true, encoding: .utf8)
        blocker.isOn = true
        store.toggle("coding")
        blocker.sync()
        #expect(try hostsText() == HostsFile.rewrite(original, blocking: ["reddit.com"]))
    }

    @Test func missingTestHostsFileIsCreated() throws {
        try FileManager.default.removeItem(at: hostsURL)
        blocker.isOn = true
        store.toggle("coding")
        blocker.sync()
        #expect(try hostsText().hasPrefix("# hours start\n"))
    }

    @Test func envVarPicksTheTargetAndListLocation() {
        #expect(Blocker.defaultTarget(environment: [:]) == .system)
        #expect(Blocker.defaultTarget(environment: ["HOURS_HOSTS": "/tmp/hosts-test"]) == .file(URL(fileURLWithPath: "/tmp/hosts-test")))
        let list = Blocker.defaultListURL(environment: ["HOURS_STORE": "/tmp/h/store.json"])
        #expect(list.path == "/tmp/h/blocked.txt")
        let real = Blocker.defaultListURL(environment: [:])
        #expect(real.path.hasSuffix("/Library/Application Support/Hours/blocked.txt"))
    }

    @Test func adminScriptQuotesPaths() {
        let script = Blocker.adminScript(copying: "/tmp/it's here", to: "/etc/hosts")
        let expected = #"do shell script "/bin/cat '/tmp/it'\\''s here' > '/etc/hosts' || exit 1; "#
            + #"/usr/bin/dscacheutil -flushcache; /usr/bin/killall -HUP mDNSResponder; exit 0" with administrator privileges"#
        #expect(script == expected)
    }
}
