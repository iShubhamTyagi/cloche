@testable import Decorating
import Foundation
import Testing

struct SurfaceMapperTests {
    let mapper = SurfaceMapper(geometry: .cake)

    @Test func straightDownHitsTheTopAtTheRightPolarPoint() throws {
        let hit = try #require(mapper.hit(origin: SIMD3(30, 40, 500), direction: SIMD3(0, 0, -1)))
        #expect(hit.point.surface == .top)
        #expect(abs(hit.point.a - 50) < 0.001)
        #expect(abs(hit.point.b - atan2(40, 30)) < 0.0001)
        #expect(hit.position.z == CakeGeometry.cake.height)
    }

    @Test func horizontalRayHitsTheSideAtItsHeight() throws {
        let hit = try #require(mapper.hit(origin: SIMD3(0, -400, 20), direction: SIMD3(0, 1, 0)))
        #expect(hit.point.surface == .side)
        #expect(abs(hit.point.a - (-Float.pi / 2)) < 0.0001)
        #expect(abs(hit.point.b - 20) < 0.001)
        #expect(abs(hit.normal.y + 1) < 0.0001)
    }

    @Test func positionRoundTripsThroughAHit() throws {
        for point in [SurfacePoint.top(radius: 72, angle: 2.1), .side(angle: -0.7, height: 31)] {
            let (p, n) = mapper.position(of: point)
            let hit = try #require(mapper.hit(origin: p + n * 100, direction: -n))
            #expect(hit.point.surface == point.surface)
            #expect(abs(hit.point.a - point.a) < 0.01)
            #expect(abs(hit.point.b - point.b) < 0.01)
        }
    }

    @Test func rayThatMissesReturnsNil() {
        #expect(mapper.hit(origin: SIMD3(500, 500, 500), direction: SIMD3(0, 0, -1)) == nil)
    }

    @Test func cupcakeHasNoSide() {
        let cup = SurfaceMapper(geometry: .cupcake)
        #expect(cup.hit(origin: SIMD3(0, -400, 20), direction: SIMD3(0, 1, 0)) == nil)
    }
}

struct TurntableTests {
    @Test func startsAtRestAndReachesFullSpeedAfterTheRamp() {
        var table = Turntable()
        table.toggle(at: 0, speed: 0.2)
        let full = 0.2 * 2 * Double.pi
        #expect(table.state(at: 0).velocity == 0)
        #expect(abs(table.state(at: 5).velocity - full) < 1e-9)
        #expect(table.state(at: 0.1).velocity < full)
    }

    @Test func stopsSmoothlyAndHoldsItsAngle() {
        var table = Turntable()
        table.toggle(at: 0, speed: 0.32)
        table.toggle(at: 3, speed: 0.32)
        let stopped = table.angle(at: 10)
        #expect(table.state(at: 10).velocity == 0)
        #expect(abs(table.angle(at: 20) - stopped) < 1e-9)
        #expect(table.angle(at: 3.2) < stopped)
    }

    @Test func fixedFingertipOnASpinningPlateLaysARing() {
        var table = Turntable()
        table.toggle(at: 0, speed: 0.2)
        let finger = SIMD3<Float>(60, 0, 40)
        let points = stride(from: 1.0, through: 7.0, by: 0.05).map { t -> SurfacePoint in
            let p = table.toPlate(finger, at: t)
            return .top(radius: (p.x * p.x + p.y * p.y).squareRoot(), angle: atan2(p.y, p.x))
        }
        #expect(points.allSatisfy { abs($0.a - 60) < 0.001 })
        let swept = table.angle(at: 7) - table.angle(at: 1)
        #expect(swept > 2 * .pi)   // more than a full turn: a closed ring
    }
}

struct ReplayTests {
    static let document = DecorDocument(dish: .cake, ops: [
        .spread(colour: 0, points: (0...40).map { .top(radius: 80, angle: Float($0) / 40 * 2 * .pi) }),
        .pipe(nozzle: .star, size: .medium, colour: 1, points: (0...60).map { .top(radius: 90, angle: Float($0) / 60 * 2 * .pi) }),
        .pipe(nozzle: .round, size: .small, colour: 2, points: (0...60).map { .side(angle: Float($0) / 60 * 2 * .pi, height: 30) }),
        .pour(colour: 8, at: .top(radius: 60, angle: 0.4), scale: 1),
        .sprinkles(seed: 42, at: .top(radius: 20, angle: 1), radius: 15),
        .topping(kind: "raspberry", variant: 1, at: .top(radius: 40, angle: 2), spin: 0.3),
        .dust(colour: 5, points: [.top(radius: 0, angle: 0), .top(radius: 30, angle: 0)]),
    ])

    @Test func replayIsDeterministic() {
        let a = CakeSurfaces(document: Self.document)
        let b = CakeSurfaces(document: Self.document)
        #expect(a == b)
        #expect(a.placements.count == 41)
    }

    @Test func documentSurvivesEncoding() throws {
        let data = try JSONEncoder().encode(Self.document)
        let decoded = try JSONDecoder().decode(DecorDocument.self, from: data)
        #expect(decoded == Self.document)
        #expect(CakeSurfaces(document: decoded) == CakeSurfaces(document: Self.document))
    }

    @Test func pipedRingRaisesIcingWhereItWasPiped() {
        let s = CakeSurfaces(document: Self.document)
        #expect(s.icingHeight(at: .top(radius: 90, angle: 1)) > 2)
        #expect(s.icingHeight(at: .side(angle: 1, height: 30)) > 1.5)
        #expect(s.icingHeight(at: .side(angle: 1, height: 5)) == 0)
    }

    @Test func sideStripIsSeamless() {
        // A bead across the seam (angle 0 = 2π) is continuous on both sides of it.
        var s = CakeSurfaces(geometry: .cake)
        s.apply(.pipe(nozzle: .round, size: .medium, colour: 0, points: [.side(angle: -0.2, height: 20), .side(angle: 0.2, height: 20)]))
        let before = s.icingHeight(at: .side(angle: -0.01, height: 20))
        let after = s.icingHeight(at: .side(angle: 0.01, height: 20))
        #expect(before > 2)
        #expect(abs(before - after) < 0.3)
    }

    @Test func beadsMergeInsteadOfStacking() {
        var s = CakeSurfaces(geometry: .cake)
        let line: [SurfacePoint] = (0...20).map { .top(radius: Float($0) * 3, angle: 0) }
        s.apply(.pipe(nozzle: .round, size: .medium, colour: 0, points: line))
        let once = s.icingHeight(at: .top(radius: 30, angle: 0))
        #expect(once > 2.5 && once < 3.5)
    }
}
