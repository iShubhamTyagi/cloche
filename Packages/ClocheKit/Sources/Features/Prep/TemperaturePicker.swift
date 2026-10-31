import DesignSystem
import Domain
import SwiftUI

/// Low / Medium / High segments, each with heat bars (board "1 Prep").
struct TemperaturePicker: View {
    @Binding var selection: Temperature

    var body: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(Temperature.allCases, id: \.self) { temperature in
                segment(temperature)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Oven temperature", bundle: .module))
    }

    private func segment(_ temperature: Temperature) -> some View {
        let isSelected = selection == temperature
        let level = Temperature.allCases.firstIndex(of: temperature) ?? 0
        return Button {
            selection = temperature
        } label: {
            HStack(spacing: Spacing.s3) {
                HStack(spacing: 3) {
                    ForEach(0..<3, id: \.self) { bar in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(bar <= level ? (isSelected ? Palette.accent : Palette.subtle) : Palette.line2)
                            .frame(width: 4, height: 12)
                    }
                }
                .accessibilityHidden(true)
                Self.name(temperature)
                    .textStyle(.body.sized(15))
                    .fontWeight(.medium)
            }
            .foregroundStyle(isSelected ? Palette.text : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 48)
            .background(isSelected ? Palette.surface : .clear, in: RoundedRectangle(cornerRadius: Radius.tile))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile)
                    .strokeBorder(isSelected ? Palette.sand.opacity(0.6) : Palette.line1.opacity(1.2), lineWidth: 1)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityIdentifier("temperature.\(temperature.rawValue)")
    }

    static func nameString(_ temperature: Temperature) -> String {
        switch temperature {
        case .low: String(localized: "Low", bundle: .module)
        case .medium: String(localized: "Medium", bundle: .module)
        case .high: String(localized: "High", bundle: .module)
        }
    }

    static func name(_ temperature: Temperature) -> Text {
        switch temperature {
        case .low: Text("Low", bundle: .module)
        case .medium: Text("Medium", bundle: .module)
        case .high: Text("High", bundle: .module)
        }
    }
}
