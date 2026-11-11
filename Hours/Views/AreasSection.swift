import SwiftUI

/// One row per area. The running one is bold with its time at the right.
struct AreasSection: View {
    let areas: [FocusArea]
    let running: Session?
    let now: Date
    let onArea: (String) -> Void

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ForEach(areas) { area in
                let session = running?.areaId == area.id ? running : nil
                Button { onArea(area.id) } label: {
                    HStack {
                        Text(area.name)
                        Spacer()
                        if let session {
                            Text(hoursMinutes(session.duration(now: now))).monospacedDigit()
                        }
                    }
                    .fontWeight(session == nil ? .regular : .bold)
                    .row()
                }
                .buttonStyle(.plain)
            }
        }
    }
}
