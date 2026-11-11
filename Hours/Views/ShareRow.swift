import AppKit
import SwiftUI

/// Row 3: `Share  1 year  No hours`. Share copies the map the dropdown shows
/// as one pasteboard item with two forms, the card as PNG and the link as
/// text, then reads Copied for 2 seconds. The other two words are settings
/// that stick: the period cycles 1 year, 90 days, All time; hours flip
/// between No hours and With hours.
struct ShareRow: View {
    let store: Store

    @AppStorage(MapSelection.defaultsKey) private var selection: MapSelection = .all
    @AppStorage(SharePeriod.defaultsKey) private var period: SharePeriod = .year
    @AppStorage(ShareRow.withHoursKey) private var withHours = false
    @State private var copied = false
    @State private var reset: Task<Void, Never>?

    static let withHoursKey = "shareWithHours"

    var body: some View {
        HStack(spacing: 14) {
            word(copied ? "Copied" : "Share", style: .primary) { share() }
            word(period.label, style: .secondary) { period = period.next }
            word(withHours ? "With hours" : "No hours", style: .secondary) { withHours.toggle() }
        }
        .row()
    }

    private func word(_ title: String, style: HierarchicalShapeStyle, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .foregroundStyle(style)
                .frame(minHeight: Layout.rowHeight)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
    }

    private func share() {
        let map = ShareLink.map(
            sessions: store.sessions,
            areas: store.areas,
            selection: selection,
            period: period,
            withHours: withHours,
            now: Date()
        )
        Self.copy(map)
        copied = true
        reset?.cancel()
        reset = Task { @MainActor in
            try? await Task.sleep(for: .seconds(2))
            if !Task.isCancelled { copied = false }
        }
    }

    /// Puts the card and the link on the pasteboard as one item, so an app
    /// that takes pictures gets the card and a text field gets the link.
    @MainActor
    static func copy(_ map: ShareMap, to pasteboard: NSPasteboard = .general) {
        let item = NSPasteboardItem()
        if let png = ShareCard.png(for: map) {
            item.setData(png, forType: .png)
        }
        item.setString(ShareLink.url(for: map), forType: .string)
        pasteboard.clearContents()
        pasteboard.writeObjects([item])
    }
}
