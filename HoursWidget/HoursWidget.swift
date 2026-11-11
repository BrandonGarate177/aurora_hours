import SwiftUI
import WidgetKit

@main
struct HoursWidgetBundle: WidgetBundle {
    var body: some Widget {
        HoursMapWidget()
    }
}

/// The map on the desktop or in Notification Center. Small shows the last 13
/// weeks, medium the year. Today's total sits under the map.
struct HoursMapWidget: Widget {
    static let kind = "HoursMap"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: Self.kind, intent: MapIntent.self, provider: MapProvider()) { entry in
            MapWidgetView(entry: entry)
                .containerBackground(.fill.tertiary, for: .widget)
        }
        .configurationDisplayName("Hours")
        .description("Your map and today's hours.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

struct MapEntry: TimelineEntry {
    let date: Date
    let snapshot: WidgetSnapshot
}

/// One entry now, the next at the top of the hour. The app reloads the
/// timeline when a session starts or stops.
struct MapProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> MapEntry {
        MapEntry(date: Date(), snapshot: .empty)
    }

    func snapshot(for configuration: MapIntent, in context: Context) async -> MapEntry {
        entry(for: configuration, now: Date())
    }

    func timeline(for configuration: MapIntent, in context: Context) async -> Timeline<MapEntry> {
        let now = Date()
        return Timeline(
            entries: [entry(for: configuration, now: now)],
            policy: .after(WidgetSnapshot.nextRefresh(after: now))
        )
    }

    private func entry(for configuration: MapIntent, now: Date) -> MapEntry {
        let file = WidgetSnapshot.read(from: Store.groupURL())
        let areaId = configuration.map?.areaId
        return MapEntry(date: now, snapshot: WidgetSnapshot(file: file, areaId: areaId, now: now))
    }
}

struct MapWidgetView: View {
    let entry: MapEntry
    @Environment(\.widgetFamily) private var family

    private var columns: Int { family == .systemSmall ? 13 : MapGrid.columns }
    private var gap: CGFloat { family == .systemSmall ? 2 : 1 }

    var body: some View {
        GeometryReader { proxy in
            // The largest square that fits the width, in half points so its
            // edges land on Retina pixels.
            let square = max(1, (((proxy.size.width + gap) / CGFloat(columns) - gap) * 2).rounded(.down) / 2)
            VStack(alignment: .leading, spacing: 0) {
                Text("Hours")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer(minLength: 6)
                MapView(
                    levels: entry.snapshot.levels,
                    colorHex: entry.snapshot.colorHex,
                    columns: columns,
                    square: square,
                    gap: gap
                )
                Spacer(minLength: 6)
                Text(hoursMinutes(entry.snapshot.today))
                    .font(.largeTitle.weight(.light))
                    .monospacedDigit()
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .leading)
        }
    }
}
