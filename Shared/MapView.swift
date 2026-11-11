import SwiftUI

/// The map itself: week columns of 7 squares, Sunday on top. The dropdown
/// shows 53 columns of 4 pt squares with a 1 pt gap, 264 x 34 pt; the widget
/// passes its own column count and sizes.
/// `levels` holds one step per cell (see MapLevels), column by column, and
/// the last `columns * 7` of them are drawn.
/// `colorHex` nil is the combined map: black on light, white on dark.
struct MapView: View {
    let levels: [Int]
    let colorHex: String?
    var columns: Int = MapGrid.columns
    var square: CGFloat = MapView.square
    var gap: CGFloat = MapView.gap

    static let square: CGFloat = 4
    static let gap: CGFloat = 1
    static let size = mapSize(columns: MapGrid.columns, square: square, gap: gap)

    static func mapSize(columns: Int, square: CGFloat, gap: CGFloat) -> CGSize {
        CGSize(
            width: CGFloat(columns) * (square + gap) - gap,
            height: CGFloat(MapGrid.rows) * (square + gap) - gap
        )
    }

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        let shown = Array(levels.suffix(columns * MapGrid.rows))
        let size = Self.mapSize(columns: columns, square: square, gap: gap)
        Canvas { context, _ in
            let dark = colorScheme == .dark
            let ink = colorHex.flatMap(Self.color(hex:)) ?? (dark ? .white : .black)
            let empty = dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07)
            let step = square + gap
            for (index, level) in shown.enumerated() {
                let rect = CGRect(
                    x: CGFloat(index / MapGrid.rows) * step,
                    y: CGFloat(index % MapGrid.rows) * step,
                    width: square,
                    height: square
                )
                let fill = level > 0 ? ink.opacity(MapLevels.opacities[min(level, 4)]) : empty
                context.fill(Path(rect), with: .color(fill))
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// "2da44e" to a Color, or nil when it isn't six hex digits.
    static func color(hex: String) -> Color? {
        guard hex.count == 6, let value = UInt32(hex, radix: 16) else { return nil }
        return Color(
            .sRGB,
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
