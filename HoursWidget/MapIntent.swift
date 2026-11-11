import AppIntents
import WidgetKit

/// The widget's one setting: which map. All by default, or one area, drawn
/// in that area's color.
struct MapIntent: WidgetConfigurationIntent {
    static let title: LocalizedStringResource = "Map"

    @Parameter(title: "Map")
    var map: MapChoice?
}

/// All, or one focus area from the store.
struct MapChoice: AppEntity {
    static let typeDisplayRepresentation: TypeDisplayRepresentation = "Map"
    static let defaultQuery = MapChoiceQuery()
    static let all = MapChoice(id: "all", name: "All")

    var id: String
    var name: String

    var areaId: String? { id == Self.all.id ? nil : id }

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(title: "\(name)")
    }
}

struct MapChoiceQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [MapChoice] {
        choices().filter { identifiers.contains($0.id) }
    }

    func suggestedEntities() async throws -> [MapChoice] {
        choices()
    }

    func defaultResult() async -> MapChoice? {
        .all
    }

    private func choices() -> [MapChoice] {
        let areas = WidgetSnapshot.read(from: Store.groupURL()).areas
        return [.all] + areas.map { MapChoice(id: $0.id, name: $0.name) }
    }
}
