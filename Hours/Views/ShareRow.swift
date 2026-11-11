import SwiftUI

/// STUB: the share task makes these words do something.
struct ShareRow: View {
    var body: some View {
        HStack(spacing: 14) {
            Text("Share")
            Text("1 year").foregroundStyle(.secondary)
            Text("No hours").foregroundStyle(.secondary)
        }
        .row()
    }
}
