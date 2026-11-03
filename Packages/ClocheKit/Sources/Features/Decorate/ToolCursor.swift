import DesignSystem
import SwiftUI
import UIKit

/// The tool in hand follows the finger: its rendered sprite (tools.py), working end on the
/// touch point, at the tool's real size against the cake. Hidden for toppings (the topping
/// drops where you tap).
struct ToolCursor: View {
    let model: DecorStudioModel
    let size: CGSize

    var body: some View {
        if let p = model.cursor, model.tool != .topping, let sprite = Self.sprite(for: model.tool) {
            let width = size.width * 0.42
            Image(uiImage: sprite.image)
                .resizable()
                .scaledToFit()
                .frame(width: width, height: width)
                .offset(x: (0.5 - sprite.anchor.x) * width, y: (0.5 - sprite.anchor.y) * width)
                .position(x: CGFloat(p.x) * size.width, y: CGFloat(p.y) * size.height)
                .allowsHitTesting(false)
                .accessibilityHidden(true)
        }
    }

    /// The active sprite and its working-end anchor (0...1 of the sprite).
    @MainActor
    static func sprite(for tool: DecorTool) -> (image: UIImage, anchor: CGPoint)? {
        guard let name = DecorCatalog.tools.first(where: { $0.tool == tool })?.sprite else { return nil }
        guard let image = DecorCatalog.sprite("tool_\(name)_active") ?? DecorCatalog.sprite("tool_\(name)_idle") else { return nil }
        return (image, anchors[name] ?? CGPoint(x: 0.5, y: 0.5))
    }

    /// Anchors from decor_tools.json (tools_manifest.json), rotation 0, active state.
    private static let anchors: [String: CGPoint] = {
        struct Manifest: Decodable {
            struct Tool: Decodable {
                struct Sprite: Decodable { let anchor_px: [Double] }
                let sprites: [String: Sprite]
            }
            let tools: [String: Tool]
            let sprite_px: Double
        }
        guard let url = Bundle.module.url(forResource: "decor_tools", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let m = try? JSONDecoder().decode(Manifest.self, from: data) else { return [:] }
        var out: [String: CGPoint] = [:]
        for (tool, entry) in m.tools {
            if let s = entry.sprites["\(tool)_active_0"] ?? entry.sprites["\(tool)_idle_0"] {
                out[tool] = CGPoint(x: s.anchor_px[0] / m.sprite_px, y: s.anchor_px[1] / m.sprite_px)
            }
        }
        return out
    }()
}
