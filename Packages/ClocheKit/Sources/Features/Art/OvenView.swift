import DesignSystem
import Domain
import SwiftUI

/// Wide countertop oven. The glass door hinges on its bottom edge: `doorOpen` 0 is shut,
/// 1 has it dropped flat, showing the cavity and the dish inside.
struct OvenView: View {
    /// Text on the display plate, e.g. "Ready" or a time.
    let plate: Text
    var isPlateItalic = false
    /// 0 cold, 1 fully heated; brightens the rods.
    var heat: Double = 0.4
    var doorOpen: Double = 0
    /// Bake progress of the dish in the cavity; nil shows an empty oven.
    var dishProgress: Double?
    var browning: Browning = .golden
    var dish: Dish = .cupcakes
    /// Clear glass shows the dish through the shut door (Prep); smoked hides it.
    var hasClearGlass = false

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            let window = CGRect(x: w * 0.04, y: h * 0.12, width: w * 0.70, height: h * 0.72)

            ZStack(alignment: .topLeading) {
                RoundedRectangle(cornerRadius: w * 0.04)
                    .fill(LinearGradient(colors: [Color(white: 0.23), Color(white: 0.14)], startPoint: .top, endPoint: .bottom))
                    .overlay(RoundedRectangle(cornerRadius: w * 0.04).strokeBorder(Palette.line2, lineWidth: 1))

                OvenCavityView(heat: heat, dishProgress: dishProgress, browning: browning, dish: dish)
                    .frame(width: window.width, height: window.height)
                    .offset(x: window.minX, y: window.minY)

                door(width: w, window: window)
                    .frame(width: window.width, height: window.height)
                    // Past 90° so the dropped door lies below the hinge, widening toward the viewer.
                    .rotation3DEffect(.degrees(-100 * min(max(doorOpen, 0), 1)), axis: (x: 1, y: 0, z: 0), anchor: .bottom, perspective: 0.45)
                    .offset(x: window.minX, y: window.minY)

                controls(width: w, height: h)
                    .offset(x: w * 0.80, y: h * 0.15)
            }
        }
        .aspectRatio(1.4, contentMode: .fit)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Oven", bundle: .module))
        .accessibilityValue(plate)
    }

    /// Glass door with handle. Darker glass hides the cavity until the door drops.
    private func door(width w: CGFloat, window: CGRect) -> some View {
        RoundedRectangle(cornerRadius: window.width * 0.035)
            .fill(Color(white: 0.05).opacity(hasClearGlass ? 0.25 : 0.92))
            .overlay(RoundedRectangle(cornerRadius: window.width * 0.035).strokeBorder(.white.opacity(0.08), lineWidth: 1))
            .overlay(alignment: .top) {
                Capsule()
                    .fill(Color(white: 0.55))
                    .frame(width: window.width * 0.88, height: max(window.height * 0.035, 3))
                    .offset(y: -window.height * 0.09)
            }
    }

    private func controls(width w: CGFloat, height h: CGFloat) -> some View {
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
    }

    private func knob(_ width: CGFloat) -> some View {
        Circle()
            .fill(Color(white: 0.32))
            .overlay(Circle().strokeBorder(.white.opacity(0.12), lineWidth: 1))
            .frame(width: width * 0.075, height: width * 0.075)
    }
}

/// Inside the oven: dark walls, glowing rods top and bottom, the dish on the rack.
/// Used inside `OvenView` and full-bleed on the Duo's top half.
struct OvenCavityView: View {
    var heat: Double = 0.8
    /// Bake progress of the dishes; nil shows an empty oven.
    var dishProgress: Double?
    var browning: Browning = .golden
    var dish: Dish = .cupcakes

    var body: some View {
        GeometryReader { proxy in
            let w = proxy.size.width
            let h = proxy.size.height
            RoundedRectangle(cornerRadius: min(w, h) * 0.035)
                .fill(LinearGradient(colors: [Color(red: 0.16, green: 0.10, blue: 0.07), Color(red: 0.07, green: 0.05, blue: 0.04)], startPoint: .top, endPoint: .bottom))
                .overlay(alignment: .top) { rod.padding(.horizontal, w * 0.07).padding(.top, h * 0.12) }
                .overlay(alignment: .bottom) {
                    VStack(spacing: 0) {
                        if let dishProgress {
                            // Keyed by dish so a new choice slides in onto the rack.
                            RackDishView(dish: dish, progress: dishProgress, browning: browning)
                                .frame(height: h * 0.45)
                                .id(dish)
                                .transition(.asymmetric(insertion: .move(edge: .trailing), removal: .move(edge: .leading)).combined(with: .opacity))
                        }
                        // Rack.
                        Capsule().fill(Color(white: 0.45)).frame(height: 2).padding(.horizontal, w * 0.05)
                        rod.padding(.horizontal, w * 0.07).padding(.top, h * 0.08)
                    }
                    .padding(.bottom, h * 0.06)
                }
                // Dishes slide in from the side; keep them inside the oven walls.
                .clipShape(RoundedRectangle(cornerRadius: min(w, h) * 0.035))
        }
        .accessibilityHidden(true)
    }

    private var rod: some View {
        Capsule()
            .fill(Color(red: 0.95, green: 0.45, blue: 0.15).opacity(0.25 + 0.6 * heat))
            .frame(height: 3)
            .shadow(color: Color(red: 0.95, green: 0.45, blue: 0.15).opacity(heat), radius: 6)
    }
}

#Preview {
    VStack(spacing: 24) {
        OvenView(plate: Text(verbatim: "Ready"))
        OvenView(plate: Text(verbatim: "0:11"), heat: 0.8, doorOpen: 0.5, dishProgress: 0.5)
        OvenView(plate: Text(verbatim: "Prêt."), isPlateItalic: true, heat: 1, doorOpen: 1, dishProgress: 1)
    }
    .frame(width: 342)
    .padding()
    .pocketScreenBackground()
}
