import DesignSystem
import Domain
import SwiftUI

/// Doneness: a 3 pt sand bar filled to time baked over target time.
struct DonenessBar: View {
    let copy: GradeCopy

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack {
                EyebrowLabel(Text("Doneness", bundle: .module))
                Spacer()
                copy.donenessLabel
                    .textStyle(.voice(15))
                    .foregroundStyle(Palette.sand)
                Text(verbatim: "\(copy.donenessPercent)%")
                    .textStyle(.numeral(15))
                    .foregroundStyle(Palette.text)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule().fill(Palette.line2)
                    Capsule().fill(Palette.sand).frame(width: proxy.size.width * Double(copy.donenessPercent) / 100)
                }
            }
            .frame(height: 3)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Doneness", bundle: .module))
        .accessibilityValue(Text("\(copy.donenessPercent) percent, ", bundle: .module) + copy.donenessLabel)
    }
}

/// Browning: a pale-to-dark gradient with an 11 pt marker ringed in the ground colour.
struct BrowningBar: View {
    let copy: GradeCopy

    var body: some View {
        VStack(alignment: .leading, spacing: Spacing.s2) {
            HStack {
                EyebrowLabel(Text("Browning", bundle: .module))
                Spacer()
                copy.browningLabel
                    .textStyle(.voice(15))
                    .foregroundStyle(Palette.sand)
            }
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(LinearGradient(colors: [FoodPalette.bakePale, FoodPalette.bakeGolden, FoodPalette.bakeDark], startPoint: .leading, endPoint: .trailing))
                        .frame(height: 3)
                    Circle()
                        .fill(Palette.text)
                        .overlay(Circle().strokeBorder(Palette.ground, lineWidth: 3))
                        .frame(width: 11, height: 11)
                        .offset(x: proxy.size.width * GradeCopy.browningPosition(copy.grade.browning) - 5.5)
                }
                .frame(maxHeight: .infinity)
            }
            .frame(height: 11)
            .accessibilityHidden(true)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Browning", bundle: .module))
        .accessibilityValue(copy.browningLabel)
    }
}
