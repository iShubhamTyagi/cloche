import Foundation

/// One point of a spatula stroke, in plate-local terms: `s` is millimetres along the dish's
/// surface from the centre of the top, over the shoulder and down the side; `a` is the angle.
public struct CreamPoint: Codable, Equatable, Sendable {
    public var s: Float
    public var a: Float

    public init(s: Float, a: Float) {
        self.s = s
        self.a = a
    }
}

/// The dish's surface as one line from the centre of the top out and down, in millimetres
/// (r, z). Cream lives on this line turned around the axis, so it runs over the edge of a cake
/// with no seam between the top and the side.
public struct DishLine: Sendable {
    public let points: [SIMD2<Float>]
    private let arcs: [Float]
    public var length: Float { arcs.last ?? 0 }

    public init(_ p: DishProfile, hasSide: Bool) {
        var line: [SIMD2<Float>] = (0...96).map {
            let r = p.topRadius * Float($0) / 96
            return SIMD2(r, p.topHeight(atRadius: r)) * 1000
        }
        if hasSide {
            for i in 1...24 {
                let z = p.sideTop * (1 - Float(i) / 24)
                line.append(SIMD2(p.sideRadius(atHeight: max(z, p.sideBottom)), z) * 1000)
            }
        }
        var total: Float = 0
        var arcs: [Float] = [0]
        for (a, b) in zip(line, line.dropFirst()) {
            total += simd_distance(a, b)
            arcs.append(total)
        }
        points = line
        self.arcs = arcs
    }

    /// The point at arc length `s`, and the outward normal there (r, z).
    public func at(_ s: Float) -> (point: SIMD2<Float>, normal: SIMD2<Float>) {
        let s = min(max(s, 0), length)
        var lo = 0, hi = arcs.count - 1
        while hi - lo > 1 {
            let mid = (lo + hi) / 2
            if arcs[mid] <= s { lo = mid } else { hi = mid }
        }
        let t = (s - arcs[lo]) / max(arcs[hi] - arcs[lo], 1e-5)
        let a = points[max(lo - 2, 0)], b = points[min(hi + 2, points.count - 1)]
        let d = b - a
        let n = SIMD2(-d.y, d.x) / max(simd_distance(a, b), 1e-5)
        return (points[lo] + (points[hi] - points[lo]) * t, n)
    }

    /// The arc length of the point on the line nearest (r, z).
    public func arc(nearestR r: Float, z: Float) -> Float {
        var best = Float.infinity, arc: Float = 0
        for (i, p) in points.enumerated() {
            let d = (p.x - r) * (p.x - r) + (p.y - z) * (p.y - z)
            if d < best {
                best = d
                arc = arcs[i]
            }
        }
        return arc
    }

    /// Where a plate-local ray first meets the dish, by stepping down it.
    public func hit(origin: SIMD3<Float>, direction: SIMD3<Float>) -> CreamPoint? {
        let d = normalize3(direction)
        guard d.z < -1e-4, let top = points.map(\.y).max(), let reach = points.map(\.x).max() else { return nil }
        var t = (top + 1 - origin.z) / d.z
        let end = (0 - origin.z) / d.z
        while t < end {
            let p = origin + d * t
            let r = (p.x * p.x + p.y * p.y).squareRoot()
            if r <= reach, p.z <= height(atR: r) {
                return CreamPoint(s: arc(nearestR: r, z: p.z), a: atan2(p.y, p.x))
            }
            t += 0.8
        }
        return nil
    }

    private func height(atR r: Float) -> Float {
        var best = points[0].y, gap = Float.infinity
        for p in points where abs(p.x - r) < gap {
            gap = abs(p.x - r)
            best = max(p.y, 0)
        }
        return best
    }
}

