import Domain
import SwiftUI
import UIKit

/// The rendered dishes on the oven's racks (`scripts/blender/dish_layers.py` writes
/// `oven_dishes.json` and the images into OvenRender). Same pixel space as the oven frames.
struct OvenDishesLayout: Decodable, Sendable {
    struct Kind: Decodable, Sendable {
        let states: [String]
        let dark: String
        let free: String
    }

    struct Masks: Decodable, Sendable {
        let names: [String]
    }

    let kinds: [String: Kind]
    let doorMasks: Masks

    enum CodingKeys: String, CodingKey { case kinds, doorMasks = "door_masks" }

    static let shared: OvenDishesLayout? = {
        guard let url = Bundle.module.url(forResource: "oven_dishes", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(OvenDishesLayout.self, from: data)
    }()

    /// Quick bakes cupcakes, Medium one cake, Long two cakes (one per rack).
    static func kind(for dish: Dish) -> String {
        switch dish {
        case .cupcakes: "cupcakes"
        case .smallCake: "cake1"
        case .largeCake: "cake2"
        }
    }
}

/// The dish load inside the oven, drawn over the oven frame at the frame's size:
/// - along the bake (`progress` 0 raw .. 1 done) the two nearest rendered states crossfade, so
///   the batter rises and browns continuously; a dark bake ends on the over-baked state;
/// - the door's frame, handle and hinges are cut back in front of it at the door's angle;
/// - `arrival` < 1 flies the raw dish in from the left (Prep), uncut, landing on the racks.
struct OvenDishLayer: View {
    let layout: OvenDishesLayout
    let dish: Dish
    let progress: Double
    let browning: Browning
    let arrival: Double
    /// The door frame's index (matches door_mask_NNN), nil when the door isn't drawn.
    let doorFrameIndex: Int?
    /// The door is shut-ish: the dish is seen through its smoked glass.
    let isBehindGlass: Bool
    let size: CGSize

    var body: some View {
        if let kind = layout.kinds[OvenDishesLayout.kind(for: dish)] {
            let landed = min(max((arrival - 0.85) / 0.15, 0), 1)
            ZStack(alignment: .topLeading) {
                baked(kind)
                    .opacity(landed * (isBehindGlass ? 0.82 : 1))
                    .mask { doorCutout }
                if landed < 1 {
                    image(kind.free)
                        .opacity(1 - landed)
                        .offset(x: -(1 - arrival) * size.width * 1.15)
                }
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .allowsHitTesting(false)
        }
    }

    @ViewBuilder
    private func baked(_ kind: OvenDishesLayout.Kind) -> some View {
        let p = min(max(progress, 0), 1)
        if browning == .dark, p >= 1 {
            image(kind.dark)
        } else {
            let position = p * Double(kind.states.count - 1)
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, kind.states.count - 1)
            ZStack(alignment: .topLeading) {
                image(kind.states[lower])
                if upper != lower {
                    image(kind.states[upper]).opacity(position - Double(lower))
                }
            }
        }
    }

    /// Opaque everywhere except the door's opaque parts.
    @ViewBuilder
    private var doorCutout: some View {
        if let index = doorFrameIndex, index < layout.doorMasks.names.count {
            ZStack {
                Rectangle()
                image(layout.doorMasks.names[index]).blendMode(.destinationOut)
            }
            .compositingGroup()
        } else {
            Rectangle()
        }
    }

    private func image(_ name: String) -> some View {
        Group {
            if let image = OvenFrameCache.shared.image(named: name) {
                Image(uiImage: image).resizable().interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: size.width, height: size.height)
    }
}
