import SwiftUI

/// Quits the app. A running session stays running and resumes on relaunch.
struct QuitRow: View {
    let onQuit: () -> Void

    var body: some View {
        Button(action: onQuit) {
            Text("Quit").row()
        }
        .buttonStyle(.plain)
    }
}
