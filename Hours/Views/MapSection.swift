import SwiftUI

/// Row 2: the selected map, a year of days. A click cycles the selection:
/// All, then each area. No label; the color says which map it is.
struct MapSection: View {
    let areas: [FocusArea]
    let sessions: [Session]
    let now: Date
    @Binding var selection: MapSelection

    var body: some View {
        // A selected area that no longer exists shows the combined map.
        let area = selection.areaId.flatMap { id in areas.first { $0.id == id } }
        let grid = MapGrid(now: now)
        MapView(
            levels: MapLevels.levels(sessions, areaId: area?.id, grid: grid, now: now),
            colorHex: area?.colorHex
        )
        .contentShape(Rectangle())
        .onTapGesture { selection = selection.next(in: areas) }
    }
}
