import SwiftUI

/// The popover's content, top to bottom. Each section lives in its own file.
struct DropdownView: View {
    let store: Store
    let clock: Clock
    let onArea: (String) -> Void
    let onQuit: () -> Void

    @AppStorage(MapSelection.defaultsKey) private var selection: MapSelection = .all

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            AreasSection(areas: store.areas, running: store.running, now: clock.now, onArea: onArea)
            Spacer().frame(height: Layout.groupGap)
            TodayRow(seconds: Totals.today(store.sessions, now: clock.now))
            Spacer().frame(height: Layout.groupGap)
            MapSwitcherRow(areas: store.areas, selection: $selection)
            MapSection(selection: selection)
            Spacer().frame(height: Layout.groupGap)
            ShareRow()
            BlockRow()
            QuitRow(onQuit: onQuit)
        }
        .padding(.horizontal, Layout.sidePadding)
        .padding(.vertical, 12)
        .frame(width: Layout.width)
        .fixedSize(horizontal: false, vertical: true)
    }
}
