// Writes a year of made-up sessions for three areas to a store file, so the
// map can be seen without a year of use. Same data every run on the same day.
//   HOURS_STORE=/tmp/hours-seed.json make seed run
//   swift scripts/seed.swift /tmp/hours-seed.json
// To see it in the widget, point it at the group container store, the one
// the widget reads:
//   HOURS_STORE=~/Library/Group\ Containers/group.com.hoursapp.Hours/store.json make seed
// Overwrites the file, after copying a group container store that is already
// there to store.before-seed-<unix time>.json beside it. Refuses the old real
// store in Application Support.
import Foundation

guard CommandLine.arguments.count == 2, !CommandLine.arguments[1].isEmpty else {
    print("usage: swift scripts/seed.swift /path/store.json")
    exit(2)
}
let url = URL(fileURLWithPath: (CommandLine.arguments[1] as NSString).expandingTildeInPath).standardizedFileURL
let real = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    .appendingPathComponent("Hours/store.json").standardizedFileURL
if url.resolvingSymlinksInPath() == real.resolvingSymlinksInPath() {
    print("seed: refusing to write over the real store at \(real.path)")
    exit(1)
}
let group = FileManager.default.homeDirectoryForCurrentUser
    .appendingPathComponent("Library/Group Containers/group.com.hoursapp.Hours/store.json").standardizedFileURL
if url.resolvingSymlinksInPath() == group.resolvingSymlinksInPath(), FileManager.default.fileExists(atPath: url.path) {
    let stamp = Int(Date().timeIntervalSince1970)
    let backup = url.deletingLastPathComponent().appendingPathComponent("store.before-seed-\(stamp).json")
    do {
        try FileManager.default.copyItem(at: url, to: backup)
    } catch {
        print("seed: could not back up \(url.path), not writing: \(error)")
        exit(1)
    }
    print("seed: copied the store that was there to \(backup.path)")
}

/// SplitMix64, so the same seed gives the same year.
struct Random {
    var state: UInt64
    mutating func unit() -> Double {
        state &+= 0x9e3779b97f4a7c15
        var z = state
        z = (z ^ (z >> 30)) &* 0xbf58476d1ce4e5b9
        z = (z ^ (z >> 27)) &* 0x94d049bb133111eb
        return Double((z ^ (z >> 31)) >> 11) / Double(1 << 53)
    }
    mutating func chance(_ p: Double) -> Bool { unit() < p }
    mutating func hours(_ low: Double, _ high: Double) -> Double { low + (high - low) * unit() * unit().squareRoot() }
}

struct Area {
    let id, name, colorHex: String
    let weekday, weekend: Double  // chance of working on it that day
    let low, high: Double         // hours when worked
}

let areas = [
    Area(id: "coding", name: "Coding", colorHex: "2da44e", weekday: 0.75, weekend: 0.3, low: 0.4, high: 5.5),
    Area(id: "writing", name: "Writing", colorHex: "0969da", weekday: 0.4, weekend: 0.25, low: 0.3, high: 3),
    Area(id: "study", name: "Study", colorHex: "bc4c00", weekday: 0.35, weekend: 0.2, low: 0.5, high: 3.5),
]

let calendar = Calendar.current
let now = Date()
let today = calendar.startOfDay(for: now)
var random = Random(state: UInt64(today.timeIntervalSince1970))
var sessions: [[String: Any]] = []

// The first logged day is 340 days back, so the oldest weeks stay empty.
for back in stride(from: 340, through: 0, by: -1) {
    guard let day = calendar.date(byAdding: .day, value: -back, to: today) else { continue }
    let weekend = calendar.isDateInWeekend(day)
    // A few quiet days: holidays, sick days.
    if random.chance(weekend ? 0.35 : 0.08) { continue }
    var cursor = day.addingTimeInterval((8.5 + random.unit() * 1.5) * 3600)
    for area in areas.shuffled(using: &random) where random.chance(weekend ? area.weekend : area.weekday) {
        let length = (random.hours(area.low, area.high) * 4).rounded() / 4 * 3600
        let end = cursor.addingTimeInterval(max(900, length))
        guard end < now else { break }
        sessions.append([
            "areaId": area.id,
            "start": cursor.timeIntervalSinceReferenceDate,
            "end": end.timeIntervalSinceReferenceDate,
        ])
        cursor = end.addingTimeInterval((10 + random.unit() * 50) * 60)
    }
}
sessions.sort { ($0["start"] as! Double) < ($1["start"] as! Double) }

let file: [String: Any] = [
    "version": 1,
    "areas": areas.map { ["id": $0.id, "name": $0.name, "colorHex": $0.colorHex] },
    "sessions": sessions,
]
do {
    try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
    let data = try JSONSerialization.data(withJSONObject: file, options: [.prettyPrinted, .sortedKeys])
    try data.write(to: url, options: .atomic)
} catch {
    print("seed: could not write \(url.path): \(error)")
    exit(1)
}
print("seed: wrote \(sessions.count) sessions to \(url.path)")

extension Random: RandomNumberGenerator {
    mutating func next() -> UInt64 {
        UInt64(unit() * Double(1 << 53)) << 11
    }
}
