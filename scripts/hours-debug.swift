// Drives a Debug build of Hours from the shell, for screenshots and checks.
//   swift scripts/hours-debug.swift open
//   swift scripts/hours-debug.swift area:coding
//   swift scripts/hours-debug.swift close
//   swift scripts/hours-debug.swift menu   (right-click menu, closes after 3 s)
import Foundation

guard CommandLine.arguments.count == 2 else {
    print("usage: swift scripts/hours-debug.swift open | close | menu | area:<id>")
    exit(2)
}
DistributedNotificationCenter.default().postNotificationName(
    Notification.Name("com.hoursapp.Hours.debug"), object: CommandLine.arguments[1],
    userInfo: nil, deliverImmediately: true
)
