import DesignSystem
import SwiftUI
import UIKit

/// Where things sit in the rendered plating station (`scripts/blender/station_export.py` writes
/// `station_layout.json` next to the images). Pixels in the station images, top-left origin.
struct StationRenderLayout: Decodable, Sendable {
    struct PlateTop: Decodable, Sendable {
        let centre: [Double]
        let halfWidth: Double
        let frontY: Double

        enum CodingKeys: String, CodingKey { case centre, halfWidth = "half_width", frontY = "front_y" }
    }

    struct ClocheFrame: Decodable, Sendable {
        let name: String
        let lift: Double
    }

    let imageSize: [Double]
    let counterY: Double
    let plateTop: PlateTop
    let clocheFrames: [ClocheFrame]

    enum CodingKeys: String, CodingKey {
        case imageSize = "image_size", counterY = "counter_y", plateTop = "plate_top", clocheFrames = "cloche_frames"
    }

    static let shared: StationRenderLayout? = {
        guard let url = Bundle.module.url(forResource: "station_layout", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let layout = try? JSONDecoder().decode(StationRenderLayout.self, from: data),
              !layout.clocheFrames.isEmpty
        else { return nil }
        return layout
    }()

    var size: CGSize { CGSize(width: imageSize[0], height: imageSize[1]) }

    /// The lift frame nearest `lift` (0 seated, 1 lifted out of frame).
    func clocheFrame(forLift lift: Double) -> String {
        let clamped = min(max(lift, 0), 1)
        return clocheFrames.min { abs($0.lift - clamped) < abs($1.lift - clamped) }?.name ?? clocheFrames[0].name
    }
}

/// The plating station, rendered: the marble turntable stand on the same counter as the oven,
/// with its glass cloche at `clocheLift` (0 seated, 1 lifted away). Drawn at the oven's scale
/// (both renders share lens, distance and resolution) with the counter at the oven's counter
/// line, so the slide from the oven to here reads as one continuous shot.
struct RenderedStation: View, Animatable {
    let layout: StationRenderLayout
    var clocheLift: Double = 1

    /// Animating the lift steps through the rendered lift frames.
    nonisolated var animatableData: Double {
        get { clocheLift }
        set { clocheLift = newValue }
    }
    /// The open Duo places the oven hinge-on-fold; the station follows the same placement.
    var alignsHingeToFold = false

    var body: some View {
        GeometryReader { slot in
            let (scale, origin) = Self.placement(layout: layout, in: slot.size, alignsHingeToFold: alignsHingeToFold)
            let size = CGSize(width: layout.size.width * scale, height: layout.size.height * scale)
            ZStack(alignment: .topLeading) {
                image("slab_station", size: size)
                image("station_base", size: size)
                image("station_plate", size: size)
                image(layout.clocheFrame(forLift: clocheLift), size: size)
            }
            .frame(width: size.width, height: size.height, alignment: .topLeading)
            .offset(x: origin.x, y: origin.y)
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(Text("Finishing table", bundle: .module))
    }

    private func image(_ name: String, size: CGSize) -> some View {
        Group {
            if let image = OvenFrameCache.shared.image(named: name) {
                Image(uiImage: image).resizable().interpolation(.high)
            } else {
                Color.clear
            }
        }
        .frame(width: size.width, height: size.height)
    }

    /// Scale and top-left of the station images in a slot: the oven's scale, the plate centred
    /// across, the counter on the oven's counter line.
    static func placement(layout: StationRenderLayout, in size: CGSize, alignsHingeToFold: Bool) -> (scale: CGFloat, origin: CGPoint) {
        guard let oven = OvenRenderLayout.shared else { return (1, .zero) }
        let (scale, ovenOrigin) = RenderedOven.placement(layout: oven, in: size, alignsHingeToFold: alignsHingeToFold)
        let counterY = ovenOrigin.y + oven.counterY * scale
        return (scale, CGPoint(x: size.width / 2 - layout.plateTop.centre[0] * scale,
                               y: counterY - layout.counterY * scale))
    }

    /// The square a serving of `fraction` of the plate's width fills, standing on the plate's
    /// top (dish art stands on the bottom ~17% of its frame), in a slot of `size`.
    static func servingFrame(layout: StationRenderLayout, fraction: CGFloat, in size: CGSize, alignsHingeToFold: Bool) -> CGRect {
        let (scale, origin) = placement(layout: layout, in: size, alignsHingeToFold: alignsHingeToFold)
        let side = layout.plateTop.halfWidth * 2 * scale * fraction
        let x = origin.x + layout.plateTop.centre[0] * scale
        let topY = origin.y + layout.plateTop.centre[1] * scale
        return CGRect(x: x - side / 2, y: topY - side * 0.83, width: side, height: side)
    }
}