/// The cream on a dish: thickness, colour and surface detail over the whole surface, changed by
/// a spatula. The rules are a small model of the real thing:
/// - a blade drags cream toward an even coat, leaving streaks along the stroke from the nicks in
///   its edge, and a raised lip at each end of the blade
/// - a first pass is thick, streaky and ragged at the sides; each further pass over the same spot
///   smooths it, as turning the cake against a still blade does
/// - a second colour doesn't replace the first, it marbles into it
///
/// Only the rows the blade touched are recomputed, and the renderer uploads only those. A class,
/// so the buffers are never copied by accident.
public final class CreamField {
    public static let rows = 384
    public static let cols = 1024

    public let line: DishLine
    public let bladeWidth: Float
    public private(set) var heights: [Float]
    /// RGBA colour (alpha 0 where there is no cream) and tangent-space normals, row by row.
    public private(set) var colour: [UInt8]
    public private(set) var normal: [UInt8]
    /// What the eye sees, worked out from the above: thin cream lets the sponge glow through, and
    /// hollows darken. Roughness is in the red channel of `gloss`: thick, worked cream is sleeker.
    public private(set) var shaded: [UInt8]
    public private(set) var gloss: [UInt8]
    /// The rows changed since the renderer last looked (nil: none).
    public private(set) var dirtyRows: ClosedRange<Int>?
    public private(set) var isEmpty = true
    private var pendingRows: ClosedRange<Int>?

    private let palette: [SIMD3<Float>]
    private var passes: [UInt8]
    private var marks: [UInt16]
    private var stroke: UInt16 = 0
    private var nicks = [Float](repeating: 0, count: 28)
    private var strokeColour = SIMD3<Float>(repeating: 0)
    private var last: CreamPoint?
    private var heading: SIMD2<Float> = SIMD2(1, 0)
    /// Cached per row: the radius there, and the length of one texel along the angle.
    private let rowRadius: [Float]
    /// Per row: 0 on the top, 1 on the side. A side is scraped smooth, so a blade's streaks and lips
    /// (which would run round it as bands) give way to fine vertical marks.
    private let rowSide: [Float]
    /// Per row: extra thickness at the foot, where the icing settles against the plate.
    private let rowFoot: [Float]
    /// Per column: the fine vertical scrape marks.
    private let scrape: [Float]
    private var rowStep: Float { line.length / Float(Self.rows - 1) }

    public static let thickness: Float = 3

    public init(line: DishLine, bladeWidth: Float, palette: [SIMD3<UInt8>]) {
        self.line = line
        self.bladeWidth = bladeWidth
        self.palette = palette.map { SIMD3(Float($0.x), Float($0.y), Float($0.z)) }
        let count = Self.rows * Self.cols
        heights = Array(repeating: 0, count: count)
        colour = Array(repeating: 0, count: count * 4)
        normal = Array(repeating: 0, count: count * 4)
        shaded = Array(repeating: 0, count: count * 4)
        gloss = Array(repeating: 160, count: count * 4)
        passes = Array(repeating: 0, count: count)
        marks = Array(repeating: 0, count: count)
        let step = line.length / Float(Self.rows - 1)
        rowRadius = (0..<Self.rows).map { line.at(Float($0) * step).point.x }
        rowSide = (0..<Self.rows).map { min(max((line.at(Float($0) * step).normal.x - 0.55) / 0.35, 0), 1) }
        let length = line.length
        rowFoot = (0..<Self.rows).map { row in
            let left = length - Float(row) * step
            let t = min(max(1 - left / 5, 0), 1)
            return t * t * (3 - 2 * t)
        }
        var rng = SplitMix64(seed: 77)
        var mark: Float = 0
        scrape = (0..<Self.cols).map { _ in
            mark = mark * 0.55 + (Float(rng.unit()) * 2 - 1) * 0.45
            return mark
        }
        reset()
    }

