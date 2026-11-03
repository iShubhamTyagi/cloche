import Foundation
import SwiftUI
import UIKit

/// The zoom-to-centre move (`scripts/blender/focus.py` → `focus_manifest.json` and
/// `focus_<shape>_bg_NN` frames): the live viewer's camera flies the exported path from the
/// stage view to straight top-down while the pre-rendered background plays behind it.
struct FocusPath: Decodable, Sendable {
    struct Frame: Decodable, Sendable {
        let frame: Int
        let time: Double
        let position: [Float]
        let target: [Float]
        let fovDeg: Float

        enum CodingKeys: String, CodingKey {
            case frame, time, position, target
            case fovDeg = "fov_deg"
        }

        var camera: FocusCamera {
            FocusCamera(position: SIMD3(position[0], position[1], position[2]), target: SIMD3(target[0], target[1], target[2]), fov: fovDeg)
        }
    }

    let fps: Double
    let paths: [String: [Frame]]

    static let shared: FocusPath? = {
        guard let url = Bundle.module.url(forResource: "focus_manifest", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return nil }
        return try? JSONDecoder().decode(FocusPath.self, from: data)
    }()

    /// "iphone" or "duo" by the screen's shape (the Duo flat is the wide one).
    static func shape(for size: CGSize) -> String { size.width / max(size.height, 1) > 0.6 ? "duo" : "iphone" }

    static func background(_ shape: String, frame: Int) -> UIImage? {
        let name = String(format: "focus_%@_bg_%02d", shape, frame)
        for ext in ["heic", "png"] {
            if let url = Bundle.module.url(forResource: name, withExtension: ext), let image = UIImage(contentsOfFile: url.path) {
                return image
            }
        }
        return nil
    }
}

/// A camera pose from the focus path, plate-local metres, +Z up.
struct FocusCamera: Equatable, Sendable {
    var position: SIMD3<Float>
    var target: SIMD3<Float>
    var fov: Float
}

/// Plays the move: background frames behind, the viewer's camera on the path, forward or reverse.
@MainActor
enum FocusMovePlayer {
    static func play(model: DecorStudioModel, shape: String, reverse: Bool = false,
                     frame: @escaping (Int) -> Void) async {
        guard let path = FocusPath.shared, let frames = path.paths[shape], !frames.isEmpty else { return }
        let ordered = reverse ? frames.reversed() : frames
        let step = 1 / max(path.fps, 1)
        // Decode the frames first so playback never stalls on disk.
        let images = ordered.map { FocusPath.background(shape, frame: $0.frame) }
        for (i, f) in ordered.enumerated() {
            model.focusCamera = f.camera
            model.focusBackground = images[i]
            frame(f.frame)
            try? await Task.sleep(for: .seconds(step))
        }
    }
}
