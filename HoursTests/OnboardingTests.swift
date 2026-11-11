import Foundation
import Testing
@testable import Hours

@MainActor
@Suite struct OnboardingTests {
    @Test func startStaysDisabledWithFewerThanTwoNames() {
        let form = OnboardingForm()
        #expect(!form.canStart)
        form.names[0] = "Coding"
        #expect(!form.canStart)
        form.names[1] = "   "
        #expect(!form.canStart)
        form.names[2] = "Study"
        #expect(form.canStart)
        form.names[0] = ""
        form.names[1] = "Writing"
        #expect(form.canStart)
    }

    @Test func presetCycleWraps() {
        let form = OnboardingForm()
        #expect(form.colors == [0, 1, 2])
        #expect(Presets.colors.count == 8)
        for _ in 0..<7 { form.cycleColor(0) }
        #expect(form.colorHex(0) == "9a6700")
        form.cycleColor(0)
        #expect(form.colorHex(0) == "2da44e")
        #expect(Presets.next(after: 7) == 0)
    }

    @Test func savedAreasCarryTheChosenColor() throws {
        let form = OnboardingForm()
        form.names = ["Coding", "", " Deep Work "]
        form.cycleColor(0) // blue
        form.cycleColor(2) // purple
        let areas = form.areas()
        #expect(areas == [
            FocusArea(id: "coding", name: "Coding", colorHex: "0969da"),
            FocusArea(id: "deep-work", name: "Deep Work", colorHex: "8250df"),
        ])

        let url = FileManager.default.temporaryDirectory
            .appendingPathComponent("HoursTests-\(UUID().uuidString)").appendingPathComponent("store.json")
        Store(url: url).setAreas(areas)
        #expect(Store(url: url).areas == areas)
    }

    @Test func idsStayUniqueAndNeverEmpty() {
        let form = OnboardingForm()
        form.names = ["Coding", "coding", "!!"]
        #expect(form.areas().map(\.id) == ["coding", "coding-2", "area-3"])
    }
}
