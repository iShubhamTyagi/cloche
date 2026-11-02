import DesignSystem
import SwiftUI
import UIKit

/// Where things sit in the Blender-rendered oven frames (`scripts/blender/app_export.py` writes
/// `oven_layout.json` next to the frames). Rects are pixels in the frame image, top-left origin.
struct OvenRenderLayout: Decodable, Sendable {
    struct Frame: Decodable, Sendable {
        let name: String
        let angle: Double
        /// The clear glass's corners on the door's inner face, in reading order: top-left,
        /// top-right (hinge edge), bottom-right, bottom-left (handle edge). Pixels.
        let glass: [[Double]]
        /// How squarely that face looks at the camera: 1 head-on, 0 edge-on, < 0 turned away.
        let facing: Double
    }

    let imageSize: [Double]
    let maxAngle: Double
    let frames: [Frame]
    let body: [Double]
    let display: [Double]
    let hinge: [[Double]]
    /// The door's clear glass when it hangs fully open (180).
    let glassOpen: [Double]
    /// The upper tray, door shut.
    let tray: [Double]
    /// The counter's line under the oven (pixels): the plating station aligns to it.
    let counterY: Double

    enum CodingKeys: String, CodingKey {
        case imageSize = "image_size", maxAngle = "max_angle", frames, body, display, hinge, glassOpen = "glass_open", tray, counterY = "counter_y"
    }

    /// Nil when the rendered frames aren't in the bundle (they are generated, not committed);
    /// the app then draws its own oven.
    static let shared: OvenRenderLayout? = {
        guard let url = Bundle.module.url(forResource: "oven_layout", withExtension: "json"),
              let data = try? Data(contentsOf: url),
              let layout = try? JSONDecoder().decode(OvenRenderLayout.self, from: data),
              !layout.frames.isEmpty
        else { return nil }
        return layout
    }()

    var size: CGSize { CGSize(width: imageSize[0], height: imageSize[1]) }
    var bodyRect: CGRect { CGRect(x: body[0], y: body[1], width: body[2], height: body[3]) }
    var displayRect: CGRect { CGRect(x: display[0], y: display[1], width: display[2], height: display[3]) }
    var hingeY: Double { hinge[0][1] }
    var trayRect: CGRect { CGRect(x: tray[0], y: tray[1], width: tray[2], height: tray[3]) }
    var glassOpenRect: CGRect { CGRect(x: glassOpen[0], y: glassOpen[1], width: glassOpen[2], height: glassOpen[3]) }

    /// The frame whose door angle is closest to `angle` (degrees, 0 shut, 180 hanging down).
    func frameName(forAngle angle: Double) -> String {
        frame(forAngle: angle).name
    }

    func frame(forAngle angle: Double) -> Frame {
        let clamped = min(max(angle, 0), maxAngle)
        return frames.min { abs($0.angle - clamped) < abs($1.angle - clamped) } ?? frames[0]
    }
}

/// The rendered oven in the oven slot: the frame for the door's angle, scaled so the oven body
/// fills the slot between the header band and the bottom band, with the plate text drawn in the
/// display window. The door may hang past the slot when open, as the drawn door did.
struct RenderedOven: View {
    let layout: OvenRenderLayout
    /// Door angle in degrees: 0 shut, 88 flat toward the viewer, 180 hanging straight down.
    let angle: Double
    let plate: Text
    var isPlateItalic = false
    /// The door is shown elsewhere (the bottom half): cut the image off at the hinge line.
    var cutsAtHinge = false
    /// Keep a door that hangs past the oven inside the slot (the open Duo, where the bottom half
    /// is other content).
    var clipsToSlot = false
    /// The open Duo: put the door's hinge line on the slot's bottom edge, which is the fold.
    var alignsHingeToFold = false

    var body: some View {
        GeometryReader { slot in
            let (scale, origin) = Self.placement(layout: layout, in: slot.size, alignsHingeToFold: alignsHingeToFold)
            let imageSize = CGSize(width: layout.size.width * scale, height: layout.size.height * scale)
            let display = layout.displayRect
            ZStack(alignment: .topLeading) {
                frameImage
                    .resizable()
                    .interpolation(.high)
                    .frame(width: imageSize.width, height: imageSize.height)
                plate
                    .textStyle(isPlateItalic ? .voice(display.height * scale * 0.5) : .numeral(display.height * scale * 0.42))
                    .foregroundStyle(isPlateItalic ? Palette.sand : Palette.text)
                    .lineLimit(1)
                    .minimumScaleFactor(0.5)
                    .frame(width: display.width * scale * 0.9, height: display.height * scale)
                    .offset(x: (display.minX + display.width * 0.05) * scale, y: display.minY * scale)
            }
            .frame(width: imageSize.width, height: imageSize.height, alignment: .topLeading)
            .mask(alignment: .top) {
                Rectangle().frame(height: cutsAtHinge ? layout.hingeY * scale : imageSize.height)
            }
            .offset(x: origin.x, y: origin.y)
        }
        .modifier(ClipIf(isOn: clipsToSlot))
    }

