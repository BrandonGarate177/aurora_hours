import Foundation

/// Sums of focus time by day. Sessions that cross local midnight count toward
/// each day they touch. A running session counts up to `now`.
enum Totals {
    /// Seconds per day, keyed by the start of each local day.
    /// Pass `areaId` to count one area only; nil counts every area.
    static func daily(
        _ sessions: [Session],
        areaId: String? = nil,
        now: Date,
        calendar: Calendar = .current
    ) -> [Date: TimeInterval] {
        var result: [Date: TimeInterval] = [:]
        for session in sessions where areaId == nil || session.areaId == areaId {
            let end = min(session.end ?? now, now)
            var cursor = session.start
            while cursor < end {
                let dayStart = calendar.startOfDay(for: cursor)
                guard let nextDay = calendar.date(byAdding: .day, value: 1, to: dayStart) else { break }
                let pieceEnd = min(end, nextDay)
                result[dayStart, default: 0] += pieceEnd.timeIntervalSince(cursor)
                cursor = pieceEnd
            }
        }
        return result
    }

    /// Seconds focused today, every area together.
    static func today(_ sessions: [Session], now: Date, calendar: Calendar = .current) -> TimeInterval {
        daily(sessions, now: now, calendar: calendar)[calendar.startOfDay(for: now)] ?? 0
    }

    /// Seconds per day over the last `days` days, today included. Every one of
    /// those days has a key, with 0 when nothing was logged. nil `areaId` is the
    /// combined map.
    static func perArea(
        _ sessions: [Session],
        areaId: String?,
        days: Int,
        now: Date,
        calendar: Calendar = .current
    ) -> [Date: TimeInterval] {
        let all = daily(sessions, areaId: areaId, now: now, calendar: calendar)
        let today = calendar.startOfDay(for: now)
        var result: [Date: TimeInterval] = [:]
        for offset in 0..<max(0, days) {
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { continue }
            result[day] = all[day] ?? 0
        }
        return result
    }
}
