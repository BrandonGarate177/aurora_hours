import Foundation

/// How far back a shared map reaches. Clicking the word cycles through them.
enum SharePeriod: String, CaseIterable, Sendable {
    case year
    case ninetyDays
    case allTime

    static let defaultsKey = "sharePeriod"

    var label: String {
        switch self {
        case .year: "1 year"
        case .ninetyDays: "90 days"
        case .allTime: "All time"
        }
    }

    var next: SharePeriod {
        let all = Self.allCases
        return all[(all.firstIndex(of: self)! + 1) % all.count]
    }
}

/// One map ready to share: the days oldest first, ending today.
struct ShareMap: Equatable, Sendable {
    /// Six hex digits for an area's map, "all" for the combined one.
    var color: String
    var lastDay: Date
    /// Quarter-hours per day, 0 to 63, oldest first.
    var quarters: [Int]
    var withHours: Bool

    /// The period's total in whole hours, rounded the way the share page rounds it.
    var totalHours: Int {
        Int((Double(quarters.reduce(0, +)) / 4).rounded())
    }
}

/// The share link. The whole map rides in the fragment, which browsers never
/// send to the server. The format is in site/README.md:
///
///     <base>#1.<color hex or all>.<last day YYYYMMDD>.<0 | 1>.<one base64url character per day>
enum ShareLink {
    /// The share page. This is a placeholder until the repo has a GitHub Pages
    /// site; change it to that site's address then.
    static let base = "https://OWNER.github.io/hours/"

    static let alphabet = Array("ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_")

    /// A day's seconds in quarter-hours, rounded to the nearest one and capped
    /// at 63, so a day tops out at 15:45.
    static func quarters(_ seconds: TimeInterval) -> Int {
        min(63, max(0, Int((seconds / 900).rounded())))
    }

    /// The shade step for a day's quarter-hours: 0 none, 1 under 1 h,
    /// 2 for 1 to 2 h, 3 for 2 to 4 h, 4 for 4 h and up.
    static func step(_ quarters: Int) -> Int {
        switch quarters {
        case ..<1: 0
        case ..<4: 1
        case ..<8: 2
        case ..<16: 3
        default: 4
        }
    }

    /// The selected map over the period, from the store's sessions.
    /// `All time` starts on the first day the selected map has any time.
    static func map(
        sessions: [Session],
        areas: [FocusArea],
        selection: MapSelection,
        period: SharePeriod,
        withHours: Bool,
        now: Date,
        calendar: Calendar = .current
    ) -> ShareMap {
        let area = selection.areaId.flatMap { id in areas.first { $0.id == id } }
        let areaId = area?.id
        let today = calendar.startOfDay(for: now)

        let count: Int
        switch period {
        case .year: count = 365
        case .ninetyDays: count = 90
        case .allTime:
            let logged = Totals.daily(sessions, areaId: areaId, now: now, calendar: calendar)
                .filter { $0.value > 0 }.keys
            if let first = logged.min() {
                count = (calendar.dateComponents([.day], from: first, to: today).day ?? 0) + 1
            } else {
                count = 1
            }
        }

        let totals = Totals.perArea(sessions, areaId: areaId, days: count, now: now, calendar: calendar)
        let quarters = (0..<count).reversed().map { offset -> Int in
            guard let day = calendar.date(byAdding: .day, value: -offset, to: today) else { return 0 }
            return Self.quarters(totals[day] ?? 0)
        }
        return ShareMap(
            color: area?.colorHex.lowercased() ?? "all",
            lastDay: today,
            quarters: quarters,
            withHours: withHours
        )
    }

    /// The link for a map.
    static func url(for map: ShareMap, base: String = base, calendar: Calendar = .current) -> String {
        let parts = calendar.dateComponents([.year, .month, .day], from: map.lastDay)
        let day = String(format: "%04d%02d%02d", parts.year ?? 0, parts.month ?? 0, parts.day ?? 0)
        let days = String(map.quarters.map { alphabet[map.withHours ? $0 : step($0)] })
        return "\(base)#1.\(map.color).\(day).\(map.withHours ? 1 : 0).\(days)"
    }
}
