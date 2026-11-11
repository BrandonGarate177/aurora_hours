import Foundation

/// The hosts file rewrite behind site blocking. Hours owns the lines between
/// `# hours start` and `# hours end` and nothing else. Each blocked host gets
/// four lines, for itself and its `www.` form, on 127.0.0.1 and ::1.
enum HostsFile {
    static let startMarker = "# hours start"
    static let endMarker = "# hours end"

    /// Returns `text` with Hours' block set to `hosts`, or removed when `hosts`
    /// is empty. Lines outside the markers stay as they are. The block goes
    /// where the first old one was, or at the end. A start marker with no end
    /// marker after it, or an end with no start, loses only its own line, so a
    /// hand-edited file never loses lines Hours didn't write. Running it twice
    /// with the same hosts gives the same text.
    static func rewrite(_ text: String, blocking hosts: [String]) -> String {
        var lines = text.split(separator: "\n", omittingEmptySubsequences: false).map(String.init)
        let endsWithNewline = text.hasSuffix("\n")
        if lines.last == "" { lines.removeLast() }

        var kept: [String] = []
        var blockAt: Int?
        var index = 0
        while index < lines.count {
            let line = lines[index]
            if isMarker(line, startMarker) {
                blockAt = blockAt ?? kept.count
                let end = lines[(index + 1)...].firstIndex { isMarker($0, endMarker) }
                index = end.map { $0 + 1 } ?? index + 1
            } else if isMarker(line, endMarker) {
                blockAt = blockAt ?? kept.count
                index += 1
            } else {
                kept.append(line)
                index += 1
            }
        }

        let entries = self.entries(for: hosts)
        let block = entries.isEmpty ? [] : [startMarker] + entries + [endMarker]
        let at = blockAt ?? kept.count
        kept.insert(contentsOf: block, at: at)

        guard !kept.isEmpty else { return "" }
        let blockIsLast = !block.isEmpty && at + block.count == kept.count
        return kept.joined(separator: "\n") + (endsWithNewline || blockIsLast ? "\n" : "")
    }

    /// Whether `text` holds a block from Hours.
    static func isBlocking(_ text: String) -> Bool {
        text.split(separator: "\n").contains { isMarker(String($0), startMarker) }
    }

    /// The lines that block `hosts`: each host and its `www.` form, on IPv4 and IPv6.
    static func entries(for hosts: [String]) -> [String] {
        unique(hosts.compactMap(hostname)).flatMap { host in
            [host, "www.\(host)"].flatMap { name in ["127.0.0.1 \(name)", "::1 \(name)"] }
        }
    }

    /// The hosts in the blocked list: one per line, `#` starts a comment. A
    /// pasted URL like `https://www.youtube.com/watch` counts as `youtube.com`.
    /// Lines that aren't a host name are skipped.
    static func hosts(inList text: String) -> [String] {
        unique(text.split(whereSeparator: \.isNewline).compactMap { line in
            hostname(String(line.prefix { $0 != "#" }))
        })
    }

    /// `www.YouTube.com` and `https://youtube.com/x` become `youtube.com`.
    /// Returns nil for anything that isn't a dotted host name, so a stray word,
    /// `localhost` or an address never gets into the hosts file.
    static func hostname(_ raw: String) -> String? {
        var host = raw.trimmingCharacters(in: .whitespaces).lowercased()
        if let scheme = host.range(of: "://") { host = String(host[scheme.upperBound...]) }
        host = String(host.prefix { $0 != "/" && $0 != ":" && $0 != "?" })
        if host.hasSuffix(".") { host.removeLast() }
        if host.hasPrefix("www.") { host.removeFirst(4) }
        let allowed = Set("abcdefghijklmnopqrstuvwxyz0123456789.-")
        guard host.contains("."), host.allSatisfy(allowed.contains),
              !host.hasPrefix("."), !host.hasPrefix("-"), !host.contains(".."),
              !host.allSatisfy({ $0.isNumber || $0 == "." })
        else { return nil }
        return host
    }

    private static func isMarker(_ line: String, _ marker: String) -> Bool {
        line.trimmingCharacters(in: .whitespacesAndNewlines) == marker
    }

    private static func unique(_ hosts: [String]) -> [String] {
        var seen = Set<String>()
        return hosts.filter { seen.insert($0).inserted }
    }
}
