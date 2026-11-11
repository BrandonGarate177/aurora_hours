import AppKit
import SwiftUI

/// The picture that goes on the pasteboard with the link: the word Hours, the
/// map at the share page's proportions (11 pt squares, 3 pt gap), and with
/// hours on, the period's total. White with black text whatever the Mac's
/// appearance, so it reads the same pasted anywhere.
struct ShareCard: View {
    let map: ShareMap
    var calendar: Calendar = .current

    static let padding: CGFloat = 16
    static let scale: CGFloat = 2

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Hours")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
            ShareCardMap(map: map, calendar: calendar)
            if map.withHours {
                HStack(alignment: .firstTextBaseline, spacing: 6) {
                    Text(map.totalHours.formatted())
                        .font(.system(size: 34, weight: .light))
                        .monospacedDigit()
                    Text("hours")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                }
            }
        }
        .foregroundStyle(.primary)
        .padding(Self.padding)
        .background(Color.white)
        .environment(\.colorScheme, .light)
    }

    /// The card as PNG data at 2x, tagged 144 dpi so apps show it at point size.
    @MainActor
    static func png(for map: ShareMap, calendar: Calendar = .current) -> Data? {
        let renderer = ImageRenderer(content: ShareCard(map: map, calendar: calendar))
        renderer.scale = scale
        guard let image = renderer.cgImage else { return nil }
        let rep = NSBitmapImageRep(cgImage: image)
        rep.size = NSSize(width: CGFloat(image.width) / scale, height: CGFloat(image.height) / scale)
        return rep.representation(using: .png, properties: [:])
    }
}

/// Where each square goes, the way the share page places them: Sunday on
/// top, one column per week, and past 53 weeks one 53-week strip per row with
/// an empty row between strips, the newest strip ending on the last day's week.
struct ShareGrid: Equatable, Sendable {
    static let cell: CGFloat = 11
    static let pitch: CGFloat = 14
    static let weeksPerStrip = 53

    /// Weekday of the first day, 0 for Sunday.
    var offset: Int
    var columns: Int
    var strips: Int

    init(days: Int, firstWeekday: Int) {
        offset = firstWeekday
        columns = (days + offset + 6) / 7
        strips = (columns + Self.weeksPerStrip - 1) / Self.weeksPerStrip
    }

    init(map: ShareMap, calendar: Calendar) {
        let first = calendar.date(byAdding: .day, value: -(map.quarters.count - 1), to: map.lastDay) ?? map.lastDay
        self.init(days: map.quarters.count, firstWeekday: calendar.component(.weekday, from: first) - 1)
    }

    /// Column and row of the day at `index`, oldest first.
    func position(of index: Int) -> (column: Int, row: Int) {
        let pad = strips > 1 ? strips * Self.weeksPerStrip - columns : 0
        let week = (index + offset) / 7 + pad
        return (week % Self.weeksPerStrip, week / Self.weeksPerStrip * 8 + (index + offset) % 7)
    }

    var size: CGSize {
        let columns = strips > 1 ? Self.weeksPerStrip : columns
        return CGSize(width: CGFloat(columns) * Self.pitch - 3, height: CGFloat(strips * 8 - 1) * Self.pitch - 3)
    }
}

/// The squares: the area's color, or black for All, shaded by the four steps.
struct ShareCardMap: View {
    let map: ShareMap
    var calendar: Calendar = .current

    static let opacity: [Double] = [0, 0.3, 0.55, 0.8, 1]

    var fill: Color {
        guard map.color != "all", let value = UInt32(map.color, radix: 16) else { return .black }
        return Color(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }

    var body: some View {
        let grid = ShareGrid(map: map, calendar: calendar)
        let fill = fill
        Canvas { context, _ in
            for (index, quarters) in map.quarters.enumerated() {
                let (column, row) = grid.position(of: index)
                let rect = CGRect(
                    x: CGFloat(column) * ShareGrid.pitch, y: CGFloat(row) * ShareGrid.pitch,
                    width: ShareGrid.cell, height: ShareGrid.cell
                )
                let step = ShareLink.step(quarters)
                let color = step == 0 ? Color.black.opacity(0.07) : fill.opacity(Self.opacity[step])
                context.fill(Path(roundedRect: rect, cornerRadius: 2), with: .color(color))
            }
        }
        .frame(width: grid.size.width, height: grid.size.height)
    }
}
