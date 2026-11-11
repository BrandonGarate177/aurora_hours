import Foundation

/// "h:mm" for a number of seconds, rounded down to the minute: 2520 -> "0:42".
func hoursMinutes(_ seconds: TimeInterval) -> String {
    let minutes = max(0, Int(seconds) / 60)
    return String(format: "%d:%02d", minutes / 60, minutes % 60)
}
