import Foundation
import Observation

/// What the onboarding window edits: three names, a color for each, and
/// whether to open at login. Start needs two names.
@MainActor
@Observable
final class OnboardingForm {
    static let placeholders = ["Coding", "Writing", "Optional"]

    var names = ["", "", ""]
    /// Index into `Presets.colors` for each field. Fields 1, 2, 3 start on presets 1, 2, 3.
    var colors = [0, 1, 2]
    var openAtLogin = true

    var canStart: Bool {
        filledNames.count >= 2
    }

    func cycleColor(_ field: Int) {
        colors[field] = Presets.next(after: colors[field])
    }

    func colorHex(_ field: Int) -> String {
        Presets.colors[colors[field]]
    }

    /// The filled-in fields as areas, in field order, each with its color.
    /// Ids come from the names and are kept unique.
    func areas() -> [FocusArea] {
        var used = Set<String>()
        return filledNames.map { field, name in
            let base = Self.slug(name).isEmpty ? "area-\(field + 1)" : Self.slug(name)
            var id = base
            var suffix = 2
            while used.contains(id) {
                id = "\(base)-\(suffix)"
                suffix += 1
            }
            used.insert(id)
            return FocusArea(id: id, name: name, colorHex: colorHex(field))
        }
    }

    private var filledNames: [(field: Int, name: String)] {
        names.enumerated().compactMap { field, raw in
            let name = raw.trimmingCharacters(in: .whitespacesAndNewlines)
            return name.isEmpty ? nil : (field, name)
        }
    }

    /// "Deep Work" becomes "deep-work".
    static func slug(_ name: String) -> String {
        name.lowercased()
            .split { !$0.isLetter && !$0.isNumber }
            .joined(separator: "-")
    }
}
