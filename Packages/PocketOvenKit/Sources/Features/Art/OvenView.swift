import DesignSystem
import SwiftUI

/// Wide countertop oven, closed, with the display plate top right. A first pass for Gate 0;
/// the door animation and cavity states come with the reveal in 1.7.
struct OvenView: View {
    /// Text on the display plate, e.g. "Ready" or a time.
    let plate: Text
    var isPlateItalic = false
    /// 0 cold, 1 fully heated; brightens the rods behind the glass.
    var heat: Double = 0.4

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: w * 0.04)
                    .fill(LinearGradient(colors: [Color(white: 0.23), Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: w * 0.04).strokeBorder(Palette.line2, lineWidth: 1))

                // Glass door with the rods glowing behind it.
                RoundedRectangle(cornerRadius: w * 0.025)
                    .fill(Color(white: 0.05))
                    .overlay {
                        VStack(spacing: h * 0.42) {
                            rod
                            rod
                        }
                        .padding(.horizontal, w * 0.05)
                    }
                    .overlay(RoundedRectangle(cornerRadius: w * 0.025).strokeBorder(.white.opacity(0.08), lineWidth: 1))
                    .frame(width: w * 0.70, height: h * 0.72)
                    .offset(x: w * 0.04, y: h * 0.12)

                // Door handle.
                Capsule()
                    .fill(Color(white: 0.55))
                    .frame(width: w * 0.62, height: h * 0.025)
                    .offset(x: w * 0.08, y: h * 0.06)

                // Control column: display plate and two knobs.
                VStack(spacing: h * 0.1) {
                    plate
                        .textStyle(isPlateItalic ? .voice(w * 0.045) : .numeral(w * 0.045))
                        .foregroundStyle(isPlateItalic ? Palette.sand : Palette.text)
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                        .frame(width: w * 0.14, height: h * 0.13)
                        .background(Color.black, in: RoundedRectangle(cornerRadius: 4))
                    knob(w)
                    knob(w)
                }
                .offset(x: w * 0.80, y: h * 0.15)
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Oven", bundle: .module))
        .accessibilityValue(plate)
    }

    private var rod: some View {
        Capsule()
            .fill(Color(red: 0.95, green: 0.45, blue: 0.15).opacity(0.25 + 0.6 * heat))
            .frame(height: 3)
            .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.15).opacity(heat), radius: 6)
    }

    private func knob(_ width: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.32))
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .frame(width: width * 0.075, height: width * 0.075)
    }
}

#Preview {
    OvenView(plate: Text(verbatim: "Ready"))
        .frame(width: 342)
        .padding()
        .pocketScreenBackground()
}
