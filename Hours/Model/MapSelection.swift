import Foundation

/// Which map the dropdown shows: the combined one or one area's. The share
/// row shares whichever is selected. Stored in UserDefaults so it survives
/// relaunch; All is the first-run default.
///
/// It follows the running area when a session starts, stays on the last pick
/// when idle, and a click on the map cycles All, then each area in order.
enum MapSelection: Hashable, Sendable, RawRepresentable {
    case all
    case area(String)

    static let defaultsKey = "mapSelection"

    init(rawValue: String) {
        self = rawValue == "all" || rawValue.isEmpty ? .all : .area(rawValue)
    }

    var rawValue: String {
        switch self {
        case .all: "all"
        case .area(let id): id
        }
    }

    /// The area id, or nil for the combined map.
    var areaId: String? {
        if case .area(let id) = self { id } else { nil }
    }

    /// The next map when the person clicks the map: All, each area, All again.
    /// A selection whose area was deleted moves on to the first area.
    func next(in areas: [FocusArea]) -> MapSelection {
        let order: [MapSelection] = [.all] + areas.map { .area($0.id) }
        guard let index = order.firstIndex(of: self) else { return order.count > 1 ? order[1] : .all }
        return order[(index + 1) % order.count]
    }

    static func load(from defaults: UserDefaults = .standard) -> MapSelection {
        MapSelection(rawValue: defaults.string(forKey: defaultsKey) ?? "all")
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
