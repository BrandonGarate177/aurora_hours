import SwiftUI

/// The first-launch window: three names, a color square beside each, open at
/// login, and Start. The squares are the only color.
struct OnboardingView: View {
    @Bindable var form: OnboardingForm
    let onStart: () -> Void
    @FocusState private var focused: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("What do you focus on?")
                .font(.title2.weight(.light))
                .padding(.bottom, 14)

            VStack(spacing: 8) {
                ForEach(0..<3, id: \.self) { field in
                    HStack(spacing: 10) {
                        TextField(OnboardingForm.placeholders[field], text: $form.names[field])
                            .textFieldStyle(.roundedBorder)
                            .focused($focused, equals: field)
                        swatch(field)
                    }
                }
            }
            .padding(.bottom, 14)

            Toggle("Open at login", isOn: $form.openAtLogin)
                .toggleStyle(.switch)
                .controlSize(.small)
                .padding(.bottom, 12)

            HStack {
                Spacer()
                Button("Start", action: onStart)
                    .keyboardShortcut(.defaultAction)
                    .disabled(!form.canStart)
            }
        }
        .padding(.horizontal, 20)
        .padding(.top, 17)
        .padding(.bottom, 16)
        // Monochrome: the switch and the default button follow the text color.
        .tint(.primary)
        .frame(width: 320)
        .fixedSize(horizontal: false, vertical: true)
        .onAppear { focused = 0 }
    }

    /// The area's color. A click steps to the next preset.
    private func swatch(_ field: Int) -> some View {
        Button { form.cycleColor(field) } label: {
            RoundedRectangle(cornerRadius: 5, style: .continuous)
                .fill(Color(hex: form.colorHex(field)))
                .frame(width: 22, height: 22)
                .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .accessibilityLabel("Color for \(OnboardingForm.placeholders[field])")
    }
}

extension Color {
    /// "2da44e" as a color.
    init(hex: String) {
        let value = UInt32(hex, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xff) / 255,
            green: Double((value >> 8) & 0xff) / 255,
            blue: Double(value & 0xff) / 255
        )
    }
}
