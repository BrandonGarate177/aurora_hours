import Foundation
import Testing
@testable import Hours

@Suite struct HostsFileTests {
    /// A stock macOS /etc/hosts.
    let stock = """
    ##
    # Host Database
    #
    # localhost is used to configure the loopback interface
    # when the system is booting.  Do not change this entry.
    ##
    127.0.0.1\tlocalhost
    255.255.255.255\tbroadcasthost
    ::1             localhost

    """

    let xBlock = """
    # hours start
    127.0.0.1 x.com
    ::1 x.com
    127.0.0.1 www.x.com
    ::1 www.x.com
    # hours end

    """

    @Test func insertAppendsTheBlockAfterTheExistingLines() {
        let result = HostsFile.rewrite(stock, blocking: ["x.com"])
        let expected = stock + xBlock
        #expect(result == expected)
        #expect(HostsFile.isBlocking(result))
    }

    @Test func updateReplacesTheOldBlockInPlace() {
        let before = "127.0.0.1 localhost\n" + xBlock + "10.0.0.5 nas.local\n"
        let result = HostsFile.rewrite(before, blocking: ["reddit.com"])
        let expected = """
        127.0.0.1 localhost
        # hours start
        127.0.0.1 reddit.com
        ::1 reddit.com
        127.0.0.1 www.reddit.com
        ::1 www.reddit.com
        # hours end
        10.0.0.5 nas.local

        """
        #expect(result == expected)
    }

    @Test func removeLeavesTheFileAsItWasBefore() {
        let blocked = HostsFile.rewrite(stock, blocking: ["x.com", "youtube.com"])
        let result = HostsFile.rewrite(blocked, blocking: [])
        #expect(result == stock)
        #expect(!HostsFile.isBlocking(result))
    }

    @Test func rewriteIsIdempotent() {
        let once = HostsFile.rewrite(stock, blocking: ["x.com", "reddit.com"])
        let twice = HostsFile.rewrite(once, blocking: ["x.com", "reddit.com"])
        #expect(twice == once)
        let removedOnce = HostsFile.rewrite(once, blocking: [])
        let removedTwice = HostsFile.rewrite(removedOnce, blocking: [])
        #expect(removedTwice == removedOnce)
    }

    @Test func fileWithNoMarkersIsUnchangedByAnUnblock() {
        #expect(HostsFile.rewrite(stock, blocking: []) == stock)
        let noFinalNewline = "127.0.0.1 localhost\n::1 localhost"
        #expect(HostsFile.rewrite(noFinalNewline, blocking: []) == noFinalNewline)
        #expect(HostsFile.rewrite("", blocking: []) == "")
    }

    @Test func emptyOrUnterminatedFileGetsABlockOnItsOwnLines() {
        #expect(HostsFile.rewrite("", blocking: ["x.com"]) == xBlock)
        let noFinalNewline = "127.0.0.1 localhost"
        #expect(HostsFile.rewrite(noFinalNewline, blocking: ["x.com"]) == noFinalNewline + "\n" + xBlock)
    }

    @Test func staleBlockFromACrashIsRemoved() {
        let stale = stock + """
        # hours start
        127.0.0.1 old.example.com
        ::1 old.example.com
        # hours end

        """
        #expect(HostsFile.rewrite(stale, blocking: []) == stock)
        #expect(HostsFile.rewrite(stale, blocking: ["x.com"]) == stock + xBlock)
    }

    @Test func twoBlocksCollapseIntoOne() {
        let doubled = "a.local\n" + xBlock + "b.local\n" + xBlock
        let result = HostsFile.rewrite(doubled, blocking: ["x.com"])
        #expect(result == "a.local\n" + xBlock + "b.local\n")
    }

    @Test func strayMarkersLoseOnlyTheirOwnLine() {
        let danglingStart = "# hours start\n10.0.0.5 nas.local\n"
        #expect(HostsFile.rewrite(danglingStart, blocking: []) == "10.0.0.5 nas.local\n")
        let danglingEnd = "10.0.0.5 nas.local\n# hours end\n"
        #expect(HostsFile.rewrite(danglingEnd, blocking: []) == "10.0.0.5 nas.local\n")
    }

    @Test func markersWithStrayWhitespaceStillMatch() {
        let messy = "a.local\n  # hours start \n127.0.0.1 x.com\n# hours end\t\nb.local\n"
        #expect(HostsFile.rewrite(messy, blocking: []) == "a.local\nb.local\n")
    }

    @Test func linesOutsideTheMarkersAreUntouched() {
        let custom = """
        # my own notes
        127.0.0.1\tlocalhost
        10.0.0.5    nas.local   # keep the spacing
        0.0.0.0 ads.example.com
        \t
        fe80::1%lo0\tlocalhost
        """
        let blocked = HostsFile.rewrite(custom, blocking: ["x.com"])
        let outside = blocked.split(separator: "\n", omittingEmptySubsequences: false)
            .prefix(while: { $0 != "# hours start" })
            .joined(separator: "\n")
        #expect(outside == custom)
        #expect(blocked.hasPrefix(custom + "\n"))
    }

    @Test func hostsWithAndWithoutWwwGiveOnePairEach() {
        let both = HostsFile.entries(for: ["youtube.com", "www.youtube.com", "WWW.YouTube.com"])
        let expected = [
            "127.0.0.1 youtube.com", "::1 youtube.com",
            "127.0.0.1 www.youtube.com", "::1 www.youtube.com",
        ]
        #expect(both == expected)
        #expect(HostsFile.rewrite("", blocking: ["www.x.com"]) == xBlock)
    }

    @Test func subdomainsKeepTheirOwnName() {
        let entries = HostsFile.entries(for: ["news.ycombinator.com"])
        #expect(entries.contains("127.0.0.1 news.ycombinator.com"))
        #expect(entries.contains("::1 www.news.ycombinator.com"))
        #expect(!entries.contains { $0.hasSuffix(" ycombinator.com") })
    }

    @Test func listParsingSkipsCommentsBlanksAndNonHosts() {
        let list = """
        # sites to block
        x.com
          Twitter.com   # old name

        https://www.youtube.com/watch?v=1
        reddit.com:443
        localhost
        127.0.0.1
        not a host
        x.com
        """
        #expect(HostsFile.hosts(inList: list) == ["x.com", "twitter.com", "youtube.com", "reddit.com"])
    }
}
