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
        /// The load with the serving lifted out (servings.py).
        let taken: [String]?
        let takenDark: String?
        let serving: String?

        enum CodingKeys: String, CodingKey {
            case states, dark, free, taken, takenDark = "taken_dark", serving
        }
    }

    /// One serving (a cupcake in its liner, or a whole cake) alone, per bake state, and its box
    /// in the frames image (x, y, w, h).
    struct Serving: Decodable, Sendable {
        let states: [String]
        let dark: String
        let box: [Double]

        var boxRect: CGRect { CGRect(x: box[0], y: box[1], width: box[2], height: box[3]) }

        func name(progress: Double, browning: Browning) -> String {
            let p = min(max(progress, 0), 1)
            if browning == .dark, p >= 1 { return dark }
            return states[Int((p * Double(states.count - 1)).rounded())]
        }
    }

    struct Masks: Decodable, Sendable {
        let names: [String]
    }

    let kinds: [String: Kind]
    let doorMasks: Masks
    let servings: [String: Serving]?

    enum CodingKeys: String, CodingKey { case kinds, doorMasks = "door_masks", servings }

    func serving(for dish: Dish) -> Serving? {
        guard let name = kinds[Self.kind(for: dish)]?.serving else { return nil }
        return servings?[name]
    }

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
    /// The tongs have lifted the serving out: show the load without it.
    var isServingTaken = false

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
        let taken = isServingTaken ? kind.taken : nil
        let states = taken ?? kind.states
        if browning == .dark, p >= 1 {
            image(isServingTaken ? (kind.takenDark ?? kind.dark) : kind.dark)
        } else {
            let position = p * Double(states.count - 1)
            let lower = Int(position.rounded(.down))
            let upper = min(lower + 1, states.count - 1)
            ZStack(alignment: .topLeading) {
                image(states[lower])
                if upper != lower {
                    image(states[upper]).opacity(position - Double(lower))
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

/// The rendered serving, drawn so its box fills `frame` (the tongs carry it; it lands on the
/// stand at the same size, since the oven and station cameras share lens and distance).
struct ServingSprite: View {
    let serving: OvenDishesLayout.Serving
    let progress: Double
    let browning: Browning
    let frame: CGRect

    var body: some View {
        let box = serving.boxRect
        let scale = frame.width / max(box.width, 1)
        if let image = OvenFrameCache.shared.image(named: serving.name(progress: progress, browning: browning)) {
            Image(uiImage: image)
                .resizable()
                .interpolation(.high)
                .frame(width: image.size.width * scale, height: image.size.height * scale)
                .offset(x: frame.minX - box.minX * scale, y: frame.minY - box.minY * scale)
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
                .allowsHitTesting(false)
        }
    }
}
