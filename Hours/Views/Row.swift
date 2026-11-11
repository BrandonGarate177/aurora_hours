import SwiftUI

/// Sizes shared by every section of the dropdown.
enum Layout {
    static let width: CGFloat = 300
    static let sidePadding: CGFloat = 14
    static let rowHeight: CGFloat = 24
    /// Space between groups. There are no dividers.
    static let groupGap: CGFloat = 14
}

extension View {
    /// A full-width, 24 pt row that is clickable across its whole width.
    func row() -> some View {
        frame(maxWidth: .infinity, minHeight: Layout.rowHeight, alignment: .leading)
            .contentShape(Rectangle())
    }
}
