import Foundation

/// Something the person focuses on, like Coding. The color shows only in its map.
struct FocusArea: Codable, Hashable, Identifiable, Sendable {
    var id: String
    var name: String
    /// Six hex digits without the leading #, e.g. "2da44e".
    var colorHex: String
}
