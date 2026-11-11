// Drives a Debug build of Hours from the shell, for screenshots and checks.
//   swift scripts/hours-debug.swift open
//   swift scripts/hours-debug.swift area:coding
//   swift scripts/hours-debug.swift close
//   swift scripts/hours-debug.swift menu   (right-click menu, closes after 3 s)
// The command reaches only the copy whose store is this shell's HOURS_STORE
// (the default store when unset), so set it the same way as for the app.
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("usage: swift scripts/hours-debug.swift open | close | menu | area:<id>")
    exit(2)
}

// The same path Store.defaultURL() picks, and the same name as
// DebugControl.channel(for:). Change all three together.
let store: URL
if let path = ProcessInfo.processInfo.environment["HOURS_STORE"], !path.isEmpty {
    store = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
} else {
    let support = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
    store = support.appendingPathComponent("Hours", isDirectory: true).appendingPathComponent("store.json")
}
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.hoursapp.Hours.debug:" + store.standardizedFileURL.path),
    object: CommandLine.arguments[1], userInfo: nil, deliverImmediately: true
)
