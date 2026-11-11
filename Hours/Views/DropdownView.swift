import SwiftUI

/// The popover's content: three rows, each in its own file.
///   1. AreasRow: the area words and today's total.
///   2. MapSection: the selected map.
///   3. ShareRow.
/// Blocking, login and Quit live in the right-click menu (MenuController).
struct DropdownView: View {
    let store: Store
    let clock: Clock
    let onArea: (String) -> Void

    @AppStorage(MapSelection.defaultsKey) private var selection: MapSelection = .all

    var body: some View {
        VStack(alignment: .leading, spacing: Layout.groupGap) {
            AreasRow(
                areas: store.areas,
                running: store.running,
                now: clock.now,
                today: Totals.today(store.sessions, now: clock.now),
                onArea: onArea
            )
            MapSection(areas: store.areas, sessions: store.sessions, now: clock.now, selection: $selection)
            ShareRow(store: store)
        }
        .padding(.horizontal, Layout.sidePadding)
        .padding(.vertical, 12)
        .frame(width: Layout.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}
