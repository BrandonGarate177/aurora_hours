import SwiftUI

/// Row 1: the area words on one line, then today's total at the right.
/// The running word is bold with its time: "Coding 0:42". Click a word to
/// start, again to stop, another to switch.
struct AreasRow: View {
    let areas: [FocusArea]
    let running: Session?
    let now: Date
    let today: TimeInterval
    let onArea: (String) -> Void

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            ForEach(areas) { area in
                word(area)
            }
            Spacer(minLength: 8)
            Text(hoursMinutes(today))
                .font(.title.weight(.light))
                .monospacedDigit()
                .layoutPriority(1)
        }
        .lineLimit(1)
    }

    private func word(_ area: FocusArea) -> some View {
        let session = running?.areaId == area.id ? running : nil
        let title = session.map { "\(area.name) \(hoursMinutes($0.duration(now: now)))" } ?? area.name
        return Button { onArea(area.id) } label: {
            Text(title)
                .monospacedDigit()
                .fontWeight(session == nil ? .regular : .bold)
                .frame(minHeight: Layout.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }
}
