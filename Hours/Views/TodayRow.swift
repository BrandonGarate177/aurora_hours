import SwiftUI

/// Today's total as a large light numeral, with the word Today small beside it.
struct TodayRow: View {
    let seconds: TimeInterval

    var body: some View {
        HStack(alignment: .firstTextBaseline) {
            Text("Today")
                .font(.subheadline)
                .foregroundStyle(.secondary)
            Spacer()
            Text(hoursMinutes(seconds))
                .font(.largeTitle.weight(.light))
                .monospacedDigit()
        }
    }
}