    /// Scale and top-left of the frame image in a slot of `size`: the oven body fills the slot
    /// between the header band and the bottom band, centred.
    static func placement(layout: OvenRenderLayout, in size: CGSize, alignsHingeToFold: Bool = false) -> (scale: CGFloat, origin: CGPoint) {
        let bodyRect = layout.bodyRect
        let width = max(size.width - Spacing.margin * 2, 1)
        if alignsHingeToFold {
            // Fit the oven from its top down to the hinge between the header band and the fold,
            // then pin the hinge line to the slot's bottom edge. The feet and the open door hang
            // past it into the bottom half, as a real oven's do past the counter edge.
            let aboveHinge = max(layout.hingeY - bodyRect.minY, 1)
            let scale = min(width / bodyRect.width, max(size.height - OvenFrame.topBand, 1) / aboveHinge)
            return (scale, CGPoint(x: size.width / 2 - bodyRect.midX * scale, y: size.height - layout.hingeY * scale))
        }
        let usable = CGSize(width: width, height: max(size.height - OvenFrame.topBand - OvenFrame.bottomBand, 1))
        let scale = min(usable.width / bodyRect.width, usable.height / bodyRect.height)
        let centre = CGPoint(x: size.width / 2, y: OvenFrame.topBand + usable.height / 2)
        return (scale, CGPoint(x: centre.x - bodyRect.midX * scale, y: centre.y - bodyRect.midY * scale))
    }

    /// The open door's glass in a slot of `size` (slot coordinates; it lies below the slot, in
    /// the bottom half), with the oven placed hinge-on-fold: where content goes as a HUD.
    static func openGlass(layout: OvenRenderLayout, in size: CGSize) -> CGRect {
        let (scale, origin) = placement(layout: layout, in: size, alignsHingeToFold: true)
        let glass = layout.glassOpenRect
        return CGRect(x: origin.x + glass.minX * scale, y: origin.y + glass.minY * scale,
                      width: glass.width * scale, height: glass.height * scale)
    }

    /// The glass on the door at `angle`, as four points in a slot of `size` (slot coordinates,
    /// hinge on the fold), and how squarely it faces the viewer. The same frame as the image.
    static func glassQuad(layout: OvenRenderLayout, angle: Double, in size: CGSize) -> (corners: [CGPoint], facing: Double) {
        let (scale, origin) = placement(layout: layout, in: size, alignsHingeToFold: true)
        let frame = layout.frame(forAngle: angle)
        let corners = frame.glass.map { CGPoint(x: origin.x + $0[0] * scale, y: origin.y + $0[1] * scale) }
        return (corners, frame.facing)
    }

    private var frameImage: Image {
        let name = layout.frameName(forAngle: cutsAtHinge ? layout.maxAngle : angle)
        if let image = OvenFrameCache.shared.image(named: name) {
            return Image(uiImage: image)
        }
        return Image(systemName: "photo")
    }
}

/// Decoded oven frames, so showing one never waits on PNG decoding. The shut and fully open
/// frames (the folded cover and the unfolded Duo) are decoded in the background at launch and
/// kept; others are cached as the hinge passes through them, a dozen at most (each is ~4.8 MB
/// decoded).
final class OvenFrameCache: @unchecked Sendable {
    static let shared = OvenFrameCache()

    private let cache: NSCache<NSString, UIImage> = {
        let cache = NSCache<NSString, UIImage>()
        cache.countLimit = 12
        return cache
    }()
    private let lock = NSLock()
    private var pinned: [String: UIImage] = [:]

    func image(named name: String) -> UIImage? {
        let kept = lock.withLock { pinned[name] }
        if let kept { return kept }
        if let cached = cache.object(forKey: name as NSString) { return cached }
        guard let image = Self.decode(name) else { return nil }
        cache.setObject(image, forKey: name as NSString)
        return image
    }

    /// Decode and keep the frames that must appear instantly. Call once at launch.
    func preload(_ names: [String]) {
        Task.detached(priority: .userInitiated) {
            for name in names {
                guard let image = Self.decode(name) else { continue }
                self.pin(image, as: name)
            }
        }
    }

    private func pin(_ image: UIImage, as name: String) {
        lock.withLock { pinned[name] = image }
    }

    private static func decode(_ name: String) -> UIImage? {
        guard let path = Bundle.module.path(forResource: name, ofType: "png"),
              let image = UIImage(contentsOfFile: path) else { return nil }
        return image.preparingForDisplay() ?? image
    }
}

private struct ClipIf: ViewModifier {
    let isOn: Bool

    func body(content: Content) -> some View {
        if isOn { content.clipped() } else { content }
    }
}
