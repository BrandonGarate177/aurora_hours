import SwiftUI

/// The map itself: 53 x 7 squares of 4 pt with a 1 pt gap, 264 x 34 pt.
/// `levels` holds one step per cell (see MapLevels), column by column.
/// `colorHex` nil is the combined map: black on light, white on dark.
struct MapView: View {
    let levels: [Int]
    let colorHex: String?

    static let square: CGFloat = 4
    static let gap: CGFloat = 1
    static let size = CGSize(
        width: CGFloat(MapGrid.columns) * (square + gap) - gap,
        height: CGFloat(MapGrid.rows) * (square + gap) - gap
    )

    @Environment(\.colorScheme) private var colorScheme

    var body: some View {
        Canvas { context, _ in
            let dark = colorScheme == .dark
            let ink = colorHex.flatMap(Self.color(hex:)) ?? (dark ? .white : .black)
            let empty = dark ? Color.white.opacity(0.1) : Color.black.opacity(0.07)
            let step = Self.square + Self.gap
            for (index, level) in levels.enumerated() {
                let rect = CGRect(
                    x: CGFloat(index / MapGrid.rows) * step,
                    y: CGFloat(index % MapGrid.rows) * step,
                    width: Self.square,
                    height: Self.square
                )
                let fill = level > 0 ? ink.opacity(MapLevels.opacities[min(level, 4)]) : empty
                context.fill(Path(rect), with: .color(fill))
            }
        }
        .frame(width: Self.size.width, height: Self.size.height)
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
