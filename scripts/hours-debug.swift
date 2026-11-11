// Drives a Debug build of Hours from the shell, for screenshots and checks.
//   swift scripts/hours-debug.swift open
//   swift scripts/hours-debug.swift area:coding
//   swift scripts/hours-debug.swift close
//   swift scripts/hours-debug.swift menu   (right-click menu, closes after 3 s)
//   swift scripts/hours-debug.swift "item:Block sites"   (choose a menu item)
//   swift scripts/hours-debug.swift quit
//   swift scripts/hours-debug.swift onboard:names:Coding,Writing,
//   swift scripts/hours-debug.swift onboard:color:0   (click the first square)
//   swift scripts/hours-debug.swift onboard:start
//   swift scripts/hours-debug.swift login:toggle   (Open at login in the menu)
// The command reaches only the copy whose store is this shell's HOURS_STORE
// (the default store when unset), so set it the same way as for the app.
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("usage: swift scripts/hours-debug.swift open | close | menu | area:<id> | item:<title> | quit | onboard:names:<a,b,c> | onboard:color:<0-2> | onboard:start | login:toggle")
    exit(2)
}

// The same path Store.defaultURL() picks, and the same name as
// DebugControl.channel(for:). Change all three together.
let store: URL
if let path = ProcessInfo.processInfo.environment["HOURS_STORE"], !path.isEmpty {
    store = URL(fileURLWithPath: (path as NSString).expandingTildeInPath)
} else {
    let home = FileManager.default.homeDirectoryForCurrentUser
    store = home.appendingPathComponent("Library/Group Containers/group.com.hoursapp.Hours/store.json")
}
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.hoursapp.Hours.debug:" + store.standardizedFileURL.path),
    object: CommandLine.arguments[1], userInfo: nil, deliverImmediately: true
)
