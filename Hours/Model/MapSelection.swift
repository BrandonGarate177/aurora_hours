import Foundation

/// Which map the dropdown shows: the combined one or one area's. The share
/// row shares whichever is selected. Stored in UserDefaults so it survives
/// relaunch; All is the first-run default.
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

    static func load(from defaults: UserDefaults = .standard) -> MapSelection {
        MapSelection(rawValue: defaults.string(forKey: defaultsKey) ?? "all")
    }

    func save(to defaults: UserDefaults = .standard) {
        defaults.set(rawValue, forKey: Self.defaultsKey)
    }
}
