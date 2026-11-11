#if DEBUG
import Foundation
import Testing
@testable import Hours

@Suite struct DebugControlTests {
    @Test func channelCarriesTheStorePath() {
        let name = DebugControl.channel(for: URL(fileURLWithPath: "/tmp/a/store.json"))
        // scripts/hours-debug.swift builds this exact string.
        #expect(name.rawValue == "com.hoursapp.Hours.debug:/tmp/a/store.json")
    }

    @Test func differentStoresGetDifferentChannels() {
        let a = DebugControl.channel(for: URL(fileURLWithPath: "/tmp/a/store.json"))
        let b = DebugControl.channel(for: URL(fileURLWithPath: "/tmp/b/store.json"))
        #expect(a != b)
    }

    @Test func spellingsOfTheSamePathShareAChannel() {
        let plain = DebugControl.channel(for: Store.defaultURL(environment: ["HOURS_STORE": "/tmp/a/store.json"]))
        let dotted = DebugControl.channel(for: Store.defaultURL(environment: ["HOURS_STORE": "/tmp/b/../a/./store.json"]))
        #expect(plain == dotted)
    }

    @Test func noHoursStoreMeansTheDefaultStoresChannel() {
        let unset = DebugControl.channel(for: Store.defaultURL(environment: [:]))
        #expect(unset.rawValue.hasSuffix("/Library/Group Containers/\(Store.appGroup)/store.json"))
    }
}
#endif