    public func reset() {
        heights.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        passes.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        marks.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        colour.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        shaded.withUnsafeMutableBufferPointer { $0.update(repeating: 0) }
        gloss.withUnsafeMutableBufferPointer { $0.update(repeating: 160) }
        normal.withUnsafeMutableBytes { raw in
            // Flat: (128, 128, 255, 255), little-endian.
            raw.bindMemory(to: UInt32.self).update(repeating: 0xFFFF_8080)
        }
        stroke = 0
        isEmpty = true
        pendingRows = nil
        dirtyRows = 0...(Self.rows - 1)
    }

    public func clearDirty() { dirtyRows = nil }

    /// Cream thickness (mm) at a surface point.
    public func height(s: Float, a: Float) -> Float {
        let row = min(max(Int(s / rowStep), 0), Self.rows - 1)
        return heights[row * Self.cols + column(a)]
    }

    /// Thickness at a point on the top given by its radius.
    public func height(radius r: Float, angle a: Float) -> Float {
        height(s: line.arc(nearestR: r, z: line.at(0).point.y), a: a)
    }

    private func column(_ a: Float) -> Int {
        let turn = 2 * Float.pi
        let wrapped = (a.truncatingRemainder(dividingBy: turn) + turn).truncatingRemainder(dividingBy: turn)
        return min(Int(wrapped / turn * Float(Self.cols)), Self.cols - 1)
    }

    // MARK: Strokes

    public func begin(colour index: Int, seed: UInt64) {
        var rng = SplitMix64(seed: seed)
        var value: Float = 0
        for i in nicks.indices {
            // A wandering line, not white noise: nicks are a few millimetres wide.
            value = value * 0.86 + (Float(rng.unit()) * 2 - 1) * 0.32
            nicks[i] = value
        }
        strokeColour = palette[min(max(index, 0), palette.count - 1)]
        stroke = stroke == .max ? 1 : stroke + 1
        last = nil
    }

    public func extend(to p: CreamPoint) {
        guard let from = last else {
            stamp(p)
            last = p
            return
        }
        var da = p.a - from.a
        while da > .pi { da -= 2 * .pi }
        while da < -.pi { da += 2 * .pi }
        let ds = p.s - from.s
        let r = max(line.at(p.s).point.x, 4)
        let distance = ((da * r) * (da * r) + ds * ds).squareRoot()
        guard distance > 0.3 else { return }
        heading = SIMD2(da * r, ds) / distance
        let steps = max(Int(distance / 1.6), 1)
        for i in 1...steps {
            let t = Float(i) / Float(steps)
            stamp(CreamPoint(s: from.s + ds * t, a: from.a + da * t))
        }
        last = p
    }

    public func apply(colour index: Int, seed: UInt64, points: [CreamPoint]) {
        begin(colour: index, seed: seed)
        for p in points { extend(to: p) }
    }

    /// One position of the blade: a thin bar across the direction of travel.
    private func stamp(_ p: CreamPoint) {
        let half = bladeWidth / 2
        let step = rowStep
        let row0 = max(Int((p.s - half) / step), 0), row1 = min(Int((p.s + half) / step) + 1, Self.rows - 1)
        guard row0 <= row1 else { return }
        let across = SIMD2(-heading.y, heading.x)
        let cols = Self.cols
        let turn = 2 * Float.pi
        let centre = column(p.a)
        heights.withUnsafeMutableBufferPointer { h in
            colour.withUnsafeMutableBufferPointer { c in
                passes.withUnsafeMutableBufferPointer { n in
                    marks.withUnsafeMutableBufferPointer { m in
                        for row in row0...row1 {
                            let dv = Float(row) * step - p.s
                            let r = max(rowRadius[row], 0.5)
                            let texel = turn * r / Float(cols)
                            let span = min(Int((half + 2) / texel) + 1, cols / 2)
                            for dc in -span...span {
                                let du = Float(dc) * texel
                                let along = du * heading.x + dv * heading.y
                                guard abs(along) < 2.4 else { continue }
                                let b = du * across.x + dv * across.y
                                let edge = abs(b) / half
                                guard edge < 1 else { continue }
                                let col = (centre + dc + cols) % cols
                                paint(row * cols + col, row: row, col: col, b: b, edge: edge, h: h, c: c, n: n, m: m)
                            }
                        }
                    }
                }
            }
        }
        isEmpty = false
        let touched = max(row0 - 1, 0)...min(row1 + 1, Self.rows - 1)
        pendingRows = pendingRows.map { min($0.lowerBound, touched.lowerBound)...max($0.upperBound, touched.upperBound) } ?? touched
    }

