/// The eight colors an area can have. Onboarding steps through them in this
/// order when the square beside a name is clicked; there is no color panel.
enum Presets {
    static let colors = [
        "2da44e", // green
        "0969da", // blue
        "bc4c00", // orange
        "8250df", // purple
        "cf222e", // red
        "1b7c83", // teal
        "bf3989", // pink
        "9a6700", // yellow
    ]

    /// The preset after `index`, back to the first after the last.
    static func next(after index: Int) -> Int {
        (index + 1) % colors.count
    }
}
