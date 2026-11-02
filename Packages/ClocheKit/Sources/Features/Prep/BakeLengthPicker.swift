import DesignSystem
import Domain
import SwiftUI

/// Quick / Medium / Long segments, each with length bars and its minutes (board "1 Prep").
struct BakeLengthPicker: View {
    @Binding var selection: BakeLength
    /// On the oven door's glass: hairline cells, the chosen one lit with a glow.
    @Environment(\.isHUD) private var isHUD

    var body: some View {
        HStack(spacing: Spacing.s2) {
            ForEach(BakeLength.allCases, id: \.self) { length in
                segment(length)
            }
        }
        .accessibilityElement(children: .contain)
        .accessibilityLabel(Text("Bake length", bundle: .module))
    }

    private func segment(_ length: BakeLength) -> some View {
        let isSelected = selection == length
        let level = BakeLength.allCases.firstIndex(of: length) ?? 0
        return Button {
            selection = length
        } label: {
            VStack(spacing: 2) {
                HStack(spacing: Spacing.s3) {
                    HStack(spacing: 3) {
                        ForEach(0..<3, id: \.self) { bar in
                            RoundedRectangle(cornerRadius: 2)
                                .fill(bar <= level ? (isSelected ? Palette.accent : Palette.subtle) : Palette.line2)
                                .frame(width: 4, height: 12)
                        }
                    }
                    .accessibilityHidden(true)
                    Self.name(length)
                        .textStyle(.body.sized(15))
                        .fontWeight(.medium)
                }
                Text("\(length.minutes) min", bundle: .module)
                    .textStyle(.note)
                    .foregroundStyle(isSelected ? Palette.sand : Palette.subtle)
            }
            .foregroundStyle(isSelected ? Palette.text : Palette.muted)
            .frame(maxWidth: .infinity, minHeight: 56)
            .background(cellFill(isSelected), in: RoundedRectangle(cornerRadius: Radius.tile))
            .overlay(
                RoundedRectangle(cornerRadius: Radius.tile)
                    .strokeBorder(cellStroke(isSelected), lineWidth: isHUD && isSelected ? 1.5 : 1)
                    .shadow(color: isHUD && isSelected ? Palette.sand.opacity(0.6) : .clear, radius: 6)
            )
            .contentShape(RoundedRectangle(cornerRadius: Radius.tile))
        }
        .buttonStyle(.plain)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("\(Self.nameString(length)), \(length.minutes) minutes", bundle: .module))
        .accessibilityAddTraits(isSelected ? [.isButton, .isSelected] : .isButton)
        .accessibilityIdentifier("length.\(length.rawValue)")
    }

    private func cellFill(_ isSelected: Bool) -> Color {
        if isHUD { return isSelected ? Palette.sand.opacity(0.12) : Palette.text.opacity(0.03) }
        return isSelected ? Palette.surface : .clear
    }

    private func cellStroke(_ isSelected: Bool) -> Color {
        if isHUD { return isSelected ? Palette.sand.opacity(0.9) : Palette.line2 }
        return isSelected ? Palette.sand.opacity(0.6) : Palette.line1.opacity(1.2)
    }

    static func nameString(_ length: BakeLength) -> String {
        switch length {
        case .quick: String(localized: "Quick", bundle: .module)
        case .medium: String(localized: "Medium", bundle: .module)
        case .long: String(localized: "Long", bundle: .module)
        }
    }

    static func name(_ length: BakeLength) -> Text {
        switch length {
        case .quick: Text("Quick", bundle: .module)
        case .medium: Text("Medium", bundle: .module)
        case .long: Text("Long", bundle: .module)
        }
    }
}

#Preview {
    @Previewable @State var length = BakeLength.quick
    BakeLengthPicker(selection: $length)
        .padding()
        .pocketScreenBackground()
}
