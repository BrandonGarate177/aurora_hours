import SwiftUI

/// "All  Coding  Writing  Study" in 12 pt. The selected word is primary, the
/// rest secondary. No underline, no box.
struct MapSwitcherRow: View {
    let areas: [FocusArea]
    @Binding var selection: MapSelection

    var body: some View {
        HStack(spacing: 12) {
            word("All", .all)
            ForEach(areas) { area in
                word(area.name, .area(area.id))
            }
        }
        .font(.system(size: 12))
        .frame(height: 22, alignment: .leading)
    }

    private func word(_ title: String, _ value: MapSelection) -> some View {
        Button { selection = value } label: {
            Text(title)
                .foregroundStyle(isSelected(value) ? .primary : .secondary)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    /// A selection that points at a deleted area falls back to All.
    private func isSelected(_ value: MapSelection) -> Bool {
        let current = areas.contains { $0.id == selection.areaId } ? selection : .all
        return current == value
    }
}
