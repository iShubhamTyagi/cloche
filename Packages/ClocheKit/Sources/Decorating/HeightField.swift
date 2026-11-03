import Foundation

/// A height field of icing over one cake surface, in millimetres, with the colour on top of each
/// texel and a powder layer. The same rules as `scripts/blender/brushes.py`:
/// - beads: within a stroke the layer is the max of its stamps; it lands as
///   `max(field, base + layer)`, `base` being the field under the stroke before it began
/// - spatula: moves the field toward an even coat under a soft mask
/// - pour: `max(field, level * blob)`
/// - dust: colour only
public struct HeightField: Equatable, Sendable {
    public let width: Int
    public let height: Int
    public let mmPerTexel: Float
    /// The side strip wraps around the cake left to right.
    public let wrapsX: Bool
    public private(set) var heights: [Float]
    /// Palette index + 1 of the icing on top of each texel; 0 is bare cake.
    public private(set) var colours: [UInt8]
    /// 0...1 powder density, and its palette index + 1.
    public private(set) var dust: [Float]
    public private(set) var dustColours: [UInt8]
    /// Bumped on every change, so renderers know when to re-upload.
    public private(set) var revision = 0

    public init(width: Int, height: Int, mmPerTexel: Float, wrapsX: Bool) {
        self.width = width
        self.height = height
        self.mmPerTexel = mmPerTexel
        self.wrapsX = wrapsX
        heights = Array(repeating: 0, count: width * height)
        colours = Array(repeating: 0, count: width * height)
        dust = Array(repeating: 0, count: width * height)
        dustColours = Array(repeating: 0, count: width * height)
    }

    public func height(atX x: Float, y: Float) -> Float {
        guard let index = index(x: Int(x / mmPerTexel), y: Int(y / mmPerTexel)) else { return 0 }
        return heights[index]
    }

    private func index(x: Int, y: Int) -> Int? {
        guard y >= 0, y < height else { return nil }
        var x = x
        if wrapsX {
            x = ((x % width) + width) % width
        } else if x < 0 || x >= width {
            return nil
        }
        return y * width + x
    }

    /// Calls `body(index, value)` for every texel under `brush` centred at (cx, cy) mm.
    private func forEachTexel(_ brush: Brush, cx: Float, cy: Float, scale: Float, angle: Float,
                              _ body: (Int, Float) -> Void) {
        let half = brush.footprint * scale / 2
        let x0 = Int(floor((cx - half) / mmPerTexel)), x1 = Int(ceil((cx + half) / mmPerTexel))
        let y0 = max(Int(floor((cy - half) / mmPerTexel)), 0), y1 = min(Int(ceil((cy + half) / mmPerTexel)), height - 1)
        guard y0 <= y1 else { return }
        let c = cos(-angle), s = sin(-angle)
        let map = brush.map, n = Brush.resolution, fn = Float(n), inv = 1 / half
        for ty in y0...y1 {
            let py = (Float(ty) + 0.5) * mmPerTexel - cy
            for tx in x0...x1 {
                guard let index = index(x: tx, y: ty) else { continue }
                let px = (Float(tx) + 0.5) * mmPerTexel - cx
                let u = (px * c - py * s) * inv, v = (px * s + py * c) * inv
                guard abs(u) <= 1, abs(v) <= 1 else { continue }
                let iu = min(Int((u + 1) * 0.5 * fn), n - 1), iv = min(Int((v + 1) * 0.5 * fn), n - 1)
                let value = map[iv * n + iu]
                if value > 0 { body(index, value) }
            }
        }
    }

    /// Beads (or drizzle) along a path of (x, y) mm points.
    public mutating func stroke(_ brush: Brush, path: [SIMD2<Float>], scale: Float, colour: Int, tail: Bool) {
        let points = Self.resample(path, step: brush.footprint * scale * 0.25)
        guard !points.isEmpty else { return }
        // Dense scratch buffers; `touched` lists the texels written, so landing is cheap.
        var layer = [Float](repeating: 0, count: heights.count)
        var base = [Float](repeating: 0, count: heights.count)
        var touched: [Int] = []
        touched.reserveCapacity(4096)
        for (i, p) in points.enumerated() {
            let next = points[min(i + 1, points.count - 1)], prev = points[max(i - 1, 0)]
            let angle = atan2(next.y - prev.y, next.x - prev.x)
            let under = height(atX: p.x, y: p.y)
            let peak = brush.maxHeight * scale
            forEachTexel(brush, cx: p.x, cy: p.y, scale: scale, angle: angle) { index, value in
                if layer[index] == 0 { touched.append(index) }
                layer[index] = max(layer[index], value * peak)
                base[index] = max(base[index], under)
            }
        }
        if tail, let last = points.last {
            let peak = Brush.tail.maxHeight * scale
            forEachTexel(.tail, cx: last.x, cy: last.y, scale: scale, angle: 0) { index, value in
                if layer[index] == 0 { touched.append(index) }
                layer[index] = max(layer[index], value * peak)
            }
        }
        let tag = UInt8(clamping: colour + 1)
        for index in touched where layer[index] > 0.02 {
            let top = base[index] + layer[index]
            if top > heights[index] {
                heights[index] = top
                colours[index] = tag
            }
        }
        revision += 1
    }

    /// Spatula: toward `target` mm under the soft mask, laying `colour`.
    public mutating func spread(path: [SIMD2<Float>], target: Float, colour: Int, strength: Float = 0.6) {
        let tag = UInt8(clamping: colour + 1)
        for p in Self.resample(path, step: Brush.spatulaMask.footprint * 0.2) {
            forEachTexel(.spatulaMask, cx: p.x, cy: p.y, scale: 1, angle: 0) { index, value in
                heights[index] += (target - heights[index]) * min(value, 1) * strength
                if value > 0.3 { colours[index] = tag }
            }
        }
        revision += 1
    }

    /// A poured pool `level` mm deep.
    public mutating func pour(at p: SIMD2<Float>, scale: Float, level: Float, colour: Int) {
        let tag = UInt8(clamping: colour + 1)
        forEachTexel(.pourBlob, cx: p.x, cy: p.y, scale: scale, angle: 0) { index, value in
            let top = value * level
            if top > heights[index] {
                heights[index] = top
                colours[index] = tag
            }
        }
        revision += 1
    }

    /// Dust: a soft powder along the path, colour only.
    public mutating func dust(path: [SIMD2<Float>], radius: Float, colour: Int) {
        let tag = UInt8(clamping: colour + 1)
        for p in Self.resample(path, step: radius * 0.5) {
            forEachTexel(.dollop, cx: p.x, cy: p.y, scale: radius * 2 / Brush.dollop.footprint, angle: 0) { index, value in
                dust[index] = min(dust[index] + value * 0.25, 1)
                dustColours[index] = tag
            }
        }
        revision += 1
    }

    static func resample(_ points: [SIMD2<Float>], step: Float) -> [SIMD2<Float>] {
        guard let first = points.first, step > 0 else { return [] }
        var out = [first]
        var carried: Float = 0
        for (a, b) in zip(points, points.dropFirst()) {
            let d = simd_distance(a, b)
            guard d > 0 else { continue }
            var t = step - carried
            while t <= d {
                out.append(a + (b - a) * (t / d))
                t += step
            }
            carried = d - (t - step)
        }
        return out
    }
}

@inline(__always) func simd_distance(_ a: SIMD2<Float>, _ b: SIMD2<Float>) -> Float {
    let d = b - a
    return (d.x * d.x + d.y * d.y).squareRoot()
}
