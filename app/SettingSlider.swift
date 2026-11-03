import SwiftUI

struct SettingSlider: View {
    let title: String
    var symbol: String?
    var color: Color = .accentColor
    @Binding var value: Double
    let range: ClosedRange<Double>
    let step: Double
    let format: (Double) -> String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LabeledContent {
                Text(format(value))
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            } label: {
                RowLabel(title: title, symbol: symbol, color: color)
            }
            Slider(value: $value, in: range, step: step)
                .labelsHidden()
                .padding(.leading, symbol == nil ? 0 : 32)
                .accessibilityLabel(title)
                .accessibilityValue(format(value))
        }
    }
}
