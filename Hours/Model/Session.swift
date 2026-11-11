import Foundation

/// One stretch of focus on one area. `end` is nil while it runs.
struct Session: Codable, Hashable, Sendable {
    var areaId: String
    var start: Date
    var end: Date?

    var isRunning: Bool { end == nil }

    /// Seconds from start to end, or to `now` while running.
    func duration(now: Date) -> TimeInterval {
        max(0, (end ?? now).timeIntervalSince(start))
    }
}
