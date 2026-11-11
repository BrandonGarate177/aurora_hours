import SwiftUI

/// Row 2. STUB: the map task draws the selected map here, 53 weeks by 7 days
/// of 4 pt squares with a 1 pt gap. Clicking already cycles the selection
/// (All, then each area), so the map task only has to draw.
struct MapSection: View {
    let areas: [FocusArea]
    @Binding var selection: MapSelection

    var body: some View {
        Color.clear
            .frame(width: 264, height: 34)
            .contentShape(Rectangle())
            .onTapGesture { selection = selection.next(in: areas) }
    }
}