    @inline(__always)
    private func paint(_ i: Int, row: Int, col: Int, b: Float, edge: Float,
                       h: UnsafeMutableBufferPointer<Float>, c: UnsafeMutableBufferPointer<UInt8>,
                       n: UnsafeMutableBufferPointer<UInt8>, m: UnsafeMutableBufferPointer<UInt16>) {
        let bare = h[i] <= 0
        // The sides of a first pass tear: cream catches on the crumb in patches.
        if bare, edge > 0.72, Self.patch(row: row, col: col) < (edge - 0.72) * 3.2 { return }
        if m[i] != stroke {
            m[i] = stroke
            if n[i] < 200 { n[i] += 1 }
        }
        let worked = Float(n[i])
        let position = (b / bladeWidth + 0.5) * Float(nicks.count - 1)
        let k = min(max(Int(position), 0), nicks.count - 2)
        let f = position - Float(k)
        let nick = nicks[k] * (1 - f) + nicks[k + 1] * f
        let streak = nick * 1.05 / (1 + worked * worked * 0.6)
        let lip = edge > 0.84 ? (edge - 0.84) / 0.16 * 0.9 / (1 + worked * 0.8) : 0
        let side = rowSide[row]
        let target = Self.thickness + (streak + lip) * (1 - side) + side * (scrape[col] * 0.05 + rowFoot[row] * 1.1)
        h[i] = bare ? max(target, 0.4) : h[i] + (target - h[i]) * 0.5

        let at = i * 4
        if bare {
            c[at] = UInt8(strokeColour.x)
            c[at + 1] = UInt8(strokeColour.y)
            c[at + 2] = UInt8(strokeColour.z)
            c[at + 3] = 255
        } else {
            // Colours fold together along the nicks, as a blade drags one cream through another.
            let mix = min(max(0.42 + 0.5 * nick, 0.12), 0.8)
            c[at] = UInt8(Float(c[at]) + (strokeColour.x - Float(c[at])) * mix)
            c[at + 1] = UInt8(Float(c[at + 1]) + (strokeColour.y - Float(c[at + 1])) * mix)
            c[at + 2] = UInt8(Float(c[at + 2]) + (strokeColour.z - Float(c[at + 2])) * mix)
        }
    }

    /// Smooth blotches in 0...1, a few millimetres across.
    @inline(__always)
    private static func patch(row: Int, col: Int) -> Float {
        func lattice(_ x: Int, _ y: Int) -> Float {
            var v = UInt32(truncatingIfNeeded: x &* 374_761_393 &+ y &* 668_265_263)
            v = (v ^ (v >> 13)) &* 1_274_126_177
            return Float((v ^ (v >> 16)) & 0xFFFF) / 65535
        }
        let size = 11
        let x = col / size, y = row / size
        let fx = Float(col % size) / Float(size), fy = Float(row % size) / Float(size)
        let top = lattice(x, y) * (1 - fx) + lattice(x + 1, y) * fx
        let bottom = lattice(x, y + 1) * (1 - fx) + lattice(x + 1, y + 1) * fx
        return top * (1 - fy) + bottom * fy
    }

    /// Works out the surface detail for everything stamped since the last call. Once a frame,
    /// not once a stamp: a finger move can be many stamps.
    public func flush() {
        guard let rows = pendingRows else { return }
        pendingRows = nil
        refreshNormals(rows: rows)
    }

