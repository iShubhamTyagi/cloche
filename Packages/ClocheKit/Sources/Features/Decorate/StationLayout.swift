import Foundation
import UIKit

/// The decorating station's layout (`scripts/blender/station.py` → `decor_layout_<shape>.json`):
/// every seat, cradle and control with its centre, size and tap radius in panel pixels, the cake
/// window, safe areas and the Duo's fold band. Positions are never hard-coded in the views.
struct StationLayout: Decodable, Sendable {
    struct Item: Decodable, Sendable, Identifiable {
        let name: String
        let kind: String
        let group: String
        let centrePx: [Double]
        let sizePx: [Double]
        let tapRadiusPx: Double

        var id: String { name }

        enum CodingKeys: String, CodingKey {
            case name, kind, group
            case centrePx = "centre_px", sizePx = "size_px", tapRadiusPx = "tap_radius_px"
        }
    }

    let shape: String
    let sizePx: [Double]
    let pxPerPt: Double
    let cakeWindowPx: [Double]
    let foldBandPx: [Double]?
    let items: [Item]

    enum CodingKeys: String, CodingKey {
        case shape, items
        case sizePx = "size_px", pxPerPt = "px_per_pt", cakeWindowPx = "cake_window_px", foldBandPx = "fold_band_px"
    }

    var size: CGSize { CGSize(width: sizePx[0], height: sizePx[1]) }

    func items(in group: String) -> [Item] { items.filter { $0.group == group } }

    /// The layout for a screen: the Duo's flat shape when the screen is wide, else the iPhone's.
    static func load(for size: CGSize) -> StationLayout? {
        let shape = size.width / max(size.height, 1) > 0.6 ? "duo" : "iphone"
        guard let url = Bundle.module.url(forResource: "decor_layout_\(shape)", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(StationLayout.self, from: data)
    }

    static func panel(_ shape: String) -> UIImage? {
        Bundle.module.url(forResource: "decor_panel_\(shape)", withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
    }

    /// Maps panel pixels onto a screen of `screen` points: aspect-fill, centred.
    func transform(for screen: CGSize) -> (scale: CGFloat, origin: CGPoint) {
        let scale = max(screen.width / size.width, screen.height / size.height)
        return (scale, CGPoint(x: (screen.width - size.width * scale) / 2, y: (screen.height - size.height * scale) / 2))
    }

    /// The coded fallback (no export bundled): the same groups in plain rows.
    static func fallback(for screen: CGSize) -> StationLayout {
        let w = screen.width * 3, h = screen.height * 3
        func row(_ names: [String], kind: String, group: String, y: Double, size: Double) -> [Item] {
            let pitch = (w - 80) / Double(names.count)
            return names.enumerated().map { i, n in
                Item(name: n, kind: kind, group: group, centrePx: [40 + pitch * (Double(i) + 0.5), y], sizePx: [size, size],
                     tapRadiusPx: max(size, 132) / 2)
            }
        }
        let pots = ViewerAssets.palette.map(\.name)
        let items = row(Array(pots.prefix(6)), kind: "seat_pot", group: "ingredients", y: h * 0.15, size: 130)
            + row(Array(pots.dropFirst(6)), kind: "seat_pot", group: "ingredients", y: h * 0.22, size: 130)
            + row(["NozzleRound", "NozzleStar", "NozzlePetal"], kind: "seat_nozzle", group: "nozzles", y: h * 0.28, size: 110)
            + row(DecorCatalog.toppings, kind: "seat_bowl", group: "toppings", y: h * 0.785, size: 120)
            + row(DecorCatalog.tools.map(\.sprite), kind: "cradle", group: "tools", y: h * 0.87, size: 140)
            + row(DecorCatalog.controls, kind: "control", group: "controls", y: h * 0.945, size: 132)
        return StationLayout(shape: "fallback", sizePx: [w, h], pxPerPt: 3, cakeWindowPx: [0, h * 0.31, w, h * 0.74],
                             foldBandPx: nil, items: items)
    }
}

/// Names shared by the layout, the art and the model.
enum DecorCatalog {
    static let toppings = ["berries", "mint", "chocolate_shavings", "gold_flakes", "sprinkles", "sugar_pearls",
                           "crushed_pistachio", "flower_petals"]
    static let controls = ["undo", "clear", "turntable", "speed", "plate", "backdrop"]
    static let tools: [(tool: DecorTool, sprite: String)] = [
        (.cone, "PipingCone"), (.spatula, "OffsetSpatula"), (.pour, "PourPan"), (.drizzle, "DrizzleBottle"), (.dust, "Sieve"),
    ]

    /// The 3D model(s) a HUD topping places.
    static func models(for topping: String) -> [String] {
        switch topping {
        case "berries": ["raspberry", "blueberry", "strawberry_slice", "cherry"]
        case "mint": ["mint_leaf"]
        case "chocolate_shavings": ["chocolate_curl", "chocolate_shard"]
        case "gold_flakes": ["gold_flake"]
        case "sugar_pearls": ["sugar_pearl"]
        case "crushed_pistachio": ["pistachio_crumb", "almond_flake"]
        case "flower_petals": ["flower_petal"]
        default: ["sprinkle"]
        }
    }

    static func sprite(_ name: String) -> UIImage? {
        Bundle.module.url(forResource: name, withExtension: "png").flatMap { UIImage(contentsOfFile: $0.path) }
    }
}