    private func refreshNormals(rows range: ClosedRange<Int>) {
        let cols = Self.cols, step = rowStep, turn = 2 * Float.pi
        // Exaggerated a little: the eye reads these marks from a distance.
        let relief: Float = 1.2
        heights.withUnsafeBufferPointer { h in
            normal.withUnsafeMutableBufferPointer { out in
                for row in range {
                    let up = max(row - 1, 0) * cols, down = min(row + 1, Self.rows - 1) * cols, here = row * cols
                    let texel = max(turn * rowRadius[row] / Float(cols), 0.15)
                    for col in 0..<cols {
                        let left = h[here + (col + cols - 1) % cols], right = h[here + (col + 1) % cols]
                        let du = (right - left) / (2 * texel) * relief
                        let dv = (h[down + col] - h[up + col]) / (2 * step) * relief
                        let inv = 1 / (du * du + dv * dv + 1).squareRoot()
                        let at = (here + col) * 4
                        out[at] = UInt8((-du * inv * 0.5 + 0.5) * 255)
                        out[at + 1] = UInt8((dv * inv * 0.5 + 0.5) * 255)
                        out[at + 2] = UInt8((inv * 0.5 + 0.5) * 255)
                    }
                }
            }
        }
        refreshLook(rows: range)
        dirtyRows = dirtyRows.map { min($0.lowerBound, range.lowerBound)...max($0.upperBound, range.upperBound) } ?? range
    }

    /// Light through thin cream, shade in the hollows, and sheen on the thick parts.
    private func refreshLook(rows range: ClosedRange<Int>) {
        let cols = Self.cols
        let under = SIMD3<Float>(214, 164, 104)
        heights.withUnsafeBufferPointer { h in
            colour.withUnsafeBufferPointer { c in
                shaded.withUnsafeMutableBufferPointer { out in
                    gloss.withUnsafeMutableBufferPointer { g in
                        for row in range {
                            let here = row * cols
                            let up = max(row - 1, 0) * cols, down = min(row + 1, Self.rows - 1) * cols
                            for col in 0..<cols {
                                let i = here + col, at = i * 4
                                let t = h[i]
                                guard t > 0 else {
                                    out[at + 3] = 0
                                    continue
                                }
                                let around = (h[here + (col + cols - 1) % cols] + h[here + (col + 1) % cols] + h[up + col] + h[down + col]) * 0.25
                                let hollow = min(max(1 + (t - around) * 1.6, 0.8), 1.05)
                                let thick = min(max((t - 0.4) / 1.8, 0), 1)
                                let body = 0.42 + 0.58 * thick * thick * (3 - 2 * thick)
                                let glow = 1 + (1 - thick) * 0.05
                                for k in 0..<3 {
                                    let cream = Float(c[at + k])
                                    let seen = (under[k] + (cream - under[k]) * body) * hollow * glow
                                    out[at + k] = UInt8(min(max(seen, 0), 255))
                                }
                                out[at + 3] = 255
                                let rough = 0.66 - 0.2 * min(t / 4, 1)
                                let value = UInt8(rough * 255)
                                g[at] = value
                                g[at + 1] = value
                                g[at + 2] = value
                            }
                        }
                    }
                }
            }
        }
    }

    /// A top-down picture of the cream, RGBA, `side` pixels square, covering the radius `reach`.
    public func topView(side: Int, reach: Float) -> [UInt8] {
        var out = [UInt8](repeating: 0, count: side * side * 4)
        let centre = Float(side) / 2
        for y in 0..<side {
            for x in 0..<side {
                let dx = (Float(x) - centre) / centre * reach, dy = (centre - Float(y)) / centre * reach
                let r = (dx * dx + dy * dy).squareRoot()
                guard r < reach else { continue }
                let s = line.arc(nearestR: r, z: line.at(0).point.y)
                let row = min(Int(s / rowStep), Self.rows - 1)
                let from = (row * Self.cols + column(atan2(dy, dx))) * 4, to = (y * side + x) * 4
                for k in 0..<4 { out[to + k] = colour[from + k] }
            }
        }
        return out
    }
}
